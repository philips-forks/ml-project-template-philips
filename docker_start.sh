#!/bin/bash
set -e

# ------------- Read default image name from build output or manual input  --------------
if [ -e .docker_image_name ]; then
    docker_image_name=$(cat .docker_image_name)
else
    docker_image_name=DOCKER_IMAGE_NAME
fi

read -r -p "Image [$docker_image_name]: " docker_image_name_input
docker_image_name=${docker_image_name_input:-$docker_image_name}

# -------------------------- Prompt for custom container name ---------------------------
container_name=$(echo $docker_image_name | tr : _)
read -r -p "Container name [$container_name]: " container_name_input
container_name=${container_name_input:-$container_name}

# ----------------------------- Prompt for workspace folder -----------------------------
if [ -e .ws_dir ]; then
    ws_dump=$(cat .ws_dir)
else
    ws_dump=""
fi

read -r -p "Absolute path to the project workspace folder with data and experiment artifacts [$ws_dump]: " ws
ws=${ws:-$ws_dump}
if [ "$ws" ]; then
    echo $ws >.ws_dir
    mkdir -p $ws/tensorboard_logs
fi

# ----------------------------- Prompt for data directory ------------------------------
if [ -e .data_dir ]; then
    data_dir_dump=$(cat .data_dir)
else
    data_dir_dump=""
fi

read -r -p "Absolute path to the read-only data directory [$data_dir_dump]: " data_dir
data_dir=${data_dir:-$data_dir_dump}
if [ "$data_dir" ]; then
    echo $data_dir >.data_dir
fi

# # ---------------------------- Prompt for tensorboard folder ----------------------------
# if [ -e .ws_dir ]; then
#     tb_dump=$(cat .tb_dir)
# else
#     tb_dump=""
# fi

# tb=${tb_dump:="/ws/experiments"}
# read -r -p "Relative path to the tensorboard logdir [$tb]: " tb
# tb=${tb:-$tb_dump}
# if [ "$tb" ]; then
#     echo $tb >.tb_dir
# fi

# ------------------------- Prompt for GPUS visible in container ------------------------
read -p "GPUs [all]: " gpus_prompt
gpus_prompt=${gpus_prompt:-all}
gpus=\"'device=str'\"
gpus=$(sed "s/str/$gpus_prompt/g" <<<$gpus)

# ---------------------------- Prompt for host Jupyter port -----------------------------
if [ -e .jupyter_port ]; then
    jupyter_port_dump=$(cat .jupyter_port)
else
    jupyter_port_dump="8888"
fi
read -p "Jupyter forwarded port [$jupyter_port_dump] -> container's 8888: " jupyter_port
jupyter_port=${jupyter_port:-$jupyter_port_dump}
if [ "$jupyter_port" ]; then
    echo $jupyter_port >.jupyter_port
fi

# -------------------------- Prompt for host TensorBoard port ---------------------------
if [ -e .tb_port ]; then
    tb_port_dump=$(cat .tb_port)
else
    tb_port_dump="6006"
fi
read -p "TensorBoard forwarded port [$tb_port_dump] -> container's 6006: " tb_port
tb_port=${tb_port:-$tb_port_dump}
if [ "$tb_port" ]; then
    echo $tb_port >.tb_port
fi

# -------------------------------- Start the container ----------------------------------

while [ true ]; do
    read -p "Restart container on reboot? [Y/n]: " rc
    rc=${rc:-"Y"}
    if [ $rc == "Y" ]; then
        docker run \
            --restart always \
            --gpus $gpus \
            -d \
            -v $HOME/.ssh:/root/.ssh \
            -v ${PWD}:/code \
            -v $ws:/ws \
            -v $data_dir:/data:ro \
            -p 127.0.0.1:$jupyter_port:8888 \
            -p 127.0.0.1:$tb_port:6006 \
            --name $container_name \
            --shm-size 32G \
            --ulimit stack=67108864 \
            $docker_image_name
        break

    elif [ $rc == "n" ]; then
        docker run \
            --rm \
            --gpus $gpus \
            -d \
            -v $HOME/.ssh:$HOME/.ssh \
            -v ${PWD}:/code \
            -v $ws:/ws \
            -v $data_dir:/data:ro \
            -p 127.0.0.1:$jupyter_port:8888 \
            -p 127.0.0.1:$tb_port:6006 \
            --name $container_name \
            --shm-size 32G \
            --ulimit stack=67108864 \
            $docker_image_name
        break
    else
        echo "Provide Y or n"
    fi
done

echo ""
echo -------------------- CONTAINER HAS BEEN SUCCESSFULLY STARTED ---------------------
echo - Jupyter Lab is available at: localhost:$jupyter_port/lab, serving at ./notebooks
echo - TensorBoard is available at: localhost:$tb_port, monitoring experiments in \<workspace_dir\>/tensorboard_logs
echo
echo - Inspect the container: docker exec -it $container_name bash
echo - Update the image: docker commit --change='CMD ~/init.sh' updated_container_name_or_hash $docker_image_name
echo
echo - Stop the container: docker stop $container_name
echo
if [ "$ws" ]; then
    echo - Inside the container $ws will be available at /ws
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
