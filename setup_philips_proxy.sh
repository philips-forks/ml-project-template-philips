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
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ciscoumbrella.pem
export SSL_CERT_FILE=/etc/ssl/certs/ciscoumbrella.pem
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ciscoumbrella.pem
alias pip='env -u SSL_CERT_FILE -u REQUESTS_CA_BUNDLE pip'
${PROXY_SETTINGS_END}"
BASHRC="/root/.bashrc"
CERT_PATH="/usr/local/share/ca-certificates/ciscoumbrella.crt"
PEM_PATH="/etc/ssl/certs/ciscoumbrella.pem"
CER_TMP="/ciscoumbrella.cer"

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
    if [ ! -f "$CERT_PATH" ]; then
        echo -e "${BLUE}Downloading and installing Cisco Umbrella certificate...${NC}"
        curl -fsSL -o "$CER_TMP" http://www.cisco.com/security/pki/certs/ciscoumbrellaroot.cer \
        && openssl x509 -inform DER -in "$CER_TMP" -out "$CERT_PATH" \
        && update-ca-certificates \
        && rm -f "$CER_TMP"
        echo -e "${BLUE}Certificate installed at $CERT_PATH.${NC}"
    else
        echo -e "${YELLOW}Certificate already installed at $CERT_PATH.${NC}"
    fi
    echo ""
    echo -e "${GREEN}Proxy setup completed successfully!${NC}"
    echo -e "${BLUE}Next step:${NC}"
    echo -e "• ${YELLOW}Run ${NC}\`source $BASHRC\`${YELLOW} or restart your shell to apply changes.${NC}"
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
    if [ -f "$CERT_PATH" ]; then
        rm -f "$CERT_PATH"
        update-ca-certificates --fresh
        echo -e "${BLUE}Certificate removed from $CERT_PATH.${NC}"
    else
        echo -e "${YELLOW}No certificate found at $CERT_PATH.${NC}"
    fi
    echo ""
    echo -e "${GREEN}Proxy removal completed successfully!${NC}"
    echo -e "${BLUE}Next step:${NC}"
    echo -e "• ${YELLOW}Run ${NC}\`source $BASHRC\`${YELLOW} or restart your shell to apply changes.${NC}"
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