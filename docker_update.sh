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
    echo -e "\033[1mUsage:\033[0m $0 [OPTIONS]"
    echo ""
    echo -e "\033[1mDescription:\033[0m"
    echo "  Update a Docker image by committing changes from an existing running container."
    echo "  This script will commit the current state of a container to update the specified image."
    echo -e "  ⚠️  \033[1mThis script should be run on the HOST SYSTEM, not inside a Docker container.\033[0m"
    echo ""
    echo -e "\033[1mOptions:\033[0m"
    echo "  -c, --container <name|id>        Container name or ID to commit from"
    echo "  -i, --image <name:tag>           Target image name and tag to update"
    echo "  -m, --message <message>          Commit message (optional)"
    echo "      --author <name>              Author of the commit (optional)"
    echo "      --change <instruction>       Dockerfile instruction to apply (optional, can be used multiple times)"
    echo "      --pause                      Pause container during commit (default: true)"
    echo "      --no-pause                   Do not pause container during commit"
    echo "      --non-interactive            Run without prompts (use provided values or defaults from .env)"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo -e "\033[1mExamples:\033[0m"
    echo "  # Interactive mode (default)"
    echo "  $0"
    echo ""
    echo "  # Non-interactive with specific container and image"
    echo "  $0 --container my_container --image my-image:latest --non-interactive"
    echo ""
    echo "  # With commit message and author"
    echo "  $0 -c my_container -i my-image:v2.0 -m \"Updated dependencies\" --author \"John Doe <john@example.com>\""
    # echo ""
    # echo "  # With Dockerfile changes"
    # echo "  $0 -c my_container -i my-image:latest --change \"CMD /app/start.sh\" --change \"EXPOSE 8080\""
}

# Safety check - ensure script is run only on host system (outside Docker containers)
check_host_environment() {
    echo -e "\033[1;33m⚠️  IMPORTANT: This script should ONLY be run on the HOST SYSTEM! ⚠️\033[0m"
    echo -e "\033[1;33m   Running this script inside a Docker container will not work properly.\033[0m"
    echo ""
    
    # Check if we're likely in a container
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        echo -e "${RED}✗ Docker container environment detected.${NC}"
        echo -e "${RED}   You appear to be running this script inside a Docker container.${NC}"
        echo ""
        echo -e "${BLUE}To use this script:${NC}"
        echo -e "${BLUE}1. Exit the Docker container${NC}"
        echo -e "${BLUE}2. Run this script from your host terminal${NC}"
        echo -e "${BLUE}3. The script will commit changes from your running container to update the image${NC}"
        echo ""
        echo -e "${RED}Aborting. This script must be run from the host system.${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ Host system environment detected.${NC}"
    fi
    
    echo ""
}

# Initialize variables
container_name=""
docker_image_name=""
commit_message=""
commit_author=""
pause_container=true
non_interactive=false
declare -a dockerfile_changes=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--container)
            container_name="$2"
            shift 2
        ;;
        -i|--image)
            docker_image_name="$2"
            shift 2
        ;;
        -m|--message)
            commit_message="$2"
            shift 2
        ;;
        --author)
            commit_author="$2"
            shift 2
        ;;
        --change)
            dockerfile_changes+=("$2")
            shift 2
        ;;
        --pause)
            pause_container=true
            shift
        ;;
        --no-pause)
            pause_container=false
            shift
        ;;
        --non-interactive)
            non_interactive=true
            shift
        ;;
        -h|--help)
            show_help
            exit 0
        ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information."
            exit 1
        ;;
    esac
done

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}                    Docker Image Update Tool                           ${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo ""

# Check that we're running on host system, not inside a container
check_host_environment

# Helper function to read value from .env
get_env_var() {
    local var="$1"
    if [ -f .env ]; then
        grep -E "^${var}=" .env | head -n1 | cut -d'=' -f2-
    fi
}

# Function to list running containers
list_running_containers() {
    echo -e "${BLUE}Currently running containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.ID}}"
    echo ""
}

# Function to validate container exists and is running
validate_container() {
    local container="$1"
    if ! docker ps --format '{{.Names}} {{.ID}}' | grep -qw "$container"; then
        return 1
    fi
    return 0
}

# Function to validate image exists
validate_image() {
    local image="$1"
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

if [[ "$non_interactive" == false ]]; then
    echo -e "${BLUE}This script will help you update a Docker image from a running container.${NC}"
    echo ""
fi

# Get container name/ID
if [[ -z "$container_name" ]]; then
    # Try to get default from .env
    env_container=$(get_env_var container_name)
    
    if [[ "$non_interactive" == true ]]; then
        if [[ -n "$env_container" ]]; then
            container_name="$env_container"
            echo -e "${BLUE}Using container from .env: $container_name${NC}"
        else
            echo -e "${RED}Error: Container name required in non-interactive mode.${NC}"
            echo "Use --container option or ensure container_name is set in .env file."
            exit 1
        fi
    else
        # Interactive mode
        list_running_containers
        
        while true; do
            read -p "Container name or ID [${env_container}]: " container_input
            container_name=${container_input:-$env_container}
            
            if [[ -z "$container_name" ]]; then
                echo -e "${RED}Container name cannot be empty.${NC}"
                continue
            fi
            
            if validate_container "$container_name"; then
                break
            else
                echo -e "${RED}Container '$container_name' is not running or does not exist.${NC}"
                list_running_containers
            fi
        done
    fi
else
    # Validate container in non-interactive mode
    if ! validate_container "$container_name"; then
        echo -e "${RED}Error: Container '$container_name' is not running or does not exist.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Using container: $container_name${NC}"

# Get target image name
if [[ -z "$docker_image_name" ]]; then
    # Try to get default from .env
    env_image=$(get_env_var docker_image_name)
    
    if [[ "$non_interactive" == true ]]; then
        if [[ -n "$env_image" ]]; then
            docker_image_name="$env_image"
            echo -e "${BLUE}Using image from .env: $docker_image_name${NC}"
        else
            echo -e "${RED}Error: Image name required in non-interactive mode.${NC}"
            echo "Use --image option or ensure docker_image_name is set in .env file."
            exit 1
        fi
    else
        # Interactive mode
        while true; do
            read -p "Target image name:tag [${env_image}]: " image_input
            docker_image_name=${image_input:-$env_image}
            
            if [[ -z "$docker_image_name" ]]; then
                echo -e "${RED}Image name cannot be empty.${NC}"
                continue
            fi
            
            # Check if image exists, warn if it doesn't
            if ! validate_image "$docker_image_name"; then
                echo -e "${YELLOW}Warning: Image '$docker_image_name' does not exist. A new image will be created.${NC}"
                read -p "Continue? [Y/n]: " confirm
                confirm=${confirm:-Y}
                if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
                    break
                fi
            else
                echo -e "${YELLOW}Image '$docker_image_name' exists and will be updated.${NC}"
                break
            fi
        done
    fi
fi

echo -e "${GREEN}✓ Target image: $docker_image_name${NC}"

# Get commit message if not provided
if [[ -z "$commit_message" && "$non_interactive" == false ]]; then
    read -p "Commit message (optional): " commit_message
fi

# Get commit author if not provided
if [[ -z "$commit_author" && "$non_interactive" == false ]]; then
    read -p "Commit author (optional): " commit_author
fi

# Show summary
echo ""
echo -e "${BLUE}=== Update Summary ===${NC}"
echo -e "Container: ${GREEN}$container_name${NC}"
echo -e "Target Image: ${GREEN}$docker_image_name${NC}"
if [[ -n "$commit_message" ]]; then
    echo -e "Message: ${GREEN}$commit_message${NC}"
fi
if [[ -n "$commit_author" ]]; then
    echo -e "Author: ${GREEN}$commit_author${NC}"
fi
echo -e "Pause container: ${GREEN}$pause_container${NC}"
if [[ ${#dockerfile_changes[@]} -gt 0 ]]; then
    echo -e "Dockerfile changes:"
    for change in "${dockerfile_changes[@]}"; do
        echo -e "  ${GREEN}$change${NC}"
    done
fi
echo ""

if [[ "$non_interactive" == false ]]; then
    read -p "Proceed with the update? [Y/n]: " proceed
    proceed=${proceed:-Y}
    
    if [[ "$proceed" != "Y" && "$proceed" != "y" ]]; then
        echo -e "${YELLOW}Update cancelled.${NC}"
        exit 0
    fi
else
    echo -e "${BLUE}Running in non-interactive mode. Proceeding with update...${NC}"
fi

echo ""
echo -e "${BLUE}=== Updating Image ===${NC}"

# Build docker commit command
commit_cmd="docker commit"

# Add pause option
if [[ "$pause_container" == false ]]; then
    commit_cmd+=" --pause=false"
fi

# Add commit message
if [[ -n "$commit_message" ]]; then
    commit_cmd+=" --message=\"$commit_message\""
fi

# Add author
if [[ -n "$commit_author" ]]; then
    commit_cmd+=" --author=\"$commit_author\""
fi

# Add dockerfile changes
for change in "${dockerfile_changes[@]}"; do
    commit_cmd+=" --change=\"$change\""
done

# Add container and image
commit_cmd+=" \"$container_name\" \"$docker_image_name\""

echo -e "${BLUE}Executing: $commit_cmd${NC}"

# Execute the commit
if eval "$commit_cmd"; then
    echo ""
    echo -e "${GREEN}========================================================================${NC}"
    echo -e "${GREEN}                    Image Update Successful!                           ${NC}"
    echo -e "${GREEN}========================================================================${NC}"
    echo ""
    echo -e "${BLUE}Image '${GREEN}$docker_image_name${BLUE}' has been successfully updated from container '${GREEN}$container_name${BLUE}'.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "• ${YELLOW}Verify the updated image:${NC} docker image inspect $docker_image_name"
    echo -e "• ${YELLOW}Test the updated image:${NC} ./docker_dev.sh $docker_image_name"
    # echo -e "• ${YELLOW}Push to registry (if needed):${NC} docker push $docker_image_name"
    echo ""
    echo -e "${BLUE}Image size:${NC}"
    docker images "$docker_image_name" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
else
    echo ""
    echo -e "${RED}========================================================================${NC}"
    echo -e "${RED}                         Update Failed!                                ${NC}"
    echo -e "${RED}========================================================================${NC}"
    echo ""
    echo -e "${RED}Failed to update image '$docker_image_name' from container '$container_name'.${NC}"
    echo -e "${YELLOW}Please check the error messages above and try again.${NC}"
    exit 1
fi
