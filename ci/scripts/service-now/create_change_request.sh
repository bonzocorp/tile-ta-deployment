#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh
source pipeline/ci/scripts/service-now/common.sh

CREATE_PAYLOAD=output/create_payload.json

function send_request(){
  cr_url=$SNOW_API_URL/now/table/change_request

  curl_snow -X POST \
    -d @$CREATE_PAYLOAD \
    $cr_url > output/create_response.json

  SYS_ID=$(cat output/create_response.json | jq -r ".result.sys_id")

  CURRENT_DATE=`date '+%Y-%m-%d %T'`

  curl_snow -X PATCH \
    -d "{\"state\":\"2\",\"u_acceptance_begin\":\"$CURRENT_DATE\"}" \
    $cr_url/$SYS_ID > output/acceptance_response.json


  echo $SYS_ID > service-now/change_request_sys_id
  echo $CURRENT_DATE > service-now/change_request_start_date

  cat output/create_response.json | jq ".result.number"
}

function generate_payload(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)

  ESTIMATED_TIME="1 hours"

  CONCOURSE_URL="https:\/\/atc_external_url\/teams\/$BUILD_TEAM_NAME\/pipelines\/$BUILD_PIPELINE_NAME\/jobs\/$BUILD_JOB_NAME\/builds\/$BUILD_NAME"
  START_DATE=`date '+%Y-%m-%d %T'`
  sleep 2
  END_DATE=`date '+%Y-%m-%d %T'`

  mkdir -p output

  cp $BASE_PAYLOAD $CREATE_PAYLOAD
  sed -i -e "s/CONCOURSE_URL/$CONCOURSE_URL/g" $CREATE_PAYLOAD
  sed -i -e "s/START_DATE/$START_DATE/g" $CREATE_PAYLOAD
  sed -i -e "s/END_DATE/$END_DATE/g" $CREATE_PAYLOAD
}


load_custom_ca_certs
generate_payload
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  send_request
else
  log "Dry run ... Skipping sending request to service now"
fi

