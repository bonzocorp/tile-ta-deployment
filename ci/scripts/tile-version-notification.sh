#!/bin/bash

set -e
set -x

url=$(cat metadata/atc-external-url)
team=$(cat metadata/build-team-name)
pipeline=$(cat metadata/build-pipeline-name)
job=$(cat metadata/build-job-name)
build=$(cat metadata/build-name)
current=$(cat current-tile/version)
latest=$(cat latest-tile/version)

current="${current/\#*/}"
latest="${latest/\#*/}"


cat <<EOT >> output/tile_version_notification
New tile v${latest} for ${PRODUCT_NAME} is available.
Currently running v${current}
<${url}/teams/${team}/pipelines/${pipeline} |Go to pipeline>
EOT

