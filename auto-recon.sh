#!/bin/bash

#########################################################
#                                                       #
#     _         _                ____                   #
#    / \  _   _| |_ ___         |  _ \ ___  ___ ___  _ __  #
#   / _ \| | | | __/ _ \ _____  | |_) / _ \/ __/ _ \| '_ \ #
#  / ___ \ |_| | || (_) |_____| |  _ <  __/ (_| (_) | | | |#
# /_/   \_\__,_|\__\___/        |_| \_\___|\___\___/|_| |_|#
#                                                       #
#  Web Recon Automation Tool v1.0.0                     #
#  Created for Penetration Testers & Bug Bounty Hunters #
#  Created by @Prof445                                  #
#########################################################

set -uo pipefail  # Removed -e flag to handle errors manually

# Script directory - resolve symlinks to get actual location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

MODULE_DIR="$SCRIPT_DIR/modules"
LIB_DIR="$SCRIPT_DIR/lib"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# Check if required directories exist
if [[ ! -d "$MODULE_DIR" ]]; then
    echo "ERROR: modules directory not found at $MODULE_DIR"
    exit 1
fi

if [[ ! -d "$LIB_DIR" ]]; then
    echo "ERROR: lib directory not found at $LIB_DIR"
    exit 1
fi

# Source libraries with error checking
if ! source "$LIB_DIR/colors.sh"; then
    echo "ERROR: Failed to load colors.sh"
    exit 1
fi

if ! source "$LIB_DIR/utils.sh"; then
    echo "ERROR: Failed to load utils.sh"
    exit 1
fi

if ! source "$LIB_DIR/logger.sh"; then
    echo "ERROR: Failed to load logger.sh"
    exit 1
fi

# Global variables
VERSION="1.0.0"
TARGET=""
OUTPUT_DIR=""
THREADS=100
VERBOSE=false
TIMEOUT=10
RATE_LIMIT=0
DELAY=0
USER_AGENT=""
RANDOM_AGENT=false
DEBUG=false
RESUME=false
STATE_FILE=""
MODULES_TO_RUN="all"
VT_API_KEY=""
ST_API_KEY=""
PROXY=""
USE_PROXYCHAINS=false
MAX_FUZZ_TARGETS=5

# Common ports for web services
COMMON_PORTS="80,81,443,591,2082,2087,2095,2096,3000,3001,4000,5000,5432,6443,7443,8000,8001,8008,8080,8081,8083,8443,8834,8888,9000,9090,9091,9200,9443,10000"


#########################################################
# Functions
#########################################################

show_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
     _         _                ____                      
    / \  _   _| |_ ___         |  _ \ ___  ___ ___  _ __  
   / _ \| | | | __/ _ \ _____  | |_) / _ \/ __/ _ \| '_ \ 
  / ___ \ |_| | || (_) |_____| |  _ <  __/ (_| (_) | | | |
 /_/   \_\__,_|\__\___/        |_| \_\___|\___\___/|_| |_|
                                                            
EOF
    echo -e "${RESET}"
    echo -e "${CYAN} Web Recon Automation Tool ${YELLOW}v${VERSION}${RESET}"
    echo -e "${CYAN} Created for Penetration Testers & Bug Bounty Hunters${RESET}"
    echo -e "${CYAN} Created by @Prof445${RESET}"
    echo -e " ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

show_help() {
    cat << EOF
Usage: auto-recon [options] <domain>

Required:
  -d, --domain <domain>          Target domain (e.g., dell.com)

Options:
  -o, --output <dir>             Output directory (default: ./recon_results)
  -t, --threads <num>            Number of threads (default: 100)
  --timeout <sec>                Request timeout in seconds (default: 10)
  
Modules:
  --only <modules>               Run only specific modules (comma-separated)
                                 Available: subdomains,ips,urls,fuzzing,ports
                                 Example: --only subdomains,ports
  --max-fuzz <num>               Max subdomains to fuzz (default: 5 + main domain)

  
Stealth & Performance:
  --rate-limit <num>             Max requests per second (0 = unlimited)
  --delay <ms>                   Delay between requests in milliseconds
  --user-agent <ua>              Custom user agent string
  --random-agent                 Use random user agents
  --proxy <url>                  Use proxy (http://proxy:port)
  --proxychains                  Use proxychains for all requests
  
Advanced:
  --debug                        Enable debug mode (save all logs)
  --resume                       Resume interrupted scan
  --verbose                      Show all command output (verbose mode)
  -h, --help                     Show this help message
  -v, --version                  Show version
  --check-tools                  Check required tools
  --install-tools                Install missing tools

Examples:
  # Basic scan
  auto-recon -d dell.com
  
  # Only subdomains and ports
  auto-recon -d dell.com --only subdomains,ports
  
  # With proxychains and debug
  auto-recon -d dell.com --proxychains --debug
  
  # Resume interrupted scan
  auto-recon --resume -d dell.com

EOF
}

show_version() {
    echo "auto-recon version $VERSION"
}

ask_api_keys() {
    log_info "API Keys Configuration"
    echo ""
    echo -e "${YELLOW}[i]${RESET} API keys are ${GREEN}optional${RESET} but provide ${CYAN}better results${RESET}"
    echo -e "${YELLOW}[i]${RESET} You can skip by pressing Enter"
    echo ""
    
    # VirusTotal API Key
    echo -ne "${CYAN}[?]${RESET} VirusTotal API key (optional): "
    read -r VT_API_KEY
    if [[ -n "$VT_API_KEY" ]]; then
        log_success "VirusTotal API key configured"
    else
        log_warning "VirusTotal scan will be skipped"
    fi
    
    # SecurityTrails API Key
    echo -ne "${CYAN}[?]${RESET} SecurityTrails API key (optional): "
    read -r ST_API_KEY
    if [[ -n "$ST_API_KEY" ]]; then
        log_success "SecurityTrails API key configured"
    else
        log_warning "SecurityTrails scan will be skipped"
    fi
    
    echo ""
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                TARGET="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --only)
                MODULES_TO_RUN="$2"
                shift 2
                ;;
            --rate-limit)
                RATE_LIMIT="$2"
                shift 2
                ;;
            --delay)
                DELAY="$2"
                shift 2
                ;;
            --user-agent)
                USER_AGENT="$2"
                shift 2
                ;;
            --random-agent)
                RANDOM_AGENT=true
                shift
                ;;
            --proxy)
                PROXY="$2"
                shift 2
                ;;
            --proxychains)
                USE_PROXYCHAINS=true
                shift
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --resume)
                RESUME=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --max-fuzz)
                MAX_FUZZ_TARGETS="$2"
                shift 2
                ;;
            --check-tools)
                check_tools
                exit 0
                ;;
            --install-tools)
                install_tools
                exit 0
                ;;
            *)
                if [[ -z "$TARGET" ]] && [[ ! "$1" =~ ^- ]]; then
                    TARGET="$1"
                else
                    log_error "Unknown option: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

validate_args() {
    if [[ -z "$TARGET" ]]; then
        log_error "Target domain is required"
        echo "Use: auto-recon -d <domain> or auto-recon --help"
        exit 1
    fi
    
    # Validate domain format
    if ! [[ "$TARGET" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format: $TARGET"
        exit 1
    fi
}

setup_environment() {
    # Set output directory with target-specific folder and timestamp
    if [[ -z "$OUTPUT_DIR" ]]; then
        TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        OUTPUT_DIR="./recon_results/${TARGET}_${TIMESTAMP}"
    fi
    
    # Create directory structure
    mkdir -p "$OUTPUT_DIR"/{subdomains,ips,urls,fuzzing,ports,logs,temp}
    
    # Set state file
    STATE_FILE="$OUTPUT_DIR/.auto-recon.state"
    
    # Setup logging
    if [[ "$DEBUG" == true ]]; then
        LOG_FILE="$OUTPUT_DIR/logs/debug.log"
        ERROR_LOG="$OUTPUT_DIR/logs/errors.log"
        setup_logging "$LOG_FILE" "$ERROR_LOG"
    fi
    
    log_info "Target: $TARGET"
    log_info "Output directory: $OUTPUT_DIR"
}

load_state() {
    if [[ "$RESUME" == true ]] && [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
        log_success "Resuming from previous state"
        return 0
    fi
    
    # Initialize state
    cat > "$STATE_FILE" << EOF
PHASE_SUBDOMAINS=0
PHASE_IPS=0
PHASE_URLS=0
PHASE_FUZZING=0
PHASE_PORTS=0
EOF
    return 1
}

save_state() {
    local phase=$1
    local status=$2
    
    sed -i "s/PHASE_${phase}=.*/PHASE_${phase}=${status}/" "$STATE_FILE"
}

should_run_module() {
    local module=$1
    
    if [[ "$MODULES_TO_RUN" == "all" ]]; then
        return 0
    fi
    
    if echo "$MODULES_TO_RUN" | grep -q "$module"; then
        return 0
    fi
    
    return 1
}

run_recon() {
    local start_time=$(date +%s)
    
    log_section "Starting Reconnaissance"
    echo -e "${CYAN}[*]${RESET} Target: ${GREEN}$TARGET${RESET}"
    echo -e "${CYAN}[*]${RESET} Output: ${YELLOW}$OUTPUT_DIR${RESET}"
    echo -e "${CYAN}[*]${RESET} Threads: $THREADS | Timeout: ${TIMEOUT}s"
    
    # Show API key status
    local api_status=""
    [[ -n "$VT_API_KEY" ]] && api_status="${GREEN}✓${RESET}" || api_status="${RED}✗${RESET}"
    echo -e "${CYAN}[*]${RESET} API Keys: VirusTotal $api_status"
    [[ -n "$ST_API_KEY" ]] && api_status="${GREEN}✓${RESET}" || api_status="${RED}✗${RESET}"
    echo -e "             SecurityTrails $api_status"
    
    echo ""
    
    # Load previous state if resuming
    load_state
    
    # Phase 1: Subdomain Enumeration
    if should_run_module "subdomains"; then
        if [[ -f "$MODULE_DIR/subdomains.sh" ]]; then
            source "$MODULE_DIR/subdomains.sh" && run_subdomain_enum
            save_state "SUBDOMAINS" "1"
        else
            log_error "subdomains.sh module not found"
        fi
    fi
    
    # Phase 2: IP Discovery
    if should_run_module "ips"; then
        if [[ -f "$MODULE_DIR/ips.sh" ]]; then
            source "$MODULE_DIR/ips.sh" && run_ip_discovery
            save_state "IPS" "1"
        else
            log_error "ips.sh module not found"
        fi
    fi
    
    # Phase 3: URL Collection
    if should_run_module "urls"; then
        if [[ -f "$MODULE_DIR/urls.sh" ]]; then
            source "$MODULE_DIR/urls.sh" && run_url_collection
            save_state "URLS" "1"
        else
            log_error "urls.sh module not found"
        fi
    fi
    
    # Phase 4: Directory Fuzzing
    if should_run_module "fuzzing"; then
        if [[ -f "$MODULE_DIR/fuzzing.sh" ]]; then
            source "$MODULE_DIR/fuzzing.sh" && run_directory_fuzzing
            save_state "FUZZING" "1"
        else
            log_error "fuzzing.sh module not found"
        fi
    fi
    
    # Phase 5: Port Probing
    if should_run_module "ports"; then
        if [[ -f "$MODULE_DIR/ports.sh" ]]; then
            source "$MODULE_DIR/ports.sh" && run_port_probing
            save_state "PORTS" "1"
        else
            log_error "ports.sh module not found"
        fi
    fi
    
    # Generate HTML Report
    if [[ -f "$MODULE_DIR/report.sh" ]]; then
        source "$MODULE_DIR/report.sh" && generate_html_report
    else
        log_error "report.sh module not found"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Get absolute path for file:// URL
    local abs_report_path=$(cd "$(dirname "$OUTPUT_DIR")" && pwd)/$(basename "$OUTPUT_DIR")/report.html
    local file_url="file://${abs_report_path}"
    
    log_section "Scan Complete!"
    echo -e "${GREEN}[✓]${RESET} Report: ${CYAN}$OUTPUT_DIR/report.html${RESET}"
    echo -e "${GREEN}[✓]${RESET} Duration: $(format_duration $duration)"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${YELLOW}📊 View Report in Browser:${RESET}"
    echo ""
    
    # Terminal clickable link (works in many modern terminals)
    echo -e "   \033]8;;${file_url}\033\\${GREEN}Ctrl+Click here to open report${RESET}\033]8;;\033\\"
    echo ""
    echo -e "   ${DIM}Or copy this URL:${RESET}"
    echo -e "   ${GREEN}$file_url${RESET}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${DIM}💡 Tip: Ctrl+Click the link above (or copy-paste the URL into browser)${RESET}"
    echo ""

}



#########################################################
# Main Execution
#########################################################

main() {
    show_banner
    parse_args "$@"
    validate_args
    
    # Check required tools
    if ! check_required_tools; then
        log_error "Missing required tools. Run: auto-recon --install-tools"
        exit 1
    fi
    
    # Ask for API keys
    ask_api_keys
    
    # Setup environment
    setup_environment
    
    # Run reconnaissance
    run_recon
}

# Run main function
main "$@"
