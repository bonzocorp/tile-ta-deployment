#!/bin/bash

exec >&2
set -e

[[ "${DEBUG,,}" == "true" ]] && set -x && env

function log() {
  green='\033[0;32m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function error() {
  green='\033[0;31m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

declare -r BBR_CMD="bbr"

declare -r OUTPUT_DIR=$PWD/output
mkdir -p $OUTPUT_DIR

declare -r BUILD_DIR=$PWD/build
mkdir -p $BUILD_DIR

declare -r BOSH_CA_CERT_FILE=$BUILD_DIR/bosh-ca.crt
declare -r BBR_SSH_KEY_FILE=$BUILD_DIR/bbr.pem

echo "$BOSH_CA_CERT" > $BOSH_CA_CERT_FILE
echo "$BBR_SSH_KEY" > $BBR_SSH_KEY_FILE

