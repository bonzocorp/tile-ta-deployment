#!/bin/bash

exec >&2
set -e

function curl_snow() {
  curl --user $SNOW_USERNAME:$SNOW_PASSWORD \
    -H "Content-Type: application/json" \
    "$@"
}
