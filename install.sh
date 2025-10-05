#!/bin/bash

#########################################################
# Auto-Recon Installation Script
#########################################################

set -e

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

echo -e "${CYAN}"
cat << "EOF"
     _         _                ____                      
    / \  _   _| |_ ___         |  _ \ ___  ___ ___  _ __  
   / _ \| | | | __/ _ \ _____  | |_) / _ \/ __/ _ \| '_ \ 
  / ___ \ |_| | || (_) |_____| |  _ <  __/ (_| (_) | | | |
 /_/   \_\__,_|\__\___/        |_| \_\___|\___\___/|_| |_|
                                                            
EOF
echo -e "${RESET}"
echo -e "${CYAN}Auto-Recon Installation Script${RESET}\n"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${YELLOW}[!] Please do not run this script as root${RESET}"
   exit 1
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo -e "${RED}[✗] Cannot detect OS${RESET}"
    exit 1
fi

echo -e "${GREEN}[✓]${RESET} Detected OS: $OS"

# Check for required system packages
echo -e "\n${CYAN}[*] Checking system dependencies...${RESET}"

SYSTEM_DEPS=("curl" "git" "jq" "python3" "python3-pip" "wget")

case $OS in
    ubuntu|debian|kali)
        PKG_MANAGER="apt"
        sudo apt update -qq
        for dep in "${SYSTEM_DEPS[@]}"; do
            if ! command -v $dep &> /dev/null && ! dpkg -l | grep -q "^ii  $dep "; then
                echo -e "${YELLOW}[*] Installing $dep...${RESET}"
                sudo apt install -y $dep
            fi
        done
        ;;
    fedora|centos|rhel)
        PKG_MANAGER="dnf"
        sudo dnf install -y curl git jq python3 python3-pip wget
        ;;
    arch)
        PKG_MANAGER="pacman"
        sudo pacman -Sy --noconfirm curl git jq python python-pip wget
        ;;
    *)
        echo -e "${YELLOW}[!] Unsupported OS. Please install dependencies manually.${RESET}"
        ;;
esac

# Check for Go
echo -e "\n${CYAN}[*] Checking Go installation...${RESET}"
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}[!] Go is not installed${RESET}"
    echo -e "${CYAN}[*] Installing Go...${RESET}"
    
    GO_VERSION="1.21.5"
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
    
    # Add to PATH for both Bash and Zsh
    for rc_file in ~/.bashrc ~/.zshrc; do
        if [[ -f "$rc_file" ]] && ! grep -q "/usr/local/go/bin" "$rc_file"; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> "$rc_file"
            echo 'export PATH=$PATH:$HOME/go/bin' >> "$rc_file"
        fi
    done
    
    export PATH=$PATH:/usr/local/go/bin
    export PATH=$PATH:$HOME/go/bin
    
    echo -e "${GREEN}[✓] Go installed successfully${RESET}"
else
    echo -e "${GREEN}[✓] Go is already installed ($(go version))${RESET}"
fi

# Ensure Go bin is in PATH
export PATH=$PATH:$HOME/go/bin

# Install Go tools
echo -e "\n${CYAN}[*] Installing reconnaissance tools...${RESET}"

echo -e "${CYAN}[1/8] Installing subfinder...${RESET}"
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

echo -e "${CYAN}[2/8] Installing assetfinder...${RESET}"
go install github.com/tomnomnom/assetfinder@latest

echo -e "${CYAN}[3/8] Installing httpx...${RESET}"
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

echo -e "${CYAN}[4/8] Installing dnsx...${RESET}"
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest

echo -e "${CYAN}[5/8] Installing waybackurls...${RESET}"
go install github.com/tomnomnom/waybackurls@latest

echo -e "${CYAN}[6/8] Installing gf...${RESET}"
go install github.com/tomnomnom/gf@latest

echo -e "${CYAN}[7/8] Installing ffuf...${RESET}"
go install github.com/ffuf/ffuf/v2@latest

echo -e "${CYAN}[8/8] Installing uro...${RESET}"
# Try pipx first (recommended for Kali/newer systems)
if command -v pipx &> /dev/null; then
    pipx install uro 2>/dev/null && echo -e "${GREEN}[✓] uro installed via pipx${RESET}" || \
    (pipx install uro --force 2>/dev/null && echo -e "${GREEN}[✓] uro installed via pipx${RESET}") || \
    echo -e "${YELLOW}[!] pipx installation failed, trying pip...${RESET}"
fi

# Fallback to pip with --break-system-packages
if ! command -v uro &> /dev/null; then
    pip3 install --user uro --break-system-packages 2>/dev/null && \
    echo -e "${GREEN}[✓] uro installed via pip3${RESET}" || \
    pip3 install uro --break-system-packages 2>/dev/null && \
    echo -e "${GREEN}[✓] uro installed via pip3${RESET}" || \
    echo -e "${YELLOW}[!] Could not install uro automatically${RESET}"
fi

# Ensure pip user bin is in PATH for both Bash and Zsh
for rc_file in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc_file" ]] && ! grep -q "$HOME/.local/bin" "$rc_file"; then
        echo 'export PATH=$PATH:$HOME/.local/bin' >> "$rc_file"
    fi
done
export PATH=$PATH:$HOME/.local/bin

# Verify uro installation
if command -v uro &> /dev/null; then
    echo -e "${GREEN}[✓] uro is working${RESET}"
else
    echo -e "${YELLOW}[!] uro not found in PATH. You may need to manually install it:${RESET}"
    echo -e "${YELLOW}    pip3 install uro --break-system-packages${RESET}"
fi

# Install GF patterns
echo -e "\n${CYAN}[*] Installing GF patterns...${RESET}"
if [[ ! -d ~/.gf ]]; then
    mkdir -p ~/.gf
    git clone -q https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns
    cp /tmp/gf-patterns/*.json ~/.gf/
    rm -rf /tmp/gf-patterns
    echo -e "${GREEN}[✓] GF patterns installed${RESET}"
else
    echo -e "${GREEN}[✓] GF patterns already installed${RESET}"
fi

# Get current directory
CURRENT_DIR="$(pwd)"

# Create wordlists directory
echo -e "\n${CYAN}[*] Setting up wordlists...${RESET}"
mkdir -p "$CURRENT_DIR/wordlists"

# Download common.txt wordlist
echo -e "${CYAN}[*] Downloading common.txt wordlist...${RESET}"
WORDLIST_URL="https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt"
WORDLIST_PATH="$CURRENT_DIR/wordlists/common.txt"

if [[ ! -f "$WORDLIST_PATH" ]]; then
    wget -q "$WORDLIST_URL" -O "$WORDLIST_PATH" && \
    echo -e "${GREEN}[✓] common.txt downloaded ($(wc -l < $WORDLIST_PATH) entries)${RESET}" || \
    echo -e "${YELLOW}[!] Failed to download wordlist. Fuzzing may not work.${RESET}"
else
    echo -e "${GREEN}[✓] common.txt already exists ($(wc -l < $WORDLIST_PATH) entries)${RESET}"
fi

# Make auto-recon.sh executable
if [[ -f "$CURRENT_DIR/auto-recon.sh" ]]; then
    chmod +x "$CURRENT_DIR/auto-recon.sh"
    echo -e "${GREEN}[✓] Made auto-recon.sh executable${RESET}"
fi

# Create symlink in /usr/local/bin (optional, requires sudo)
echo -e "\n${CYAN}[*] Creating system-wide command...${RESET}"
if sudo ln -sf "$CURRENT_DIR/auto-recon.sh" /usr/local/bin/auto-recon 2>/dev/null; then
    echo -e "${GREEN}[✓] Created system-wide command: auto-recon${RESET}"
    echo -e "${GREEN}[✓] You can now run: ${YELLOW}auto-recon -d example.com${RESET}${GREEN} from anywhere${RESET}"
else
    echo -e "${YELLOW}[!] Could not create system-wide command (needs sudo)${RESET}"
    echo -e "${YELLOW}[!] Run from this directory: ${CYAN}./auto-recon.sh -d example.com${RESET}"
fi

echo -e "\n${GREEN}╔════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║                                            ║${RESET}"
echo -e "${GREEN}║  ✓ Installation Complete!                 ║${RESET}"
echo -e "${GREEN}║                                            ║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${RESET}"

echo -e "\n${CYAN}Tool Location:${RESET}"
echo -e "  ${YELLOW}$CURRENT_DIR${RESET}"

echo -e "\n${CYAN}Usage Options:${RESET}"

if [[ -f /usr/local/bin/auto-recon ]]; then
    echo -e "  ${GREEN}Option 1 (Anywhere):${RESET} ${YELLOW}auto-recon -d example.com${RESET}"
    echo -e "  ${GREEN}Option 2 (Local):${RESET}    ${YELLOW}cd $CURRENT_DIR && ./auto-recon.sh -d example.com${RESET}"
else
    echo -e "  ${GREEN}Run from tool directory:${RESET}"
    echo -e "  ${YELLOW}cd $CURRENT_DIR${RESET}"
    echo -e "  ${YELLOW}./auto-recon.sh -d example.com${RESET}"
fi

echo -e "\n${CYAN}Quick Test:${RESET}"
if [[ -f /usr/local/bin/auto-recon ]]; then
    echo -e "  ${YELLOW}auto-recon --check-tools${RESET}"
else
    echo -e "  ${YELLOW}cd $CURRENT_DIR && ./auto-recon.sh --check-tools${RESET}"
fi

echo -e "\n${CYAN}For help:${RESET}"
if [[ -f /usr/local/bin/auto-recon ]]; then
    echo -e "  ${YELLOW}auto-recon --help${RESET}"
else
    echo -e "  ${YELLOW}./auto-recon.sh --help${RESET}"
fi

echo ""
