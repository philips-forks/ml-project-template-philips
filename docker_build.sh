#!/bin/bash
set -e

# Function to display help message
show_help() {
    echo "Usage: ./docker_build.sh <image_name[:tag]> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install-jupyter                Install Jupyter"
    echo "  --jupyter-pwd <jupyterpwd>       Set Jupyter password"
    echo "  --install-tensorboard            Install TensorBoard"
    echo "  -h, --help                       Show this help message"
}

# Argument parsing
while [ $# -gt 0 ]; do
    case "$1" in
    --jupyter-pwd)
        jupyter_password="$2"
        shift 2
        ;;
    --install-jupyter)
        install_jupyter=true
        shift
        ;;
    --install-tensorboard)
        install_tensorboard=true
        shift
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *)
        if [[ -z $docker_image_name ]]; then
            docker_image_name="$1"
        fi
        shift
        ;;
    esac
done

echo "------------------------ Hi, let's set up your project! ------------------------"

# ---------------------------- Prompts to define variables  -----------------------------
curdir=${PWD##*/}
if [[ -z $docker_image_name ]]; then
    read -r -p "Set up Docker image name[:tag] [$curdir]: " docker_image_name
    docker_image_name=${docker_image_name:-$curdir}
else
    echo Docker image name parsed from args: $docker_image_name
fi

if [[ -z $jupyter_password ]]; then
    read -s -p "Set up Jupyter password: " jupyter_password
    echo ""
else
    echo Jupyter password parsed from args. Saved into '.jupyter_password'
fi

if [[ -z $install_jupyter ]]; then
    read -r -p "Install Jupyter? (y/n): " install_jupyter
    install_jupyter=${install_jupyter,,}   # to lowercase
    install_jupyter=${install_jupyter:0:1} # first character
    install_jupyter=$([[ $install_jupyter == "y" ]] && echo true || echo false)
else
    echo "Install Jupyter parsed from args: $install_jupyter"
fi

if [[ -z $install_tensorboard ]]; then
    read -r -p "Install TensorBoard? (y/n): " install_tensorboard
    install_tensorboard=${install_tensorboard,,}   # to lowercase
    install_tensorboard=${install_tensorboard:0:1} # first character
    install_tensorboard=$([[ $install_tensorboard == "y" ]] && echo true || echo false)
else
    echo "Install TensorBoard parsed from args: $install_tensorboard"
fi

echo $jupyter_password >.jupyter_password
echo $docker_image_name >.docker_image_name
echo "" >.ws_dir
echo "" >.tb_dir

# ------------------------------------ Build docker -------------------------------------
docker build -t $docker_image_name \
    --build-arg JUPYTERPWD=$jupyter_password \
    --build-arg INSTALL_JUPYTER=$install_jupyter \
    --build-arg INSTALL_TENSORBOARD=$install_tensorboard \
    .

# ----- Install user packages from ./src to the container and submodules from ./libs ----
tmp_container_name=tmp_${docker_image_name%%:*}_$RANDOM
docker run -dt -v ${PWD}:/code --name $tmp_container_name --entrypoint="" $docker_image_name bash
for lib in $(ls ./libs); do
    if test -f ./libs/$lib/setup.py; then
        echo "Installing $lib"
        docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -e /code/libs/$lib/.
    else
        echo "$lib does not have setup.py file to install."
    fi
done
docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -e /code/.
docker stop $tmp_container_name
docker commit --change='CMD ~/init.sh' $tmp_container_name $docker_image_name
docker rm $tmp_container_name &>/dev/null

echo "------------------ Build successfully finished! --------------------------------"
echo "------------------ Start the container: bash docker_start_interactive.sh -------------------"
