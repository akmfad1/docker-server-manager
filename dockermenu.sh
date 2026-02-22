#!/bin/bash
# Version: 1.0.2
# Docker Server Manager - https://github.com/akmfad1/docker-server-manager

GITHUB_REPO="akmfad1/docker-server-manager"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main/dockermenu.sh"
INSTALL_PATH="/usr/local/bin/dockermenu"

CONFIG_FILE="$HOME/.config/dockermenu/config"
LOG_FILE="/var/log/dockermenu.log"
BASE_DIR="/root/docker-services"
UPDATE_CACHE_FILE="/tmp/dockermenu_update_cache"

# Extract current version from script header
CURRENT_VERSION=$(grep -m1 '^# Version:' "$0" | awk '{print $3}')

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Handle Ctrl+C gracefully
trap 'echo -e "\n${RED}برنامه با دستور کاربر متوقف شد.${NC}"; exit 130' SIGINT

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

pause() {
    read -p "Press Enter to continue..."
}

# Run version check in background, cache result to /tmp
check_update_async() {
    (
        # Skip if cache is fresh (less than 1 hour old)
        if [[ -f "$UPDATE_CACHE_FILE" ]]; then
            local cache_age=$(( $(date +%s) - $(date -r "$UPDATE_CACHE_FILE" +%s 2>/dev/null || echo 0) ))
            [[ $cache_age -lt 3600 ]] && exit 0
        fi
        # Fetch remote version silently
        if command -v curl &>/dev/null; then
            local remote_ver
            remote_ver=$(curl -fsSL --max-time 5 "$GITHUB_RAW" 2>/dev/null | grep -m1 '^# Version:' | awk '{print $3}')
            if [[ -n "$remote_ver" ]]; then
                echo "$remote_ver" > "$UPDATE_CACHE_FILE"
            fi
        fi
    ) &>/dev/null &
    disown
}

# Read cache and compare versions. Returns: "available <remote_ver>" or "uptodate"
get_update_status() {
    [[ ! -f "$UPDATE_CACHE_FILE" ]] && echo "unknown" && return
    local remote_ver
    remote_ver=$(cat "$UPDATE_CACHE_FILE" 2>/dev/null)
    [[ -z "$remote_ver" ]] && echo "unknown" && return
    if [[ "$remote_ver" != "$CURRENT_VERSION" ]]; then
        # Simple semver-style: compare version strings
        local latest
        latest=$(printf '%s\n' "$CURRENT_VERSION" "$remote_ver" | sort -V | tail -1)
        if [[ "$latest" == "$remote_ver" && "$remote_ver" != "$CURRENT_VERSION" ]]; then
            echo "available $remote_ver"
        else
            echo "uptodate"
        fi
    else
        echo "uptodate"
    fi
}

get_system_info() {
    local os_info ip_addr firewall_status docker_status crowdsec_status
    
    # OS Information
    os_info=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
    
    # IP Address (primary IP)
    ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
    
    # Firewall Status
    firewall_status=$(sudo ufw status 2>/dev/null | head -1 || echo "N/A")
    
    # Docker Status
    if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        docker_status="✓ Installed & Running"
    elif command -v docker &>/dev/null; then
        docker_status="✗ Installed (not running)"
    else
        docker_status="✗ Not installed"
    fi
    
    # CrowdSec Status
    if command -v cscli &>/dev/null; then
        crowdsec_status="✓ Installed"
    else
        crowdsec_status="✗ Not installed"
    fi
    
    echo "$os_info|$ip_addr|$firewall_status|$docker_status|$crowdsec_status"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
BASE_DIR="$BASE_DIR"
EOF
    echo -e "${GREEN}Config saved: $CONFIG_FILE${NC}"
}

first_run_wizard() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        clear
        echo -e "${GREEN}=====================================${NC}"
        echo -e "${GREEN}  Docker Server Manager - First Run  ${NC}"
        echo -e "${GREEN}=====================================${NC}"
        echo ""
        echo -e "This wizard will set up your configuration."
        echo ""
        read -p "Enter your Docker projects base directory [/root/docker-services]: " input_dir
        BASE_DIR="${input_dir:-/root/docker-services}"
        if [[ ! -d "$BASE_DIR" ]]; then
            read -p "Directory '$BASE_DIR' does not exist. Create it? (Y/n): " mk
            if [[ ! "$mk" =~ ^[nN]$ ]]; then
                mkdir -p "$BASE_DIR"
                echo -e "${GREEN}Created: $BASE_DIR${NC}"
            fi
        fi
        save_config
        echo ""
        echo -e "${GREEN}Setup complete! Starting menu...${NC}"
        sleep 1
    fi
}

self_update() {
    clear
    echo -e "${YELLOW}=== Self Update ===${NC}"
    echo -e "Fetching latest version from: ${GREEN}${GITHUB_REPO}${NC}"
    echo ""
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}curl is required for updates. Install with: apt install curl${NC}"
        pause; return
    fi
    local tmp_file
    tmp_file=$(mktemp)
    if curl -fsSL "$GITHUB_RAW" -o "$tmp_file"; then
        local remote_ver local_ver
        remote_ver=$(grep -m1 '^# Version:' "$tmp_file" | awk '{print $3}')
        local_ver=$(grep -m1 '^# Version:' "$INSTALL_PATH" 2>/dev/null | awk '{print $3}')
        echo -e "Installed : ${YELLOW}${local_ver:-unknown}${NC}"
        echo -e "Available : ${GREEN}${remote_ver:-unknown}${NC}"
        echo ""
        read -p "Update now? (y/N): " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            chmod +x "$tmp_file"
            if sudo cp "$tmp_file" "$INSTALL_PATH"; then
                sudo chmod +x "$INSTALL_PATH"
                echo -e "${GREEN}Update successful! Please restart dockermenu.${NC}"
                log_action "self-update to version $remote_ver"
                rm -f "$tmp_file" "$UPDATE_CACHE_FILE"
                exit 0
            else
                echo -e "${RED}Update failed. Could not write to $INSTALL_PATH${NC}"
            fi
        else
            echo "Update cancelled."
        fi
    else
        echo -e "${RED}Failed to fetch update. Check your internet connection or GitHub URL.${NC}"
        echo -e "Current repo: ${YELLOW}$GITHUB_RAW${NC}"
    fi
    rm -f "$tmp_file"
    pause
}

install_docker() {
    echo -e "${YELLOW}Installing Docker...${NC}"
    sudo apt update && sudo apt upgrade -y
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker "$USER"
    rm -f /tmp/get-docker.sh
    echo -e "${GREEN}Docker installed successfully.${NC}"
    docker --version
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect.${NC}"
    echo -e "${YELLOW}Running: newgrp docker${NC}"
    newgrp docker
}

install_crowdsec() {
    echo -e "${YELLOW}Installing CrowdSec...${NC}"
    curl -s https://install.crowdsec.net | sudo sh
    sudo apt install -y crowdsec
    sudo apt install -y crowdsec-firewall-bouncer-iptables
    echo -e "${GREEN}CrowdSec installed successfully.${NC}"
    pause
}

install_speedtest() {
    echo -e "${YELLOW}Installing Speedtest CLI...${NC}"
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    sudo apt-get install -y speedtest
    echo -e "${GREEN}Speedtest CLI installed successfully.${NC}"
    speedtest --version
    pause
}

backup_docker_volumes() {
    clear
    echo -e "${YELLOW}=== Docker Volumes Backup ===${NC}"
    echo ""
    
    mapfile -t volumes < <(docker volume ls --format '{{.Name}}')
    
    if [[ ${#volumes[@]} -eq 0 ]]; then
        echo -e "${RED}No Docker volumes found.${NC}"
        pause
        return
    fi
    
    echo -e "${YELLOW}Available volumes:${NC}"
    PS3="Select volume to backup (0 to cancel): "
    select vol in "${volumes[@]}" "Back"; do
        if [[ "$vol" == "Back" || -z "$vol" ]]; then
            break
        elif [[ -n "$vol" ]]; then
            local backup_dir="$BASE_DIR/backups"
            local backup_file="$backup_dir/volume_backup_${vol}_$(date +%Y%m%d_%H%M%S).tar.gz"
            
            mkdir -p "$backup_dir"
            echo -e "${YELLOW}Backing up volume: $vol${NC}"
            echo -e "${YELLOW}Output: $backup_file${NC}"
            echo ""
            
            if docker run --rm -v "$vol":/volume -v "$backup_dir":/backup alpine tar -czf "/backup/$(basename "$backup_file")" -C /volume ./; then
                local size=$(du -h "$backup_file" | awk '{print $1}')
                echo -e "${GREEN}✓ Backup completed successfully!${NC}"
                echo -e "${GREEN}Size: $size${NC}"
                log_action "Docker volume backup: $vol -> $(basename "$backup_file") ($size)"
            else
                echo -e "${RED}✗ Backup failed!${NC}"
            fi
            pause
            break
        else
            echo "Invalid selection"
        fi
    done
}

manage_docker_logs() {
    clear
    echo -e "${YELLOW}=== Docker Logs Management ===${NC}"
    echo ""
    echo "1) View Docker log disk usage"
    echo "2) Truncate all Docker container logs (clear without stopping)"
    echo "3) Clear Docker daemon logs"
    echo "4) Back"
    echo ""
    
    read -p "Select: " choice
    case $choice in
        1)
            echo -e "${YELLOW}Docker logs disk usage:${NC}"
            du -sh /var/lib/docker/containers/*/*-json.log 2>/dev/null | sort -rh | head -20 || echo "No logs found"
            echo ""
            echo -e "${YELLOW}Total logs size:${NC}"
            du -sh /var/lib/docker/containers 2>/dev/null || echo "Unable to calculate"
            pause
            ;;
        2)
            echo -e "${RED}This will clear all Docker container logs WITHOUT stopping containers.${NC}"
            read -p "Continue? (y/N): " confirm
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Truncating Docker logs...${NC}"
                sudo find /var/lib/docker/containers -name "*-json.log" -exec truncate -s 0 {} \;
                echo -e "${GREEN}✓ All Docker logs truncated successfully!${NC}"
                log_action "Docker logs truncated"
            fi
            pause
            ;;
        3)
            echo -e "${YELLOW}Clearing Docker daemon journal logs...${NC}"
            sudo journalctl --vacuum=time=7d 2>/dev/null
            sudo journalctl --vacuum=size=100M 2>/dev/null
            echo -e "${GREEN}✓ Docker daemon logs cleaned!${NC}"
            log_action "Docker daemon logs cleaned"
            pause
            ;;
        4) return ;;
        *) echo "Invalid option" ;;
    esac
}

fail2ban_menu() {
    if ! command -v fail2ban-client &>/dev/null; then
        echo -e "${RED}fail2ban is not installed.${NC}"
        read -p "Install fail2ban now? (y/N): " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${YELLOW}Installing fail2ban...${NC}"
            sudo apt update && sudo apt install -y fail2ban
            sudo systemctl enable fail2ban
            sudo systemctl start fail2ban
            echo -e "${GREEN}fail2ban installed and started.${NC}"
        else
            pause
            return
        fi
    fi
    
    while true; do
        clear
        echo -e "${YELLOW}=== Fail2Ban Management ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) Show banned IPs (SSH)"
        echo "2) Show banned IPs (all jails)"
        echo "3) Unban a specific IP"
        echo "4) View fail2ban status"
        echo "5) Show jail statistics"
        echo "6) Back"
        echo ""
        
        read -p "Select: " choice
        case $choice in
            1)
                echo -e "${YELLOW}Banned IPs in SSH jail:${NC}"
                sudo fail2ban-client status sshd 2>/dev/null || echo "SSH jail not found"
                pause
                ;;
            2)
                echo -e "${YELLOW}All fail2ban jails status:${NC}"
                sudo fail2ban-client status 2>/dev/null || echo "fail2ban service not running"
                pause
                ;;
            3)
                read -p "Enter SSH jail name [sshd]: " jail_name
                jail_name="${jail_name:-sshd}"
                
                echo -e "${YELLOW}Banned IPs in '$jail_name':${NC}"
                sudo fail2ban-client status "$jail_name" 2>/dev/null || { echo "Jail not found"; pause; continue; }
                
                echo ""
                read -p "Enter IP to unban (or press Enter to skip): " ip_to_unban
                if [[ -n "$ip_to_unban" ]]; then
                    if sudo fail2ban-client set "$jail_name" unbanip "$ip_to_unban" 2>/dev/null; then
                        echo -e "${GREEN}✓ IP $ip_to_unban has been unbanned from $jail_name${NC}"
                        log_action "fail2ban - unbanned $ip_to_unban from $jail_name"
                    else
                        echo -e "${RED}✗ Failed to unban IP (check jail name or IP format)${NC}"
                    fi
                fi
                pause
                ;;
            4)
                echo -e "${YELLOW}fail2ban service status:${NC}"
                sudo systemctl status fail2ban --no-pager 2>/dev/null || echo "fail2ban not running"
                echo ""
                echo -e "${YELLOW}fail2ban active jails:${NC}"
                sudo fail2ban-client status 2>/dev/null | grep "Jail list" || echo "No active jails"
                pause
                ;;
            5)
                echo -e "${YELLOW}Fail2Ban Statistics:${NC}"
                local jails
                jails=$(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*Jail list:[ \t]*//' | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//')
                if [[ -n "$jails" ]]; then
                    printf "%-20s %-15s %-15s\n" "Jail" "Failed" "Banned"
                    printf "%-20s %-15s %-15s\n" "----" "------" "------"
                    while IFS= read -r jail; do
                        local status=$(sudo fail2ban-client status "$jail" 2>/dev/null)
                        local failed=$(echo "$status" | grep "Currently failed" | awk -F': ' '{print $2}')
                        local banned=$(echo "$status" | grep "Currently banned" | awk -F': ' '{print $2}')
                        printf "%-20s %-15s %-15s\n" "$jail" "${failed:-0}" "${banned:-0}"
                    done <<< "$jails"
                else
                    echo "No active jails"
                fi
                pause
                ;;
            6) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

apply_arvan_whitelist() {
    clear
    echo -e "${YELLOW}=== ArvanCloud Whitelist Configuration ===${NC}"
    echo ""
    echo -e "${YELLOW}Creating ArvanCloud whitelist file...${NC}"
    echo ""
    
    # Check if CrowdSec is installed
    if ! command -v crowdsec &>/dev/null; then
        echo -e "${RED}CrowdSec is not installed.${NC}"
        read -p "Install CrowdSec now? (y/N): " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            install_crowdsec
        else
            echo -e "${RED}CrowdSec is required for this operation.${NC}"
            pause; return
        fi
    fi
    
    # Create parser directory if it doesn't exist
    sudo mkdir -p /etc/crowdsec/parsers/s02-enrich
    
    # Create the whitelist file
    sudo tee /etc/crowdsec/parsers/s02-enrich/arvan-whitelist.yaml > /dev/null <<'EOF'
name: crowdsecurity/arvan-whitelist
description: "Whitelist ArvanCloud IPs"
whitelist:
  reason: "ArvanCloud CDN Nodes"
  cidr:
    - "185.143.232.0/22"
    - "188.229.116.16/30"
    - "94.101.182.0/27"
    - "2.144.3.128/28"
    - "37.32.16.0/27"
    - "37.32.17.0/27"
    - "37.32.18.0/27"
    - "37.32.19.0/27"
    - "185.215.232.0/22"
    - "178.131.120.48/28"
EOF
    
    echo -e "${GREEN}✓ Whitelist file created successfully${NC}"
    echo ""
    echo -e "${YELLOW}Testing CrowdSec configuration...${NC}"
    
    if sudo crowdsec -t 2>&1 | grep -q "config: Ok"; then
        echo -e "${GREEN}✓ Configuration test passed${NC}"
        echo ""
        echo -e "${YELLOW}Restarting CrowdSec service...${NC}"
        sudo systemctl restart crowdsec
        echo -e "${GREEN}✓ CrowdSec restarted successfully${NC}"
        log_action "ArvanCloud whitelist applied - CrowdSec restarted"
    else
        echo -e "${RED}✗ Configuration test failed${NC}"
        echo -e "${YELLOW}Output:${NC}"
        sudo crowdsec -t
        log_action "ArvanCloud whitelist application failed - config test error"
    fi
    
    pause
}

check_requirements() {
    # Load config if exists, otherwise run first-run wizard
    if [[ -f "$CONFIG_FILE" ]]; then
        load_config
    else
        first_run_wizard
        load_config
    fi
    
    # Verify BASE_DIR exists
    if [[ ! -d "$BASE_DIR" ]]; then
        echo -e "${RED}Error: BASE_DIR '$BASE_DIR' does not exist.${NC}"
        exit 1
    fi
    
    # Check Docker installation
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}Docker is not installed.${NC}"
        read -p "Install Docker now? (y/N): " confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            install_docker
        else
            echo -e "${RED}Docker is required. Exiting.${NC}"
            exit 1
        fi
    fi
    
    # Check Docker daemon is running
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running.${NC}"
        exit 1
    fi
    
    # Setup logging
    mkdir -p "$(dirname "$LOG_FILE")" && touch "$LOG_FILE" 2>/dev/null || {
        echo -e "${YELLOW}Warning: Cannot write to log file '$LOG_FILE'. Logging disabled.${NC}"
        LOG_FILE="/dev/null"
    }
}

get_projects() {
    find "$BASE_DIR" -maxdepth 2 -name "docker-compose.yml" -exec dirname {} \;
}

select_service() {
    SERVICE=""
    mapfile -t services < <(docker compose config --services)
    select svc in "${services[@]}" "Back"; do
        if [[ "$svc" == "Back" ]]; then
            break
        elif [[ -n "$svc" ]]; then
            SERVICE="$svc"
            return
        else
            echo "Invalid selection"
        fi
    done
}

project_menu() {
    cd "$1" || return
    PROJECT_NAME=$(basename "$1")

    while true; do
        clear
        echo -e "${GREEN}Project: $PROJECT_NAME${NC}"
        echo "1)  Up (no build)"
        echo "2)  Up (with build)"
        echo "3)  Down"
        echo "4)  Restart all services"
        echo "5)  Restart single service"
        echo "6)  Logs (select service)"
        echo "7)  Logs all services (tail 100)"
        echo "8)  Exec bash (select service)"
        echo "9)  Env variables (select service)"
        echo "10) Status"
        echo "11) Pull"
        echo "12) Validate config"
        echo "13) Auto Update Stack (Pull + Up + Prune)"
        echo "14) Back"

        read -p "Select: " choice

        case $choice in
            1)
                log_action "$PROJECT_NAME - up"
                docker compose up -d
                pause
                ;;
            2)
                log_action "$PROJECT_NAME - up build"
                docker compose up -d --build
                pause
                ;;
            3)
                read -p "Bring down $PROJECT_NAME? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    log_action "$PROJECT_NAME - down"
                    docker compose down --remove-orphans
                fi
                pause
                ;;
            4)
                read -p "Restart all services in $PROJECT_NAME? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    log_action "$PROJECT_NAME - restart"
                    docker compose restart
                fi
                pause
                ;;
            5)
                select_service
                if [[ -n "$SERVICE" ]]; then
                    log_action "$PROJECT_NAME - restart $SERVICE"
                    docker compose restart "$SERVICE"
                fi
                pause
                ;;
            6)
                select_service
                if [[ -n "$SERVICE" ]]; then
                    log_action "$PROJECT_NAME - logs $SERVICE"
                    docker compose logs -f --tail 200 "$SERVICE"
                fi
                ;;
            7)
                log_action "$PROJECT_NAME - logs all"
                docker compose logs --tail 100
                pause
                ;;
            8)
                select_service
                if [[ -n "$SERVICE" ]]; then
                    log_action "$PROJECT_NAME - exec $SERVICE"
                    docker compose exec "$SERVICE" bash 2>/dev/null || docker compose exec "$SERVICE" sh
                fi
                ;;
            9)
                select_service
                if [[ -n "$SERVICE" ]]; then
                    log_action "$PROJECT_NAME - env $SERVICE"
                    docker compose exec "$SERVICE" env | sort
                    pause
                fi
                ;;
            10)
                docker compose ps
                pause
                ;;
            11)
                log_action "$PROJECT_NAME - pull"
                docker compose pull
                pause
                ;;
            12)
                docker compose config
                pause
                ;;
            13)
                echo -e "${YELLOW}This will Pull + Up + Prune dangling images${NC}"
                read -p "Continue? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    log_action "$PROJECT_NAME - auto update"
                    docker compose pull
                    docker compose up -d
                    docker image prune -f
                fi
                pause
                ;;
            14)
                break
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

monitoring_menu() {
    while true; do
        clear
        echo -e "${YELLOW}Monitoring Menu${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1)  htop"
        echo "2)  uptime"
        echo "3)  Memory (free -h)"
        echo "4)  Open ports (ss -tulpn)"
        echo "5)  Docker journal (live)"
        echo "6)  UFW status"
        echo "7)  CrowdSec metrics"
        echo "8)  CrowdSec decisions"
        echo "9)  CrowdSec - Apply ArvanCloud Whitelist"
        echo "10) Docker events (last 1h)"
        echo "11) Top memory processes"
        echo "12) Disk I/O (iostat)"
        echo "13) Last logins"
        echo "14) Failed SSH logins (today)"
        echo "15) Back"

        read -p "Select: " choice

        case $choice in
            1)  htop ;;
            2)  uptime; pause ;;
            3)  free -h; pause ;;
            4)  ss -tulpn; pause ;;
            5)  sudo journalctl -u docker -f ;;
            6)  sudo ufw status verbose; pause ;;
            7)  if ! command -v cscli &>/dev/null; then
                    echo -e "${YELLOW}CrowdSec is not installed.${NC}"
                    read -p "Install CrowdSec now? (y/N): " confirm
                    [[ "$confirm" =~ ^[yY]$ ]] && install_crowdsec
                else
                    sudo cscli metrics; pause
                fi ;;
            8)  if ! command -v cscli &>/dev/null; then
                    echo -e "${YELLOW}CrowdSec is not installed.${NC}"
                    read -p "Install CrowdSec now? (y/N): " confirm
                    [[ "$confirm" =~ ^[yY]$ ]] && install_crowdsec
                else
                    sudo cscli decisions list; pause
                fi ;;
            9)  apply_arvan_whitelist ;;
            10) docker events --since 1h --until "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; pause ;;
            11) ps aux --sort=-%mem | head -15; pause ;;
            12) iostat -xz 1 5 2>/dev/null || echo "iostat not found (install sysstat)"; pause ;;
            13) last -n 20; pause ;;
            14) sudo journalctl -u ssh --since today | grep -i "failed\|invalid\|refused" | tail -30; pause ;;
            15) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *)  echo "Invalid option";;
        esac
    done
}


crontab_wizard() {
    clear
    echo -e "${YELLOW}=== Crontab Wizard ===${NC}"
    echo ""
    echo -e "Schedule format: ${GREEN}minute hour day_of_month month day_of_week${NC}"
    echo -e "Use ${YELLOW}*${NC} for 'every', ${YELLOW}*/5${NC} for 'every 5', ${YELLOW}1-5${NC} for ranges"
    echo ""

    read -p "Step 1/6 - Minute   (0-59)  [*]: " c_min;   c_min="${c_min:-*}"
    read -p "Step 2/6 - Hour     (0-23)  [*]: " c_hour;  c_hour="${c_hour:-*}"
    read -p "Step 3/6 - Day/Month(1-31)  [*]: " c_dom;   c_dom="${c_dom:-*}"
    read -p "Step 4/6 - Month    (1-12)  [*]: " c_month; c_month="${c_month:-*}"
    read -p "Step 5/6 - Day/Week (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat) [*]: " c_dow;   c_dow="${c_dow:-*}"
    echo ""
    read -p "Step 6/6 - Command to run: " c_cmd

    if [[ -z "$c_cmd" ]]; then
        echo -e "${RED}Command cannot be empty. Cancelled.${NC}"
        pause; return
    fi

    read -p "Description/comment (optional): " c_comment

    echo ""
    echo -e "${YELLOW}--- Preview ---${NC}"
    [[ -n "$c_comment" ]] && echo "# $c_comment"
    echo "$c_min $c_hour $c_dom $c_month $c_dow $c_cmd"
    echo "----------------"
    read -p "Add this cron job? (y/N): " confirm

    if [[ "$confirm" =~ ^[yY]$ ]]; then
        (
            crontab -l 2>/dev/null
            [[ -n "$c_comment" ]] && echo "# $c_comment"
            echo "$c_min $c_hour $c_dom $c_month $c_dow $c_cmd"
        ) | crontab -
        echo -e "${GREEN}Cron job added successfully.${NC}"
        log_action "crontab - added: $c_min $c_hour $c_dom $c_month $c_dow $c_cmd"
    else
        echo "Cancelled."
    fi
    pause
}

crontab_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== Crontab Manager ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) List all cron jobs"
        echo "2) Add new cron job (wizard)"
        echo "3) Delete a cron job by line number"
        echo "4) Edit crontab directly (nano)"
        echo "5) Back"

        read -p "Select: " choice
        case $choice in
            1)
                echo -e "${YELLOW}Current crontab:${NC}"
                crontab -l 2>/dev/null || echo "No crontab found"
                pause ;;
            2) crontab_wizard ;;
            3)
                current=$(crontab -l 2>/dev/null)
                if [[ -z "$current" ]]; then
                    echo "No crontab found."; pause; continue
                fi
                echo -e "${YELLOW}Current crontab:${NC}"
                echo "$current" | nl -ba
                echo ""
                read -p "Enter line number to delete (0 to cancel): " linenum
                if [[ "$linenum" =~ ^[1-9][0-9]*$ ]]; then
                    total_lines=$(echo "$current" | wc -l)
                    if [[ $linenum -le $total_lines ]]; then
                        echo "$current" | sed "${linenum}d" | crontab -
                        echo -e "${GREEN}Line $linenum removed.${NC}"
                        log_action "crontab - removed line $linenum"
                    else
                        echo -e "${RED}Invalid line number.${NC}"
                    fi
                fi
                pause ;;
            4) EDITOR=nano crontab -e ;;
            5) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

_pkg_install() {
    local pkgs=("$@")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        dpkg -s "$pkg" &>/dev/null || to_install+=("$pkg")
    done
    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo -e "${GREEN}All packages already installed.${NC}"
    else
        echo -e "${YELLOW}Installing: ${to_install[*]}${NC}"
        sudo apt update -qq
        sudo apt install -y "${to_install[@]}"
        echo -e "${GREEN}Done.${NC}"
    fi
    pause
}

package_installer_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== Package Installer ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) Essential bundle (همه ابزارهای پایه) + speedtest"
        echo "2) Network tools      (htop, nethogs, vnstat, nmap, net-tools, dnsutils)"
        echo "3) General tools      (curl, wget, git, nano, vim, unzip, zip, tree, jq, rsync, sysstat)"
        echo "4) Security tools     (fail2ban, ufw, certbot)"
        echo "5) Terminal tools     (tmux, ncdu, iotop)"
        echo "6) Install custom package"
        echo "7) Show installed status"
        echo "8) Back"
        echo ""
        read -p "Select: " choice

        case $choice in
            1)
                _pkg_install \
                    htop ncdu iotop nethogs vnstat nmap net-tools dnsutils \
                    curl wget git nano vim unzip zip tree jq rsync sysstat \
                    fail2ban ufw certbot tmux speedtest
                ;;
            2)
                _pkg_install htop nethogs vnstat nmap net-tools dnsutils
                ;;
            3)
                _pkg_install curl wget git nano vim unzip zip tree jq rsync sysstat
                ;;
            4)
                _pkg_install fail2ban ufw certbot
                ;;
            5)
                _pkg_install tmux ncdu iotop
                ;;
            6)
                read -p "Package name(s) to install (space-separated): " custom_pkgs
                if [[ -n "$custom_pkgs" ]]; then
                    read -ra pkg_arr <<< "$custom_pkgs"
                    _pkg_install "${pkg_arr[@]}"
                fi
                ;;
            7)
                clear
                echo -e "${YELLOW}=== Package Status ===${NC}"
                echo ""
                local all_pkgs=(htop ncdu iotop nethogs vnstat nmap net-tools dnsutils
                                curl wget git nano vim unzip zip tree jq rsync sysstat
                                fail2ban ufw certbot tmux speedtest)
                printf "%-30s %s\n" "Package" "Status"
                printf "%-30s %s\n" "-------" "------"
                for pkg in "${all_pkgs[@]}"; do
                    if dpkg -s "$pkg" &>/dev/null; then
                        printf "%-30s ${GREEN}%s${NC}\n" "$pkg" "installed"
                    else
                        printf "%-30s ${RED}%s${NC}\n" "$pkg" "not installed"
                    fi
                done
                pause
                ;;
            8) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

system_menu() {
    while true; do
        clear
        echo -e "${YELLOW}System Menu${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) Disk usage (df -h)"
        echo "2) Update system (apt)"
        echo "3) Failed systemd services"
        echo "4) Cron jobs"
        echo "5) Backup compose files"
        echo "6) Package installer"
        echo "7) Reboot system"
        echo "8) Update dockermenu"
        echo "9) Back"

        read -p "Select: " choice

        case $choice in
            1)  df -h --total; pause ;;
            2)  sudo apt update && sudo apt upgrade -y; pause ;;
            3)  systemctl list-units --state=failed; pause ;;
            4)  crontab_menu ;;
            5)  BACKUP_FILE="/tmp/compose-backup-$(date +%F).tar.gz"
                tar -czf "$BACKUP_FILE" "$BASE_DIR" 2>/dev/null && echo -e "${GREEN}Backup saved: $BACKUP_FILE${NC}" || echo -e "${RED}Backup failed${NC}"
                pause ;;
            6)  package_installer_menu ;;
            7)  read -p "Reboot the system? (y/N): " confirm
                [[ "$confirm" =~ ^[yY]$ ]] && sudo reboot ;;
            8)  self_update ;;
            9)  break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *)  echo "Invalid option";;
        esac
    done
}

docker_global_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== Docker Management ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) Docker stats (live)"
        echo "2) Docker stats (snapshot)"
        echo "3) Docker system df"
        echo "4) Restart Docker service"
        echo "5) Prune stopped containers"
        echo "6) Prune unused volumes"
        echo "7) Prune unused networks"
        echo "8) Full Docker system prune"
        echo "9) Backup Docker volumes"
        echo "10) Manage Docker logs"
        echo "11) Back"

        read -p "Select: " choice

        case $choice in
            1)  docker stats ;;
            2)  docker stats --no-stream; pause ;;
            3)  docker system df -v; pause ;;
            4)  read -p "Restart Docker service? (y/N): " confirm
                [[ "$confirm" =~ ^[yY]$ ]] && sudo systemctl restart docker
                pause ;;
            5)  docker container prune -f; pause ;;
            6)  docker volume prune -f; pause ;;
            7)  docker network prune -f; pause ;;
            8)  echo -e "${RED}This removes ALL unused Docker data (images, containers, volumes, networks)!${NC}"
                read -p "Continue? (y/N): " confirm
                [[ "$confirm" =~ ^[yY]$ ]] && docker system prune -af --volumes
                pause ;;
            9)  backup_docker_volumes ;;
            10) manage_docker_logs ;;
            11) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *)  echo "Invalid option" ;;
        esac
    done
}

network_menu() {
    while true; do
        clear
        echo -e "${YELLOW}Network Menu${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) List Docker networks"
        echo "2) Inspect a network"
        echo "3) List containers in a network"
        echo "4) Remove unused networks"
        echo "5) Show host routes"
        echo "6) Show iptables rules"
        echo "7) Back"

        read -p "Select: " choice

        case $choice in
            1) docker network ls; pause ;;
            2)
                mapfile -t nets < <(docker network ls --format '{{.Name}}')
                select net in "${nets[@]}" "Back"; do
                    [[ "$net" == "Back" || -z "$net" ]] && break
                    docker network inspect "$net"; pause; break
                done
                ;;
            3)
                mapfile -t nets < <(docker network ls --format '{{.Name}}')
                select net in "${nets[@]}" "Back"; do
                    [[ "$net" == "Back" || -z "$net" ]] && break
                    docker network inspect "$net" --format '{{range .Containers}}{{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}'
                    pause; break
                done
                ;;
            4) docker network prune -f; pause ;;
            5) ip route show; pause ;;
            6) sudo iptables -L -n --line-numbers 2>/dev/null; pause ;;
            7) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option";;
        esac
    done
}

ssh_change_settings() {
    clear
    echo -e "${YELLOW}=== SSH Settings Wizard ===${NC}"
    echo ""

    local cur_port cur_maxtries cur_grace cur_maxsess
    cur_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'); cur_port="${cur_port:-22}"
    cur_maxtries=$(grep -E "^MaxAuthTries " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'); cur_maxtries="${cur_maxtries:-3}"
    cur_grace=$(grep -E "^LoginGraceTime " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'); cur_grace="${cur_grace:-20}"
    cur_maxsess=$(grep -E "^MaxSessions " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}'); cur_maxsess="${cur_maxsess:-5}"

    echo -e "  ${YELLOW}Port${NC}            : Max failed attempts before disconnect"
    read -p "  Port [$cur_port]: " new_port; new_port="${new_port:-$cur_port}"

    echo -e "  ${YELLOW}MaxAuthTries${NC}    : Max failed attempts before disconnect"
    read -p "  MaxAuthTries [$cur_maxtries]: " new_maxtries; new_maxtries="${new_maxtries:-$cur_maxtries}"

    echo -e "  ${YELLOW}LoginGraceTime${NC}  : Seconds allowed for auth after connect"
    read -p "  LoginGraceTime [$cur_grace]: " new_grace; new_grace="${new_grace:-$cur_grace}"

    echo -e "  ${YELLOW}MaxSessions${NC}     : Max simultaneous sessions per connection"
    read -p "  MaxSessions [$cur_maxsess]: " new_maxsess; new_maxsess="${new_maxsess:-$cur_maxsess}"

    echo ""
    echo -e "${YELLOW}--- Summary ---${NC}"
    echo "  Port           : $new_port"
    echo "  MaxAuthTries   : $new_maxtries"
    echo "  LoginGraceTime : $new_grace"
    echo "  MaxSessions    : $new_maxsess"
    echo "---------------"
    read -p "Apply these settings? (y/N): " confirm
    [[ ! "$confirm" =~ ^[yY]$ ]] && { echo "Cancelled."; pause; return; }

    # Backup
    local backup_file="/etc/ssh/sshd_config.bak.$(date +%F-%H%M%S)"
    sudo cp /etc/ssh/sshd_config "$backup_file"
    echo -e "${GREEN}Backup saved: $backup_file${NC}"

    # Helper to update or append a setting
    _apply_sshd() {
        local key="$1" val="$2"
        if sudo grep -qE "^${key} " /etc/ssh/sshd_config; then
            sudo sed -i "s|^${key} .*|${key} ${val}|" /etc/ssh/sshd_config
        elif sudo grep -qE "^#${key} " /etc/ssh/sshd_config; then
            sudo sed -i "s|^#${key} .*|${key} ${val}|" /etc/ssh/sshd_config
        else
            echo "${key} ${val}" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        fi
    }

    _apply_sshd "Port"           "$new_port"
    _apply_sshd "MaxAuthTries"   "$new_maxtries"
    _apply_sshd "LoginGraceTime" "$new_grace"
    _apply_sshd "MaxSessions"    "$new_maxsess"

    echo -e "${YELLOW}Disabling ssh.socket, enabling ssh.service...${NC}"
    sudo systemctl disable ssh.socket 2>/dev/null
    sudo systemctl stop    ssh.socket 2>/dev/null
    sudo systemctl enable  ssh.service
    sudo systemctl restart ssh.service 2>/dev/null

    echo -e "${YELLOW}Active SSH listeners:${NC}"
    sudo ss -tlnp | grep ssh

    echo ""
    echo -e "${YELLOW}Running config syntax test (sshd -t)...${NC}"
    if ! sudo sshd -t; then
        echo -e "${RED}Config has errors! Reverting backup...${NC}"
        sudo cp "$backup_file" /etc/ssh/sshd_config
        sudo systemctl restart ssh
        pause; return
    fi
    echo -e "${GREEN}Config syntax OK.${NC}"

    echo ""
    echo -e "${RED}IMPORTANT: Open ANOTHER terminal and test SSH login before confirming!${NC}"
    read -p "Have you confirmed SSH login works from another terminal? (y/N): " ssh_test
    if [[ "$ssh_test" =~ ^[yY]$ ]]; then
        sudo systemctl restart ssh
        log_action "SSH config changed - Port:$new_port MaxAuthTries:$new_maxtries LoginGraceTime:$new_grace MaxSessions:$new_maxsess"
        echo -e "${GREEN}SSH configuration applied successfully.${NC}"
    else
        echo -e "${RED}Reverting to backup for safety...${NC}"
        sudo cp "$backup_file" /etc/ssh/sshd_config
        sudo systemctl restart ssh
        echo -e "${YELLOW}Config reverted. SSH restarted on original settings.${NC}"
    fi
    pause
}

ssh_config_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== SSH Configuration ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        local cur_port
        cur_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
        echo -e "Current port: ${GREEN}$cur_port${NC}"
        echo ""
        echo "1) View current SSH config"
        echo "2) Change SSH settings (wizard)"
        echo "3) Test SSH config syntax (sshd -t)"
        echo "4) Restart SSH service"
        echo "5) Show active SSH listeners"
        echo "6) Back"

        read -p "Select: " choice
        case $choice in
            1) grep -vE "^#|^$" /etc/ssh/sshd_config 2>/dev/null; pause ;;
            2) ssh_change_settings ;;
            3) sudo sshd -t && echo -e "${GREEN}Config OK${NC}" || echo -e "${RED}Config has errors!${NC}"; pause ;;
            4)
                read -p "Restart SSH service? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    sudo systemctl restart ssh
                    sudo ss -tlnp | grep ssh
                fi
                pause ;;
            5) sudo ss -tlnp | grep ssh; pause ;;
            6) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

firewall_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== Firewall (UFW) ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null | head -1)
        echo -e "Status: ${GREEN}${ufw_status}${NC}"
        echo ""
        echo "1) Show full rules"
        echo "2) Enable UFW"
        echo "3) Disable UFW"
        echo "4) Allow a port/service"
        echo "5) Deny a port/service"
        echo "6) Delete a rule"
        echo "7) Fail2Ban Management"
        echo "8) Back"

        read -p "Select: " choice
        case $choice in
            1) sudo ufw status verbose; pause ;;
            2) sudo ufw enable; pause ;;
            3)
                read -p "Disable firewall? (y/N): " confirm
                [[ "$confirm" =~ ^[yY]$ ]] && sudo ufw disable
                pause ;;
            4)
                read -p "Port/service to ALLOW (e.g. 80, 443, ssh, 8080/tcp): " fw_port
                [[ -z "$fw_port" ]] && { pause; continue; }
                read -p "Comment/description: " fw_comment
                sudo ufw allow "$fw_port" comment "${fw_comment:-added by dockermenu}"
                log_action "firewall - allow $fw_port ($fw_comment)"
                pause ;;
            5)
                read -p "Port/service to DENY (e.g. 23, telnet): " fw_port
                [[ -z "$fw_port" ]] && { pause; continue; }
                read -p "Comment/description: " fw_comment
                sudo ufw deny "$fw_port" comment "${fw_comment:-added by dockermenu}"
                log_action "firewall - deny $fw_port ($fw_comment)"
                pause ;;
            6)
                sudo ufw status numbered
                echo ""
                read -p "Enter rule number to delete (0 to cancel): " rule_num
                if [[ "$rule_num" =~ ^[1-9][0-9]*$ ]]; then
                    echo "y" | sudo ufw delete "$rule_num"
                    log_action "firewall - deleted rule #$rule_num"
                fi
                pause ;;
            7)
                fail2ban_menu
                ;;
            8) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}



dns_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== DNS Management ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "Current DNS Configuration:"
        echo "--------------------------"
        grep -E "^DNS=|^FallbackDNS=" /etc/systemd/resolved.conf 2>/dev/null || echo "No custom DNS configured"
        echo ""
        echo "1) Custom DNS (دریافت از کاربر)"
        echo "2) Public DNS (عمومی) - Google & Cloudflare"
        echo "   DNS=8.8.8.8 1.1.1.1"
        echo "   FallbackDNS=9.9.9.9"
        echo "3) Shecan (شکن)"
        echo "   DNS=178.22.122.100 185.51.200.2"
        echo "   FallbackDNS=8.8.8.8"
        echo "4) Infrastructure (زیرساخت)"
        echo "   DNS=217.218.127.127 217.218.155.155"
        echo "   FallbackDNS=8.8.8.8"
        echo "5) Reset to Default (DHCP)"
        echo "6) Back"

        read -p "Select: " choice
        case $choice in
            1)
                echo -e "${YELLOW}Enter primary DNS (e.g., 8.8.8.8):${NC}"
                read -p "Primary DNS: " primary_dns
                read -p "Secondary DNS (optional): " secondary_dns
                read -p "Fallback DNS (optional): " fallback_dns
                
                if [[ -z "$primary_dns" ]]; then
                    echo -e "${RED}Primary DNS cannot be empty${NC}"
                    pause; continue
                fi
                
                sudo sed -i "/^\[Resolve\]/,/^$/s/^DNS=.*/DNS=$primary_dns ${secondary_dns:-}/" /etc/systemd/resolved.conf
                [[ -z "${secondary_dns}" ]] && sudo sed -i "s/^DNS=.*/DNS=$primary_dns/" /etc/systemd/resolved.conf
                [[ -n "${secondary_dns}" ]] && sudo sed -i "s/^DNS=.*/DNS=$primary_dns $secondary_dns/" /etc/systemd/resolved.conf
                [[ -n "${fallback_dns}" ]] && (grep -q "^FallbackDNS=" /etc/systemd/resolved.conf && sudo sed -i "s/^FallbackDNS=.*/FallbackDNS=$fallback_dns/" /etc/systemd/resolved.conf || echo "FallbackDNS=$fallback_dns" | sudo tee -a /etc/systemd/resolved.conf > /dev/null)
                
                sudo systemctl restart systemd-resolved
                echo -e "${GREEN}DNS configuration updated${NC}"
                log_action "DNS changed to: $primary_dns ${secondary_dns:-} (Fallback: ${fallback_dns:-none})"
                pause
                ;;
            2)
                _apply_dns "8.8.8.8 1.1.1.1" "9.9.9.9" "Public DNS"
                ;;
            3)
                _apply_dns "178.22.122.100 185.51.200.2" "8.8.8.8" "Shecan"
                ;;
            4)
                _apply_dns "217.218.127.127 217.218.155.155" "8.8.8.8" "Infrastructure"
                ;;
            5)
                echo -e "${YELLOW}Resetting DNS to DHCP...${NC}"
                sudo sed -i "s/^DNS=.*/# DNS=/; s/^FallbackDNS=.*/# FallbackDNS=/" /etc/systemd/resolved.conf
                sudo systemctl restart systemd-resolved
                echo -e "${GREEN}DNS reset to DHCP defaults${NC}"
                log_action "DNS reset to DHCP defaults"
                pause
                ;;
            6) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

_apply_dns() {
    local dns_servers="$1" fallback_dns="$2" preset_name="$3"
    
    echo -e "${YELLOW}Applying $preset_name DNS configuration...${NC}"
    
    # Create backup
    sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak.$(date +%s)
    
    # Update DNS settings
    if grep -q "^DNS=" /etc/systemd/resolved.conf; then
        sudo sed -i "s/^DNS=.*/DNS=$dns_servers/" /etc/systemd/resolved.conf
    else
        sudo sed -i "/\[Resolve\]/a DNS=$dns_servers" /etc/systemd/resolved.conf
    fi
    
    if grep -q "^FallbackDNS=" /etc/systemd/resolved.conf; then
        sudo sed -i "s/^FallbackDNS=.*/FallbackDNS=$fallback_dns/" /etc/systemd/resolved.conf
    else
        sudo sed -i "/\[Resolve\]/a FallbackDNS=$fallback_dns" /etc/systemd/resolved.conf
    fi
    
    # Restart systemd-resolved
    sudo systemctl restart systemd-resolved
    
    echo -e "${GREEN}✓ $preset_name DNS applied successfully${NC}"
    echo -e "${YELLOW}DNS Servers:${NC} $dns_servers"
    echo -e "${YELLOW}Fallback DNS:${NC} $fallback_dns"
    log_action "DNS changed to $preset_name: $dns_servers (Fallback: $fallback_dns)"
    pause
}

network_test_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== Network Testing ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        echo ""
        echo "1) Ping google.com (4 packets)"
        echo "2) DNS Lookup google.com"
        echo "3) DNS Lookup (current resolver)"
        echo "4) Network interface info (ip addr)"
        echo "5) Network routes"
        echo "6) Speed test (download test)"
        echo "7) Speedtest CLI (Ookla Speedtest)"
        echo "8) DNS servers being used (systemd-resolved)"
        echo "9) Back"

        read -p "Select: " choice
        case $choice in
            1)
                echo -e "${YELLOW}Pinging google.com...${NC}"
                ping -c 4 google.com
                pause
                ;;
            2)
                echo -e "${YELLOW}Performing DNS lookup for google.com...${NC}"
                nslookup google.com
                pause
                ;;
            3)
                echo -e "${YELLOW}Using host command for DNS lookup...${NC}"
                host google.com
                pause
                ;;
            4)
                echo -e "${YELLOW}Network Interfaces:${NC}"
                ip addr
                pause
                ;;
            5)
                echo -e "${YELLOW}Network Routes:${NC}"
                ip route
                pause
                ;;
            6)
                echo -e "${YELLOW}Testing network speed (downloading 1MB from Google)...${NC}"
                curl -o /dev/null -s -w "Speed: %{speed_download} bytes/sec\nTime: %{time_total}s\n" https://www.google.com
                pause
                ;;
            7)
                if ! command -v speedtest &>/dev/null; then
                    echo -e "${RED}Speedtest CLI is not installed.${NC}"
                    read -p "Install Speedtest CLI now? (y/N): " confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        install_speedtest
                    else
                        echo -e "${RED}Speedtest CLI is required for this operation.${NC}"
                        pause
                        continue
                    fi
                fi
                echo -e "${YELLOW}Running Speedtest CLI...${NC}"
                echo -e "${YELLOW}This may take a minute...${NC}"
                speedtest
                pause
                ;;
            8)
                echo -e "${YELLOW}Current DNS Configuration:${NC}"
                systemd-resolve --status | grep -A 20 "^[^ ]"
                pause
                ;;
            9) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

system_settings_menu() {
    while true; do
        clear
        echo -e "${YELLOW}=== System Settings ===${NC}"
        echo "Tip: Press 'b' to go back, 'e' to exit"
        local cur_tz cur_host
        cur_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "unknown")
        cur_host=$(hostname)
        echo -e "  Timezone : ${GREEN}$cur_tz${NC}"
        echo -e "  Hostname : ${GREEN}$cur_host${NC}"
        echo ""
        echo "1) Set timezone to Asia/Tehran"
        echo "2) Set custom timezone"
        echo "3) Change hostname"
        echo "4) DNS Management"
        echo "5) Network Testing"
        echo "6) Show full system info"
        echo "7) Back"

        read -p "Select: " choice
        case $choice in
            1)
                sudo timedatectl set-timezone Asia/Tehran
                echo -e "${GREEN}Timezone set to Asia/Tehran.${NC}"
                timedatectl
                log_action "timezone set to Asia/Tehran"
                pause ;;
            2)
                echo -e "${YELLOW}Examples: Europe/London, US/Eastern, UTC${NC}"
                read -p "Enter timezone: " tz_input
                if [[ -n "$tz_input" ]] && timedatectl list-timezones | grep -q "^${tz_input}$"; then
                    sudo timedatectl set-timezone "$tz_input"
                    echo -e "${GREEN}Timezone set to $tz_input.${NC}"
                    log_action "timezone set to $tz_input"
                else
                    echo -e "${RED}Invalid or empty timezone: '$tz_input'${NC}"
                fi
                pause ;;
            3)
                read -p "New hostname [$cur_host]: " new_hostname
                if [[ -n "$new_hostname" && "$new_hostname" != "$cur_host" ]]; then
                    sudo hostnamectl set-hostname "$new_hostname"
                    echo -e "${GREEN}Hostname changed to: $new_hostname${NC}"
                    log_action "hostname changed from $cur_host to $new_hostname"
                else
                    echo "No change."
                fi
                pause ;;
            4)
                dns_menu
                ;;
            5)
                network_test_menu
                ;;
            6)
                echo -e "${YELLOW}--- hostnamectl ---${NC}"
                hostnamectl
                echo ""
                echo -e "${YELLOW}--- timedatectl ---${NC}"
                timedatectl
                pause ;;
            7) break ;;
            b|B) break ;;
            e|E) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        echo -e "${GREEN}Docker Server Manager${NC}"
        echo "---------------------------------"
        echo -e "${YELLOW}Repository:${NC} https://github.com/${GITHUB_REPO}"
        echo -e "${YELLOW}Version:${NC} ${CURRENT_VERSION}"

        # Check for update and show banner if available
        local update_status
        update_status=$(get_update_status)
        local UPDATE_AVAILABLE=false
        if [[ "$update_status" == available* ]]; then
            local remote_ver="${update_status#available }"
            UPDATE_AVAILABLE=true
            echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║  🆕 نسخه جدید موجود است: ${GREEN}v${remote_ver}${CYAN}          ║${NC}"
            echo -e "${CYAN}║  برای بروزرسانی گزینه Update را انتخاب کنید ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
        fi
        echo ""

        # Display System Information
        IFS='|' read -r os_info ip_addr firewall_status docker_status crowdsec_status < <(get_system_info)
        echo -e "${YELLOW}System Information:${NC}"
        echo -e "  OS:        $os_info"
        echo -e "  IP:        $ip_addr"
        echo -e "  Firewall:  $firewall_status"
        echo -e "  Docker:    $docker_status"
        echo -e "  CrowdSec:  $crowdsec_status"
        echo ""
        echo "Tip: Press 'e' to exit"
        echo ""

        mapfile -t projects < <(get_projects)
        i=1
        for proj in "${projects[@]}"; do
            echo "$i) $(basename "$proj")"
            ((i++))
        done

        echo "$i) Monitoring"
        ((i++))
        echo "$i) Docker Management"
        ((i++))
        echo "$i) Network Menu"
        ((i++))
        echo "$i) System Menu"
        ((i++))
        echo "$i) Firewall"
        ((i++))
        echo "$i) SSH Config"
        ((i++))
        echo "$i) System Settings"
        ((i++))
        if $UPDATE_AVAILABLE; then
            echo -e "${CYAN}$i) 🆕 Update dockermenu (v${remote_ver} available)${NC}"
        else
            echo "$i) Update dockermenu"
        fi
        ((i++))
        echo "$i) Exit"

        read -p "Select: " choice

        if [[ $choice -ge 1 && $choice -lt $((i-8)) ]]; then
            project_menu "${projects[$((choice-1))]}"
        elif [[ $choice -eq $((i-8)) ]]; then
            monitoring_menu
        elif [[ $choice -eq $((i-7)) ]]; then
            docker_global_menu
        elif [[ $choice -eq $((i-6)) ]]; then
            network_menu
        elif [[ $choice -eq $((i-5)) ]]; then
            system_menu
        elif [[ $choice -eq $((i-4)) ]]; then
            firewall_menu
        elif [[ $choice -eq $((i-3)) ]]; then
            ssh_config_menu
        elif [[ $choice -eq $((i-2)) ]]; then
            system_settings_menu
        elif [[ $choice -eq $((i-1)) ]]; then
            self_update
        elif [[ $choice -eq $i ]]; then
            exit 0
        elif [[ "$choice" =~ ^[eE]$ ]]; then
            exit 0
        else
            echo "Invalid option"
            sleep 1
        fi
    done
}


check_requirements
check_update_async
main_menu
