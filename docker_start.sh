#!/bin/bash
set -e

# ------------- Read default image name from build output or manual input  --------------
docker_image_name=$(cat .docker_image_name)
read -r -p "Image [$docker_image_name]: " docker_image_name_input
docker_image_name=${docker_image_name_input:-$docker_image_name}

# -------------------------- Prompt for custom container name ---------------------------
container_name=$(echo $docker_image_name | tr : _)
read -r -p "Container name [$container_name]: " container_name_input
container_name=${container_name_input:-$container_name}

# ----------------------------- Prompt for workspace folder -----------------------------
ws_dump=$(cat .ws_dir)
read -r -p "Absolute path to the project workspace folder with data and experiment artifacts [$ws_dump]: " ws
ws=${ws:-$ws_dump}
if [ "$ws" ]
then
    echo $ws > .ws_dir
fi

# ---------------------------- Prompt for tensorboard folder ----------------------------
tb_dump=$(cat .tb_dir)
tb=${tb_dump:="/ws/experiments"}
read -r -p "Relative path to the tensorboard logdir [$tb]: " tb
tb=${tb:-$tb_dump}
if [ "$tb" ]
then
    echo $tb > .tb_dir
fi

# ------------------------- Prompt for GPUS visible in container ------------------------
read -p "GPUs [all]: " gpus_prompt
gpus_prompt=${gpus_prompt:-all}
gpus=\"'device=str'\"
gpus=$(sed "s/str/$gpus_prompt/g" <<< $gpus)

# ---------------------------- Prompt for host Jupyter port -----------------------------
read -p "Jupyter port [8888]: " jupyter_port
jupyter_port=${jupyter_port:-8888}

# -------------------------- Prompt for host TensorBoard port ---------------------------
read -p "TensorBoard port [6006]: " tb_port
tb_port=${tb_port:-6006}

# ------------------------------ Prompt for host SSH port -------------------------------
read -p "SSH port [22]: " ssh_port
ssh_port=${ssh_port:-22}

# -------------------------------- Start the container ----------------------------------

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
            -v $HOME/.ssh:$HOME/.ssh \
            -v ${PWD}:/code \
            -v $ws:/ws \
            --shm-size 32G \
            -p 127.0.0.1:$jupyter_port:8888 \
            -p 127.0.0.1:$tb_port:6006 \
            -p 127.0.0.1:$ssh_port:22 \
            -e TB_DIR=$tb \
            --name $container_name \
            $docker_image_name
        docker exec --user=root $container_name service ssh start
        break

    elif [ $rc == "n" ]
    then
        docker run \
            --rm \
            --gpus $gpus \
            -d \
            -v $HOME/.ssh:$HOME/.ssh \
            -v ${PWD}:/code \
            -v $ws:/ws \
            --shm-size 32G \
            -p 127.0.0.1:$jupyter_port:8888 \
            -p 127.0.0.1:$tb_port:6006 \
            -p 127.0.0.1:$ssh_port:22 \
            -e TB_DIR=$tb \
            --name $container_name \
            $docker_image_name
        docker exec --user=root $container_name service ssh start
        break
    else
        echo "Provide Y or n"
    fi
done


echo ------------------------ CONTAINER IS SUCCESSFULLY STARTED ------------------------
echo - Jupyter Lab is available at: localhost:$jupyter_port/lab  
echo - Jupyter Notebook is available at: localhost:$jupyter_port/tree
echo
echo - Connect to container via SSH: ssh -p $ssh_port root@localhost
echo - Inspect the container: docker exec -it $container_name bash
echo - Update the image: docker commit --change='CMD ~/init.sh' updated_container_name_or_hash $docker_image_name
echo
echo - Stop the container: docker stop $container_name
echo
if [ "$ws" ]
then
    echo - Inside the container $ws will be available at /ws
    echo - Tensorboard is available at: localhost:$tb_port, monitoring experiments in $tb.
fi
echo -----------------------------------------------------------------------------------

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
# --name container_name: give a name to the created container
