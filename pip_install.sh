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
    echo -e "\033[1mUsage:\033[0m $0 [PACKAGE_NAMES] [OPTIONS]"
    echo ""
    echo -e "\033[1mDescription:\033[0m"
    echo "  Install Python packages using pip and automatically update pyproject.toml"
    echo "  dependencies section with the installed package versions."
    echo "  with all installed packages (pip freeze)."
    echo ""
    echo -e "\033[1mPositional arguments:\033[0m"
    echo "  PACKAGE_NAMES                    One or more package names/specifications to install"
    echo ""
    echo -e "\033[1mOptions:\033[0m"
    echo "      --uninstall                  Uninstall packages instead of installing"
    echo "      --upgrade                    Upgrade packages to latest versions"
    # echo "      --upgrade-all                Upgrade all packages"
    echo "      --sync                       Synchronize installed packages with pyproject.toml"
    echo "      --no-deps                    Don't install package dependencies"
    # echo "      --user                       Install to the Python user install directory"
    echo "      --force-reinstall            Reinstall all packages even if up-to-date"
    echo "      --no-pyproject-update        Skip updating pyproject.toml"
    # echo "      --no-requirements-update     Skip updating requirements.txt"
    echo "      --dry-run                    Show what would be installed without actually installing"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo -e "\033[1mExamples:\033[0m"
    echo "  # Install single package"
    echo "  $0 numpy"
    echo ""
    echo "  # Install with version constraint"
    echo "  $0 numpy==1.26"
    echo "  $0 \"numpy<2\""
    echo ""
    echo "  # Install multiple packages"
    echo "  $0 numpy pandas matplotlib"
    echo "  $0 \"numpy<2 pandas matplotlib==3.10\""
    echo ""
    echo "  # Uninstall packages"
    echo "  $0 --uninstall numpy pandas"
    echo ""
    echo "  # Upgrade packages"
    echo "  $0 --upgrade numpy"
    # echo "  $0 --upgrade-all"
    echo ""
    echo "  # Sync with pyproject.toml"
    echo "  $0 --sync"
    echo ""
    echo "  # Install without updating pyproject.toml"
    echo "  $0 --no-pyproject-update temporary-package"
}

# Initialize variables
UNINSTALL=false
UPGRADE=false
UPGRADE_ALL=false
SYNC=false
NO_DEPS=false
USER_INSTALL=false
FORCE_REINSTALL=false
NO_PYPROJECT_UPDATE=false
NO_REQUIREMENTS_UPDATE=false
DRY_RUN=false
PACKAGES=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --uninstall)
            UNINSTALL=true
            shift
        ;;
        --upgrade)
            UPGRADE=true
            shift
        ;;
        --upgrade-all)
            UPGRADE_ALL=true
            shift
        ;;
        --sync)
            SYNC=true
            shift
        ;;
        --no-deps)
            NO_DEPS=true
            shift
        ;;
        --user)
            USER_INSTALL=true
            shift
        ;;
        --force-reinstall)
            FORCE_REINSTALL=true
            shift
        ;;
        --no-pyproject-update)
            NO_PYPROJECT_UPDATE=true
            shift
        ;;
        --no-requirements-update)
            NO_REQUIREMENTS_UPDATE=true
            shift
        ;;
        --dry-run)
            DRY_RUN=true
            shift
        ;;
        -h|--help)
            show_help
            exit 0
        ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information."
            exit 1
        ;;
        *)
            PACKAGES+=("$1")
            shift
        ;;
    esac
done

# Validate arguments
if [[ $SYNC == true && ${#PACKAGES[@]} -gt 0 ]]; then
    echo -e "${RED}Error: --sync cannot be used with package arguments.${NC}"
    echo "Use --help for usage information."
    exit 1
fi

if [[ $UPGRADE_ALL == false && $SYNC == false && ${#PACKAGES[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No packages specified.${NC}"
    echo "Use --help for usage information."
    exit 1
fi

echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}                    Python Package Installation Tool                   ${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo ""

# Show current Python environment
echo -e "${BLUE}=== Current Python Environment ===${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo -e "${RED}Error: Python not found in PATH${NC}"
    exit 1
fi

echo -e "${BLUE}Python executable: ${GREEN}$(which $PYTHON_CMD)${NC}"
echo -e "${BLUE}Python version: ${GREEN}$($PYTHON_CMD --version)${NC}"

# Check if we're in a virtual environment
if [[ -n "$VIRTUAL_ENV" ]]; then
    echo -e "${BLUE}Virtual environment: ${GREEN}$VIRTUAL_ENV${NC}"
    elif [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    echo -e "${BLUE}Conda environment: ${GREEN}$CONDA_DEFAULT_ENV${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Not in a virtual environment${NC}"
fi

echo -e "${BLUE}Pip version: ${GREEN}$(pip --version)${NC}"
echo ""

# Function to extract package name from package specification
extract_package_name() {
    local spec="$1"
    
    # Handle git URLs (e.g., "tqdm @ git+https://github.com/tqdm/tqdm.git")
    if [[ "$spec" == *" @ git+"* ]]; then
        echo "$spec" | cut -d' ' -f1
        return
    fi
    
    # Handle other URL formats
    if [[ "$spec" == *"@"* && "$spec" == *"://"* ]]; then
        echo "$spec" | cut -d'@' -f1
        return
    fi
    
    # Remove version constraints (==, >=, <=, >, <, !=, ~=)
    echo "$spec" | sed -E 's/[><=!~]=?.*$//' | sed 's/\[.*\]$//'
}

# Function to get installed package version
get_installed_version() {
    local package="$1"
    pip show "$package" 2>/dev/null | grep "Version:" | cut -d' ' -f2
}

# Function to parse pyproject.toml dependencies
get_pyproject_dependencies() {
    if [[ ! -f "pyproject.toml" ]]; then
        echo -e "${YELLOW}Warning: pyproject.toml not found in current directory${NC}"
        return 1
    fi
    
    # Extract dependencies from pyproject.toml, handling git URLs properly
    sed -n '/^dependencies = \[/,/^]/p' pyproject.toml | \
    grep -E '^\s*"' | \
    sed 's/^\s*"//' | \
    sed 's/",\?$//' | \
    sed 's/"$//' | \
    grep -v '^\s*#'  # Remove comment lines
}

# Function to get all installed packages
get_installed_packages() {
    pip list --format=freeze | cut -d'=' -f1
}

# Function to check if package is installed
is_package_installed() {
    local package="$1"
    pip show "$package" &>/dev/null
}

# Function to add package to pyproject.toml dependencies
add_to_pyproject() {
    local package_spec="$1"
    local package_name=$(extract_package_name "$package_spec")
    local installed_version=$(get_installed_version "$package_name")
    
    if [[ -z "$installed_version" ]]; then
        echo -e "${YELLOW}Warning: Could not determine installed version for $package_name${NC}"
        return
    fi
    
    # Create the dependency entry with pinned version
    local dependency_entry="\"$package_name==$installed_version\","
    
    if [[ ! -f "pyproject.toml" ]]; then
        echo -e "${YELLOW}Warning: pyproject.toml not found in current directory${NC}"
        return
    fi
    
    # Check if package already exists in dependencies
    if grep -q "\"$package_name" pyproject.toml; then
        echo -e "${BLUE}Updating $package_name in pyproject.toml (version: $installed_version)${NC}"
        # Replace existing entry
        sed -i "/\"$package_name/c\\    $dependency_entry" pyproject.toml
    else
        echo -e "${BLUE}Adding $package_name to pyproject.toml (version: $installed_version)${NC}"
        # Find the dependencies section and insert before its closing bracket
        # First, find the line number of the dependencies section start
        deps_start=$(grep -n "^dependencies = \[" pyproject.toml | cut -d: -f1)
        if [[ -n "$deps_start" ]]; then
            # Find the next standalone ']' after the dependencies start
            deps_end=$(tail -n +$((deps_start + 1)) pyproject.toml | grep -n "^]" | head -n1 | cut -d: -f1)
            if [[ -n "$deps_end" ]]; then
                deps_end=$((deps_start + deps_end))
                # Insert the dependency before the closing bracket
                sed -i "${deps_end}i\\    $dependency_entry" pyproject.toml
            else
                echo -e "${YELLOW}Warning: Could not find dependencies section closing bracket${NC}"
            fi
        else
            echo -e "${YELLOW}Warning: Could not find dependencies section in pyproject.toml${NC}"
        fi
    fi
}

# Function to remove package from pyproject.toml dependencies
remove_from_pyproject() {
    local package_spec="$1"
    local package_name=$(extract_package_name "$package_spec")
    
    if [[ ! -f "pyproject.toml" ]]; then
        echo -e "${YELLOW}Warning: pyproject.toml not found in current directory${NC}"
        return
    fi
    
    if grep -q "\"$package_name" pyproject.toml; then
        echo -e "${BLUE}Removing $package_name from pyproject.toml${NC}"
        sed -i "/\"$package_name/d" pyproject.toml
    fi
}

# # Function to update requirements.txt
# update_requirements() {
#     echo -e "${BLUE}Updating requirements.txt with all installed packages...${NC}"
#     pip freeze > requirements.txt
#     echo -e "${GREEN}✓ requirements.txt updated${NC}"
# }

# Build pip command
PIP_CMD="pip"

if [[ $DRY_RUN == true ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No actual changes will be made ===${NC}"
fi

# Handle different operations
if [[ $SYNC == true ]]; then
    echo -e "${BLUE}=== Synchronizing with pyproject.toml ===${NC}"
    
    if [[ ! -f "pyproject.toml" ]]; then
        echo -e "${RED}Error: pyproject.toml not found in current directory${NC}"
        exit 1
    fi
    
    # Get dependencies from pyproject.toml
    echo -e "${BLUE}Reading dependencies from pyproject.toml...${NC}"
    mapfile -t dependencies < <(get_pyproject_dependencies)
    
    if [[ ${#dependencies[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No dependencies found in pyproject.toml${NC}"
    else
        echo -e "${BLUE}Found ${#dependencies[@]} dependencies in pyproject.toml${NC}"
        
        # Process each dependency
        for dep in "${dependencies[@]}"; do
            # Skip empty lines
            if [[ -z "$dep" ]]; then
                continue
            fi
            
            package_name=$(extract_package_name "$dep")
            echo ""
            echo -e "${BLUE}Processing: $dep${NC}"
            
            # Check if package has version constraint
            if [[ "$dep" == *"=="* || "$dep" == *">="* || "$dep" == *"<="* || "$dep" == *">"* || "$dep" == *"<"* || "$dep" == *"!="* || "$dep" == *"~="* ]]; then
                # Package has version constraint - install/upgrade to specified version
                echo -e "${BLUE}Installing/updating $package_name to match constraint: $dep${NC}"
                if [[ $DRY_RUN == false ]]; then
                    pip install "$dep"
                else
                    echo "Would run: pip install \"$dep\""
                fi
            else
                # Package without version constraint
                if is_package_installed "$package_name"; then
                    # Package is installed - add version to pyproject.toml
                    installed_version=$(get_installed_version "$package_name")
                    if [[ -n "$installed_version" ]]; then
                        echo -e "${BLUE}Package $package_name is installed (version: $installed_version)${NC}"
                        if [[ $DRY_RUN == false ]]; then
                            # Update pyproject.toml with pinned version
                            sed -i "/\"$package_name\"/c\\    \"$package_name==$installed_version\"," pyproject.toml
                            echo -e "${GREEN}✓ Updated pyproject.toml with $package_name==$installed_version${NC}"
                        else
                            echo "Would update pyproject.toml with $package_name==$installed_version"
                        fi
                    fi
                else
                    # Package not installed - install it
                    echo -e "${BLUE}Installing $package_name...${NC}"
                    if [[ $DRY_RUN == false ]]; then
                        pip install "$package_name"
                        # Update pyproject.toml with installed version
                        installed_version=$(get_installed_version "$package_name")
                        if [[ -n "$installed_version" ]]; then
                            sed -i "/\"$package_name\"/c\\    \"$package_name==$installed_version\"," pyproject.toml
                            echo -e "${GREEN}✓ Installed $package_name==$installed_version and updated pyproject.toml${NC}"
                        fi
                    else
                        echo "Would run: pip install \"$package_name\""
                        echo "Would update pyproject.toml with installed version"
                    fi
                fi
            fi
        done
    fi
    
    elif [[ $UPGRADE_ALL == true ]]; then
    echo -e "${BLUE}=== Upgrading All Packages ===${NC}"
    if [[ $DRY_RUN == false ]]; then
        pip list --outdated --format=freeze | cut -d'=' -f1 | xargs -r pip install --upgrade
    else
        echo "Would run: pip list --outdated --format=freeze | cut -d'=' -f1 | xargs -r pip install --upgrade"
    fi
    elif [[ $UNINSTALL == true ]]; then
    echo -e "${BLUE}=== Uninstalling Packages ===${NC}"
    for package in "${PACKAGES[@]}"; do
        package_name=$(extract_package_name "$package")
        echo -e "${BLUE}Uninstalling: $package_name${NC}"
        if [[ $DRY_RUN == false ]]; then
            pip uninstall -y "$package_name"
            if [[ $NO_PYPROJECT_UPDATE == false ]]; then
                remove_from_pyproject "$package"
            fi
        else
            echo "Would run: pip uninstall -y $package_name"
            if [[ $NO_PYPROJECT_UPDATE == false ]]; then
                echo "Would remove $package_name from pyproject.toml"
            fi
        fi
    done
else
    # Install packages
    echo -e "${BLUE}=== Installing Packages ===${NC}"
    
    # Build pip install command
    INSTALL_CMD="$PIP_CMD install"
    
    if [[ $UPGRADE == true ]]; then
        INSTALL_CMD="$INSTALL_CMD --upgrade"
    fi
    
    if [[ $NO_DEPS == true ]]; then
        INSTALL_CMD="$INSTALL_CMD --no-deps"
    fi
    
    if [[ $USER_INSTALL == true ]]; then
        INSTALL_CMD="$INSTALL_CMD --user"
    fi
    
    if [[ $FORCE_REINSTALL == true ]]; then
        INSTALL_CMD="$INSTALL_CMD --force-reinstall"
    fi
    
    # Add packages to command
    for package in "${PACKAGES[@]}"; do
        INSTALL_CMD="$INSTALL_CMD \"$package\""
    done
    
    echo -e "${BLUE}Running: $INSTALL_CMD${NC}"
    
    if [[ $DRY_RUN == false ]]; then
        # Execute the install command
        eval $INSTALL_CMD
        
        echo ""
        echo -e "${BLUE}=== Updating Project Files ===${NC}"
        
        # Update pyproject.toml for each successfully installed package
        if [[ $NO_PYPROJECT_UPDATE == false ]]; then
            for package in "${PACKAGES[@]}"; do
                add_to_pyproject "$package"
            done
        fi
    else
        echo "Would run: $INSTALL_CMD"
        if [[ $NO_PYPROJECT_UPDATE == false ]]; then
            echo "Would update pyproject.toml with installed package versions"
        fi
    fi
fi

# # Update requirements.txt
# if [[ $NO_REQUIREMENTS_UPDATE == false && $DRY_RUN == false ]]; then
#     echo ""
#     update_requirements
#     elif [[ $DRY_RUN == true ]]; then
#     echo "Would update requirements.txt with: pip freeze > requirements.txt"
# fi

echo ""
echo -e "${GREEN}========================================================================${NC}"
echo -e "${GREEN}                    Operation Completed Successfully!                   ${NC}"
echo -e "${GREEN}========================================================================${NC}"

if [[ $DRY_RUN == false ]]; then
    echo ""
    echo -e "${BLUE}Summary of changes:${NC}"
    if [[ $SYNC == true ]]; then
        echo -e "• ${YELLOW}Synchronized packages with pyproject.toml${NC}"
        elif [[ $UNINSTALL == true ]]; then
        echo -e "• ${YELLOW}Uninstalled packages:${NC} ${PACKAGES[*]}"
        elif [[ $UPGRADE_ALL == true ]]; then
        echo -e "• ${YELLOW}Upgraded all outdated packages${NC}"
    else
        echo -e "• ${YELLOW}Installed packages:${NC} ${PACKAGES[*]}"
    fi
    
    if [[ $NO_PYPROJECT_UPDATE == false && $SYNC == false ]]; then
        echo -e "• ${YELLOW}Updated pyproject.toml dependencies${NC}"
    fi
    
    # if [[ $NO_REQUIREMENTS_UPDATE == false ]]; then
    #     echo -e "• ${YELLOW}Updated requirements.txt${NC}"
    # fi
else
    echo ""
    echo -e "${YELLOW}This was a dry run - no actual changes were made.${NC}"
    echo -e "${YELLOW}Remove --dry-run flag to execute the commands.${NC}"
fi
