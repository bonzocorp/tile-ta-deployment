#!/bin/bash

exec >&2
set -e

if [[ "${DEBUG,,}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env
fi

# Extra options to append to the OM command
om_options=""
if [[ $OM_SKIP_SSL_VALIDATION == true ]]; then
  om_options+=" --skip-ssl-validation"
fi
if [[ $OM_TRACE == true ]]; then
  om_options+=" --trace"
fi
om_options+=" --request-timeout ${OM_REQUEST_TIMEOUT:-3600}"

OUTPUT=output
mkdir -p $OUTPUT

function load_custom_ca_certs(){
  if [[ ! -z "$CUSTOM_CERTS" ]] ; then
    echo -e "$CUSTOM_CERTS" > custom_certs.crt
    csplit -k -f /etc/ssl/certs/ -b "%04d.crt" custom_certs.crt '/END CERTIFICATE/+1' '{*}'
  fi

  update-ca-certificates
}

function log() {
  green='\033[0;32m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function warning() {
  orange='\033[1;33m'
  reset='\033[0m'

  echo -e "${orange}$1${reset}"
}

function error() {
  red='\033[0;31m'
  reset='\033[0m'

  echo -e "${red}$1${reset}"
  exit 1
}

function generate_config() {
  log "Generating config files ..."

  find_or_create $PRODUCT_CONFIG
  spruce merge --prune meta $PRODUCT_CONFIG  2>/dev/null > $OUTPUT/product_config.yml

  find_or_create $ERRANDS_CONFIG
  spruce merge --prune meta $ERRANDS_CONFIG  2>/dev/null > $OUTPUT/errands.yml
}

function check_if_exists(){
  ERROR_MSG=$1
  CONTENT=$2

  if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
    echo $ERROR_MSG
    exit 1
  fi
}

function apply_changes() {
   om apply-changes  \
      -c $OUTPUT/errands.yml \
      --product-name $PRODUCT_NAME
}

function find_or_create() {
  for file in "$@"; do
    basedir=$(dirname "$file")
    mkdir -p $basedir
    if [[ ! -s "$file" ]] ; then
      echo -e "---\n{}" > $file
    fi
  done
}

load_custom_ca_certs
