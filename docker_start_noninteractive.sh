#!/bin/bash
set -e

docker_image_name=$(cat .docker_image_name)
container_name=$(echo $docker_image_name | tr : _)
gpus="device=0,1"
workspace_dir=/home/artem/ws/ml-template-project
mkdir -p $workspace_dir/experiments

jupyter_port=8450
tb_port=8451
ssh_port=8455

docker run \
    --restart unless-stopped \
    --gpus $gpus \
    -d \
    -v $HOME/.ssh:$HOME/.ssh \
    -v ${PWD}:/code \
    -v $workspace_dir:/ws \
    --shm-size 32G \
    -p 127.0.0.1:$jupyter_port:8888 \
    -p 127.0.0.1:$tb_port:6006 \
    -p 127.0.0.1:$ssh_port:22 \
    -e TB_DIR=/ws/experiments \
    --name $container_name \
    $@ \
    $docker_image_name

# Run SSH service in the started container
docker exec --user=root $container_name service ssh start