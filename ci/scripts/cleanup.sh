#!/bin/bash

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/common.sh

function cleanup() {
  local bosh_ca_cert_file=$BUILD_DIR/bosh-ca.crt
  echo "$BOSH_CA_CERT" > $bosh_ca_cert_file

  log "Cleaning up"
  bbr deployment \
    --target "$BOSH_TARGET" \
    --username "$BOSH_CLIENT" \
    --deployment "$DEPLOYMENT_NAME" \
    --ca-cert $bosh_ca_cert_file \
      backup-cleanup
}

cleanup
