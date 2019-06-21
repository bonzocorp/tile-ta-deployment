#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh
source pipeline/ci/scripts/service-now/common.sh

# state (close complete) 3
# u_implementation_result
#  <option value="" role="option">-- None --</option>
#  <option value="Implemented - Successfully" role="option">Implemented - Successfully</option>
#  <option value="Implemented - With error / issue" role="option">Implemented - With error / issue</option>
#  <option value="Not Implemented" role="option">Not Implemented</option>
#  <option value="Implemented Partially" role="option">Implemented Partially</option>
#  <option value="Not Implemented - Rolled Back" role="option">Not Implemented - Rolled Back</option>
# u_actual_start DATE
# u_actual_end DATE
# work_notes

CLOSED_STATE=3

function send_request(){
  ct_url=$SNOW_API_URL/now/table/change_task
  SYS_ID=$( cat service-now/change_request_sys_id)
  ACTUAL_START=$( cat service-now/change_request_start_date)
  ACTUAL_END=`date '+%Y-%m-%d %T'`

  curl_snow -X GET \
    $ct_url?change_request=$SYS_ID > output/get_task_response.json

  TASK_SYS_ID="$(cat output/get_task_response.json | jq -r '.result[0].sys_id')"

  curl_snow -X PATCH \
    -d "{\"u_implementation_result\":\"$IMPLEMENTATION_RESULT\",\
        \"u_actual_start\":\"$ACTUAL_START\",\
        \"u_actual_end\":\"$ACTUAL_END\",\
        \"state\":\"$CLOSED_STATE\",\
        \"work_notes\":\"Concourse build finished\"}" \
    $ct_url/$TASK_SYS_ID > output/close_task_response.json
}

load_custom_ca_certs
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  send_request
else
  log "Dry run ... Skipping sending request to service now"
fi
