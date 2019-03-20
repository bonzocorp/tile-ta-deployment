#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

STEMCELL=
STEMCELL_VERSION=

output_dir=./stemcell
metadata_file=./tile/metadata.json

function get_stemcell_version() {
  log "Getting stemcell version"
  # Determine the stemcell version from metadata
  STEMCELL_VERSION=$(
  cat $metadata_file |
  jq --raw-output \
    '
  [
    .Dependencies // []
    | .[]
    | select(.Release.Product.Name | contains("Stemcells"))
    | .Release.Version
  ]
  | map(split(".") | map(tonumber))
  | transpose | transpose
  | max // empty
  | map(tostring)
  | join(".")
  '
  )
  if [[ -z "$STEMCELL_VERSION" ]]; then
    log "Unable to determine stemcell version: $STEMCELL_VERSION"
  fi
}

function is_stemcell_uploaded() {
  log "Checking available stemcells"
  # If stemcell version is available, check om
  if [ -n "$STEMCELL_VERSION" ]; then
    diagnostic_report=$(
    om \
      --target $OM_TARGET \
      $om_options \
      curl \
      --silent \
      --path "/api/v0/diagnostic_report"
    )

    STEMCELL=$(
    echo $diagnostic_report |
    jq \
      --arg version "$STEMCELL_VERSION" \
      --arg glob "$IAAS" \
      '
    .stemcells[]
    | select(contains($version) and contains($glob))
    '
    )

    if [[ -n "$STEMCELL" ]]; then
      log "Stemcell $STEMCELL_VERSION found"
    else
      log "Stemcell $STEMCELL_VERSION not found"
      return 1
    fi
  fi
}

function download_stemcell() {
  if [[ -z "$STEMCELL_VERSION" ]]; then
    log "No stemcell to be downloaded"
  else
    log "Downloading stemcell $STEMCELL_VERSION"

    product_slug=$(
    cat $metadata_file |
    jq --raw-output \
      '
    if any(.Dependencies[]; select(.Release.Product.Name | contains("Stemcells for PCF (Windows)"))) then
      "stemcells-windows-server"
    elif any(.Dependencies[]; select(.Release.Product.Name | contains("Stemcells for PCF (Ubuntu Xenial)"))) then
      "stemcells-ubuntu-xenial"
    else
      "stemcells"
    end
    '
    )

    # Login and download the stemcell
    if [[ "$IAAS" == "vsphere" && "$product_slug" == "stemcells-windows-server" ]]; then
      log "Skipping because there are no vsphere Windows stemcells on Pivnet"
    else
      pivnet \
        login \
        --api-token="$PIVNET_API_TOKEN"
      pivnet \
        download-product-files \
        -p "$product_slug" \
        -r $STEMCELL_VERSION \
        -g "*${IAAS}*" \
        --accept-eula

      stemcell_file_path=`find ./ -name *.tgz`

      if [ ! -f "$stemcell_file_path" ]; then
        error "Stemcell file not found!"
      fi

      mv $stemcell_file_path $output_dir
    fi
  fi
}

get_stemcell_version
if is_stemcell_uploaded; then
  log "stemcell is already uploaded"
else
  download_stemcell
fi

