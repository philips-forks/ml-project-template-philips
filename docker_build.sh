#!/bin/bash
set -e

# Colors for output
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Function to display help message
show_help() {
    echo -e "\033[1mUsage:\033[0m $0 [image_name:tag] [OPTIONS]"
    echo ""
    echo -e "\033[1mDescription:\033[0m"
    echo "  Build a Docker image for the ML project."
    echo "  This script will build the image and install all dependencies from src/ and libs/."
    echo ""
    echo -e "\033[1mPositional arguments:\033[0m"
    echo "  image_name:tag                   Docker image name and tag to build (optional, will prompt if not provided)"
    echo ""
    echo -e "\033[1mOptions:\033[0m"
    echo "      --deploy                     Copy code into the Docker image for standalone deployment"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo -e "\033[1mExamples:\033[0m"
    echo "  # Interactive mode (will prompt for image name)"
    echo "  $0"
    echo ""
    echo "  # Build development image (code mounted)"
    echo "  $0 my-image:latest"
    echo ""
    echo "  # Build deployment image (code copied)"
    echo "  $0 my-image:latest --deploy"
}

# Initialize variables
DEPLOY=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy)
            DEPLOY=true
            shift
        ;;
        -h|--help)
            show_help
            exit 0
        ;;
        *)
            if [[ -z $docker_image_name ]]; then
                docker_image_name="$1"
            else
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information."
                exit 1
            fi
            shift
        ;;
    esac
done

# Validate required arguments early if running non-interactively
if ! [ -t 0 ] && [ -z "$docker_image_name" ]; then
    echo -e "${RED}Error: <image_name:tag> is required in non-interactive mode.${NC}" >&2
    exit 1
fi

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}                    Docker Image Build Tool                            ${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo ""

# Helper function to read value from .env
get_env_var() {
    local var="$1"
    if [ -f .env ]; then
        grep -E "^${var}=" .env | head -n1 | cut -d'=' -f2-
    fi
}

# Get current directory name as fallback default
curdir=${PWD##*/}:latest

# Get image name from .env, command line, or prompt
if [[ -z $docker_image_name ]]; then
    docker_image_name=$(get_env_var docker_image_name)
    if [[ -z $docker_image_name ]]; then
        docker_image_name="$curdir"
        echo -e "${YELLOW}No image name found in .env. Using directory-based default: $docker_image_name${NC}"
    else
        echo -e "${BLUE}Using image name from .env: $docker_image_name${NC}"
    fi
    read -r -p "Docker image name:tag [$docker_image_name]: " docker_image_name_input
    docker_image_name=${docker_image_name_input:-$docker_image_name}
else
    echo -e "${BLUE}Using Docker image name: $docker_image_name${NC}"
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

echo ""
echo -e "${BLUE}=== Building Docker Image ===${NC}"
echo -e "${BLUE}Building image: $docker_image_name${NC}"
docker build -t $docker_image_name .

# Install user packages from ./src and submodules from ./libs
echo ""
echo -e "${BLUE}=== Installing User Packages and Submodules ===${NC}"
tmp_container_name=tmp_${docker_image_name%%:*}_$RANDOM

if [ ${DEPLOY} = true ]; then
    echo -e "${BLUE}Deploying code into the image for standalone deployment...${NC}"
    # Run the container without mounting the code
    docker run -dt --name $tmp_container_name --entrypoint="" $docker_image_name bash
    # Copy code into the container
    docker cp . $tmp_container_name:/code
else
    echo -e "${BLUE}Setting up development image with mounted code...${NC}"
    # Mount the code directory
    docker run -dt -v ${PWD}:/code --name $tmp_container_name --entrypoint="" $docker_image_name bash
fi

# Install packages
for lib in $(ls ./libs); do
    if test -f ./libs/$lib/requirements.txt; then
        echo -e "${BLUE}Installing $lib requirements.txt${NC}"
        docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -r /code/libs/$lib/requirements.txt
    fi
    if test -f ./libs/$lib/setup.py; then
        echo -e "${BLUE}Installing $lib${NC}"
        docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -e /code/libs/$lib/.
    else
        echo -e "${YELLOW}$lib does not have setup.py file to install.${NC}"
    fi
done
echo -e "${BLUE}Installing main project package...${NC}"
docker exec $tmp_container_name pip install --no-cache-dir --root-user-action=ignore -e /code/.

docker stop $tmp_container_name
docker commit --change='CMD ~/start.sh' $tmp_container_name $docker_image_name
docker rm -f $tmp_container_name &>/dev/null

echo ""
echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}                    Build Successfully Completed!                      ${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo ""
echo -e "${BLUE}Image '${GREEN}$docker_image_name${BLUE}' has been successfully built.${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "• ${YELLOW}Start development container:${NC} ./docker_dev.sh"
echo -e "• ${YELLOW}Start training container:${NC} ./docker_train.sh"
echo -e "• ${YELLOW}Update the image:${NC} ./docker_update.sh"
