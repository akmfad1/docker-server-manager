#!/bin/bash
# Docker Server Manager - Installer
# https://github.com/akmfad1/docker-server-manager

set -e

GITHUB_REPO="akmfad1/docker-server-manager"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main/dockermenu.sh"
INSTALL_PATH="/usr/local/bin/dockermenu"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Docker Server Manager - Installer   ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check root or sudo
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${YELLOW}Note: sudo will be used for installation to $INSTALL_PATH${NC}"
fi

# Check curl
if ! command -v curl &>/dev/null; then
    echo -e "${YELLOW}Installing curl...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y curl
fi

echo -e "Downloading from: ${YELLOW}${GITHUB_RAW}${NC}"
echo ""

if curl -fsSL "$GITHUB_RAW" -o /tmp/dockermenu.sh; then
    sudo mv /tmp/dockermenu.sh "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH"
    echo -e "${GREEN}✓ Installed to: $INSTALL_PATH${NC}"
else
    echo -e "${RED}Download failed. Check your internet connection.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo -e "Run with: ${YELLOW}dockermenu${NC}"
echo -e "Or:       ${YELLOW}sudo dockermenu${NC}"
echo ""
