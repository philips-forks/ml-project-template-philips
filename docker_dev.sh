#!/bin/bash
set -e

# Function to display help message
show_help() {
    echo -e "\033[1mUsage:\033[0m $0 <image_name> [OPTIONS]"
    echo ""
    echo -e "\033[1mPositional arguments:\033[0m"
    echo "  image_name                              Docker image name (if omitted, read from .env)"
    echo ""
    echo -e "\033[1mOptions:\033[0m"
    echo "  -c, --container-name <name>             Container name (default: <image_name> with colons replaced by underscores)"
    echo "  -w, --workspace <path>                  Absolute path to the workspace folder (will be cached)"
    echo "  -d, --data-dir <path>                   Absolute path to the read-only data directory (will be cached)"
    echo "  -g, --gpus <gpus>                       GPUs visible in container [all]"
    echo "      --restart <Y|n>                     Restart container on reboot [Y]"
    echo "      --docker-args <args>                Additional arguments to pass to docker run"
    echo "  --non-interactive                       Run in non-interactive mode (use default values and do not prompt)"
    echo "  -h, --help                              Show this help message"
    echo ""
    echo -e "\033[1mExamples:\033[0m"
    echo "  $0 my-image:latest -c mycontainer -w /home/user/ws -d /home/user/data --gpus all --restart Y"
    echo "  $0 my-image:latest --non-interactive"
    echo "  $0 --help"
}

# Initialize variables
docker_image_name=""
container_name=""
ws=""
data_dir=""
gpus_prompt=""
rc=""
docker_extra_args=""

# Detect non-interactive mode
non_interactive=false
for arg in "$@"; do
    if [[ "$arg" == "--non-interactive" ]]; then
        non_interactive=true
        # Remove --non-interactive from arguments
        set -- "${@/--non-interactive/}"
        break
    fi
done

# Remove empty arguments (caused by set -- above)
args=()
for arg in "$@"; do
    if [[ -n "$arg" ]]; then
        args+=("$arg")
    fi
done
set -- "${args[@]}"

# -------------------- Parse positional image_name argument --------------------
if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
    docker_image_name="$1"
    shift
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -c | --container-name)
        container_name="$2"
        shift; shift ;;
    -w | --workspace)
        ws="$2"
        shift; shift ;;
    -d | --data-dir)
        data_dir="$2"
        shift; shift ;;
    -g | --gpus)
        gpus_prompt="$2"
        shift; shift ;;
    --restart)
        rc="$2"
        shift; shift ;;
    --docker-args)
        docker_extra_args="$2"
        shift; shift ;;
    -h | --help)
        show_help
        exit 0 ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1 ;;
    esac
done

# Helper to read value from .env
get_env_var() {
    local var="$1"
    if [ -f .env ]; then
        grep -E "^${var}=" .env | head -n1 | cut -d'=' -f2-
    fi
}

# ------------- Read default image name from .env or prompt user --------------
if [ -z "$docker_image_name" ]; then
    docker_image_name=$(get_env_var docker_image_name)
    if [ -z "$docker_image_name" ]; then
        docker_image_name="DOCKER_IMAGE_NAME"
        echo -e "\033[33mNo image name provided and .env not found. Using placeholder: $docker_image_name\033[0m"
    else
        echo -e "\033[33mNo image name provided, using image name from .env: $docker_image_name\033[0m"
    fi
    if [ "$non_interactive" = false ]; then
        read -r -p "Image [$docker_image_name]: " docker_image_name_input
        docker_image_name=${docker_image_name_input:-$docker_image_name}
    fi
fi

# Check if the Docker image exists, prompt to retry if not
while ! docker image inspect "$docker_image_name" >/dev/null 2>&1; do
    if [ "$non_interactive" = true ]; then
        echo -e "\033[31mDocker image '$docker_image_name' does not exist.\033[0m"
        exit 1
    fi
    echo -e "\033[31mDocker image '$docker_image_name' does not exist.\033[0m"
    read -r -p "Image [$docker_image_name]: " docker_image_name
done
echo -e "\033[36mUsing image name: $docker_image_name\033[0m"

# -------------------------- Prompt for custom container name ---------------------------
if [ -z "$container_name" ]; then
    container_name=$(get_env_var container_name)
    if [ -z "$container_name" ]; then
        container_name=$(echo $docker_image_name | tr : _)
    fi
    if [ "$non_interactive" = false ]; then
        read -r -p "Container name [$container_name]: " container_name_input
        container_name=${container_name_input:-$container_name}
    fi
fi

# Check if the container with this name already exists, prompt to retry if it does
while docker ps -a --format '{{.Names}}' | grep -wq "$container_name"; do
    if [ "$non_interactive" = true ]; then
        echo -e "\033[31mA container with the name '$container_name' already exists.\033[0m"
        exit 1
    fi
    echo -e "\033[31mA container with the name '$container_name' already exists.\033[0m"
    read -r -p "Enter a different container name: " container_name
done
echo -e "\033[36mUsing container name: $container_name\033[0m"

# ----------------------------- Prompt for workspace folder -----------------------------
if [ -z "$ws" ]; then
    ws=$(get_env_var workspace_dir)
    ws_default="${PWD}/ws"
    if [ "$non_interactive" = false ]; then
        read -r -p "Absolute path to the project workspace folder with data and experiment artifacts [${ws:-$ws_default}]: " ws_input
        ws=${ws_input:-${ws:-$ws_default}}
    else
        ws=${ws:-$ws_default}
    fi
fi

# Check if the provided ws path exists, prompt until it does
while [ ! -d "$ws" ]; do
    if [ "$non_interactive" = true ]; then
        echo -e "\033[31mWorkspace directory '$ws' does not exist.\033[0m"
        exit 1
    fi
    echo -e "\033[31mWorkspace directory '$ws' does not exist. Attempting to create it...\033[0m"
    mkdir -p "$ws"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mFailed to create workspace directory '$ws'.\033[0m"
        # Prompt for a valid workspace directory
        read -r -p "Please provide an existing workspace directory: " ws
    fi
done

echo -e "\033[36mUsing workspace directory: $ws\033[0m"

# ----------------------------- Prompt for data directory ------------------------------
if [ -z "$data_dir" ]; then
    data_dir=$(get_env_var data_dir)
    data_dir_default="${PWD}/data"
    if [ "$non_interactive" = false ]; then
        read -r -p "Absolute path to the read-only data directory [${data_dir:-$data_dir_default}]: " data_dir_input
        data_dir=${data_dir_input:-${data_dir:-$data_dir_default}}
    else
        data_dir=${data_dir:-$data_dir_default}
    fi
fi

# Check if the provided data_dir path exists, prompt until it does
while [ ! -d "$data_dir" ]; do
    if [ "$non_interactive" = true ]; then
        echo -e "\033[31mDirectory '$data_dir' does not exist.\033[0m"
        exit 1
    fi
    echo -e "\033[31mDirectory '$data_dir' does not exist. Attempting to create it...\033[0m"
    mkdir -p "$data_dir"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mFailed to create directory '$data_dir'.\033[0m"
        # Prompt for a valid data directory
        read -r -p "Please provide an existing data directory: " data_dir
    fi
done

echo -e "\033[36mUsing data directory: $data_dir\033[0m"

# ------------------------- Prompt for GPUs visible in container ------------------------
if [ -z "$gpus_prompt" ]; then
    gpus_prompt=$(get_env_var gpus)
    gpus_prompt=${gpus_prompt#device=}
    if [ "$non_interactive" = false ]; then
        read -p "GPUs [${gpus_prompt:-all}]: " gpus_input
        gpus_prompt=${gpus_input:-${gpus_prompt:-all}}
    else
        gpus_prompt=${gpus_prompt:-all}
    fi
fi
gpus="device=$gpus_prompt"
echo -e "\033[36mUsing GPUs: $gpus_prompt\033[0m"

# Show GPU memory usage if nvidia-smi is available and GPUs are present
if command -v nvidia-smi &>/dev/null; then
    echo -e "\033[1;34mCurrent GPU memory usage:\033[0m"
    nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free --format=csv,noheader,nounits \
        | awk -F, '{printf "GPU %s (%s): Used %s MiB / %s MiB (Free: %s MiB)\n", $1, $2, $4, $3, $5}'
fi

# ----------------------- Prompt for restart policy (on reboot) -------------------------
if [ -z "$rc" ]; then
    rc=$(get_env_var restart_container)
    rc=${rc:-Y}
    if [ "$non_interactive" = false ]; then
        while true; do
            read -p "Restart container on reboot? [Y/n]: " rc_input
            rc=${rc_input:-$rc}
            if [ "$rc" == "Y" ] || [ "$rc" == "n" ]; then
                break
            else
                echo "Provide Y or n"
            fi
        done
    fi
fi
if [ "$rc" != "Y" ] && [ "$rc" != "n" ]; then
    echo "Invalid value for --restart. Use 'Y' or 'n'."
    exit 1
fi
echo -e "\033[36mUsing restart policy: $rc\033[0m"

# Include any extra docker arguments
if [ ! -z "$docker_extra_args" ]; then
    echo -e "\033[36mUsing extra docker args: $docker_extra_args\033[0m"
fi

# -------------------------- Save configuration to .env file ----------------------------
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

# Ensure .env exists
touch .env && chmod 600 .env

# Update each configuration value
update_env_var "docker_image_name" "$docker_image_name"
update_env_var "container_name" "$container_name"
update_env_var "workspace_dir" "$ws"
update_env_var "data_dir" "$data_dir"
update_env_var "gpus" "$gpus"
update_env_var "restart_container" "$rc"

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
docker_run_options+=(--name "$container_name")
docker_run_options+=(--shm-size 32G)
docker_run_options+=(--ulimit stack=67108864)

# Include any extra docker arguments
if [ ! -z "$docker_extra_args" ]; then
    docker_run_options+=($docker_extra_args)
fi

# Validate required arguments early if running non-interactively
if ! [ -t 0 ] && [ -z "$docker_image_name" ]; then
    echo -e "\033[31mError: --image is required in non-interactive mode.\033[0m" >&2
    exit 1
fi

# Run the Docker container
docker run "${docker_run_options[@]}" "$docker_image_name"

GREEN='\033[1;32m'
NC='\033[0m'

# Add color to success output
success_msg="${GREEN}-------------------- CONTAINER HAS BEEN SUCCESSFULLY STARTED ---------------------${NC}
\033[1mContainer name:\033[0m $container_name

\033[1mAttach shell to the container:\033[0m docker exec -it $container_name bash
\033[1mStop the container:\033[0m docker stop $container_name
\033[1mDelete the container:\033[0m docker rm $container_name

\033[1mUpdate the image:\033[0m docker commit CONTAINER_ID $docker_image_name
\n"
if [ "$ws" ]; then
    success_msg+="Inside the container $ws will be available at /ws\n"
fi
if [ "$data_dir" ]; then
    success_msg+="Inside the container $data_dir will be available at /data (read-only)\n"
fi
success_msg+="\n"
success_msg+="This message is saved in the .hint file.\n"
success_msg+="${GREEN}-----------------------------------------------------------------------------------${NC}"

# Print to terminal
echo -e "$success_msg"

# Write plain version to .hint file (strip color codes)
echo -e "$(echo "$success_msg" | sed 's/\\033\[[0-9;]*m//g')" > .hint
