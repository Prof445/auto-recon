# 🔍 Auto-Recon

**Web Reconnaissance Automation Tool for Penetration Testers & Bug Bounty Hunters**

Auto-Recon is a comprehensive, modular reconnaissance tool that automates the entire web application reconnaissance process. It collects subdomains, resolves IPs, discovers URLs, performs directory fuzzing, probes ports, and **generates interactive HTML report**.

---

## ✨ Features

### 🎯 Core Functionality
- **Multi-Source Subdomain Enumeration** - 7+ sources (crt.sh, Certspotter, VirusTotal, SecurityTrails, AlienVault, Subfinder, Assetfinder)
- **Smart Deduplication** - Tracks sources and eliminates duplicates
- **IP Discovery** - Resolves subdomains and discovers IPs from passive DNS
- **URL Collection** - Wayback Machine integration with intelligent filtering
- **Directory Fuzzing** - Automated fuzzing with SecLists wordlists
- **Port Probing** - Checks 30+ common web service ports
- **Vulnerability Detection** - GF patterns for XSS, SQLi, LFI, IDOR, SSRF, etc.

### 📊 Professional HTML Report
- **Interactive Dashboard** - Beautiful UI with statistics cards
- **Dark/Light Mode** - Theme toggle with persistence
- **Tabbed Navigation** - Easy access to all results
- **Search & Filter** - Find specific entries instantly
- **Export to CSV** - Download any dataset
- **Clickable URLs** - All URLs open in new tabs
- **Charts & Visualizations** - Subdomain sources, vulnerability distribution
- **Responsive Design** - Works on all devices

### 🚀 Advanced Features
- **Resume Capability** - Continue interrupted scans
- **Modular Execution** - Run specific phases only
- **Parallel Processing** - Fast execution with threading
- **Proxychains Support** - Route through proxy
- **Debug Mode** - Comprehensive logging
- **Rate Limiting** - Control request speed
- **Error Handling** - Automatic retries with exponential backoff
- **API Integration** - Optional VirusTotal & SecurityTrails

---

## 📦 Installation

### Quick Install

Clone the repository
```bash
git clone https://github.com/yourusername/auto-recon.git
cd auto-recon
```
Run installation script
```bash
chmod +x install.sh
./install.sh
```

---

## 🎯 Usage

### Basic Scan
```bash
auto-recon -d example.com
```

This runs all phases and generates a complete report.

### With API Keys
```bash
auto-recon -d example.com
```
You'll be prompted for API keys (optional)


### Run Specific Modules

Only subdomains and ports
```bash
auto-recon -d example.com --only subdomains,ports
```
Only URLs and fuzzing
```bash
auto-recon -d example.com --only urls,fuzzing
```

### Advanced Options

With proxychains
```bash
auto-recon -d example.com --proxychains
```
Debug mode (save logs)
```bash
auto-recon -d example.com --debug
```
Custom threads and timeout
```bash
auto-recon -d example.com -t 50 --timeout 15
```
Rate limiting
```bash
auto-recon -d example.com --rate-limit 50 --delay 500
```
Resume interrupted scan
```bash
auto-recon --resume -d example.com
```

### Check Tools

Verify all tools are installed
```bash
auto-recon --check-tools
```
Install missing tools
```bash
auto-recon --install-tools
```

---

## 📁 Output Structure

After running a scan on `example.com`, the following structure is created:

```bash
recon_results/
└── example.com_2025-10-05_00-30-45/
├── report.html # Interactive HTML report
├── subdomains/
│ ├── all_subdomains.txt # All discovered subdomains
│ ├── live_subdomains.txt # Only live subdomains
│ ├── subdomain_sources.json # Source tracking
│ └── stats.json # Statistics
├── ips/
│ ├── all_ips.txt # All discovered IPs
│ ├── live_ips.txt # Only live IPs
│ └── stats.json
├── urls/
│ ├── all_wayback_urls.txt # All URLs from Wayback
│ ├── live_interesting.txt # Interesting live files
│ ├── gf_results/
│ │ ├── xss_urls.txt # Potential XSS
│ │ ├── sqli_urls.txt # Potential SQLi
│ │ ├── lfi_urls.txt # Potential LFI
│ │ └── idor_urls.txt # Potential IDOR
│ └── stats.json
├── fuzzing/
│ ├── discovered_paths.txt # All discovered paths
│ └── stats.json
├── ports/
│ ├── open_ports.txt # Open web services
│ └── stats.json
├── logs/
│ ├── debug.log # Debug logs (if --debug)
│ └── errors.log # Error logs
└── .auto-recon.state # Resume state file
```

---

## 🎨 HTML Report Features

The generated HTML report includes:

### Dashboard
- **Statistics Cards** - Total subdomains, IPs, URLs, ports, fuzzing results
- **Live Counts** - Shows live vs. total for each category
- **Vulnerability Summary** - Count of potential vulnerabilities

### Tabs
1. **Overview** - Charts and visualizations
2. **Subdomains** - All live subdomains with search
3. **IPs** - All discovered IP addresses
4. **URLs** - Interesting URLs with file types
5. **Potential Vulnerabilities** - Grouped by type (XSS, SQLi, LFI, IDOR)
6. **Fuzzing** - Discovered directories and files
7. **Ports** - Open web services

### Features
- **Search/Filter** - Find specific entries instantly
- **Export CSV** - Download any dataset
- **Dark Mode** - Toggle theme (persists)
- **Clickable URLs** - All links open in new tabs
- **Responsive** - Works on mobile/tablet/desktop

---

## 🔧 Configuration

### API Keys

Auto-Recon supports optional API keys for enhanced results:

**VirusTotal:**
- Get your API key: https://www.virustotal.com/gui/join-us
- Provides additional subdomains and IP resolutions

**SecurityTrails:**
- Get your API key: https://securitytrails.com/
- Provides historical subdomain data

When running auto-recon, you'll be prompted to enter these keys. Press Enter to skip.

### Custom Ports

Edit `COMMON_PORTS` in `auto-recon.sh` to customize port scanning:

COMMON_PORTS="80,443,8080,8443,3000,5000,8000"


---

## 📝 Examples

### Example 1: Full Reconnaissance
```bash
auto-recon -d hackerone.com
```

**Output:**
- 150+ subdomains discovered
- 45 unique IPs
- 5,000+ URLs from Wayback
- 234 interesting files found
- 12 potential attack endpoints for: XSS, 8 SQLi, 3 LFI
- 456 paths from fuzzing
- 23 open web services

**Report:** `recon_results/hackerone.com_2025-10-05_01-30-00/report.html`

### Example 2: Quick Subdomain Scan
```bash
auto-recon -d example.com --only subdomains
```

**Duration:** ~2-3 minutes  
**Output:** Subdomains only, fast execution

### Example 3: Stealth Scan
```bash
auto-recon -d example.com --proxychains --delay 1000 --rate-limit 10
```

**Features:**
- Routes through proxychains
- 1 second delay between requests
- Maximum 10 requests/second

### Example 4: Resume Interrupted Scan

Scan interrupted during fuzzing phase
Resume from where it left off
```bash
auto-recon --resume -d example.com
```

---

## 🛡️ Best Practices

### Before Scanning
1. **Get Permission** - Only scan targets you're authorized to test
2. **Check Scope** - Verify target is in scope for bug bounty programs
3. **API Keys** - Set up VirusTotal & SecurityTrails for better results

### During Scanning
1. **Use Rate Limiting** - Avoid overwhelming target servers
2. **Monitor Resources** - Check CPU/memory usage
3. **Review Logs** - Check debug logs if errors occur

### After Scanning
1. **Review Report** - Analyze findings systematically
2. **Verify Findings** - Manually test potential vulnerabilities
3. **Document Everything** - Export CSVs for records

---

## 🐛 Troubleshooting

### Tools Not Found

Check tool status
```bash
auto-recon --check-tools
```
Install missing tools
```bash
auto-recon --install-tools
```

### Permission Errors

Don't run as root
Use your regular user account


### Network Issues

Enable debug mode to see detailed logs
```bash
auto-recon -d example.com --debug
```
Check error logs
```bash
cat recon_results/example.com_*/logs/errors.log
```

### Empty Results

- **No Subdomains:** Target may have few public subdomains
- **No URLs:** Target may not be in Wayback Machine
- **No Fuzzing Results:** Wordlist may not match target structure

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## ⚠️ Disclaimer

This tool is for educational and authorized security testing purposes only. Always obtain proper authorization before scanning any target. The authors are not responsible for misuse or damage caused by this tool.

---

## 🙏 Credits

**Tools Used:**
- [subfinder](https://github.com/projectdiscovery/subfinder) - ProjectDiscovery
- [assetfinder](https://github.com/tomnomnom/assetfinder) - TomNomNom
- [httpx](https://github.com/projectdiscovery/httpx) - ProjectDiscovery
- [dnsx](https://github.com/projectdiscovery/dnsx) - ProjectDiscovery
- [waybackurls](https://github.com/tomnomnom/waybackurls) - TomNomNom
- [gf](https://github.com/tomnomnom/gf) - TomNomNom
- [ffuf](https://github.com/ffuf/ffuf) - ffuf
- [uro](https://github.com/s0md3v/uro) - s0md3v
- [GF Patterns](https://github.com/1ndianl33t/Gf-Patterns) - 1ndianl33t
- [SecLists](https://github.com/danielmiessler/SecLists) - Daniel Miessler

---

## 📧 Contact

Created by **@Prof445**  
GitHub: [github.com/Prof445/auto-recon](https://github.com/Prof445/auto-recon)

---

**Happy Hunting! 🎯**

