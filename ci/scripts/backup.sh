#!/bin/bash

exec >&2
set -e

[[ "${DEBUG,,}" == "true" ]] && set -x && env

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/common.sh

function backup() {

  local output_dir=$PWD/output
  local build_dir=$PWD/build

  mkdir -p $build_dir/backup

  echo "$BOSH_CA_CERT" >> $build_dir/bosh-ca.crt
  echo "$BBR_SSH_KEY" >> $build_dir/bbr.pem

  echo "DEPLOYMENT NAME:  $DEPLOYMENT_NAME"

  local bosh_ca_cert_file="$build_dir/bosh-ca.crt"
  local bbr_ssh_key_file="$build_dir/bbr.pem"

  local deployment_command="
    bbr deployment
      --target $BOSH_TARGET
      --username $BOSH_CLIENT
      --deployment $DEPLOYMENT_NAME
      --ca-cert $bosh_ca_cert_file"

  pushd $build_dir/backup > /dev/null
    log "Prechecking deployment backup"
    $deployment_command pre-backup-check

    log "Backing up pas"
    $deployment_command backup --with-manifest

    log "Compressing backup files"
    tar -cvzf $output_dir/backup.tgz *
    rm -rf *
  popd > /dev/null
}

backup

