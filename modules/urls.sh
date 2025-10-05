#!/bin/bash

# URL Collection Module
# Collects URLs from Wayback Machine and applies filters

run_url_collection() {
    log_phase "3" "URL Collection & Analysis"
    
    local all_urls="$OUTPUT_DIR/urls/all_wayback_urls.txt"
    local interesting_urls="$OUTPUT_DIR/urls/live_interesting.txt"
    local temp_dir="$OUTPUT_DIR/temp/urls"
    
    mkdir -p "$temp_dir" "$OUTPUT_DIR/urls/gf_results"
    
    # Step 1: Collect URLs from Wayback Machine
    log_task "Collecting URLs from Wayback Machine"
    local proxy_cmd=$(add_proxy_prefix)
    $proxy_cmd waybackurls "$TARGET" > "$all_urls" 2>/dev/null
    local total_urls=$(count_lines "$all_urls")
    echo "        Found: $total_urls URLs"
    
    if is_empty "$all_urls"; then
        log_warning "No URLs found from Wayback Machine"
        touch "$interesting_urls"
        cat > "$OUTPUT_DIR/urls/stats.json" << EOF
{
  "total_urls": 0,
  "interesting_files": 0,
  "xss": 0,
  "sqli": 0,
  "lfi": 0,
  "idor": 0,
  "redirect": 0,
  "ssrf": 0,
  "ssti": 0,
  "rce": 0
}
EOF
        return 1
    fi
    
    # Step 2: Filter interesting files
    log_task "Filtering interesting files"
    
    # First, deduplicate with uro
    cat "$all_urls" | uro > "$temp_dir/deduplicated.txt" 2>/dev/null
    local dedup_count=$(count_lines "$temp_dir/deduplicated.txt")
    echo "        Deduplicated: $dedup_count unique URLs"
    
    # Filter interesting extensions (more lenient)
    cat "$temp_dir/deduplicated.txt" | grep -iE '\.(txt|php|bak|sql|log|xml|json|config|env|old|backup|dump|dmp|db|zip|tar|gz)' > "$temp_dir/interesting.txt" 2>/dev/null || touch "$temp_dir/interesting.txt"
    
    # Check if live (increase timeout and retries)
    if [[ -s "$temp_dir/interesting.txt" ]]; then
        $proxy_cmd httpx -l "$temp_dir/interesting.txt" -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 15 -retries 2 -o "$interesting_urls" > /dev/null 2>&1
    else
        touch "$interesting_urls"
    fi
    
    local interesting_count=$(count_lines "$interesting_urls")
    echo "        Live interesting files: $interesting_count"
    
    # Step 3: Run GF patterns for potential endpoints detection
    log_task "Running GF patterns for potential endpoints detection"
    
    # Prepare URLs for GF scanning (use deduplicated, limit to most relevant 5000)
    local urls_for_gf="$temp_dir/gf_scan_urls.txt"
    if [[ $dedup_count -gt 5000 ]]; then
        cat "$temp_dir/deduplicated.txt" | tail -5000 > "$urls_for_gf"
        echo "        Scanning 5000 most recent URLs (of $dedup_count total)"
    else
        cp "$temp_dir/deduplicated.txt" "$urls_for_gf"
        echo "        Scanning all $dedup_count unique URLs"
    fi
    
    # XSS
    cat "$urls_for_gf" | gf xss 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/xss_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/xss_urls.txt"
    local xss_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/xss_urls.txt")
    echo "        XSS: $xss_count URLs"
    
    # SQLi
    cat "$urls_for_gf" | gf sqli 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/sqli_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/sqli_urls.txt"
    local sqli_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/sqli_urls.txt")
    echo "        SQLi: $sqli_count URLs"
    
    # LFI
    cat "$urls_for_gf" | gf lfi 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/lfi_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/lfi_urls.txt"
    local lfi_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/lfi_urls.txt")
    echo "        LFI: $lfi_count URLs"
    
    # IDOR
    cat "$urls_for_gf" | gf idor 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/idor_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/idor_urls.txt"
    local idor_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/idor_urls.txt")
    echo "        IDOR: $idor_count URLs"
    
    # Open Redirect
    cat "$urls_for_gf" | gf redirect 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/redirect_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/redirect_urls.txt"
    local redirect_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/redirect_urls.txt")
    echo "        Redirect: $redirect_count URLs"
    
    # SSRF
    cat "$urls_for_gf" | gf ssrf 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/ssrf_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/ssrf_urls.txt"
    local ssrf_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/ssrf_urls.txt")
    echo "        SSRF: $ssrf_count URLs"
    
    # SSTI
    cat "$urls_for_gf" | gf ssti 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/ssti_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/ssti_urls.txt"
    local ssti_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/ssti_urls.txt")
    echo "        SSTI: $ssti_count URLs"
    
    # RCE
    cat "$urls_for_gf" | gf rce 2>/dev/null | $proxy_cmd httpx -silent -mc 200,301,302,307 -no-color -threads 50 -timeout 10 > "$OUTPUT_DIR/urls/gf_results/rce_urls.txt" 2>/dev/null || touch "$OUTPUT_DIR/urls/gf_results/rce_urls.txt"
    local rce_count=$(count_lines "$OUTPUT_DIR/urls/gf_results/rce_urls.txt")
    echo "        RCE: $rce_count URLs"
    
    log_result "Total URLs: $total_urls | Unique: $dedup_count | Interesting: $interesting_count"
    log_result "Potential attack endpoints found: XSS($xss_count) SQLi($sqli_count) LFI($lfi_count) IDOR($idor_count)"
    
    # Save statistics
    cat > "$OUTPUT_DIR/urls/stats.json" << EOF
{
  "total_urls": $total_urls,
  "deduplicated_urls": $dedup_count,
  "interesting_files": $interesting_count,
  "xss": $xss_count,
  "sqli": $sqli_count,
  "lfi": $lfi_count,
  "idor": $idor_count,
  "redirect": $redirect_count,
  "ssrf": $ssrf_count,
  "ssti": $ssti_count,
  "rce": $rce_count
}
EOF
}
