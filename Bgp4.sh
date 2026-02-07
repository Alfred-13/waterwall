#!/bin/bash

# Color Codes
Purple='\033[0;35m'
Cyan='\033[0;36m'
cyan='\033[0;36m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
yellow='\033[0;33m'
White='\033[0;96m'
RED='\033[0;31m'
red='\033[0;31m'
BLUE='\033[0;34m'
green='\033[0;32m'
MAGENTA='\033[0;35m'
rest='\033[0m' # Reset Color

# Detect the Linux distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "${ID}" in
        ubuntu | debian)
            p_m="apt-get"
            ;;
        centos)
            p_m="yum"
            ;;
        fedora)
            p_m="dnf"
            ;;
        *)
            echo -e "${red}Unsupported distribution!${rest}"
            exit 1
            ;;
        esac
    else
        echo -e "${red}Unsupported distribution!${rest}"
        exit 1
    fi
}

# Install Dependencies
check_dependencies() {
    detect_distribution

    local dependencies
    dependencies=("wget" "curl" "unzip" "socat" "jq")

    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" &>/dev/null; then
            echo -e "${YELLOW} ${dep} is not installed. Installing...${rest}"
            sudo "${p_m}" update -y && sudo "${p_m}" install "${dep}" -y
        fi
    done
}

# Check and install waterwall
install_waterwall() {
    INSTALL_DIR="/root/Waterwall"
    FILE_NAME="Waterwall"

    if [ ! -f "$INSTALL_DIR/$FILE_NAME" ]; then
        check_dependencies
        echo ""
        echo -e "${YELLOW}============================${rest}"
        echo -e "${YELLOW}Installing Waterwall...${rest}"

        # Determine the download URL based on your specific link
        ARCH=$(uname -m)
        if [ "$ARCH" == "x86_64" ]; then
            DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.41/Waterwall-linux-clang-x64.zip"
        elif [ "$ARCH" == "aarch64" ]; then
            DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.41/Waterwall-linux-arm64.zip"
        else
            echo -e "${red}Unsupported architecture: $ARCH${rest}"
            return 1
        fi

        echo -e "${YELLOW}Downloading from: ${cyan}${DOWNLOAD_URL}${rest}"

        # Create the installation directory
        mkdir -p "$INSTALL_DIR"

        # Download the ZIP file
        ZIP_FILE="$INSTALL_DIR/Waterwall.zip"
        curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"
        
        if [ $? -ne 0 ] || [ ! -s "$ZIP_FILE" ]; then
            echo -e "${red}Download failed or file is empty.${rest}"
            return 1
        fi

        # Unzip - using -j to junk paths and extract directly to INSTALL_DIR
        unzip -o "$ZIP_FILE" -d "$INSTALL_DIR"
        
        # شناسایی نام فایل استخراج شده (چون ممکنه Waterwall یا WaterWall باشه)
        # این بخش چک میکنه اگر فایلی با نام WaterWall (W بزرگ) اومد، به نامی که اسکریپت میخواد تغییرش بده
        if [ -f "$INSTALL_DIR/WaterWall" ] && [ ! -f "$INSTALL_DIR/Waterwall" ]; then
            mv "$INSTALL_DIR/WaterWall" "$INSTALL_DIR/Waterwall"
        fi

        if [ $? -ne 0 ]; then
            echo -e "${red}Unzip failed.${rest}"
            rm -f "$ZIP_FILE"
            return 1
        fi

        rm -f "$ZIP_FILE"

        # Set executable permission
        chmod +x "$INSTALL_DIR/$FILE_NAME"
        
        echo -e "${green}Waterwall installed successfully in $INSTALL_DIR.${rest}"
        echo -e "${YELLOW}============================${rest}"
        return 0
    fi
}

# --- بقیه توابع (core_json, bgp4, service و غیره) بدون تغییر در منطق اما با اصلاح متغیر رنگ‌ها استفاده می‌شوند ---

create_core_json() {
    if [ ! -d /root/Waterwall ]; then
        mkdir -p /root/Waterwall
    fi

    if [ ! -f /root/Waterwall/core.json ]; then
        echo -e "${YELLOW}Creating core.json...${rest}"
        cat <<EOF >/root/Waterwall/core.json
{
    "log": {
        "path": "log/",
        "core": {
            "loglevel": "DEBUG",
            "file": "core.log",
            "console": true
        },
        "network": {
            "loglevel": "DEBUG",
            "file": "network.log",
            "console": true
        },
        "dns": {
            "loglevel": "SILENT",
            "file": "dns.log",
            "console": false
        }
    },
    "dns": {},
    "misc": {
        "workers": 0,
        "ram-profile": "server",
        "libs-path": "libs/"
    },
    "configs": [
        "config.json"
    ]
}
EOF
    fi
}

bgp4() {
    create_bgp4_multiport_iran() {
        echo -e "${YELLOW}============================${rest}"
        echo -en "${green}Enter the starting local port [>23]: ${rest}"
        read -r start_port
        echo -en "${green}Enter the ending local port [<65535]: ${rest}"
        read -r end_port
        echo -en "${green}Enter the remote address: ${rest}"
        read -r remote_address
        echo -en "${green}Enter the remote Connection port [Default: 2249]: ${rest}"
        read -r remote_port
        remote_port=${remote_port:-2249}

        install_waterwall

        json=$(cat <<EOF
{
    "name": "bgp_Multiport_client",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": [$start_port,$end_port],
                "nodelay": true
            },
            "next": "port_header"
        },
        {
            "name": "port_header",
            "type": "HeaderClient",
            "settings": {
                "data": "src_context->port"
            },
            "next": "bgp_client"
        },
        {
            "name": "bgp_client",
            "type": "Bgp4Client",
            "settings": {},
            "next": "output"
        }, 
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "$remote_address",
                "port": $remote_port
            }
        }
    ]
}
EOF
        )
        echo "$json" >/root/Waterwall/config.json
    }

    create_bgp4_multiport_kharej() {
        echo -e "${YELLOW}============================${rest}"
        echo -en "${green}Enter the local Connection port [Default: 2249]: ${rest}"
        read -r local_port
        local_port=${local_port:-2249}

        install_waterwall

        json=$(cat <<EOF
{
    "name": "bgp_Multiport_server",
    "nodes": [
        {
            "name": "input",
            "type": "TcpListener",
            "settings": {
                "address": "0.0.0.0",
                "port": $local_port,
                "nodelay": true
            },
            "next": "bgp_server"
        },
        {
            "name": "bgp_server",
            "type": "Bgp4Server",
            "settings": {},
            "next": "port_header"
        },
        {
            "name":"port_header",
            "type": "HeaderServer",
            "settings": {
                "override": "dest_context->port"
            },
            "next": "output"
        },
        {
            "name": "output",
            "type": "TcpConnector",
            "settings": {
                "nodelay": true,
                "address": "127.0.0.1",
                "port": "dest_context->port"
            }
        }
    ]
}
EOF
        )
        echo "$json" >/root/Waterwall/config.json
    }

    echo -e "1. ${YELLOW} bgp4 Multiport Iran${rest}"
    echo -e "2. ${White} bgp4 Multiport kharej${rest}"
    echo -e "0. ${YELLOW} Back to Main Menu${rest}"
    echo -en "${Purple} Enter your choice: ${rest}"
    read -r choice

    case $choice in
    1)
        create_bgp4_multiport_iran
        waterwall_service
        ;;
    2)
        create_bgp4_multiport_kharej
        waterwall_service
        ;;
    0)
        main
        ;;
    *)
        echo -e "${red}Invalid choice!${rest}"
        ;;
    esac
}

uninstall_waterwall() {
    if [ -d /root/Waterwall ] || [ -f /etc/systemd/system/Waterwall.service ]; then
        echo -e "${YELLOW}Uninstalling...${rest}"
        systemctl stop Waterwall.service >/dev/null 2>&1
        systemctl disable Waterwall.service >/dev/null 2>&1
        rm -rf /etc/systemd/system/Waterwall.service
        rm -rf /root/Waterwall
        systemctl daemon-reload
        echo -e "${green}Uninstalled successfully.${rest}"
    else
        echo -e "${red}Waterwall is not installed.${rest}"
    fi
}

waterwall_service() {
    create_core_json
    cat <<EOL >/etc/systemd/system/Waterwall.service
[Unit]
Description=Waterwall Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/Waterwall
ExecStart=/root/Waterwall/Waterwall
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable Waterwall.service
    sudo systemctl restart Waterwall.service
    check_waterwall_status
}

check_install_service() {
    if [ -f /etc/systemd/system/Waterwall.service ]; then
        echo -e "${red}Please uninstall existing service first.${rest}"
        exit 1
    fi
}

check_waterwall_status() {
    sleep 2
    if systemctl is-active --quiet Waterwall.service; then
        echo -e "${green}Waterwall is RUNNING!${rest}"
    else
        echo -e "${red}Waterwall failed to start. Check logs.${rest}"
    fi
}

main() {
    clear
    echo -e "${CYAN}--- Waterwall BGP4 Manager ---${rest}"
    echo -e "${YELLOW}1. Bgp4 Tunnel${rest}"
    echo -e "${YELLOW}2. Uninstall Waterwall${rest}"
    echo -e "${White}0. Exit${rest}"
    echo -en "${Purple}Enter your choice: ${rest}"
    read -r choice

    case $choice in
    1)
        check_install_service
        bgp4
        ;;
    2)
        uninstall_waterwall
        ;;
    0)
        exit
        ;;
    *)
        main
        ;;
    esac
}

main
