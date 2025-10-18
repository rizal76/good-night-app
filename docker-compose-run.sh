#!/bin/bash
# docker-compose-run
export UID=$(id -u)
export GID=$(id -g)
docker-compose run --rm "$@"