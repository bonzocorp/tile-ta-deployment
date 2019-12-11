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

notification=output/tile_version_notification
pending_upgrades=output/pending_upgrades

echo "${PRODUCT_NAME} tile status notification:" >> $notification
if [[ $current  == $latest ]]; then
  echo "Tile \`${release}\` up to date at *v${latest}*." >> $notification
else
  echo "New \`${release}\` *v${latest}* is available. Currently running *v${current}*" >> $notification
  echo "${release},${current},${latest}" 																							 >> $pending_upgrades
fi


echo "<${url}/teams/${team}/pipelines/${pipeline} |Go to pipeline>" >> $notification

exit 0
