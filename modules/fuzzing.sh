#!/bin/bash

# Directory Fuzzing Module
# Performs directory and file fuzzing on live subdomains

run_directory_fuzzing() {
    log_phase "4" "Directory Fuzzing"
    
    local live_subs="$OUTPUT_DIR/subdomains/live_subdomains.txt"
    local output_file="$OUTPUT_DIR/fuzzing/discovered_paths.txt"
    local temp_dir="$OUTPUT_DIR/temp/fuzzing"
    local start_time=$(date +%s)
    
    mkdir -p "$temp_dir"
    
    # Check for wordlist in multiple locations
    local wordlist=""
    local wordlist_paths=(
        "$SCRIPT_DIR/wordlists/common.txt"
        "$HOME/auto-recon/wordlists/common.txt"
        "/usr/share/seclists/Discovery/Web-Content/common.txt"
        "/usr/share/wordlists/dirb/common.txt"
    )
    
    for wl in "${wordlist_paths[@]}"; do
        if [[ -f "$wl" ]]; then
            wordlist="$wl"
            break
        fi
    done
    
    if [[ -z "$wordlist" ]]; then
        log_warning "No wordlist found. Skipping directory fuzzing."
        log_warning "Download wordlist manually:"
        echo "    wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt -O ~/auto-recon/wordlists/common.txt"
        return 1
    fi
    
    local wordlist_size=$(wc -l < $wordlist)
    log_task "Using wordlist: $(basename $wordlist) ($wordlist_size entries)"
    
    # Prepare target list: main domain + live subdomains (limited)
    local targets_file="$temp_dir/targets_to_fuzz.txt"
    > "$targets_file"
    
    # Add main domain first
    echo "https://$TARGET" >> "$targets_file"
    
    # Add live subdomains (limit to prevent extremely long scans)
    local max_subdomains=$MAX_FUZZ_TARGETS
    
    if [[ -f "$live_subs" ]] && [[ -s "$live_subs" ]]; then
        head -n "$max_subdomains" "$live_subs" >> "$targets_file"
    fi
    
    local total_targets=$(count_lines "$targets_file")
    local estimated_time=$(awk "BEGIN {printf \"%.1f\", ($wordlist_size * $total_targets) / 1200}")
    
    log_task "Fuzzing $total_targets targets (main domain + $((total_targets - 1)) subdomains)"
    echo "        Estimated time: ~${estimated_time} minutes"
    
    if [[ -f "$live_subs" ]]; then
        local total_live=$(count_lines "$live_subs")
        if [[ $total_live -gt $max_subdomains ]]; then
            echo "        ${YELLOW}Note: Found $total_live live subdomains, fuzzing first $max_subdomains${RESET}"
            echo "        ${YELLOW}Use --max-fuzz $total_live to scan all subdomains${RESET}"
        fi
    fi
    
    local processed=0
    local total_found=0
    
    > "$output_file"  # Clear output file
    
    while IFS= read -r full_url; do
        processed=$((processed + 1))
        
        # Extract just the hostname from full URL (remove http:// or https://)
        local subdomain=$(echo "$full_url" | sed -E 's~https?://~~' | cut -d'/' -f1)
        
        # Determine protocol (prefer https)
        local protocol="https"
        if [[ "$full_url" =~ ^http:// ]]; then
            protocol="http"
        fi
        
        # Clean subdomain for filename
        local safe_name=$(echo "$subdomain" | tr -d '/:' | tr '.' '_')
        
        # Run ffuf - Match only successful codes: 200, 204, 301, 302, 307
        local proxy_cmd=$(add_proxy_prefix)
        
        # Show which subdomain is being fuzzed (only in verbose mode, before fuzzing starts)
        if [[ "$VERBOSE" == true ]]; then
            echo -e "\n${DIM}[FUZZING $processed/$total_targets]${RESET} $subdomain"
        fi
        
        # Always suppress ffuf output to keep progress bar clean
        $proxy_cmd ffuf -w "$wordlist" -u "${protocol}://${subdomain}/FUZZ" -mc 200,204,301,302,307 -fc 401,403,404,501,502 -t $THREADS -timeout $TIMEOUT -se -o "$temp_dir/${safe_name}.json" -of json -s > /dev/null 2>&1
        
        # Extract URLs from JSON and double-check status codes
        if [[ -f "$temp_dir/${safe_name}.json" ]]; then
            # Only extract results with allowed status codes
            jq -r '.results[] | select(.status == 200 or .status == 204 or .status == 301 or .status == 302 or .status == 307) | .url' "$temp_dir/${safe_name}.json" 2>/dev/null >> "$output_file" || true
        fi
        
        # Show progress with percentage (clear line first)
        local completed_percent=$((processed * 100 / total_targets))
        if [[ $processed -gt 1 ]]; then
            local elapsed=$(($(date +%s) - start_time))
            local avg_time=$((elapsed / processed))
            local remaining=$((total_targets - processed))
            local eta=$((avg_time * remaining))
            printf "\r        Progress: %d/%d (%d%%) - ETA: %s        " $processed $total_targets $completed_percent "$(format_duration $eta)"
        else
            printf "\r        Progress: %d/%d (%d%%)        " $processed $total_targets $completed_percent
        fi
    done < "$targets_file"
    
    echo ""  # New line after progress bar
    
    # Deduplicate results and final status code check
    if [[ -f "$output_file" ]]; then
        sort -u "$output_file" -o "$output_file"
        total_found=$(count_lines "$output_file")
    fi
    
    log_result "Discovered paths: $total_found"
    
    # Save statistics
    cat > "$OUTPUT_DIR/fuzzing/stats.json" << EOF
{
  "targets_fuzzed": $total_targets,
  "main_domain_included": true,
  "subdomains_fuzzed": $((total_targets - 1)),
  "paths_discovered": $total_found,
  "wordlist": "$(basename $wordlist)",
  "wordlist_size": $wordlist_size,
  "max_targets_limit": $MAX_FUZZ_TARGETS,
  "allowed_status_codes": "200,204,301,302,307",
  "filtered_status_codes": "401,403,404"
}
EOF
}
