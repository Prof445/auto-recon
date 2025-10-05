#!/bin/bash

# Format duration in human readable format
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Execute command with verbose output
verbose_exec() {
    local cmd="$@"
    
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${DIM}[CMD]${RESET} ${CYAN}$cmd${RESET}"
        eval "$cmd"
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo -e "${YELLOW}[!] Command exited with code: $exit_code${RESET}"
        fi
        return $exit_code
    else
        eval "$cmd 2>/dev/null"
    fi
}

# Retry function with exponential backoff
retry() {
    local max_attempts=3
    local attempt=1
    local delay=2
    local command="$@"
    
    while [[ $attempt -le $max_attempts ]]; do
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${DIM}[ATTEMPT $attempt/$max_attempts]${RESET} $command"
        fi
        
        if verbose_exec "$command"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${YELLOW}[!] Attempt $attempt failed. Retrying in ${delay}s...${RESET}"
            else
                log_warning "Attempt $attempt failed. Retrying in ${delay}s..."
            fi
            sleep $delay
            delay=$((delay * 2))
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf ">"
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %d%%" $percentage
}

# Clean up on exit
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script interrupted with exit code: $exit_code"
    fi
    
    # Remove temporary files
    if [[ -d "$OUTPUT_DIR/temp" ]]; then
        rm -rf "$OUTPUT_DIR/temp"/*
    fi
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Deduplicate and merge results
deduplicate_results() {
    local input_file=$1
    local output_file=$2
    
    sort -u "$input_file" > "$output_file"
}

# Count lines in file
count_lines() {
    local file=$1
    if [[ -f "$file" ]]; then
        wc -l < "$file" | tr -d ' '
    else
        echo "0"
    fi
}

# Check if file is empty
is_empty() {
    local file=$1
    if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
        return 0
    fi
    return 1
}

# Sanitize filename
sanitize_filename() {
    local filename=$1
    echo "$filename" | tr -d '/:*?"<>|' | tr '.' '_'
}

# Check required tools
check_required_tools() {
    local missing_tools=()
    local required_tools=(
        "curl"
        "jq"
        "subfinder"
        "assetfinder"
        "httpx"
        "waybackurls"
        "uro"
        "gf"
        "ffuf"
        "dnsx"
    )
    
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        return 1
    fi
    
    return 0
}

# Check tools and show status
check_tools() {
    log_section "Checking Required Tools"
    
    local tools=(
        "curl:Core"
        "jq:Core"
        "grep:Core"
        "sed:Core"
        "awk:Core"
        "subfinder:Subdomain Enum"
        "assetfinder:Subdomain Enum"
        "httpx:HTTP Probing"
        "waybackurls:URL Discovery"
        "uro:URL Filtering"
        "gf:Pattern Matching"
        "ffuf:Directory Fuzzing"
        "dnsx:DNS Resolution"
    )
    
    for tool_info in "${tools[@]}"; do
        IFS=':' read -r tool category <<< "$tool_info"
        printf "  %-20s %-20s " "$tool" "$category"
        
        if command_exists "$tool"; then
            echo -e "[${GREEN}✓${RESET}]"
        else
            echo -e "[${RED}✗${RESET}]"
        fi
    done
    
    echo ""
}

# Install missing tools
install_tools() {
    log_section "Installing Required Tools"
    
    # Check if Go is installed
    if ! command_exists go; then
        log_error "Go is not installed. Please install Go first:"
        echo "  https://golang.org/doc/install"
        return 1
    fi
    
    log_info "Installing Go-based tools..."
    
    # Subdomain enumeration
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    go install github.com/tomnomnom/assetfinder@latest
    
    # DNS resolution
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
    
    # HTTP probing
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
    
    # URL discovery
    go install github.com/tomnomnom/waybackurls@latest
    pip3 install uro --break-system-packages 2>/dev/null || pip install uro
    
    # Pattern matching
    go install github.com/tomnomnom/gf@latest
    
    # Install gf patterns
    if [[ ! -d ~/.gf ]]; then
        mkdir -p ~/.gf
        git clone https://github.com/1ndianl33t/Gf-Patterns /tmp/gf-patterns
        cp /tmp/gf-patterns/*.json ~/.gf/
        rm -rf /tmp/gf-patterns
    fi
    
    # Directory fuzzing
    go install github.com/ffuf/ffuf/v2@latest
    
    log_success "Tool installation complete!"
}

# Add proxychains prefix if enabled
add_proxy_prefix() {
    if [[ "$USE_PROXYCHAINS" == true ]]; then
        echo "proxychains -q"
    else
        echo ""
    fi
}
