#!/bin/bash

# Read default image name from build output
docker_image_name=$(cat .docker_image_name)
container_name=$(echo $docker_image_name | tr : _)
ws_dump=$(cat .ws_path)

read -r -p "Image [$docker_image_name]: " docker_image_name_input
docker_image_name=${docker_image_name_input:-$docker_image_name}

# Prompt for workspace folder
read -r -p "Absolute path to project workspace folder [$ws_dump]: " ws
ws=${ws:-$ws_dump}
if [ "$ws" ]
then
    echo $ws > .ws_path
fi

# Prompt for custom container name
read -r -p "Container name [$container_name]: " container_name_input
container_name=${container_name_input:-$container_name}

# Prompt for GPUS visible in container
read -p "GPUs [all]: " gpus_prompt
gpus_prompt=${gpus_prompt:-all}
gpus=\"'device=str'\"
gpus=$(sed "s/str/$gpus_prompt/g" <<< $gpus)

# Prompt for host Jupyter port
read -p "Jupyter port [8888]: " jupyter_port
jupyter_port=${jupyter_port:-8888}

while [ true ]
do

    read -p "Restart container on reboot? [Y/n]: " rc
    rc=${rc:-"Y"}

    if [ $rc == "Y" ]
    then
        docker run \
            --restart unless-stopped \
            --gpus $gpus \
            -d \
            -v ${PWD}:/code \
            -v $ws:/ws \
            -p 127.0.0.1:$jupyter_port:8888 \
            --user $(id -u):$(id -g) \
            --name $container_name \
            $docker_image_name
        break

    elif [ $rc == "n" ]
    then
        docker run \
            --rm \
            --gpus $gpus \
            -d \
            -v ${PWD}:/code \
            -v $ws:/ws \
            -p 127.0.0.1:$jupyter_port:8888 \
            --user $(id -u):$(id -g) \
            --name $container_name \
            $docker_image_name
        break
    else
        echo "Provide Y or n"
    fi

done


echo
echo - Jupyter Lab is now available at: localhost:$jupyter_port/lab  
echo - Jupyter Notebook is available at: localhost:$jupyter_port/tree
echo
echo - Inspect the container: docker exec -it $container_name bash
echo - Inspect the container and install packages: docker exec -it --user=root $container_name bash
echo
echo - Stop the container: docker stop $container_name
echo
if [ "$ws" ]
then
    echo - Inside the container $ws will be available at /ws
fi

# OPTIONS DESCRIPTION
# --rm: remove container after stop
# --gpus all: allows access of docker container to your GPU
# -d: runs container in detached mode
# -v ${PWD}:/code: attaches current repository folder to /code in container. 
#                  All changes in the /code folder are changes in the repo folder.
# -v $1:/ws: attaches dir, which is specified in the first arg of docker_run.sh call
#            as /ws folder. All changes in the /ws folder are changes in the attached folder.
# -p 8888:8888: maps host port 8888 to 8888 port in teh container. The former is host port, 
#               the latter is the container port (8888 is default port for jupyter)
# --user $(id -u):$(id -u): run container under current user.
#                           By default container is run by root user, hence all files in 
#                           /code and /ws are created under the root user. Usually this is
#                           undesirable behaviour.
# --name container_name: give a name to the created container
