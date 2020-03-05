#!/bin/bash

exec >&2

source pipeline/ci/scripts/common.sh

function authenticate_concourse(){
  fly -t concourse login -k -u $CONCOURSE_USERNAME -p $CONCOURSE_PASSWORD -c $CONCOURSE_TARGET
}
function get_version_id(){
  regex=$1
  versions_response="$(fly -t concourse curl /api/v1/teams/$CONCOURSE_TEAM/pipelines/$PIPELINE_NAME/resources/$resource_name/versions '' -- -k)"
  version_id=$(echo $versions_response | jq -r ".[] | select(.version.product_version | contains(\"$version_regex\")) | .id")
  echo $version_id
}

function pin_versions(){
  while read pin; do
    resource_name=$(echo $pin | cut -d':' -f1)
    version_regex=$(echo $pin | cut -d':' -f2 | tr -d '[:space:]')

    if [[ -z "$(get_version_id $version_regex)" ]]; then
      fly -t concourse check-resource -r $PIPELINE_NAME/$resource_name -f product_version:$version_regex
    fi

  done < $PINS_FILE

  sleep 30

  while read pin; do
    version_regex=$(echo $pin | cut -d':' -f2 | tr -d '[:space:]')
    version_id="$(get_version_id $version_regex)"

    log "Pinning $resource_name with version matching: $version_regex"
    fly -t concourse curl /api/v1/teams/$CONCOURSE_TEAM/pipelines/$PIPELINE_NAME/resources/$resource_name/unpin '' -- -k -X PUT
    fly -t concourse curl /api/v1/teams/$CONCOURSE_TEAM/pipelines/$PIPELINE_NAME/resources/$resource_name/versions/$version_id/pin '' -- -k -X PUT
  done < $PINS_FILE
}

check_if_exists "PIPELINE_NAME is empty" $PIPELINE_NAME
check_if_exists "PINS_FILE is empty" $PINS_FILE
check_if_exists "CONCOURSE_TEAM is empty" $CONCOURSE_TEAM
check_if_exists "CONCOURSE_TARGET is empty" $CONCOURSE_TARGET
check_if_exists "CONCOURSE_USERNAME is empty" $CONCOURSE_USERNAME
check_if_exists "CONCOURSE_PASSWORD is empty" $CONCOURSE_PASSWORD

authenticate_concourse
pin_versions
