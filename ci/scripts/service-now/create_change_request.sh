#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh
source pipeline/ci/scripts/service-now/common.sh

CREATE_PAYLOAD=output/create_payload.json

CHANGE_REQUEST_URL=$SNOW_API_URL/now/table/change_request

function accept_change_request(){
  id=$1
  acceptance_state=2
  current_date=`date '+%Y-%m-%d %T'`

  curl_snow -X PATCH \
    -d "{\"state\":\"$acceptance_state\",\"u_acceptance_begin\":\"$current_date\"}" \
    $CHANGE_REQUEST_URL/$id > output/acceptance_response.json
}

function create_change_request(){
  curl_snow -X POST \
    -d @$CREATE_PAYLOAD \
    $CHANGE_REQUEST_URL > output/create_response.json

  return $(cat output/create_response.json | jq -r ".result.sys_id")
}

function generate_payload(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)


  CONCOURSE_URL="https:\/\/atc_external_url\/teams\/$BUILD_TEAM_NAME\/pipelines\/$BUILD_PIPELINE_NAME\/jobs\/$BUILD_JOB_NAME\/builds\/$BUILD_NAME"
  START_DATE=`date '+%Y-%m-%d %T'`
  END_DATE=`date '+%Y-%m-%d %T' -d "+$RUNNING_ESTIMATED_TIME"`

  mkdir -p output

  cp $BASE_PAYLOAD $CREATE_PAYLOAD
  sed -i -e "s/CONCOURSE_URL/$CONCOURSE_URL/g" $CREATE_PAYLOAD
  sed -i -e "s/START_DATE/$START_DATE/g" $CREATE_PAYLOAD
  sed -i -e "s/END_DATE/$END_DATE/g" $CREATE_PAYLOAD
}

load_custom_ca_certs
generate_payload

if [[ "${DRY_RUN,,}" == "false" ]] ; then
  id=$(create_change_request)

  if [[ "${SNOW_ACCEPT_CHANGE_REQUEST,,}" == "true" ]] ; then
    accept_change_request $id
  fi

  echo $id > service-now/change_request_sys_id
  echo $current_date > service-now/change_request_start_date

  cat output/create_response.json | jq ".result.number"
else
  log "Dry run ... Skipping sending request to service now"
fi

