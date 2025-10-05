#!/bin/bash

# Port Probing Module
# Checks common web service ports on live subdomains

run_port_probing() {
    log_phase "5" "Port Probing"
    
    local live_subs="$OUTPUT_DIR/subdomains/live_subdomains.txt"
    local output_file="$OUTPUT_DIR/ports/open_ports.txt"
    local services_file="$OUTPUT_DIR/ports/services_by_port.json"
    
    if is_empty "$live_subs"; then
        log_warning "No live subdomains found. Skipping port probing."
        return 1
    fi
    
    log_task "Probing common web service ports"
    echo "        Ports: $COMMON_PORTS"
    
    # Probe ports with httpx
    local proxy_cmd=$(add_proxy_prefix)
    cat "$live_subs" | $proxy_cmd httpx -silent -ports "$COMMON_PORTS" -sc -title -tech-detect -no-color -threads $THREADS -timeout $TIMEOUT -o "$output_file" > /dev/null 2>&1
    
    local total_services=$(count_lines "$output_file")
    log_result "Open web services: $total_services"
    
    # Skip port analysis if no services found
    if [[ $total_services -eq 0 ]]; then
        cat > "$OUTPUT_DIR/ports/stats.json" << EOF
{
  "total_services": 0,
  "ports_scanned": "$COMMON_PORTS"
}
EOF
        return 0
    fi
    
    # Group by port
    log_task "Analyzing services by port"
    
    # Initialize JSON
    echo "{}" > "$services_file"
    
    # Common port groupings
    declare -A port_groups
    port_groups["80,443"]="Standard Web"
    port_groups["8080,8443"]="Alternate HTTP/HTTPS"
    port_groups["3000,3001"]="Node.js/React"
    port_groups["5000,5001"]="Flask/Python"
    port_groups["8000,8001"]="Django/Development"
    port_groups["9000,9090"]="APIs/Microservices"
    port_groups["2082,2087"]="cPanel/WHM"
    
    # Count services by port category
    for ports_key in "${!port_groups[@]}"; do
        local category="${port_groups[$ports_key]}"
        local count=0
        
        IFS=',' read -ra PORT_ARRAY <<< "$ports_key"
        for port in "${PORT_ARRAY[@]}"; do
            # Use grep to count occurrences, handle empty results
            local matches=$(grep ":${port} " "$output_file" 2>/dev/null | wc -l)
            matches=${matches:-0}
            count=$((count + matches))
        done
        
        if [[ $count -gt 0 ]]; then
            echo "        $category: $count services"
            # Add to JSON safely
            local temp_json=$(mktemp)
            if jq ". + {\"$category\": $count}" "$services_file" > "$temp_json" 2>/dev/null; then
                mv "$temp_json" "$services_file"
            else
                rm -f "$temp_json"
            fi
        fi
    done
    
    # Save statistics
    cat > "$OUTPUT_DIR/ports/stats.json" << EOF
{
  "total_services": $total_services,
  "ports_scanned": "$COMMON_PORTS"
}
EOF
}
