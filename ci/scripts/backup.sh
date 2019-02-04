#!/bin/bash

exec >&2
set -e

[[ "${DEBUG,,}" == "true" ]] && set -x && env

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/common.sh

function backup() {
  local output_dir=$PWD/output
  local build_dir=$PWD/build
  local bosh_ca_cert_file=$BUILD_DIR/bosh-ca.crt
  local bbr_ssh_key_file=$BUILD_DIR/bbr.pem

  local deployment_command="
    bbr deployment
      --target $BOSH_TARGET
      --username $BOSH_CLIENT
      --deployment $DEPLOYMENT_NAME
      --ca-cert $bosh_ca_cert_file"

  echo "$BOSH_CA_CERT" > $bosh_ca_cert_file
  echo "$BBR_SSH_KEY" > $bbr_ssh_key_file

  mkdir -p $output_dir
  mkdir -p $build_dir/backup

  pushd $BUILD_DIR/backup > /dev/null
    log "Prechecking deployment backup"
    $deployment_command pre-backup-check

    log "Backing up pas"
    $deployment_command backup --with-manifest

    log "Compressing backup files"
    tar -cvzf $output_dir/backup.tgz --remove-file -- *
  popd > /dev/null
}

backup

