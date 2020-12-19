#!/bin/bash

docker build -t cloudff_app ./docker/app;
docker build -t cloudff_db ./docker/db;
