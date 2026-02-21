#!/bin/bash
# Version: 1.0.1
# Docker Server Manager - https://github.com/akmfad1/docker-server-manager

GITHUB_REPO="akmfad1/docker-server-manager"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main/dockermenu.sh"
INSTALL_PATH="/usr/local/bin/dockermenu"

CONFIG_FILE="$HOME/.config/dockermenu/config"
LOG_FILE="/var/log/dockermenu.log"
BASE_DIR="/root/docker-services"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

pause() {
    read -p "Press Enter to continue..."
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
                rm -f "$tmp_file"
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

check_requirements() {
    load_config
    first_run_wizard
    load_config
    if [[ ! -d "$BASE_DIR" ]]; then
        echo -e "${RED}Error: BASE_DIR '$BASE_DIR' does not exist.${NC}"
        exit 1
    fi
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
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running.${NC}"
        exit 1
    fi
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
        echo "9)  Docker events (last 1h)"
        echo "10) Top memory processes"
        echo "11) Disk I/O (iostat)"
        echo "12) Last logins"
        echo "13) Failed SSH logins (today)"
        echo "14) Back"

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
            9)  docker events --since 1h --until "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; pause ;;
            10) ps aux --sort=-%mem | head -15; pause ;;
            11) iostat -xz 1 5 2>/dev/null || echo "iostat not found (install sysstat)"; pause ;;
            12) last -n 20; pause ;;
            13) sudo journalctl -u ssh --since today | grep -i "failed\|invalid\|refused" | tail -30; pause ;;
            14) break ;;
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
        echo "1) Essential bundle (همه ابزارهای پایه)"
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
                    fail2ban ufw certbot tmux
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
                                fail2ban ufw certbot tmux)
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
        echo "9) Back"

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
            9)  break ;;
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
        echo "7) Back"

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
            7) break ;;
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
        echo "4) Show full system info"
        echo "5) Back"

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
                echo -e "${YELLOW}--- hostnamectl ---${NC}"
                hostnamectl
                echo ""
                echo -e "${YELLOW}--- timedatectl ---${NC}"
                timedatectl
                pause ;;
            5) break ;;
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
        echo -e "${YELLOW}Version:${NC} 1.0.1"
        echo -e "${YELLOW}Location:${NC} ${INSTALL_PATH:-$0}"
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
        echo "$i) Exit"

        read -p "Select: " choice

        if [[ $choice -ge 1 && $choice -lt $((i-7)) ]]; then
            project_menu "${projects[$((choice-1))]}"
        elif [[ $choice -eq $((i-7)) ]]; then
            monitoring_menu
        elif [[ $choice -eq $((i-6)) ]]; then
            docker_global_menu
        elif [[ $choice -eq $((i-5)) ]]; then
            network_menu
        elif [[ $choice -eq $((i-4)) ]]; then
            system_menu
        elif [[ $choice -eq $((i-3)) ]]; then
            firewall_menu
        elif [[ $choice -eq $((i-2)) ]]; then
            ssh_config_menu
        elif [[ $choice -eq $((i-1)) ]]; then
            system_settings_menu
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
main_menu
