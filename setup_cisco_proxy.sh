#!/bin/bash
set -e

# Colors for output
GREEN='\033[1;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Safety check - ensure script is run only in Docker container
check_docker_environment() {
    echo -e "\033[1;31m⚠️  WARNING: This script should ONLY be used within a Docker container! ⚠️\033[0m"
    echo -e "\033[1;31m   Running this script on your host system may modify system-wide proxy settings.\033[0m"
    echo ""
    
    # Check if we're likely in a container
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        echo -e "${GREEN}✓ Docker container environment detected.${NC}"
    else
        echo -e "${RED}✗ This does not appear to be a Docker container environment.${NC}"
        echo -e "${YELLOW}  Are you sure you want to proceed? This may affect your host system.${NC}"
    fi
    
    echo ""
    read -p "Are you running this inside a Docker container? [y/N]: " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborting for safety. Please run this script only within a Docker container.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Proceeding with proxy setup...${NC}"
    echo ""
}

# --------------------------------- Install Cisco proxy ---------------------------------
PROXY_SETTINGS_START="# --- Cisco Proxy Settings START ---"
PROXY_SETTINGS_END="# --- Cisco Proxy Settings END ---"
PROXY_SETTINGS="${PROXY_SETTINGS_START}
export HTTP_PROXY=http://146.112.255.50:80
export HTTPS_PROXY=http://146.112.255.50:443
export NO_PROXY=localhost,127.0.0.1,.philips.com
export http_proxy=http://146.112.255.50:80
export https_proxy=http://146.112.255.50:443
export no_proxy=localhost,127.0.0.1,.philips.com
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/combined-certs.pem
export SSL_CERT_FILE=/etc/ssl/certs/combined-certs.pem
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/combined-certs.pem
# alias pip='env -u SSL_CERT_FILE -u REQUESTS_CA_BUNDLE pip'
${PROXY_SETTINGS_END}"
BASHRC="/root/.bashrc"
CERT_PATH="/usr/local/share/ca-certificates/ciscoumbrella.crt"
PEM_PATH="/etc/ssl/certs/ciscoumbrella.pem"
COMBINED_CERT_PATH="/etc/ssl/certs/combined-certs.pem"
CER_TMP="/ciscoumbrella.cer"
PIP_INSTALL_SCRIPT="pip_install.sh"

# Function to download and install individual Cisco certificate
setup_individual_cert() {
    echo -e "${BLUE}Downloading and installing Cisco Umbrella certificate...${NC}"
    curl -fsSL -o "$CER_TMP" http://www.cisco.com/security/pki/certs/ciscoumbrellaroot.cer \
    && openssl x509 -inform DER -in "$CER_TMP" -out "$CERT_PATH" \
    && update-ca-certificates \
    && rm -f "$CER_TMP"
    echo -e "${BLUE}Certificate installed at $CERT_PATH.${NC}"
}

# Function to create combined certificate bundle (certifi + corporate CA)
setup_combined_cert() {
    echo -e "${BLUE}Creating combined certificate bundle (certifi + Cisco CA)...${NC}"
    
    # First, ensure the individual certificate is installed
    if [ ! -f "$CERT_PATH" ]; then
        setup_individual_cert
    fi
    
    # Check if Python and certifi are available
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
        elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    else
        echo -e "${YELLOW}Warning: Python not found. Falling back to individual certificate setup.${NC}"
        echo -e "${YELLOW}This may cause issues with tunneled domains.${NC}"
        return 1
    fi
    
    # Create combined certificate bundle
    echo -e "${BLUE}Building combined certificate bundle...${NC}"
    $PYTHON_CMD - <<'PY'
import sys
try:
    import certifi
    import shutil
    import os

    dst = "/etc/ssl/certs/combined-certs.pem"
    shutil.copyfile(certifi.where(), dst)
    print(f"Base (certifi) copied to: {dst}")

    # Ensure proper permissions
    os.chmod(dst, 0o644)

except ImportError:
    print("Error: certifi package not found. Please install it first.")
    sys.exit(1)
except Exception as e:
    print(f"Error creating combined certificate bundle: {e}")
    sys.exit(1)
PY
    
    if [ $? -eq 0 ]; then
        # Append the Cisco certificate to the combined bundle
        if [ -f "$PEM_PATH" ]; then
            cat "$PEM_PATH" >> "$COMBINED_CERT_PATH"
            echo -e "${BLUE}Cisco certificate appended to combined bundle.${NC}"
            echo -e "${GREEN}Combined certificate bundle created at $COMBINED_CERT_PATH${NC}"
            return 0
        else
            echo -e "${RED}Error: Cisco certificate not found at $PEM_PATH${NC}"
            return 1
        fi
    else
        echo -e "${RED}Error: Failed to create combined certificate bundle.${NC}"
        return 1
    fi
}

# Function to clean up certificate files
cleanup_certificates() {
    echo -e "${BLUE}Cleaning up certificate files...${NC}"
    
    # Remove individual certificate
    if [ -f "$CERT_PATH" ]; then
        rm -f "$CERT_PATH"
        echo -e "${BLUE}Individual certificate removed from $CERT_PATH.${NC}"
    fi
    
    # Remove combined certificate bundle
    if [ -f "$COMBINED_CERT_PATH" ]; then
        rm -f "$COMBINED_CERT_PATH"
        echo -e "${BLUE}Combined certificate bundle removed from $COMBINED_CERT_PATH.${NC}"
    fi
    
    # Update CA certificates
    update-ca-certificates --fresh
}

# Function to update /etc/environment
update_etc_environment() {
    local env_file="/etc/environment"
    
    if grep -q "$PROXY_SETTINGS_START" "$env_file" 2>/dev/null; then
        echo -e "${YELLOW}Proxy settings already present in $env_file. Skipping.${NC}"
    else
        echo -e "${BLUE}Adding proxy settings to $env_file...${NC}"
        # Convert export statements to simple VAR=value format for /etc/environment
        cat >> "$env_file" << EOF
$PROXY_SETTINGS_START
HTTP_PROXY=http://146.112.255.50:80
HTTPS_PROXY=http://146.112.255.50:443
NO_PROXY=localhost,127.0.0.1,.philips.com
http_proxy=http://146.112.255.50:80
https_proxy=http://146.112.255.50:443
no_proxy=localhost,127.0.0.1,.philips.com
REQUESTS_CA_BUNDLE=/etc/ssl/certs/combined-certs.pem
SSL_CERT_FILE=/etc/ssl/certs/combined-certs.pem
NODE_EXTRA_CA_CERTS=/etc/ssl/certs/combined-certs.pem
$PROXY_SETTINGS_END
EOF
        echo -e "${BLUE}Proxy settings added to $env_file.${NC}"
    fi
}

# Function to remove proxy settings from /etc/environment
remove_from_etc_environment() {
    local env_file="/etc/environment"
    
    if grep -q "$PROXY_SETTINGS_START" "$env_file" 2>/dev/null; then
        echo -e "${BLUE}Removing proxy settings from $env_file...${NC}"
        sed -i "/$PROXY_SETTINGS_START/,/$PROXY_SETTINGS_END/d" "$env_file"
        echo -e "${BLUE}Proxy settings removed from $env_file.${NC}"
    else
        echo -e "${YELLOW}No proxy settings found in $env_file.${NC}"
    fi
}

show_help() {
    echo -e "\033[1mUsage:\033[0m $0 [--set|--unset|--help]"
    echo ""
    echo -e "\033[1;31m⚠️  WARNING: This script should ONLY be used within a Docker container! ⚠️\033[0m"
    echo -e "\033[1;31m   Do NOT run this script on your host system.\033[0m"
    echo ""
    echo -e "\033[1mDescription:\033[0m"
    echo "  Configure Cisco corporate proxy settings and certificate for the container."
    echo ""
    echo -e "\033[1mOptions:\033[0m"
    echo "  --set     Set up Cisco proxy settings and install certificate (default if no arg)"
    echo "  --unset   Remove Cisco proxy settings and uninstall certificate"
    echo "  --help    Show this help message"
}

set_proxy() {
    echo ""
    echo -e "${BLUE}=== Setting up Cisco Proxy ===${NC}"
    if grep -q "$PROXY_SETTINGS_START" "$BASHRC"; then
        echo -e "${YELLOW}Proxy settings already present in $BASHRC. Skipping append.${NC}"
    else
        echo "$PROXY_SETTINGS" >> "$BASHRC"
        echo -e "${BLUE}Proxy settings appended to $BASHRC.${NC}"
    fi
    
    # Update /etc/environment for system-wide proxy settings
    update_etc_environment
    
    # # Update PIP_CMD in pip_install.sh
    # if [ -f "$PIP_INSTALL_SCRIPT" ]; then
    #     echo -e "${BLUE}Updating PIP_CMD in $PIP_INSTALL_SCRIPT...${NC}"
    #     sed -i 's/^PIP_CMD="pip"/PIP_CMD="env -u SSL_CERT_FILE -u REQUESTS_CA_BUNDLE pip"/' "$PIP_INSTALL_SCRIPT"
    #     echo -e "${BLUE}PIP_CMD updated in $PIP_INSTALL_SCRIPT.${NC}"
    # else
    #     echo -e "${YELLOW}Warning: $PIP_INSTALL_SCRIPT not found. Skipping PIP_CMD update.${NC}"
    # fi
    
    # Set up certificate bundle
    if [ ! -f "$COMBINED_CERT_PATH" ]; then
        echo -e "${BLUE}Setting up certificate bundle...${NC}"
        if setup_combined_cert; then
            echo -e "${GREEN}✓ Combined certificate bundle configured successfully.${NC}"
            echo -e "${BLUE}  This bundle includes both standard CAs and the Cisco certificate.${NC}"
            echo -e "${BLUE}  This should work with both corporate proxy and tunneled domains.${NC}"
        else
            echo -e "${YELLOW}⚠ Falling back to individual certificate setup.${NC}"
            echo -e "${YELLOW}  Note: This may cause issues with tunneled domains.${NC}"
            if [ ! -f "$CERT_PATH" ]; then
                setup_individual_cert
            fi
        fi
    else
        echo -e "${YELLOW}Combined certificate bundle already exists at $COMBINED_CERT_PATH.${NC}"
    fi
    echo ""
    echo -e "${GREEN}Proxy setup completed successfully!${NC}"
    echo -e "${BLUE}Next step:${NC}"
    echo -e "• ${YELLOW}Run ${NC}\`source $BASHRC\`${YELLOW} or restart your shell to apply changes.${NC}"
    echo -e "• ${YELLOW}Note: System-wide environment variables (from /etc/environment) will be available after container restart.${NC}"
}

unset_proxy() {
    echo ""
    echo -e "${BLUE}=== Removing Cisco Proxy ===${NC}"
    if grep -q "$PROXY_SETTINGS_START" "$BASHRC"; then
        sed -i "/$PROXY_SETTINGS_START/,/$PROXY_SETTINGS_END/d" "$BASHRC"
        echo -e "${BLUE}Proxy settings removed from $BASHRC.${NC}"
    else
        echo -e "${YELLOW}No proxy settings found in $BASHRC.${NC}"
    fi
    
    # Remove proxy settings from /etc/environment
    remove_from_etc_environment
    
    # # Restore original PIP_CMD in pip_install.sh
    # if [ -f "$PIP_INSTALL_SCRIPT" ]; then
    #     echo -e "${BLUE}Restoring original PIP_CMD in $PIP_INSTALL_SCRIPT...${NC}"
    #     sed -i 's/^PIP_CMD="env -u SSL_CERT_FILE -u REQUESTS_CA_BUNDLE pip"/PIP_CMD="pip"/' "$PIP_INSTALL_SCRIPT"
    #     echo -e "${BLUE}PIP_CMD restored in $PIP_INSTALL_SCRIPT.${NC}"
    # else
    #     echo -e "${YELLOW}Warning: $PIP_INSTALL_SCRIPT not found. Skipping PIP_CMD restore.${NC}"
    # fi
    
    # Clean up certificate files
    cleanup_certificates
    echo ""
    echo -e "${GREEN}Proxy removal completed successfully!${NC}"
    echo -e "${BLUE}Next step:${NC}"
    echo -e "• ${YELLOW}Run ${NC}\`source $BASHRC\`${YELLOW} or restart your shell to apply changes.${NC}"
    echo -e "• ${YELLOW}Note: System-wide environment variables will be fully removed after container restart.${NC}"
}

case "$1" in
    --set|"")
        # Run safety check before proceeding
        check_docker_environment
        set_proxy
    ;;
    --unset)
        # Run safety check before proceeding
        check_docker_environment
        unset_proxy
    ;;
    --help|-h)
        show_help
    ;;
    *)
        echo -e "${RED}Unknown argument: $1${NC}"
        show_help
        exit 1
    ;;
esac