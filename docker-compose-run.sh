#!/bin/bash
# docker-compose-run
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
docker-compose run --rm -e USER_ID -e GROUP_ID "$@"