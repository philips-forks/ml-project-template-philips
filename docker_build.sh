#!/bin/bash
set -e

while [ $# -gt 0 ]; do
    if [[ $1 == "--"* ]]; then
        v="${1/--/}"
        declare "$v"="$2"
        shift
    fi
    shift
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


if [[ -z $ssh_password ]]; then
    read -s -p "Set up SSH password: " ssh_password
    echo ""
else
    echo SSH password parsed from args. Saved into `.ssh_password`
fi


if [[ -z $jupyter_password ]]; then
    read -s -p "Set up Jupyter password: " jupyter_password
    echo ""
else
    echo Jupyter password parsed from args. Saved into `.jupyter_password`
fi

echo $jupyter_password > .jupyter_password
echo $ssh_password > .ssh_password
echo $docker_image_name > .docker_image_name
echo "" > .ws_dir
echo "" > .tb_dir


# ------------------------------------ Build docker -------------------------------------
docker build -t $docker_image_name \
    --build-arg userpwd=$ssh_password \
    .


tmp_container_name=tmp_${docker_image_name}_$RANDOM
# ----- Install user packages from ./src to the container and submodules from ./libs ----
docker run -dt -v ${PWD}:/code --name $tmp_container_name --entrypoint="" $docker_image_name bash
for lib in $(ls ./libs)
    do
        if test -f ./libs/$lib/setup.py; then
            echo "Installing $lib"
            docker exec $tmp_container_name pip install -e /code/libs/$lib/.
        else 
            echo "$lib does not have setup.py file to install."
        fi
    done
docker exec $tmp_container_name pip install -e /code/.
docker stop $tmp_container_name
docker commit --change='CMD ~/init.sh' $tmp_container_name $docker_image_name
docker rm $tmp_container_name &> /dev/null


echo "------------------ Build successfully finished! --------------------------------"
echo "------------------ Start the container: bash docker_start_interactive.sh -------------------"
