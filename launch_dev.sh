#!/bin/bash

cd docker;

# Ensure the docker images are built
./build_docker.sh

# Remove the existing containers if you pass --rm
echo "\$1 = $1";
if [ "$1" == '--rm' ]; then 
  docker-compose rm -f;
fi

# Run the test environment on port 3000
docker-compose up

