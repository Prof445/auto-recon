#!/bin/bash

# Subdomain Enumeration Module
# Collects subdomains from multiple sources with deduplication

run_subdomain_enum() {
    log_phase "1" "Subdomain Enumeration"
    
    local temp_dir="$OUTPUT_DIR/temp/subdomains"
    local output_file="$OUTPUT_DIR/subdomains/all_subdomains.txt"
    local live_file="$OUTPUT_DIR/subdomains/live_subdomains.txt"
    local sources_file="$OUTPUT_DIR/subdomains/subdomain_sources.json"
    
    mkdir -p "$temp_dir"
    
    # Initialize sources tracking
    echo "{}" > "$sources_file"
    
    local total_found=0
    local source_count=0
    
    # Source 1: crt.sh
    log_task "crt.sh"
    if run_crtsh "$temp_dir/crtsh.txt"; then
        local count=$(count_lines "$temp_dir/crtsh.txt")
        echo "        Found: $count subdomains"
        total_found=$((total_found + count))
        source_count=$((source_count + 1))
        add_source_to_json "$sources_file" "crt.sh" "$count"
    else
        echo "        ${YELLOW}Failed or no results (rate limited)${RESET}"
    fi
    
    # Source 2: Certspotter
    log_task "Certspotter"
    if run_certspotter "$temp_dir/certspotter.txt"; then
        local count=$(count_lines "$temp_dir/certspotter.txt")
        echo "        Found: $count subdomains"
        total_found=$((total_found + count))
        source_count=$((source_count + 1))
        add_source_to_json "$sources_file" "certspotter" "$count"
    else
        echo "        ${YELLOW}Failed or no results${RESET}"
    fi
    
    # Source 3: VirusTotal (if API key provided)
    if [[ -n "$VT_API_KEY" ]]; then
        log_task "VirusTotal"
        if run_virustotal "$temp_dir/virustotal.txt"; then
            local count=$(count_lines "$temp_dir/virustotal.txt")
            echo "        Found: $count subdomains"
            total_found=$((total_found + count))
            source_count=$((source_count + 1))
            add_source_to_json "$sources_file" "virustotal" "$count"
        else
            echo "        ${YELLOW}Failed or no results${RESET}"
        fi
    fi
    
    # Source 4: SecurityTrails (if API key provided)
    if [[ -n "$ST_API_KEY" ]]; then
        log_task "SecurityTrails"
        if run_securitytrails "$temp_dir/securitytrails.txt"; then
            local count=$(count_lines "$temp_dir/securitytrails.txt")
            echo "        Found: $count subdomains"
            total_found=$((total_found + count))
            source_count=$((source_count + 1))
            add_source_to_json "$sources_file" "securitytrails" "$count"
        else
            echo "        ${YELLOW}Failed or no results${RESET}"
        fi
    fi
    
    # Source 5: AlienVault OTX
    log_task "AlienVault OTX"
    if run_alienvault "$temp_dir/alienvault.txt"; then
        local count=$(count_lines "$temp_dir/alienvault.txt")
        echo "        Found: $count subdomains"
        total_found=$((total_found + count))
        source_count=$((source_count + 1))
        add_source_to_json "$sources_file" "alienvault" "$count"
    else
        echo "        ${YELLOW}Failed or no results${RESET}"
    fi
    
    # Source 6: Subfinder
    log_task "Subfinder"
    if run_subfinder "$temp_dir/subfinder.txt"; then
        local count=$(count_lines "$temp_dir/subfinder.txt")
        echo "        Found: $count subdomains"
        total_found=$((total_found + count))
        source_count=$((source_count + 1))
        add_source_to_json "$sources_file" "subfinder" "$count"
    else
        echo "        ${YELLOW}Failed or no results${RESET}"
    fi
    
    # Source 7: Assetfinder
    log_task "Assetfinder"
    if run_assetfinder "$temp_dir/assetfinder.txt"; then
        local count=$(count_lines "$temp_dir/assetfinder.txt")
        echo "        Found: $count subdomains"
        total_found=$((total_found + count))
        source_count=$((source_count + 1))
        add_source_to_json "$sources_file" "assetfinder" "$count"
    else
        echo "        ${YELLOW}Failed or no results${RESET}"
    fi
    
    # Merge and deduplicate
    log_task "Merging and deduplicating results"
    cat "$temp_dir"/*.txt 2>/dev/null | sort -u > "$output_file"
    local unique_count=$(count_lines "$output_file")
    
    if [[ $unique_count -eq 0 ]]; then
        log_warning "No subdomains found from any source"
        touch "$live_file"
        cat > "$OUTPUT_DIR/subdomains/stats.json" << EOF
{
  "total_found": 0,
  "unique": 0,
  "live": 0,
  "live_percentage": 0,
  "sources_count": 0
}
EOF
        return 0
    fi
    
    echo "        Total unique: $unique_count subdomains"
    
# Check live subdomains
log_task "Checking live subdomains (this may take a while...)"
local proxy_cmd=$(add_proxy_prefix)

$proxy_cmd httpx -l "$output_file" -silent -threads $THREADS -timeout $TIMEOUT -no-color -o "$live_file" > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    local live_count=$(count_lines "$live_file")
    local live_percentage=$(awk "BEGIN {printf \"%.1f\", ($live_count/$unique_count)*100}")

        
        log_result "Total unique: $unique_count | Live: $live_count ($live_percentage%)"
        log_result "Sources used: $source_count"
        
        # Save statistics
        cat > "$OUTPUT_DIR/subdomains/stats.json" << EOF
{
  "total_found": $total_found,
  "unique": $unique_count,
  "live": $live_count,
  "live_percentage": $live_percentage,
  "sources_count": $source_count
}
EOF
    else
        log_warning "httpx failed to check live subdomains"
        touch "$live_file"
    fi
}

# Individual source functions
run_crtsh() {
    local output=$1
    verbose_exec "curl -s 'https://crt.sh/?q=%25.$TARGET&output=json' | jq -r '.[].name_value' | grep -Po '(\\w+\\.\\w+.\\w+)$' | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

run_certspotter() {
    local output=$1
    verbose_exec "curl -s 'https://api.certspotter.com/v1/issuances?domain=$TARGET&include_subdomains=true&expand=dns_names' | jq -r '.[].dns_names[]' | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

run_virustotal() {
    local output=$1
    verbose_exec "curl -s 'https://www.virustotal.com/vtapi/v2/domain/report?apikey=$VT_API_KEY&domain=$TARGET' | jq -r '.subdomains[]' | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

run_securitytrails() {
    local output=$1
    verbose_exec "curl -s 'https://api.securitytrails.com/v1/domain/$TARGET/subdomains' -H 'APIKEY: $ST_API_KEY' | jq -r '.subdomains[]' | sed 's/$/.$TARGET/' | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

run_alienvault() {
    local output=$1
    verbose_exec "curl -s 'https://otx.alienvault.com/api/v1/indicators/domain/$TARGET/passive_dns' | jq -r '.passive_dns[].hostname' | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

run_subfinder() {
    local output=$1
    local proxy_cmd=$(add_proxy_prefix)
    verbose_exec "$proxy_cmd subfinder -d $TARGET -silent -all | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

run_assetfinder() {
    local output=$1
    local proxy_cmd=$(add_proxy_prefix)
    verbose_exec "$proxy_cmd assetfinder --subs-only $TARGET | sort -u > \"$output\""
    [[ -s "$output" ]] && return 0 || return 1
}

# Add source to JSON tracking
add_source_to_json() {
    local json_file=$1
    local source_name=$2
    local count=$3
    
    local temp_json=$(mktemp)
    jq ". + {\"$source_name\": $count}" "$json_file" > "$temp_json" 2>/dev/null && mv "$temp_json" "$json_file"
}
