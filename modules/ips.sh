#!/bin/bash

# IP Discovery Module
# Resolves subdomains to IPs and discovers IPs from various sources

run_ip_discovery() {
    log_phase "2" "IP Discovery"
    
    local live_subs="$OUTPUT_DIR/subdomains/live_subdomains.txt"
    local all_ips="$OUTPUT_DIR/ips/all_ips.txt"
    local live_ips="$OUTPUT_DIR/ips/live_ips.txt"
    local temp_dir="$OUTPUT_DIR/temp/ips"
    
    mkdir -p "$temp_dir"
    
    if is_empty "$live_subs"; then
        log_warning "No live subdomains found. Skipping IP discovery."
        return 1
    fi
    
    # Method 1: Resolve subdomains with dnsx
    log_task "Resolving subdomains to IPs"
    local proxy_cmd=$(add_proxy_prefix)
    $proxy_cmd dnsx -l "$live_subs" -a -resp-only -silent 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u > "$temp_dir/resolved.txt"
    local resolved_count=$(count_lines "$temp_dir/resolved.txt")
    echo "        Resolved: $resolved_count IPs"
    
    # Method 2: Get IPs from AlienVault passive DNS
    log_task "AlienVault Passive DNS"
    curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$TARGET/passive_dns" 2>/dev/null | jq -r '.passive_dns[].address' 2>/dev/null | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u > "$temp_dir/alienvault_ips.txt" || touch "$temp_dir/alienvault_ips.txt"
    local av_count=$(count_lines "$temp_dir/alienvault_ips.txt")
    echo "        Found: $av_count IPs"
    
    # Method 3: Get IPs from VirusTotal (if API key provided)
    if [[ -n "$VT_API_KEY" ]]; then
        log_task "VirusTotal Domain Resolutions"
        curl -s "https://www.virustotal.com/api/v3/domains/$TARGET/resolutions" -H "x-apikey: $VT_API_KEY" 2>/dev/null | jq -r '.data[].attributes.ip_address' 2>/dev/null | sort -u > "$temp_dir/virustotal_ips.txt" || touch "$temp_dir/virustotal_ips.txt"
        local vt_count=$(count_lines "$temp_dir/virustotal_ips.txt")
        echo "        Found: $vt_count IPs"
    fi
    
    # Merge all IPs
    log_task "Merging and deduplicating IPs"
    cat "$temp_dir"/*.txt 2>/dev/null | sort -u > "$all_ips"
    local total_ips=$(count_lines "$all_ips")
    echo "        Total unique IPs: $total_ips"
    
    # Verify live IPs
    log_task "Verifying live IPs"
    $proxy_cmd httpx -l "$all_ips" -silent -threads $THREADS -timeout $TIMEOUT -no-color -o "$live_ips" > /dev/null 2>&1
    local live_count=$(count_lines "$live_ips")
    
    log_result "Total IPs: $total_ips | Live: $live_count"
    
    # Save statistics
    cat > "$OUTPUT_DIR/ips/stats.json" << EOF
{
  "total_ips": $total_ips,
  "live_ips": $live_count,
  "resolved_from_subdomains": $resolved_count,
  "from_passive_dns": ${av_count:-0}
}
EOF
}
