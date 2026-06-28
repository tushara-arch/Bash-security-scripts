# Phase 2: Automated Threat Intelligence & Remediation Engine

##  Overview
This script parses an `auth.log` file to identify the top source IPs responsible for brute-force login attempts, geolocates each one using local Threat Intelligence, and optionally applies UFW blocking rules depending on operator privilege. 

Designed for rapid triage during an active incident, this tool extracts attacker origin data and deploys automated firewall remediation in a single, highly optimized pass.

##  Features
* **Log Parsing:** Extracts and ranks attacker IPs by attempt count from a provided auth log file.
* **Offline Geolocation:** Resolves each IP to a country using the local MaxMind `geoiplookup` database, allowing for zero-latency Threat Intelligence gathering without relying on rate-limited external web APIs.
* **Optimized Architecture (Separation of Concerns):** Engineered with strict loop decoupling. Reporting and Threat Intel generation run completely independent of the automated firewall modifications, preventing redundant condition checks and code duplication.
* **Privilege-Aware Remediation:** Dynamically detects operator privileges (`EUID`). If executed as root, UFW deny rules are applied automatically. If run as a standard user, the script safely generates the audit report and skips remediation without throwing disruptive terminal errors.
* **Fail-Fast Design & Secure Execution:** Hardened with `set -euo pipefail` and comprehensive pre-flight checks to validate log file paths, read permissions, and system dependencies before any data processing begins.
* **Persistent Artifacts:** Writes extracted IP intelligence to `Attacker_origin.txt` to provide a persistent artifact for post-incident reporting or SIEM ingestion.

## ⚙️ Prerequisites & Assumptions
* **OS:** Ubuntu/Debian-based systems (relies on `apt` and `ufw`).
* **Dependencies:** `geoip-bin` (Install via `sudo apt install geoip-bin`).
* **SSH Hardening Assumption:** This script is designed for environments adhering to enterprise SSH hardening standards. Specifically, it assumes `UseDNS no` is configured in `/etc/ssh/sshd_config`. This prevents reverse DNS lookups, ensuring logs record raw attacker IPs rather than spoofed hostnames, optimizing the extraction pipeline.

##  Usage

**1. Make the script executable:**

`chmod +x phase2.sh`

**2. Run in Audit/Report Mode (Non-Root):**
Executing without `sudo` will parse the logs and generate the Threat Intelligence report, but will safely bypass the firewall modification loop.

`./phase2.sh /var/log/auth.log`

**3. Run in Remediation Mode (Root):**
Executing with `sudo` will generate the report and immediately block the extracted malicious IPs across all ports using UFW.

`sudo ./phase2.sh /var/log/auth.log`

---

##  Engineering & Refactoring Journey
Building this tool required several iterations to optimize performance and adhere to enterprise architecture standards. Below are the key design evolutions.

### 1. Refactoring the Remediation Loop
The most significant architectural shift occurred in how the script handles automated blocking based on user privileges (`EUID`).

* **The Initial Mistake (Inefficient Evaluation):** Initially, the privilege check (`if [[ "$EUID" -eq 0 ]]`) was placed *inside* the main extraction loop. This meant the script was redundantly evaluating a static flag on every single iteration (for every IP address), creating unnecessary computational overhead.
```bash
while read -r count ip; do
        country=$(geoiplookup "$ip" 2>/dev/null | awk -F': ' '{print $2}' || echo "Unknown")
        printf '%-10s  %-18s  %s\n' "$count" "$ip" "$country"
        if [[ "$BLOCKING_ENABLED" == true ]]; then
            ufw deny from "$ip" &>/dev/null
            (( ++BLOCKED )) || true
        fi
    done < "$OUTPUT_FILE"
``` 
* **The First Fix (Code Duplication):** To solve the efficiency issue, the condition was moved outside the loop. However, this created two massive `while` loops—one for root and one for non-root. This resulted in severe code duplication, with the Threat Intel (`geoiplookup`) and formatting (`printf`) logic written twice.
```bash
if [[ "$BLOCKING_ENABLED" == true ]]; then
    while read -r count ip; do
        country=$(geoiplookup "$ip" 2>/dev/null | awk -F': ' '{print $2}' || echo "Unknown")
        printf '%-10s  %-18s  %s\n' "$count" "$ip" "$country"
        ufw deny from "$ip" &>/dev/null
        echo "[+] Blocked $ip"
        (( BLOCKED++ )) || true
    done < "$OUTPUT_FILE"
else
    while read -r count ip; do
        country=$(geoiplookup "$ip" 2>/dev/null | awk -F': ' '{print $2}' || echo "Unknown")
        printf '%-10s  %-18s  %s\n' "$count" "$ip" "$country"
    done < "$OUTPUT_FILE"
fi
```
In these the blocking enabled or disbaled is decided before by using the EUID.
* **The Final Architecture (Separation of Concerns):** The logic was decoupled entirely. The script now utilizes two distinct loops with single responsibilities:
  1. A **Reporting Loop** that always runs, handling geolocation and output.
  2. A **Remediation Loop** that only executes if `EUID == 0`, quietly reading from the temp file to apply UFW blocks. No duplication, no redundant evaluations.

### 2. Universal Data Extraction (Regex Optimization)
The initial prototype utilized `awk` to parse standard Linux `auth.log` files:
`grep "authentication failure" "$1" | awk -F'rhost=' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10`

While effective for specific formats, log structures vary wildly between OS distributions (e.g., using `from` instead of `rhost=`). 

**The Universal Regex Alternative:**
To make this extraction pipeline universally deployable regardless of column spacing, the final pipeline utilizes Extended Regular Expressions to isolate the IPv4 addresses directly:
`grep -E "Failed password|authentication failure" "$LOG_FILE" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort | uniq -c | sort -nr | head -n 10`

---

## 🏢 Enterprise Architecture Limitations & Future Scope
While this script effectively demonstrates the core logic of log triage, deploying permanent, automated Bash scripts in a live production environment carries specific architectural risks:

1.  **Threshold-Based Detection vs. Absolute Ranking:** This script triages the absolute "Top 10" offenders for rapid incident response. However, automated enterprise blocking is governed by strict behavioral thresholds (e.g., ≥ 5 failed attempts within a 5-minute window) rather than arbitrary ranking. This prevents false positives, ensuring a legitimate user making a simple typo is not instantly banned.
2.  **Self-Denial of Service (Lack of Whitelisting):** This standalone script lacks subnet whitelisting capabilities. In a production environment, if an internal administrator repeatedly fails authentication, this tool would inadvertently lock the IT team out of their own infrastructure.
3.  **Firewall Rule Bloat:** Attackers rapidly cycle IP addresses. Permanently adding every offending IP to UFW will eventually degrade kernel networking performance. 

**Future Implementation:** 
The blocking logic in this script should be migrated to a dedicated Intrusion Prevention System like Fail2Ban, which natively handles threshold-based triggers, ephemeral bans, and subnet whitelisting. The log parsing and geolocation output should be forwarded to a SIEM to build centralized dashboards and enable correlation across multiple log sources — the kind of visibility that a standalone script cannot provide.

