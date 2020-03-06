#!/bin/bash

source pipeline/ci/scripts/common.sh

function backup() {

  local output_dir=$PWD/output
  local build_dir=$PWD/build
  local bbr_ssh_key_file="$build_dir/bbr.pem"
  local bosh_ca_cert_file="$build_dir/bosh-ca.crt"

  mkdir -p $build_dir/backup

  echo "$BOSH_CA_CERT" >> $bosh_ca_cert_file
  echo "$BBR_SSH_KEY" >> $bbr_ssh_key_file

  echo "DEPLOYMENT NAME:  $DEPLOYMENT_NAME"

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

