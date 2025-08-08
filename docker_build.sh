#!/bin/bash
set -e

# Function to display help message
show_help() {
    echo -e "\033[1mUsage:\033[0m ./docker_build.sh <image_name:tag> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --deploy                         Copy code into the Docker image for standalone deployment"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo -e "\033[1mExamples:\033[0m"
    echo "  ./docker_build.sh my-image:latest"
    echo "  ./docker_build.sh my-image:latest --deploy"
    echo "  ./docker_build.sh --help"
}

# Initialize variables
DEPLOY=false

# Argument parsing
while [ $# -gt 0 ]; do
    case "$1" in
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

# Validate required arguments early if running non-interactively
if ! [ -t 0 ] && [ -z "$docker_image_name" ]; then
    echo -e "\033[31mError: <image_name:tag> is required in non-interactive mode.\033[0m" >&2
    exit 1
fi

echo -e "\033[1;32m------------------------ Hi, let's set up your project! ------------------------\033[0m"

# ---------------------------- Prompts to define variables  -----------------------------
curdir=${PWD##*/}:latest
if [[ -z $docker_image_name ]]; then
    read -r -p "Set up Docker image-name:tag [$curdir]: " docker_image_name
    docker_image_name=${docker_image_name:-$curdir}
else
    echo Docker image name parsed from args: $docker_image_name
fi

# Update or create .env file
touch .env && chmod 600 .env

# Function to update or add a key-value pair in .env
update_env_var() {
    local key="$1"
    local value="$2"
    # Escape special characters in the value for sed
    local escaped_value=$(printf '%s\n' "$value" | sed 's/[[\.*^$()+?{|]/\\&/g')
    if grep -q "^${key}=" .env 2>/dev/null; then
        # Key exists, update it using | as delimiter to avoid conflicts with special chars
        sed -i "s|^${key}=.*|${key}=${escaped_value}|" .env
    else
        # Key doesn't exist, add it
        echo "${key}=${value}" >> .env
    fi
}

update_env_var "docker_image_name" "$docker_image_name"

echo "------------------------------------ Building image -------------------------------------"
docker build -t $docker_image_name .

# ----- Install user packages from ./src to the container and submodules from ./libs ----
echo -e "\033[1;34m---------------------- Installing user packages and submodules --------------------------\033[0m"
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
    if test -f ./libs/$lib/requirements.txt; then
        echo "Installing $lib requirements.txt"
        docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -r /code/libs/$lib/requirements.txt
    fi
    if test -f ./libs/$lib/setup.py; then
        echo "Installing $lib"
        docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -e /code/libs/$lib/.
    else
        echo "$lib does not have setup.py file to install."
    fi
done
docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -e /code/.

docker stop $tmp_container_name
docker commit --change='CMD ~/start.sh' $tmp_container_name $docker_image_name
docker rm -f $tmp_container_name &>/dev/null

# Add color to build success output
echo -e "\033[1;32m------------------- Build successfully finished! ----------------------------------------\033[0m"
echo -e "\033[1;32m------------------- Start dev container: bash docker_dev.sh ---------------------------\033[0m"
echo -e "\033[1;32m------------------- Start training contaner: bash docker_train.sh ------------------------------\033[0m"
