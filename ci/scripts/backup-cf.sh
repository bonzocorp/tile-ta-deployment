#!/bin/bash

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/common.sh

function backup_cf() {
  local deployment_command="
    $BBR_CMD deployment
      --target $BOSH_TARGET
      --username $BOSH_CLIENT
      --deployment $PAS_DEPLOYMENT_NAME
      --ca-cert $BOSH_CA_CERT_FILE"

  mkdir -p $BUILD_DIR/cf
  pushd $BUILD_DIR/cf > /dev/null
    log "Prechecking deployment backup"
    $deployment_command pre-backup-check

    log "Backing up pas"
    $deployment_command backup --with-manifest

    log "Compressing backup files"
    tar -cvzf $OUTPUT_DIR/cf.tgz --remove-file -- *
  popd > /dev/null
}

backup_cf

