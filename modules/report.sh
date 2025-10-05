#!/bin/bash

# HTML Report Generator Module
# Creates professional interactive HTML report

generate_html_report() {
    log_section "Generating HTML Report"
    
    local report_file="$OUTPUT_DIR/report.html"
    
    # Load statistics from all modules
    local subdomain_stats=$(cat "$OUTPUT_DIR/subdomains/stats.json" 2>/dev/null || echo '{"unique":0,"live":0,"live_percentage":0,"sources_count":0}')
    local ip_stats=$(cat "$OUTPUT_DIR/ips/stats.json" 2>/dev/null || echo '{"total_ips":0,"live_ips":0}')
    local url_stats=$(cat "$OUTPUT_DIR/urls/stats.json" 2>/dev/null || echo '{"total_urls":0,"interesting_files":0,"xss":0,"sqli":0,"lfi":0,"idor":0}')
    local fuzzing_stats=$(cat "$OUTPUT_DIR/fuzzing/stats.json" 2>/dev/null || echo '{"paths_discovered":0}')
    local port_stats=$(cat "$OUTPUT_DIR/ports/stats.json" 2>/dev/null || echo '{"total_services":0}')
    local source_data=$(cat "$OUTPUT_DIR/subdomains/subdomain_sources.json" 2>/dev/null || echo '{}')
    
    # Extract values
    local total_subdomains=$(echo "$subdomain_stats" | jq -r '.unique // 0')
    local live_subdomains=$(echo "$subdomain_stats" | jq -r '.live // 0')
    local total_ips=$(echo "$ip_stats" | jq -r '.total_ips // 0')
    local live_ips=$(echo "$ip_stats" | jq -r '.live_ips // 0')
    local total_urls=$(echo "$url_stats" | jq -r '.total_urls // 0')
    local interesting_files=$(echo "$url_stats" | jq -r '.interesting_files // 0')
    local xss_count=$(echo "$url_stats" | jq -r '.xss // 0')
    local sqli_count=$(echo "$url_stats" | jq -r '.sqli // 0')
    local lfi_count=$(echo "$url_stats" | jq -r '.lfi // 0')
    local idor_count=$(echo "$url_stats" | jq -r '.idor // 0')
    local fuzzing_paths=$(echo "$fuzzing_stats" | jq -r '.paths_discovered // 0')
    local open_ports=$(echo "$port_stats" | jq -r '.total_services // 0')
    local vuln_count=$((xss_count + sqli_count + lfi_count + idor_count))
    
    # Read and prepare data files as JSON arrays
    log_task "Loading data files"
    
    # Subdomains
    local live_subs_data="[]"
    if [[ -f "$OUTPUT_DIR/subdomains/live_subdomains.txt" ]] && [[ -s "$OUTPUT_DIR/subdomains/live_subdomains.txt" ]]; then
        live_subs_data=$(cat "$OUTPUT_DIR/subdomains/live_subdomains.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # IPs
    local live_ips_data="[]"
    if [[ -f "$OUTPUT_DIR/ips/live_ips.txt" ]] && [[ -s "$OUTPUT_DIR/ips/live_ips.txt" ]]; then
        live_ips_data=$(cat "$OUTPUT_DIR/ips/live_ips.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # URLs
    local interesting_urls_data="[]"
    if [[ -f "$OUTPUT_DIR/urls/live_interesting.txt" ]] && [[ -s "$OUTPUT_DIR/urls/live_interesting.txt" ]]; then
        interesting_urls_data=$(head -100 "$OUTPUT_DIR/urls/live_interesting.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # XSS URLs
    local xss_urls="[]"
    if [[ -f "$OUTPUT_DIR/urls/gf_results/xss_urls.txt" ]] && [[ -s "$OUTPUT_DIR/urls/gf_results/xss_urls.txt" ]]; then
        xss_urls=$(head -50 "$OUTPUT_DIR/urls/gf_results/xss_urls.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # SQLi URLs
    local sqli_urls="[]"
    if [[ -f "$OUTPUT_DIR/urls/gf_results/sqli_urls.txt" ]] && [[ -s "$OUTPUT_DIR/urls/gf_results/sqli_urls.txt" ]]; then
        sqli_urls=$(head -50 "$OUTPUT_DIR/urls/gf_results/sqli_urls.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # LFI URLs
    local lfi_urls="[]"
    if [[ -f "$OUTPUT_DIR/urls/gf_results/lfi_urls.txt" ]] && [[ -s "$OUTPUT_DIR/urls/gf_results/lfi_urls.txt" ]]; then
        lfi_urls=$(head -50 "$OUTPUT_DIR/urls/gf_results/lfi_urls.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # IDOR URLs
    local idor_urls="[]"
    if [[ -f "$OUTPUT_DIR/urls/gf_results/idor_urls.txt" ]] && [[ -s "$OUTPUT_DIR/urls/gf_results/idor_urls.txt" ]]; then
        idor_urls=$(head -50 "$OUTPUT_DIR/urls/gf_results/idor_urls.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # Fuzzing
    local fuzzing_data="[]"
    if [[ -f "$OUTPUT_DIR/fuzzing/discovered_paths.txt" ]] && [[ -s "$OUTPUT_DIR/fuzzing/discovered_paths.txt" ]]; then
        fuzzing_data=$(head -100 "$OUTPUT_DIR/fuzzing/discovered_paths.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    # Ports
    local ports_data="[]"
    if [[ -f "$OUTPUT_DIR/ports/open_ports.txt" ]] && [[ -s "$OUTPUT_DIR/ports/open_ports.txt" ]]; then
        ports_data=$(head -100 "$OUTPUT_DIR/ports/open_ports.txt" | jq -R -s -c 'split("\n") | map(select(length > 0))')
    fi
    
    log_task "Generating HTML report"
    
    # Create the HTML report with embedded data
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Auto-Recon Report - TARGET_PLACEHOLDER</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --bg-tertiary: #334155;
            --text-primary: #f1f5f9;
            --text-secondary: #cbd5e1;
            --accent-blue: #3b82f6;
            --accent-purple: #a855f7;
            --accent-green: #10b981;
            --accent-orange: #f59e0b;
            --accent-red: #ef4444;
            --accent-pink: #ec4899;
            --accent-cyan: #06b6d4;
            --shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
            --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.3), 0 4px 6px -4px rgb(0 0 0 / 0.2);
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: var(--text-primary);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1600px;
            margin: 0 auto;
        }

        /* Header */
        .header {
            background: linear-gradient(135deg, var(--accent-blue) 0%, var(--accent-purple) 100%);
            border-radius: 20px;
            padding: 40px;
            margin-bottom: 30px;
            box-shadow: var(--shadow-lg);
            position: relative;
            overflow: hidden;
        }

        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg"><defs><pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M 40 0 L 0 0 0 40" fill="none" stroke="rgba(255,255,255,0.05)" stroke-width="1"/></pattern></defs><rect width="100" height="100" fill="url(%23grid)"/></svg>');
            opacity: 0.5;
        }

        .header-content {
            position: relative;
            z-index: 1;
            text-align: center;
        }

        .header h1 {
            font-size: 3rem;
            font-weight: 800;
            margin-bottom: 10px;
            text-shadow: 0 2px 10px rgba(0,0,0,0.3);
        }

        .header .target {
            font-size: 1.5rem;
            font-weight: 600;
            opacity: 0.95;
            margin-bottom: 10px;
        }

        .header .timestamp {
            font-size: 0.95rem;
            opacity: 0.8;
        }

        .theme-toggle {
            position: fixed;
            top: 30px;
            right: 30px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            color: white;
            padding: 12px 24px;
            border-radius: 50px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            z-index: 1000;
            box-shadow: var(--shadow-lg);
        }

        .theme-toggle:hover {
            background: rgba(255, 255, 255, 0.2);
            transform: scale(1.05);
        }

        /* Stats Grid */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .stat-card {
            background: rgba(255, 255, 255, 0.03);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 16px;
            padding: 28px;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            position: relative;
            overflow: hidden;
        }

        .stat-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, var(--accent-blue), var(--accent-purple));
            transform: scaleX(0);
            transition: transform 0.3s;
        }

        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: var(--shadow-lg);
            border-color: rgba(255, 255, 255, 0.15);
        }

        .stat-card:hover::before {
            transform: scaleX(1);
        }

        .stat-card-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
        }

        .stat-icon {
            width: 48px;
            height: 48px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
        }

        .stat-card h3 {
            font-size: 0.875rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: var(--text-secondary);
        }

        .stat-value {
            font-size: 2.5rem;
            font-weight: 800;
            margin-bottom: 8px;
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .stat-label {
            font-size: 0.875rem;
            color: var(--text-secondary);
        }

        /* Tabs */
        .tabs {
            background: var(--bg-secondary);
            border-radius: 16px;
            padding: 8px;
            margin-bottom: 30px;
            display: flex;
            gap: 8px;
            overflow-x: auto;
            box-shadow: var(--shadow);
        }

        .tab {
            padding: 12px 24px;
            background: transparent;
            border: none;
            color: var(--text-secondary);
            font-weight: 600;
            font-size: 0.95rem;
            border-radius: 10px;
            cursor: pointer;
            transition: all 0.3s;
            white-space: nowrap;
        }

        .tab:hover {
            background: rgba(255, 255, 255, 0.05);
            color: var(--text-primary);
        }

        .tab.active {
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
            color: white;
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
        }

        /* Tab Content */
        .tab-content {
            display: none;
            animation: fadeInUp 0.4s ease;
        }

        .tab-content.active {
            display: block;
        }

        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .content-card {
            background: var(--bg-secondary);
            border-radius: 16px;
            padding: 30px;
            box-shadow: var(--shadow);
            border: 1px solid rgba(255, 255, 255, 0.05);
        }

        .section-title {
            font-size: 1.75rem;
            font-weight: 700;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .section-title i {
            color: var(--accent-blue);
        }

        /* Search Box */
        .search-box {
            width: 100%;
            padding: 14px 20px 14px 48px;
            background: var(--bg-tertiary);
            border: 2px solid rgba(255, 255, 255, 0.08);
            border-radius: 12px;
            color: var(--text-primary);
            font-size: 1rem;
            margin-bottom: 20px;
            transition: all 0.3s;
            position: relative;
        }

        .search-wrapper {
            position: relative;
        }

        .search-wrapper i {
            position: absolute;
            left: 18px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-secondary);
            pointer-events: none;
        }

        .search-box:focus {
            outline: none;
            border-color: var(--accent-blue);
            box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.1);
        }

        /* Data Table */
        .table-wrapper {
            overflow-x: auto;
            border-radius: 12px;
        }

        .data-table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
        }

        .data-table th {
            background: var(--bg-tertiary);
            color: var(--text-secondary);
            padding: 16px;
            text-align: left;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.8rem;
            letter-spacing: 1px;
            position: sticky;
            top: 0;
            z-index: 10;
        }

        .data-table th:first-child {
            border-radius: 12px 0 0 0;
        }

        .data-table th:last-child {
            border-radius: 0 12px 0 0;
        }

        .data-table td {
            padding: 16px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }

        .data-table tr:hover {
            background: rgba(255, 255, 255, 0.02);
        }

        .data-table a {
            color: var(--accent-blue);
            text-decoration: none;
            transition: all 0.2s;
            word-break: break-all;
        }

        .data-table a:hover {
            color: var(--accent-purple);
            text-decoration: underline;
        }

        /* Badge */
        .badge {
            display: inline-flex;
            align-items: center;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 600;
            gap: 6px;
        }

        .badge.success {
            background: rgba(16, 185, 129, 0.15);
            color: var(--accent-green);
        }

        .badge.warning {
            background: rgba(245, 158, 11, 0.15);
            color: var(--accent-orange);
        }

        .badge.danger {
            background: rgba(239, 68, 68, 0.15);
            color: var(--accent-red);
        }

        .badge.info {
            background: rgba(6, 182, 212, 0.15);
            color: var(--accent-cyan);
        }

        /* Buttons */
        .export-btn {
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            font-size: 0.95rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            margin-bottom: 20px;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }

        .export-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 16px rgba(59, 130, 246, 0.3);
        }

        /* Charts */
        .chart-container {
            background: var(--bg-secondary);
            border-radius: 16px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: var(--shadow);
            border: 1px solid rgba(255, 255, 255, 0.05);
        }

        .chart-wrapper {
            position: relative;
            height: 400px;
        }

        /* Collapsible */
        .collapsible {
            background: var(--bg-tertiary);
            padding: 18px 24px;
            border-radius: 12px;
            margin-bottom: 12px;
            cursor: pointer;
            transition: all 0.3s;
            border: 2px solid transparent;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .collapsible:hover {
            border-color: var(--accent-blue);
            transform: translateX(4px);
        }

        .collapsible h3 {
            font-size: 1.1rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .collapsible i {
            transition: transform 0.3s;
        }

        .collapsible.active i {
            transform: rotate(180deg);
        }

        .collapsible-content {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease;
        }

        .collapsible-content.active {
            max-height: 5000px;
            margin-bottom: 20px;
        }

        /* No Data */
        .no-data {
            text-align: center;
            padding: 60px 20px;
            color: var(--text-secondary);
            font-size: 1.1rem;
        }

        .no-data i {
            font-size: 3rem;
            margin-bottom: 16px;
            opacity: 0.5;
        }

        /* Responsive */
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }

            .stats-grid {
                grid-template-columns: 1fr;
            }

            .tabs {
                flex-direction: column;
            }
        }
    </style>
</head>
<body>
    <button class="theme-toggle" onclick="toggleTheme()">
        <i class="fas fa-moon"></i> Toggle Theme
    </button>
    
    <div class="container">
        <div class="header">
            <div class="header-content">
                <h1><i class="fas fa-shield-alt"></i> Auto-Recon Report</h1>
                <div class="target">TARGET_PLACEHOLDER</div>
                <div class="timestamp">Generated: TIMESTAMP_PLACEHOLDER</div>
            </div>
        </div>

        <div class="stats-grid">
            <div class="stat-card" onclick="openTabByName('subdomains')">
                <div class="stat-card-header">
                    <div class="stat-icon" style="background: linear-gradient(135deg, #3b82f6, #a855f7);">
                        <i class="fas fa-sitemap"></i>
                    </div>
                    <h3>Subdomains</h3>
                </div>
                <div class="stat-value">LIVE_SUBDOMAINS_PLACEHOLDER</div>
                <div class="stat-label">of TOTAL_SUBDOMAINS_PLACEHOLDER found</div>
            </div>

            <div class="stat-card" onclick="openTabByName('ips')">
                <div class="stat-card-header">
                    <div class="stat-icon" style="background: linear-gradient(135deg, #ec4899, #f59e0b);">
                        <i class="fas fa-network-wired"></i>
                    </div>
                    <h3>IP Addresses</h3>
                </div>
                <div class="stat-value">LIVE_IPS_PLACEHOLDER</div>
                <div class="stat-label">of TOTAL_IPS_PLACEHOLDER discovered</div>
            </div>

            <div class="stat-card" onclick="openTabByName('urls')">
                <div class="stat-card-header">
                    <div class="stat-icon" style="background: linear-gradient(135deg, #06b6d4, #10b981);">
                        <i class="fas fa-link"></i>
                    </div>
                    <h3>URLs Found</h3>
                </div>
                <div class="stat-value">TOTAL_URLS_PLACEHOLDER</div>
                <div class="stat-label">INTERESTING_FILES_PLACEHOLDER interesting files</div>
            </div>

            <div class="stat-card" onclick="openTabByName('ports')">
                <div class="stat-card-header">
                    <div class="stat-icon" style="background: linear-gradient(135deg, #10b981, #3b82f6);">
                        <i class="fas fa-door-open"></i>
                    </div>
                    <h3>Open Ports</h3>
                </div>
                <div class="stat-value">OPEN_PORTS_PLACEHOLDER</div>
                <div class="stat-label">web services</div>
            </div>

            <div class="stat-card" onclick="openTabByName('fuzzing')">
                <div class="stat-card-header">
                    <div class="stat-icon" style="background: linear-gradient(135deg, #f59e0b, #ec4899);">
                        <i class="fas fa-folder-open"></i>
                    </div>
                    <h3>Fuzzing</h3>
                </div>
                <div class="stat-value">FUZZING_PATHS_PLACEHOLDER</div>
                <div class="stat-label">paths discovered</div>
            </div>

            <div class="stat-card" onclick="openTabByName('vulnerabilities')">
                <div class="stat-card-header">
                    <div class="stat-icon" style="background: linear-gradient(135deg, #ef4444, #a855f7);">
                        <i class="fas fa-exclamation-triangle"></i>
                    </div>
                    <h3>Attack Endpoints</h3>
                </div>
                <div class="stat-value">VULN_COUNT_PLACEHOLDER</div>
                <div class="stat-label">potential vectors</div>
            </div>
        </div>

        <div class="tabs">
            <button class="tab active" onclick="openTab(event, 'overview')">
                <i class="fas fa-chart-pie"></i> Overview
            </button>
            <button class="tab" onclick="openTab(event, 'subdomains')">
                <i class="fas fa-sitemap"></i> Subdomains
            </button>
            <button class="tab" onclick="openTab(event, 'ips')">
                <i class="fas fa-network-wired"></i> IP Addresses
            </button>
            <button class="tab" onclick="openTab(event, 'urls')">
                <i class="fas fa-link"></i> URLs
            </button>
            <button class="tab" onclick="openTab(event, 'vulnerabilities')">
                <i class="fas fa-bug"></i> Attack Endpoints
            </button>
            <button class="tab" onclick="openTab(event, 'fuzzing')">
                <i class="fas fa-folder-open"></i> Fuzzing
            </button>
            <button class="tab" onclick="openTab(event, 'ports')">
                <i class="fas fa-door-open"></i> Ports
            </button>
        </div>

        <div id="overview" class="tab-content active">
            <div class="chart-container">
                <h2 class="section-title"><i class="fas fa-chart-pie"></i> Subdomain Sources</h2>
                <div class="chart-wrapper">
                    <canvas id="subdomainSourcesChart"></canvas>
                </div>
            </div>

            <div class="chart-container">
                <h2 class="section-title"><i class="fas fa-chart-bar"></i> Attack Surface Distribution</h2>
                <div class="chart-wrapper">
                    <canvas id="vulnerabilityChart"></canvas>
                </div>
            </div>
        </div>

        <div id="subdomains" class="tab-content">
            <div class="content-card">
                <h2 class="section-title"><i class="fas fa-sitemap"></i> Live Subdomains</h2>
                <div class="search-wrapper">
                    <i class="fas fa-search"></i>
                    <input type="text" class="search-box" placeholder="Search subdomains..." onkeyup="filterTable(this, 'subdomainTable')">
                </div>
                <button class="export-btn" onclick="exportData('subdomains')">
                    <i class="fas fa-download"></i> Export CSV
                </button>
                <div class="table-wrapper">
                    <table class="data-table" id="subdomainTable">
                        <thead>
                            <tr>
                                <th style="width: 60px;">#</th>
                                <th>Subdomain</th>
                                <th style="width: 120px;">Status</th>
                            </tr>
                        </thead>
                        <tbody id="subdomainTableBody">
                            <!-- Data will be injected here -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div id="ips" class="tab-content">
            <div class="content-card">
                <h2 class="section-title"><i class="fas fa-network-wired"></i> IP Addresses</h2>
                <div class="search-wrapper">
                    <i class="fas fa-search"></i>
                    <input type="text" class="search-box" placeholder="Search IPs..." onkeyup="filterTable(this, 'ipTable')">
                </div>
                <button class="export-btn" onclick="exportData('ips')">
                    <i class="fas fa-download"></i> Export CSV
                </button>
                <div class="table-wrapper">
                    <table class="data-table" id="ipTable">
                        <thead>
                            <tr>
                                <th style="width: 60px;">#</th>
                                <th>IP Address</th>
                                <th style="width: 120px;">Status</th>
                            </tr>
                        </thead>
                        <tbody id="ipTableBody">
                            <!-- Data will be injected here -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div id="urls" class="tab-content">
            <div class="content-card">
                <h2 class="section-title"><i class="fas fa-link"></i> Interesting URLs</h2>
                <div class="search-wrapper">
                    <i class="fas fa-search"></i>
                    <input type="text" class="search-box" placeholder="Search URLs..." onkeyup="filterTable(this, 'urlTable')">
                </div>
                <button class="export-btn" onclick="exportData('urls')">
                    <i class="fas fa-download"></i> Export CSV
                </button>
                <div class="table-wrapper">
                    <table class="data-table" id="urlTable">
                        <thead>
                            <tr>
                                <th style="width: 60px;">#</th>
                                <th>URL</th>
                                <th style="width: 120px;">Type</th>
                            </tr>
                        </thead>
                        <tbody id="urlTableBody">
                            <!-- Data will be injected here -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div id="vulnerabilities" class="tab-content">
            <div class="content-card">
                <h2 class="section-title"><i class="fas fa-bug"></i> Potential Attack Endpoints</h2>
                
                <div class="collapsible" onclick="toggleCollapse(this)">
                    <h3><i class="fas fa-code" style="color: #ef4444;"></i> XSS - Cross-Site Scripting (XSS_COUNT_PLACEHOLDER)</h3>
                    <i class="fas fa-chevron-down"></i>
                </div>
                <div class="collapsible-content">
                    <div class="table-wrapper">
                        <table class="data-table">
                            <tbody id="xssTableBody">
                                <!-- Data will be injected here -->
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="collapsible" onclick="toggleCollapse(this)">
                    <h3><i class="fas fa-database" style="color: #ef4444;"></i> SQLi - SQL Injection (SQLI_COUNT_PLACEHOLDER)</h3>
                    <i class="fas fa-chevron-down"></i>
                </div>
                <div class="collapsible-content">
                    <div class="table-wrapper">
                        <table class="data-table">
                            <tbody id="sqliTableBody">
                                <!-- Data will be injected here -->
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="collapsible" onclick="toggleCollapse(this)">
                    <h3><i class="fas fa-file" style="color: #f59e0b;"></i> LFI - Local File Inclusion (LFI_COUNT_PLACEHOLDER)</h3>
                    <i class="fas fa-chevron-down"></i>
                </div>
                <div class="collapsible-content">
                    <div class="table-wrapper">
                        <table class="data-table">
                            <tbody id="lfiTableBody">
                                <!-- Data will be injected here -->
                            </tbody>
                        </table>
                    </div>
                </div>

                <div class="collapsible" onclick="toggleCollapse(this)">
                    <h3><i class="fas fa-key" style="color: #f59e0b;"></i> IDOR - Insecure Direct Object Reference (IDOR_COUNT_PLACEHOLDER)</h3>
                    <i class="fas fa-chevron-down"></i>
                </div>
                <div class="collapsible-content">
                    <div class="table-wrapper">
                        <table class="data-table">
                            <tbody id="idorTableBody">
                                <!-- Data will be injected here -->
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <div id="fuzzing" class="tab-content">
            <div class="content-card">
                <h2 class="section-title"><i class="fas fa-folder-open"></i> Directory Fuzzing Results</h2>
                <div class="search-wrapper">
                    <i class="fas fa-search"></i>
                    <input type="text" class="search-box" placeholder="Search paths..." onkeyup="filterTable(this, 'fuzzingTable')">
                </div>
                <button class="export-btn" onclick="exportData('fuzzing')">
                    <i class="fas fa-download"></i> Export CSV
                </button>
                <div class="table-wrapper">
                    <table class="data-table" id="fuzzingTable">
                        <thead>
                            <tr>
                                <th style="width: 60px;">#</th>
                                <th>Path</th>
                            </tr>
                        </thead>
                        <tbody id="fuzzingTableBody">
                            <!-- Data will be injected here -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div id="ports" class="tab-content">
            <div class="content-card">
                <h2 class="section-title"><i class="fas fa-door-open"></i> Open Ports & Services</h2>
                <div class="search-wrapper">
                    <i class="fas fa-search"></i>
                    <input type="text" class="search-box" placeholder="Search services..." onkeyup="filterTable(this, 'portsTable')">
                </div>
                <button class="export-btn" onclick="exportData('ports')">
                    <i class="fas fa-download"></i> Export CSV
                </button>
                <div class="table-wrapper">
                    <table class="data-table" id="portsTable">
                        <thead>
                            <tr>
                                <th style="width: 60px;">#</th>
                                <th>Service</th>
                            </tr>
                        </thead>
                        <tbody id="portsTableBody">
                            <!-- Data will be injected here -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Data injection
        const data = DATA_JSON_PLACEHOLDER;

        // Populate tables
        function populateTables() {
            // Subdomains
            const subdomainTbody = document.getElementById('subdomainTableBody');
            if (data.subdomains && data.subdomains.length > 0) {
                data.subdomains.forEach((sub, idx) => {
                    const cleanSub = sub.replace(/^https?:\/\//, '');
                    const row = `<tr>
                        <td>${idx + 1}</td>
                        <td><a href="https://${cleanSub}" target="_blank">${cleanSub}</a></td>
                        <td><span class="badge success"><i class="fas fa-check-circle"></i> Live</span></td>
                    </tr>`;
                    subdomainTbody.innerHTML += row;
                });
            } else {
                subdomainTbody.innerHTML = '<tr><td colspan="3" class="no-data"><i class="fas fa-inbox"></i><br>No subdomains found</td></tr>';
            }

            // IPs
            const ipTbody = document.getElementById('ipTableBody');
            if (data.ips && data.ips.length > 0) {
                data.ips.forEach((ip, idx) => {
                    const cleanIP = ip.replace(/^https?:\/\//, '').split('/')[0].split(':')[0];
                    const row = `<tr>
                        <td>${idx + 1}</td>
                        <td><a href="http://${cleanIP}" target="_blank">${cleanIP}</a></td>
                        <td><span class="badge success"><i class="fas fa-check-circle"></i> Live</span></td>
                    </tr>`;
                    ipTbody.innerHTML += row;
                });
            } else {
                ipTbody.innerHTML = '<tr><td colspan="3" class="no-data"><i class="fas fa-inbox"></i><br>No IPs found</td></tr>';
            }

            // URLs
            const urlTbody = document.getElementById('urlTableBody');
            if (data.urls && data.urls.length > 0) {
                data.urls.forEach((url, idx) => {
                    const ext = url.split('.').pop().split('?')[0];
                    const row = `<tr>
                        <td>${idx + 1}</td>
                        <td><a href="${url}" target="_blank">${url}</a></td>
                        <td><span class="badge info">${ext}</span></td>
                    </tr>`;
                    urlTbody.innerHTML += row;
                });
            } else {
                urlTbody.innerHTML = '<tr><td colspan="3" class="no-data"><i class="fas fa-inbox"></i><br>No interesting URLs found</td></tr>';
            }

            // XSS
            const xssTbody = document.getElementById('xssTableBody');
            if (data.xss && data.xss.length > 0) {
                data.xss.forEach((url, idx) => {
                    const row = `<tr><td><a href="${url}" target="_blank">${url}</a></td></tr>`;
                    xssTbody.innerHTML += row;
                });
            } else {
                xssTbody.innerHTML = '<tr><td class="no-data"><i class="fas fa-inbox"></i><br>No XSS URLs found</td></tr>';
            }

            // SQLi
            const sqliTbody = document.getElementById('sqliTableBody');
            if (data.sqli && data.sqli.length > 0) {
                data.sqli.forEach((url, idx) => {
                    const row = `<tr><td><a href="${url}" target="_blank">${url}</a></td></tr>`;
                    sqliTbody.innerHTML += row;
                });
            } else {
                sqliTbody.innerHTML = '<tr><td class="no-data"><i class="fas fa-inbox"></i><br>No SQLi URLs found</td></tr>';
            }

            // LFI
            const lfiTbody = document.getElementById('lfiTableBody');
            if (data.lfi && data.lfi.length > 0) {
                data.lfi.forEach((url, idx) => {
                    const row = `<tr><td><a href="${url}" target="_blank">${url}</a></td></tr>`;
                    lfiTbody.innerHTML += row;
                });
            } else {
                lfiTbody.innerHTML = '<tr><td class="no-data"><i class="fas fa-inbox"></i><br>No LFI URLs found</td></tr>';
            }

            // IDOR
            const idorTbody = document.getElementById('idorTableBody');
            if (data.idor && data.idor.length > 0) {
                data.idor.forEach((url, idx) => {
                    const row = `<tr><td><a href="${url}" target="_blank">${url}</a></td></tr>`;
                    idorTbody.innerHTML += row;
                });
            } else {
                idorTbody.innerHTML = '<tr><td class="no-data"><i class="fas fa-inbox"></i><br>No IDOR URLs found</td></tr>';
            }

            // Fuzzing
            const fuzzingTbody = document.getElementById('fuzzingTableBody');
            if (data.fuzzing && data.fuzzing.length > 0) {
                data.fuzzing.forEach((path, idx) => {
                    const row = `<tr>
                        <td>${idx + 1}</td>
                        <td><a href="${path}" target="_blank">${path}</a></td>
                    </tr>`;
                    fuzzingTbody.innerHTML += row;
                });
            } else {
                fuzzingTbody.innerHTML = '<tr><td colspan="2" class="no-data"><i class="fas fa-inbox"></i><br>No paths discovered</td></tr>';
            }

            // Ports
            const portsTbody = document.getElementById('portsTableBody');
            if (data.ports && data.ports.length > 0) {
                data.ports.forEach((service, idx) => {
                    const urlMatch = service.match(/^(https?:\/\/[^\s]+)/);
                    const url = urlMatch ? urlMatch[1] : '';
                    const details = service.replace(url, '').trim();
                    
                    let row;
                    if (url) {
                        row = `<tr>
                            <td>${idx + 1}</td>
                            <td><a href="${url}" target="_blank">${url}</a> <span style="color: #94a3b8;">${details}</span></td>
                        </tr>`;
                    } else {
                        row = `<tr>
                            <td>${idx + 1}</td>
                            <td>${service}</td>
                        </tr>`;
                    }
                    portsTbody.innerHTML += row;
                });
            } else {
                portsTbody.innerHTML = '<tr><td colspan="2" class="no-data"><i class="fas fa-inbox"></i><br>No open ports found</td></tr>';
            }
        }

        // Tab switching
        function openTab(evt, tabName) {
            const tabs = document.querySelectorAll('.tab');
            const contents = document.querySelectorAll('.tab-content');
            
            tabs.forEach(tab => tab.classList.remove('active'));
            contents.forEach(content => content.classList.remove('active'));
            
            if (evt) {
                evt.currentTarget.classList.add('active');
            }
            document.getElementById(tabName).classList.add('active');
        }

        // Open tab by name (for stat card clicks)
        function openTabByName(tabName) {
            const tabs = document.querySelectorAll('.tab');
            const contents = document.querySelectorAll('.tab-content');
            
            tabs.forEach(tab => tab.classList.remove('active'));
            contents.forEach(content => content.classList.remove('active'));
            
            // Find and activate the matching tab button
            tabs.forEach(tab => {
                if (tab.textContent.toLowerCase().includes(tabName.toLowerCase()) ||
                    tab.onclick.toString().includes(tabName)) {
                    tab.classList.add('active');
                }
            });
            
            document.getElementById(tabName).classList.add('active');
        }

        // Theme toggle
        function toggleTheme() {
            document.body.classList.toggle('light-mode');
            localStorage.setItem('theme', document.body.classList.contains('light-mode') ? 'light' : 'dark');
        }

        // Load saved theme
        if (localStorage.getItem('theme') === 'light') {
            document.body.classList.add('light-mode');
        }

        // Filter table
        function filterTable(input, tableId) {
            const filter = input.value.toUpperCase();
            const table = document.getElementById(tableId);
            const tr = table.getElementsByTagName('tr');

            for (let i = 1; i < tr.length; i++) {
                const td = tr[i].getElementsByTagName('td');
                let found = false;
                
                for (let j = 0; j < td.length; j++) {
                    if (td[j].textContent.toUpperCase().indexOf(filter) > -1) {
                        found = true;
                        break;
                    }
                }
                
                tr[i].style.display = found ? '' : 'none';
            }
        }

        // Collapsible sections
        function toggleCollapse(element) {
            element.classList.toggle('active');
            const content = element.nextElementSibling;
            content.classList.toggle('active');
        }

        // Export data
        function exportData(type) {
            let csv = '';
            let filename = '';
            
            switch(type) {
                case 'subdomains':
                    csv = 'Subdomain,Status\n';
                    data.subdomains.forEach(sub => {
                        const cleanSub = sub.replace(/^https?:\/\//, '');
                        csv += `${cleanSub},Live\n`;
                    });
                    filename = 'subdomains.csv';
                    break;
                case 'ips':
                    csv = 'IP Address,Status\n';
                    data.ips.forEach(ip => {
                        const cleanIP = ip.replace(/^https?:\/\//, '').split('/')[0].split(':')[0];
                        csv += `${cleanIP},Live\n`;
                    });
                    filename = 'ips.csv';
                    break;
                case 'urls':
                    csv = 'URL\n';
                    data.urls.forEach(url => {
                        csv += `${url}\n`;
                    });
                    filename = 'urls.csv';
                    break;
                case 'fuzzing':
                    csv = 'Path\n';
                    data.fuzzing.forEach(path => {
                        csv += `${path}\n`;
                    });
                    filename = 'fuzzing.csv';
                    break;
                case 'ports':
                    csv = 'Service\n';
                    data.ports.forEach(port => {
                        csv += `${port}\n`;
                    });
                    filename = 'ports.csv';
                    break;
            }
            
            const blob = new Blob([csv], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            a.click();
        }

        // Charts
        function createCharts() {
            // Subdomain Sources Chart
            const sourcesCtx = document.getElementById('subdomainSourcesChart');
            if (sourcesCtx && Object.keys(data.sources).length > 0) {
                new Chart(sourcesCtx, {
                    type: 'doughnut',
                    data: {
                        labels: Object.keys(data.sources),
                        datasets: [{
                            data: Object.values(data.sources),
                            backgroundColor: [
                                '#3b82f6', '#a855f7', '#ec4899', '#f59e0b',
                                '#10b981', '#06b6d4', '#8b5cf6', '#ef4444'
                            ],
                            borderWidth: 0
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: {
                                position: 'right',
                                labels: {
                                    color: '#cbd5e1',
                                    font: {
                                        size: 13,
                                        family: 'Inter'
                                    },
                                    padding: 15
                                }
                            }
                        }
                    }
                });
            }

            // Vulnerability Chart
            const vulnCtx = document.getElementById('vulnerabilityChart');
            if (vulnCtx) {
                new Chart(vulnCtx, {
                    type: 'bar',
                    data: {
                        labels: ['XSS', 'SQLi', 'LFI', 'IDOR'],
                        datasets: [{
                            label: 'Potential Attack Endpoints',
                            data: [data.xss.length, data.sqli.length, data.lfi.length, data.idor.length],
                            backgroundColor: [
                                '#ef4444', '#f59e0b', '#10b981', '#3b82f6'
                            ],
                            borderRadius: 8,
                            borderWidth: 0
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: {
                                display: false
                            }
                        },
                        scales: {
                            y: {
                                beginAtZero: true,
                                grid: {
                                    color: 'rgba(255, 255, 255, 0.05)'
                                },
                                ticks: {
                                    color: '#cbd5e1',
                                    font: {
                                        family: 'Inter'
                                    }
                                }
                            },
                            x: {
                                grid: {
                                    display: false
                                },
                                ticks: {
                                    color: '#cbd5e1',
                                    font: {
                                        family: 'Inter'
                                    }
                                }
                            }
                        }
                    }
                });
            }
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', function() {
            populateTables();
            createCharts();
        });
    </script>
</body>
</html>
EOF

    # Replace text placeholders
    sed -i "s/TARGET_PLACEHOLDER/$TARGET/g" "$report_file"
    sed -i "s/TIMESTAMP_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M:%S')/g" "$report_file"
    sed -i "s/LIVE_SUBDOMAINS_PLACEHOLDER/$live_subdomains/g" "$report_file"
    sed -i "s/TOTAL_SUBDOMAINS_PLACEHOLDER/$total_subdomains/g" "$report_file"
    sed -i "s/LIVE_IPS_PLACEHOLDER/$live_ips/g" "$report_file"
    sed -i "s/TOTAL_IPS_PLACEHOLDER/$total_ips/g" "$report_file"
    sed -i "s/TOTAL_URLS_PLACEHOLDER/$total_urls/g" "$report_file"
    sed -i "s/INTERESTING_FILES_PLACEHOLDER/$interesting_files/g" "$report_file"
    sed -i "s/OPEN_PORTS_PLACEHOLDER/$open_ports/g" "$report_file"
    sed -i "s/FUZZING_PATHS_PLACEHOLDER/$fuzzing_paths/g" "$report_file"
    sed -i "s/VULN_COUNT_PLACEHOLDER/$vuln_count/g" "$report_file"
    sed -i "s/XSS_COUNT_PLACEHOLDER/$xss_count/g" "$report_file"
    sed -i "s/SQLI_COUNT_PLACEHOLDER/$sqli_count/g" "$report_file"
    sed -i "s/LFI_COUNT_PLACEHOLDER/$lfi_count/g" "$report_file"
    sed -i "s/IDOR_COUNT_PLACEHOLDER/$idor_count/g" "$report_file"
    
    # Replace data placeholder by directly inserting JSON
    # This avoids sed issues with special characters
    python3 << PYTHON
import json

# Read the HTML
with open("$report_file", 'r') as f:
    html = f.read()

# Create data object
data = {
    "subdomains": $live_subs_data,
    "ips": $live_ips_data,
    "urls": $interesting_urls_data,
    "xss": $xss_urls,
    "sqli": $sqli_urls,
    "lfi": $lfi_urls,
    "idor": $idor_urls,
    "fuzzing": $fuzzing_data,
    "ports": $ports_data,
    "sources": $source_data
}

# Convert to JSON string
data_json = json.dumps(data, indent=2)

# Replace placeholder
html = html.replace('DATA_JSON_PLACEHOLDER', data_json)

# Write back
with open("$report_file", 'w') as f:
    f.write(html)
PYTHON
    
    log_success "HTML report generated: $report_file"
}
