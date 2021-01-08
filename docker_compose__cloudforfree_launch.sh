#!/bin/bash

cd docker;

# Docker images must be built before running `docker-compose` commands;
# DEV NOTE: prefer default Docker Hub images; enable command below to build your own images
#./docker_build.sh

# remove existing containers if you pass --rm
if [ "$1" == '--rm' ]; then 
    docker-compose rm -f;
else
    echo "Unrecognized command-line argument: " $1
    exit
fi

# run Docker images, default to localhost on port 3000
# http://localhost:3000
docker-compose up
