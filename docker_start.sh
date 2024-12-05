#!/bin/bash
set -e

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --image <image_name>             Docker image name"
    echo "  -c, --container-name <name>          Container name"
    echo "  -w, --workspace <path>               Absolute path to the workspace folder"
    echo "  -d, --data-dir <path>                Absolute path to the read-only data directory"
    echo "  -g, --gpus <gpus>                    GPUs visible in container [all]"
    echo "      --jupyter-port <port>            Host port mapped to container's 8888 (Jupyter) [8888]"
    echo "      --tb-port <port>                 Host port mapped to container's 6006 (TensorBoard) [6006]"
    echo "      --restart <Y|n>                  Restart container on reboot [Y]"
    echo "      --docker-args <args>             Additional arguments to pass to docker run"
    echo "  -h, --help                           Show this help message"
}

# Initialize variables
docker_image_name=""
container_name=""
ws=""
data_dir=""
gpus_prompt=""
jupyter_port=""
tb_port=""
rc=""
docker_extra_args=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -i | --image)
        docker_image_name="$2"
        shift
        shift
        ;;
    -c | --container-name)
        container_name="$2"
        shift
        shift
        ;;
    -w | --workspace)
        ws="$2"
        shift
        shift
        ;;
    -d | --data-dir)
        data_dir="$2"
        shift
        shift
        ;;
    -g | --gpus)
        gpus_prompt="$2"
        shift
        shift
        ;;
    --jupyter-port)
        jupyter_port="$2"
        shift
        shift
        ;;
    --tb-port)
        tb_port="$2"
        shift
        shift
        ;;
    --restart)
        rc="$2"
        shift
        shift
        ;;
    --docker-args)
        docker_extra_args="$2"
        shift
        shift
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
done

# ------------- Read default image name from build output or manual input  --------------
if [ -z "$docker_image_name" ]; then
    if [ -e .docker_image_name ]; then
        docker_image_name=$(cat .docker_image_name)
    else
        docker_image_name="DOCKER_IMAGE_NAME"
    fi
    read -r -p "Image [$docker_image_name]: " docker_image_name_input
    docker_image_name=${docker_image_name_input:-$docker_image_name}
fi

# -------------------------- Prompt for custom container name ---------------------------
if [ -z "$container_name" ]; then
    container_name=$(echo $docker_image_name | tr : _)
    read -r -p "Container name [$container_name]: " container_name_input
    container_name=${container_name_input:-$container_name}
fi

# ----------------------------- Prompt for workspace folder -----------------------------
if [ -z "$ws" ]; then
    if [ -e .ws_dir ]; then
        ws_dump=$(cat .ws_dir)
    else
        ws_dump=""
    fi
    read -r -p "Absolute path to the project workspace folder with data and experiment artifacts [$ws_dump]: " ws_input
    ws=${ws_input:-$ws_dump}
    if [ "$ws" ]; then
        echo $ws >.ws_dir
        mkdir -p $ws/tensorboard_logs
    fi
fi

# ----------------------------- Prompt for data directory ------------------------------
if [ -z "$data_dir" ]; then
    if [ -e .data_dir ]; then
        data_dir_dump=$(cat .data_dir)
    else
        data_dir_dump=""
    fi
    read -r -p "Absolute path to the read-only data directory [$data_dir_dump]: " data_dir_input
    data_dir=${data_dir_input:-$data_dir_dump}
    if [ "$data_dir" ]; then
        echo $data_dir >.data_dir
    fi
fi

# ------------------------- Prompt for GPUs visible in container ------------------------
if [ -z "$gpus_prompt" ]; then
    read -p "GPUs [all]: " gpus_input
    gpus_prompt=${gpus_input:-all}
fi
gpus="device=$gpus_prompt"

# ---------------------------- Prompt for host Jupyter port -----------------------------
if [ -z "$jupyter_port" ]; then
    if [ -e .jupyter_port ]; then
        jupyter_port_dump=$(cat .jupyter_port)
    else
        jupyter_port_dump="8888"
    fi
    read -p "Jupyter forwarded port [$jupyter_port_dump] -> container's 8888: " jupyter_port_input
    jupyter_port=${jupyter_port_input:-$jupyter_port_dump}
    if [ "$jupyter_port" ]; then
        echo $jupyter_port >.jupyter_port
    fi
fi

# -------------------------- Prompt for host TensorBoard port ---------------------------
if [ -z "$tb_port" ]; then
    if [ -e .tb_port ]; then
        tb_port_dump=$(cat .tb_port)
    else
        tb_port_dump="6006"
    fi
    read -p "TensorBoard forwarded port [$tb_port_dump] -> container's 6006: " tb_port_input
    tb_port=${tb_port_input:-$tb_port_dump}
    if [ "$tb_port" ]; then
        echo $tb_port >.tb_port
    fi
fi

# ----------------------- Prompt for restart policy (on reboot) -------------------------
if [ -z "$rc" ]; then
    while true; do
        read -p "Restart container on reboot? [Y/n]: " rc_input
        rc=${rc_input:-"Y"}
        if [ "$rc" == "Y" ] || [ "$rc" == "n" ]; then
            break
        else
            echo "Provide Y or n"
        fi
    done
else
    if [ "$rc" != "Y" ] && [ "$rc" != "n" ]; then
        echo "Invalid value for --restart. Use 'Y' or 'n'."
        exit 1
    fi
fi

# -------------------------------- Start the container ----------------------------------
docker_run_options=()

if [ "$rc" == "Y" ]; then
    docker_run_options+=(--restart unless-stopped)
elif [ "$rc" == "n" ]; then
    docker_run_options+=(--rm)
fi

docker_run_options+=(--gpus \"$gpus\")
docker_run_options+=(-d)
docker_run_options+=(-v "$HOME/.ssh:/root/.ssh")
if [ "$SSH_AUTH_SOCK" ]; then
    docker_run_options+=(-v "$SSH_AUTH_SOCK:/ssh-agent")
    docker_run_options+=(-e "SSH_AUTH_SOCK=/ssh-agent")
fi
docker_run_options+=(-v "${PWD}:/code")
if [ "$ws" ]; then
    docker_run_options+=(-v "$ws:/ws")
fi
if [ "$data_dir" ]; then
    docker_run_options+=(-v "$data_dir:/data:ro")
fi
docker_run_options+=(-p "127.0.0.1:$jupyter_port:8888")
docker_run_options+=(-p "127.0.0.1:$tb_port:6006")
docker_run_options+=(--name "$container_name")
docker_run_options+=(--shm-size 32G)
docker_run_options+=(--ulimit stack=67108864)

# Include any extra docker arguments
if [ ! -z "$docker_extra_args" ]; then
    docker_run_options+=($docker_extra_args)
fi

# Run the Docker container
docker run "${docker_run_options[@]}" "$docker_image_name"

echo ""
echo "-------------------- CONTAINER HAS BEEN SUCCESSFULLY STARTED ---------------------"
echo "- Jupyter Lab is available at: localhost:$jupyter_port/lab, serving at ./notebooks"
echo "- TensorBoard is available at: localhost:$tb_port, monitoring experiments in <workspace_dir>/tensorboard_logs"
echo ""
echo "- Attach shell to the container: docker exec -it $container_name bash"
echo "- Stop the container: docker stop $container_name"
echo "- Delete the container: docker rm $container_name"
echo ""
echo "- Update the image: docker commit --change='CMD ~/init.sh' updated_container_name_or_hash $docker_image_name"
echo ""
if [ "$ws" ]; then
    echo "- Inside the container $ws will be available at /ws"
fi
echo "-----------------------------------------------------------------------------------"
