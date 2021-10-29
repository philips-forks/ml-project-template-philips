#!/bin/bash
echo "Hi, let's set up your project."

curdir=${PWD##*/}
read -r -p "Set up Docker image name [$curdir]: " project_name
project_name=${project_name:-$curdir}

read -s -p "Set up password for Jupyter: " password
echo ""

echo $password > .jupyter_password
echo $project_name > .docker_image_name

docker build -t $project_name \
    --build-arg username=$(whoami) \
    --build-arg groupname=$(id -g -n) \
    --build-arg uid=$(id -u) \
    --build-arg gid=$(id -g) \
    .
