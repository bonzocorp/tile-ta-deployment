# Tile-ta-deployment

Travel agent deployment project to deploy pivotal tiles


## Global features

**slack_updates**

Sends slack notification when a new tile is available.

**update_deployment**

When enabled it will create update jobs for each of your environments. This can be useful when
you do not want a new tile or stemcell to apply when deploying.

**pin_versions**

__Note__: Requires concourse v5

Pins resources to provided version through a yaml config file.

## Environment Features

**slack_updates**

Requires global **slack_updates**. Sends slack notification when a deployment upgrade finishes.

**allow_destroy**

When enabled it will add a destroy job to remove the tile in the provided environment.
Recomended only for dev environments.

**artifactory_stemcell**

Download stemcell from artifactory instead of pivnet

**service_now**

Available values: `create`, `create-and-close`
      o

It create a change request. If set with `create-and-close`
it will change the state of the request to implemented and
after running the upgrade/update deployment it closes any
change task associated to the change request.

**backup**

Currently only tested for bbr backups with the elastic-runtime tile.

Available opts:
 *on_updates*: performs backup before updates  only
 *backup_daily*: performs backups before updates and daily
