#!/bin/bash

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/common.sh

function cleanup_cf() {
  log "Cleaning up cf"
  $BBR_CMD deployment \
    --target "$BOSH_TARGET" \
    --username "$BOSH_CLIENT" \
    --deployment "$PAS_DEPLOYMENT_NAME" \
    --ca-cert $BOSH_CA_CERT_FILE \
      backup-cleanup
}

cleanup_cf

