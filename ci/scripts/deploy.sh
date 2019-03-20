#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function generate_config() {
  log "Generating config files ..."

  find_or_create "$NETWORK_CONFIG $PROPERTIES_CONFIG $RESOURCES_CONFIG"

  spruce merge --prune meta $NETWORK_CONFIG    2>/dev/null | spruce json 2>/dev/null > $OUTPUT/network.json
  spruce merge --prune meta $PROPERTIES_CONFIG 2>/dev/null | spruce json 2>/dev/null > $OUTPUT/properties.json
  spruce merge --prune meta $RESOURCES_CONFIG  2>/dev/null | spruce json 2>/dev/null > $OUTPUT/resources.json

  if [ -n "$ERRANDS_CONFIG" ]; then
    spruce merge --prune meta $ERRANDS_CONFIG  2>/dev/null | spruce json 2>/dev/null > $OUTPUT/errands.json
  fi
}

function upload_stemcell() {
  stemcell_file_path=`find ./stemcell -name *.tgz | sort | head -1`

  if [[ -n $stemcell_file_path ]]; then
    log "Uploading stemcell: $stemcell_file_path"
    om -t $OM_TARGET \
      $om_options \
      upload-stemcell \
      -s $stemcell_file_path
  else
    log "Skipping stemcell upload. No stemcell found."
  fi
}

function fetch_opsman_creds() {
  log "Grabbing credentials from opsman"
	# Grab the guid of the product we are deploying
  product_guid=$(get_product_guid)

  tmp=$OUTPUT/tmp
  mkdir -p $tmp
  out=$OUTPUT/store.yml

  log "Initializing the store"
	# Set up initial running creds file
  {
    echo '---'
    echo '{}'
  } > $tmp/store.yml

  log "Adding each credential"
  count=0
	# Loop through each credential identifier
  for cred in $(om -t $OM_TARGET $om_options curl --path /api/v0/deployed/products/$product_guid/credentials | jq -r '.credentials[]'); do
    count=$((count+1))
		# Create an ops file to add the yaml entry the running creds file
    {
      echo "- type: replace"
      echo "  path: /$cred?"
      echo "  value: ((credential.value))"
    } > $tmp/ops.yml

		# Pull the value from opsman into a yaml file
    om \
      -t $OM_TARGET \
      $om_options \
      curl \
        --path /api/v0/deployed/products/$product_guid/credentials/$cred \
    | jq '.' \
    | spruce merge \
    > $tmp/vars.yml

		# Update the creds file with the value needed
    bosh int $tmp/store.yml \
			-o $tmp/ops.yml \
			-l $tmp/vars.yml \
		> $out

		# Replace the rolling creds file with the current
		cp $out $tmp/store.yml
  done

  log "Added $count credentials"
}

function sanitize_opsman_creds() {
  log "Sanitizing credentials from opsman"
  yaml2vault -f $OUTPUT/store.yml -p $YAML2VAULT_PREFIX > ${OUTPUT}/sanitized-store.yml
}

function replicate_product() {
  if [[ -n "${REPLICATOR_NAME}" ]]; then
    log "Replicating product: $product_file_path -> $REPLICATOR_NAME"
    product_file_path=`find ./tile -name *.pivotal | sort | head -1`
    echo "replicating product: $product_file_path"
    replicator \
      -name "$REPLICATOR_NAME" \
      -path "$product_file_path" \
      -output ./tile/$REPLICATOR_NAME.pivotal
    mv $product_file_path $product_file_path.bak
  else
    log "Skipping Replicating: No REPLICATOR_NAME provided."
  fi
}

function winfs_inject_product() {
  # Replicate the product
  if [[ "${WINDOWS,,}" == "true" ]]; then
    log "winfs injecting product: $product_file_path"
    product_file_path=`find ./tile -name *.pivotal | sort | head -1`
    winfs-injector \
      -i "$product_file_path" \
      -o ./tile/$PRODUCT_NAME-injected.pivotal
    mv $product_file_path $product_file_path.bak
  else
    log "Skipping winfs injecting product: WINDOWS is empty or false."
  fi
}

function upload_product() {
  product_file_path=`find ./tile -name *.pivotal | sort | head -1`

  if [[ -n $product_file_path ]]; then
    log "Uploading product: $product_file_path"
    om -t $OM_TARGET \
      $om_options \
      upload-product \
      -p $product_file_path
  else
    log "Skipping product upload. No product found."
  fi

}

function stage_product() {
  if [[ -d ./tile ]]; then
    log "Staging product: $PRODUCT_NAME"

    product_version=$(cat ./tile/version | sed 's/#.*//')
    product_version=$( om -t $OM_TARGET $om_options available-products --format json | \
      jq -r --arg PRODUCT_VERSION "$product_version" --arg PRODUCT_NAME "$PRODUCT_NAME" \
      '.[] | select(.name == $PRODUCT_NAME and (.version | test($PRODUCT_VERSION; "i"))) | .version'
    )

    log "Version: $product_version"

    om -t $OM_TARGET \
      $om_options \
      stage-product \
      -p $PRODUCT_NAME \
      -v $product_version
  else
    log "Staging product: $PRODUCT_NAME version $product_version"
  fi
}

function configure_product() {
  log "Configuring product"
  om -t $OM_TARGET \
    $om_options \
    configure-product \
      --product-name "$PRODUCT_NAME" \
      --product-network "$(cat $OUTPUT/network.json)" \
      --product-resources "$(cat $OUTPUT/resources.json)" \
      --product-properties "$(cat $OUTPUT/properties.json)"
}

function configure_errands() {
  if [[ -f $OUTPUT/errands.json ]]; then
    log "Configuring product errands"
    cat $OUTPUT/errands.json \
      | jq -r '.errands | .[] | to_entries | "--errand-name \(.[0].value) --\(.[1].key)-state \(.[1].value)"' \
      | while read err_cmd; do
        cmd="om -t $OM_TARGET $om_options set-errand-state --product-name $PRODUCT_NAME $err_cmd"
        log "Running command: $cmd"
        eval $cmd
      done
  else
    log "No errands configuration found"
  fi
}

function commit_config(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)

  log "Cloning config as config-mod"
  git clone config config-mod

  if [[ -s ${OUTPUT}/sanitized-store.yml ]]; then
    log "Adding store file"
    cp ${OUTPUT}/sanitized-store.yml ${STORE_FILE/config/config-mod}
    git -C config-mod add ${STORE_FILE/config\//}
  fi

  pushd config-mod > /dev/null
    log "Setting up git configurations"
    git config --global user.name $GIT_USERNAME
    git config --global user.email $GIT_EMAIL

    if ! git diff-index --quiet HEAD --; then
      log "Commiting"
      git commit -m "Updates store file: https://$ATC_EXTERNAL_URL/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME "
    fi
  popd > /dev/null
}

trap "commit_config" EXIT

load_custom_ca_certs
generate_config
upload_stemcell
replicate_product
winfs_inject_product
upload_product
stage_product
configure_product
configure_errands
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  apply_changes
  fetch_opsman_creds
  sanitize_opsman_creds
else
  log "Dry run ... Skipping apply changes"
fi
