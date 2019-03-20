#!/bin/bash

exec >&2
set -e

[[ "${DEBUG,,}" == "true" ]] && set -x

# Extra options to append to the OM command
om_options=""
if [[ $OM_SKIP_SSL_VALIDATION == true ]]; then
  om_options+=" --skip-ssl-validation"
fi
if [[ $OM_TRACE == true ]]; then
  om_options+=" --trace"
fi
om_options+=" --request-timeout ${OM_REQUEST_TIMEOUT:-3600}"

OUTPUT=output
mkdir -p $OUTPUT

function load_custom_ca_certs(){
  if [[ ! -z "$CUSTOM_ROOT_CA" ]] ; then
    echo -e "$CUSTOM_ROOT_CA" > /etc/ssl/certs/custom_root_ca.crt
  fi

  if [[ ! -z "$CUSTOM_INTERMEDIATE_CA" ]] ; then
    echo -e "$CUSTOM_INTERMEDIATE_CA" > /etc/ssl/certs/custom_intermediate_ca.crt
  fi

  update-ca-certificates
}

function log() {
  green='\033[0;32m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function warning() {
  orange='\033[1;33m'
  reset='\033[0m'

  echo -e "${orange}$1${reset}"
}

function error() {
  red='\033[0;31m'
  reset='\033[0m'

  echo -e "${red}$1${reset}"
  exit 1
}

function check_if_exists(){
  ERROR_MSG=$1
  CONTENT=$2

  if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
    echo $ERROR_MSG
    exit 1
  fi
}

function find_or_create(){
  files=$1

  for file in $files; do
    if [ ! -f "$file" ]; then
      warning "$file is empty; skipping merge of this file"
      echo -e "---\n{}" > $file
    fi
  done
}

function apply_changes() {
  product_guid="$(get_product_guid)"

  installation_id=""
  if [ -z "$product_guid" ];then
    log "Applying changes"

    installation_id=$(
      om -t $OM_TARGET \
        $om_options \
        curl $CURL_OPTS \
          --path /api/v0/installations \
          --request POST | jq -r '.install.id'
    )

  else
    log "Applying changes on $product_guid"
    installation_id=$(
      om -t $OM_TARGET \
        $om_options \
        curl \
          --path /api/v0/installations \
          --request POST \
          --data '{"deploy_products": ["'$product_guid'"]}' \
      | jq -r '.install.id'
    )

  fi
  log "Watching installation $installation_id"

  status=$( get_installation_status $installation_id )
  while [[ $status == 'running' ]]; do
    echo -n '.'
    sleep 1

    status=$( get_installation_status $installation_id )
  done

  echo "Installation $installation_id $status!"
  echo "You can view logs at https://$OM_TARGET/installation_logs/$installation_id"
  if [[ $status == succeeded ]]; then
    return 0
  else
    return 1
  fi
}

function get_installation_status() {
  local id="$1"

  om -t $OM_TARGET \
    $om_options \
    curl \
      --path /api/v0/installations/$id \
    2>/dev/null \
  | jq -r '.status'
}

function get_product_guid() {
  om -t $OM_TARGET \
    $om_options \
    curl \
      --path /api/v0/staged/products \
  | jq -r '.[] | select(.type == "'$PRODUCT_NAME'") | .guid'
}

load_custom_ca_certs
