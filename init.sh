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
    echo "  Initialize a new ML project from the template."
    echo "  This script will rename the source directory, update project files,"
    echo "  and configure Docker settings for your project."
    echo ""
    echo -e "\033[1mOptions:\033[0m"
    echo "  -n, --name <name>                Project name (Python package name)"
    echo "  -d, --description <desc>         Project description"
    echo "  -a, --author <name>              Author name"
    echo "  -e, --email <email>              Author email"
    echo "  -i, --image <name:tag>           Docker image name"
    echo "  -c, --container <name>           Default container name"
    echo "  -w, --workspace <path>           Workspace directory path"
    echo "      --data-dir <path>            Data directory path"
    echo "  -g, --gpus <config>              GPU configuration (e.g., 'device=all')"
    echo "      --restart <Y|n>              Container restart policy [Y]"
    echo "      --non-interactive            Run without prompts (use provided values or defaults)"
    echo "      --force                      Force re-initialization if already initialized"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo -e "\033[1mExamples:\033[0m"
    echo "  # Interactive mode (default)"
    echo "  $0"
    echo ""
    echo "  # Non-interactive with minimal options"
    echo "  $0 --name my_project --author \"John Doe\" --email john@example.com --non-interactive"
    echo ""
    echo "  # Full non-interactive setup"
    echo "  $0 --name my_project --description \"My ML project\" \\"
    echo "       --author \"John Doe\" --email john@example.com \\"
    echo "       --image my-project:v1.0 --workspace /path/to/ws \\"
    echo "       --data-dir /path/to/data --non-interactive"
}

# Initialize variables
project_name=""
project_description=""
author_name=""
author_email=""
docker_image_name=""
container_name=""
workspace_dir=""
data_dir=""
gpus=""
restart_container=""
non_interactive=false
force_init=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            project_name="$2"
            shift 2
            ;;
        -d|--description)
            project_description="$2"
            shift 2
            ;;
        -a|--author)
            author_name="$2"
            shift 2
            ;;
        -e|--email)
            author_email="$2"
            shift 2
            ;;
        -i|--image)
            docker_image_name="$2"
            shift 2
            ;;
        -c|--container)
            container_name="$2"
            shift 2
            ;;
        -w|--workspace)
            workspace_dir="$2"
            shift 2
            ;;
        --data-dir)
            data_dir="$2"
            shift 2
            ;;
        -g|--gpus)
            gpus="$2"
            shift 2
            ;;
        --restart)
            restart_container="$2"
            shift 2
            ;;
        --non-interactive)
            non_interactive=true
            shift
            ;;
        --force)
            force_init=true
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
echo -e "${GREEN}           Welcome to ML Project Template Initialization!               ${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo ""

# Check if the project has already been initialized
if [[ -f ".initialized" ]]; then
    echo -e "${YELLOW}This project appears to have been initialized already.${NC}"
    if [[ "$force_init" == true ]]; then
        echo -e "${YELLOW}Force flag detected. Re-initializing...${NC}"
    elif [[ "$non_interactive" == true ]]; then
        echo -e "${RED}Project already initialized. Use --force to re-initialize.${NC}"
        exit 1
    else
        read -p "Do you want to re-initialize? This will overwrite current settings. [y/N]: " reinit
        reinit=${reinit:-N}
        if [[ "$reinit" != "y" && "$reinit" != "Y" ]]; then
            echo -e "${BLUE}Initialization cancelled. Use the existing configuration or manually edit files.${NC}"
            exit 0
        fi
    fi
    echo ""
fi

if [[ "$non_interactive" == false ]]; then
    echo -e "${BLUE}This script will help you customize the template for your project.${NC}"
    echo -e "${BLUE}You can leave any field empty to keep the default values.${NC}"
    echo ""
fi

# Function to validate project name (should be a valid Python package name)
validate_project_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z][a-z0-9_]*$ ]]; then
        echo -e "${RED}Error: Project name must be a valid Python package name (lowercase, start with letter, contain only letters, numbers, and underscores)${NC}"
        return 1
    fi
    return 0
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ -n "$email" && ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo -e "${RED}Warning: Email format may be invalid${NC}"
    fi
}

# Function to convert string to valid Docker image name
to_docker_name() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g'
}

# Get current directory name as default project name
current_dir=$(basename "$PWD")
default_project_name=$(echo "$current_dir" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g')

# Get current directory name as default project name
current_dir=$(basename "$PWD")
default_project_name=$(echo "$current_dir" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g')

if [[ "$non_interactive" == false ]]; then
    echo -e "${YELLOW}=== Project Configuration ===${NC}"
fi

# Get project name
if [[ -z "$project_name" ]]; then
    if [[ "$non_interactive" == true ]]; then
        project_name="$default_project_name"
        echo -e "${BLUE}Using default project name: $project_name${NC}"
    else
        while true; do
            read -p "Project name (Python package name) [$default_project_name]: " project_name_input
            project_name=${project_name_input:-$default_project_name}
            
            if validate_project_name "$project_name"; then
                break
            fi
        done
    fi
else
    if ! validate_project_name "$project_name"; then
        echo -e "${RED}Invalid project name provided: $project_name${NC}"
        exit 1
    fi
fi

# Get project description
if [[ -z "$project_description" ]]; then
    if [[ "$non_interactive" == true ]]; then
        project_description="A machine learning project"
        echo -e "${BLUE}Using default description: $project_description${NC}"
    else
        read -p "Project description [A machine learning project]: " project_description
        project_description=${project_description:-"A machine learning project"}
    fi
fi

# Get author information
if [[ "$non_interactive" == false ]]; then
    echo ""
    echo -e "${YELLOW}=== Author Information ===${NC}"
fi

if [[ -z "$author_name" ]]; then
    if [[ "$non_interactive" == true ]]; then
        author_name="Your Name"
        echo -e "${BLUE}Using default author name: $author_name${NC}"
    else
        read -p "Author name [Your Name]: " author_name
        author_name=${author_name:-"Your Name"}
    fi
fi

if [[ -z "$author_email" ]]; then
    if [[ "$non_interactive" == true ]]; then
        author_email="your.name@example.com"
        echo -e "${BLUE}Using default author email: $author_email${NC}"
    else
        read -p "Author email [your.name@example.com]: " author_email
        author_email=${author_email:-"your.name@example.com"}
    fi
fi

if [[ "$non_interactive" == false ]]; then
    validate_email "$author_email"
fi

# Get Docker configuration
if [[ "$non_interactive" == false ]]; then
    echo ""
    echo -e "${YELLOW}=== Docker Configuration ===${NC}"
fi

# Default Docker image name based on project name
if [[ -z "$docker_image_name" ]]; then
    default_docker_image=$(to_docker_name "$project_name"):latest
    if [[ "$non_interactive" == true ]]; then
        docker_image_name="$default_docker_image"
        echo -e "${BLUE}Using default Docker image name: $docker_image_name${NC}"
    else
        read -p "Docker image name [$default_docker_image]: " docker_image_name
        docker_image_name=${docker_image_name:-$default_docker_image}
    fi
fi

# Default container name
if [[ -z "$container_name" ]]; then
    default_container_name=$(to_docker_name "$project_name")_dev
    if [[ "$non_interactive" == true ]]; then
        container_name="$default_container_name"
        echo -e "${BLUE}Using default container name: $container_name${NC}"
    else
        read -p "Default container name [$default_container_name]: " container_name
        container_name=${container_name:-$default_container_name}
    fi
fi

# Workspace directory
if [[ -z "$workspace_dir" ]]; then
    if [[ -f ".env" ]]; then
        current_ws_dir=$(grep "^workspace_dir=" .env 2>/dev/null | cut -d'=' -f2-)
    fi
    current_ws_dir=${current_ws_dir:-"${PWD}/ws"}
    if [[ "$non_interactive" == true ]]; then
        workspace_dir="$current_ws_dir"
        echo -e "${BLUE}Using default workspace directory: $workspace_dir${NC}"
    else
        read -p "Default workspace directory [$current_ws_dir]: " workspace_dir
        workspace_dir=${workspace_dir:-$current_ws_dir}
    fi
fi

# Data directory
if [[ -z "$data_dir" ]]; then
    if [[ -f ".env" ]]; then
        current_data_dir=$(grep "^data_dir=" .env 2>/dev/null | cut -d'=' -f2-)
    fi
    current_data_dir=${current_data_dir:-"${PWD}/data"}
    if [[ "$non_interactive" == true ]]; then
        data_dir="$current_data_dir"
        echo -e "${BLUE}Using default data directory: $data_dir${NC}"
    else
        read -p "Default data directory [$current_data_dir]: " data_dir
        data_dir=${data_dir:-$current_data_dir}
    fi
fi

# GPU configuration
if [[ -z "$gpus" ]]; then
    if [[ -f ".env" ]]; then
        current_gpus=$(grep "^gpus=" .env 2>/dev/null | cut -d'=' -f2-)
    fi
    current_gpus=${current_gpus:-"all"}
    if [[ "$non_interactive" == true ]]; then
        gpus="$current_gpus"
        echo -e "${BLUE}Using default GPU configuration: $gpus${NC}"
    else
        read -p "Default GPU configuration [$current_gpus]: " gpus
        gpus=${gpus:-$current_gpus}
    fi
fi

# Restart policy
if [[ -z "$restart_container" ]]; then
    if [[ -f ".env" ]]; then
        current_restart=$(grep "^restart_container=" .env 2>/dev/null | cut -d'=' -f2-)
    fi
    current_restart=${current_restart:-"Y"}
    if [[ "$non_interactive" == true ]]; then
        restart_container="$current_restart"
        echo -e "${BLUE}Using default restart policy: $restart_container${NC}"
    else
        while true; do
            read -p "Default restart container policy (Y/n) [$current_restart]: " restart_container
            restart_container=${restart_container:-$current_restart}
            if [[ "$restart_container" == "Y" || "$restart_container" == "n" ]]; then
                break
            else
                echo -e "${RED}Please enter Y or n${NC}"
            fi
        done
    fi
fi

# Validate restart policy
if [[ "$restart_container" != "Y" && "$restart_container" != "n" ]]; then
    echo -e "${RED}Invalid restart policy: $restart_container. Must be Y or n.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=== Summary of Changes ===${NC}"
echo -e "Project name: ${GREEN}$project_name${NC}"
echo -e "Description: ${GREEN}$project_description${NC}"
echo -e "Author: ${GREEN}$author_name <$author_email>${NC}"
echo -e "Docker image: ${GREEN}$docker_image_name${NC}"
echo -e "Container name: ${GREEN}$container_name${NC}"
echo -e "Workspace dir: ${GREEN}$workspace_dir${NC}"
echo -e "Data dir: ${GREEN}$data_dir${NC}"
echo ""

if [[ "$non_interactive" == false ]]; then
    read -p "Proceed with these changes? [Y/n]: " proceed
    proceed=${proceed:-Y}
    
    if [[ "$proceed" != "Y" ]]; then
        echo -e "${YELLOW}Initialization cancelled.${NC}"
        exit 0
    fi
else
    echo -e "${BLUE}Running in non-interactive mode. Proceeding with initialization...${NC}"
fi

echo ""
echo -e "${BLUE}=== Applying Changes ===${NC}"

# 1. Rename the source directory if it exists and is different
current_src_dirs=(src/*)
if [[ ${#current_src_dirs[@]} -gt 0 ]]; then
    # Find the first Python package directory in src/
    for src_path in "${current_src_dirs[@]}"; do
        if [[ -d "$src_path" && -f "$src_path/__init__.py" ]]; then
            current_src_dir="$src_path"
            break
        fi
    done
    
    if [[ -n "$current_src_dir" ]]; then
        current_package_name=$(basename "$current_src_dir")
        new_src_dir="src/$project_name"
        
        if [[ "$current_package_name" != "$project_name" ]]; then
            echo -e "${BLUE}Renaming source directory: $current_src_dir -> $new_src_dir${NC}"
            if [[ -d "$new_src_dir" ]]; then
                echo -e "${RED}Warning: Target directory $new_src_dir already exists. Skipping rename.${NC}"
            else
                mv "$current_src_dir" "$new_src_dir"
            fi
        fi
    else
        echo -e "${YELLOW}No Python package found in src/. Creating new package: src/$project_name${NC}"
        mkdir -p "src/$project_name"
        touch "src/$project_name/__init__.py"
        
        # Create a basic main.py if it doesn't exist
        if [[ ! -f "src/$project_name/main.py" ]]; then
            cat > "src/$project_name/main.py" << 'EOF'
"""
Main training script.

This script serves as the entry point for training the model.
"""

import logging
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/ws/training.log')
    ]
)

logger = logging.getLogger(__name__)


def main() -> None:
    """Main training function."""
    logger.info("Starting training...")
    
    # TODO: Implement your training logic here
    logger.info("Training logic placeholder - implement your model training here")
    
    logger.info("Training completed successfully!")


if __name__ == "__main__":
    main()
EOF
        fi
    fi
else
    echo -e "${YELLOW}Creating new package: src/$project_name${NC}"
    mkdir -p "src/$project_name"
    touch "src/$project_name/__init__.py"
fi

# 2. Update pyproject.toml
echo -e "${BLUE}Updating pyproject.toml...${NC}"

# Create a temporary file for sed operations
temp_file=$(mktemp)

# Update project name
sed "s/^name = .*/name = \"$project_name\"/" pyproject.toml > "$temp_file" && mv "$temp_file" pyproject.toml

# Update description
sed "s/^description = .*/description = \"$project_description\"/" pyproject.toml > "$temp_file" && mv "$temp_file" pyproject.toml

# Update author information
sed "s/authors = .*/authors = [{ name = \"$author_name\", email = \"$author_email\" }]/" pyproject.toml > "$temp_file" && mv "$temp_file" pyproject.toml

# Update project.scripts entry point
sed "s/ml-project-training = .*/ml-project-training = \"$project_name.main:main\"/" pyproject.toml > "$temp_file" && mv "$temp_file" pyproject.toml

# 3. Update .env file
echo -e "${BLUE}Updating .env file...${NC}"

cat > .env << EOF
docker_image_name=$docker_image_name
container_name=$container_name
workspace_dir=$workspace_dir
data_dir=$data_dir
gpus=$gpus
restart_container=$restart_container
EOF

# 4. Update main.py to use the correct package name in the training script paths
main_py_path="src/$project_name/main.py"
if [[ -f "$main_py_path" ]]; then
    echo -e "${BLUE}Updating main.py with correct package paths...${NC}"
    # Update any references to old package names in the main.py file
    sed -i "s/mlproject/$project_name/g" "$main_py_path"
fi

# 5. Update docker_train.sh to use the correct path
echo -e "${BLUE}Updating docker_train.sh with correct package path...${NC}"
sed -i "s|src/mlproject/main.py|src/$project_name/main.py|g" docker_train.sh

# 6. Create directories if they don't exist
echo -e "${BLUE}Creating necessary directories...${NC}"
mkdir -p "$workspace_dir"
mkdir -p "$data_dir"
mkdir -p "$workspace_dir/checkpoints"
mkdir -p "$workspace_dir/logs"

# 7. Update README.md with project-specific information
echo -e "${BLUE}Updating README.md...${NC}"
sed -i "1s/.*/# $project_name/" README.md
# Update the description line (should be line 3, but let's be more specific)
sed -i "/^This template was prepared/c\\$project_description" README.md

# 8. Mark project as initialized
echo -e "${BLUE}Marking project as initialized...${NC}"
echo "Project initialized on $(date)" > .initialized
echo "Project name: $project_name" >> .initialized
echo "Docker image: $docker_image_name" >> .initialized

# 9. Configure git with author information
echo -e "${BLUE}Configuring git with author information...${NC}"
if command -v git >/dev/null 2>&1; then
    # Check if we're in a git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git config user.name "$author_name"
        git config user.email "$author_email"
        echo -e "${GREEN}Git configured with author: $author_name <$author_email>${NC}"
    else
        echo -e "${YELLOW}Not in a git repository. Skipping git configuration.${NC}"
    fi
else
    echo -e "${YELLOW}Git not found. Skipping git configuration.${NC}"
fi

echo ""
echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}                    Initialization Complete!                           ${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo ""
echo -e "${BLUE}Your project has been successfully initialized with the following structure:${NC}"
echo -e "📁 Source code: ${GREEN}src/$project_name/${NC}"
echo -e "📄 Package info: ${GREEN}pyproject.toml${NC} (updated)"
echo -e "🐳 Docker config: ${GREEN}.env${NC} (updated)"
echo -e "📂 Workspace: ${GREEN}$workspace_dir${NC}"
echo -e "📂 Data: ${GREEN}$data_dir${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. ${YELLOW}Build your Docker image:${NC} ./docker_build.sh"
echo -e "2. ${YELLOW}Start development:${NC} ./docker_dev.sh"
echo -e "3. ${YELLOW}Start training:${NC} ./docker_train.sh"
echo ""
echo -e "${BLUE}Happy coding! 🚀${NC}"
