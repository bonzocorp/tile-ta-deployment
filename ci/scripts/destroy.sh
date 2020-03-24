#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function configure_errands() {
  log "Configuring errands"

  name=""
  product_guid=$(get_product_guid)

  om -t $OM_TARGET $om_options \
    curl --path /api/v0/staged/products/$product_guid/errands \
    | jq -r '.errands[]' \
    > $OUTPUT/errands.json

  jq -c '' $OUTPUT/errands.json | while read i; do
    name=`echo $i | jq '.name' -r`

    if [ $(echo $i | jq -e 'has("post_deploy")') == true ]; then
      om -t $OM_TARGET $om_options \
      curl --path /api/v0/staged/products/$product_guid/errands \
      -x PUT \
      -H "Content-Type: application/json" \
      -d '{
            "errands": [
              {
                "name": "'"${name}"'",
                "post_deploy": true
              }
            ]
          }'
    elif [ $(echo $i | jq -e 'has("pre_delete")') == true ]; then
      om -t $OM_TARGET $om_options \
      curl --path /api/v0/staged/products/$product_guid/errands \
      -x PUT \
      -H "Content-Type: application/json" \
      -d '{
            "errands": [
              {
                "name": "'"${name}"'",
                "pre_delete": true
              }
            ]
          }'
    fi
  done
}

function unstage_product() {
  log "Unstaging product: $PRODUCT_NAME"

  om -t $OM_TARGET \
    $om_options \
    unstage-product \
    -p $PRODUCT_NAME
}

unstage_product
if [[ "${DRY_RUN,,}" != "true" ]] ; then
  configure_errands
  apply_changes
else
  log "Dry run ... Skipping apply changes"
fi
