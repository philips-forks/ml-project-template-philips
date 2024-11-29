#!/bin/bash
set -e

# Function to display help message
show_help() {
    echo "Usage: ./docker_build.sh <image_name:tag> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --jupyter-pwd <jupyterpwd>       Set Jupyter password"
    echo "  --deploy                         Copy code into the Docker image for standalone deployment"
    echo "  -h, --help                       Show this help message"
}

# Initialize variables
DEPLOY=false

# Argument parsing
while [ $# -gt 0 ]; do
    case "$1" in
    --jupyter-pwd)
        jupyter_password="$2"
        shift 2
        ;;
    --deploy)
        DEPLOY=true
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
curdir=${PWD##*/}:latest
if [[ -z $docker_image_name ]]; then
    read -r -p "Set up Docker image-name:tag [$curdir]: " docker_image_name
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
echo $jupyter_password >.jupyter_password

echo $docker_image_name >.docker_image_name

echo "------------------------------------ Building image -------------------------------------"
docker build -t $docker_image_name \
    --build-arg JUPYTERPWD=$jupyter_password \
    .

# ----- Install user packages from ./src to the container and submodules from ./libs ----
echo "---------------------- Installing user packages and submodules --------------------------"
tmp_container_name=tmp_${docker_image_name%%:*}_$RANDOM

if [ ${DEPLOY} = true ]; then
    echo "---------------------- Deploying code into the image --------------------------"
    # Run the container without mounting the code
    docker run -dt --name $tmp_container_name --entrypoint="" $docker_image_name bash
    # Copy code into the container
    docker cp . $tmp_container_name:/code
else
    # Mount the code directory
    docker run -dt -v ${PWD}:/code --name $tmp_container_name --entrypoint="" $docker_image_name bash
fi

# Install packages
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

echo "------------------- Build successfully finished! ----------------------------------------"
echo "------------------- Start a container: bash docker_start.sh -----------------------------"
