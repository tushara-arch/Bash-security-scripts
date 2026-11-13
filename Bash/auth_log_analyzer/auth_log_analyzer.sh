#!/usr/bin/env bash

set -euo pipefail

# Validate input
if [[ $# -ne 1 ]]; then
    echo "[-] Error: Incorrect number of arguments."
    echo "Usage: $0 <Auth_Log_file_path>"
    echo "Example: $0 /var/log/auth.log"
    exit 1
fi

log_file="$1"

if [[ ! -f "$log_file" ]]; then
    echo "[-] Error: Log file does not exist at the specified path."
    exit 1
fi

if [[ ! -r "$log_file" ]]; then
    echo "[-] Error: File is not readable. Check file permissions."
    exit 1
fi

if ! command -v geoiplookup &>/dev/null; then
    echo "[-] Error: 'geoiplookup' command not found."
    echo "[*] Install it using: sudo apt install geoip-bin"
    exit 1
fi

# Extract and count the top 10 source IP addresses
(
    grep "authentication failure" "$log_file" |
    awk -F'rhost=' '{print $2}' |
    awk '{print $1}' |
    sort |
    uniq -c |
    sort -nr |
    head -n 10
) > Attacker_origin.txt

# Generate report with GeoIP information
printf '\n%-10s  %-32s  %s\n' "Attempts" "Source IP/Host" "Location"
printf '%-10s  %-32s  %s\n' "--------" "----------" "--------"

while read -r count ip; do
    country=$(geoiplookup "$ip" 2>/dev/null | awk -F': ' '!/not found|can\x27t resolve/ {print $2}')

    if [[ -z "$country" ]]; then
        country="Unknown"
    fi
    printf '%-10s  %-32s  %s\n' "$count" "$ip" "$country"
done < Attacker_origin.txt

# Apply UFW deny rules when running as root
BLOCKED=0

if [[ "$EUID" -eq 0 ]]; then
    echo ""

    if ! command -v ufw &>/dev/null; then
        echo "[-] Error: 'ufw' command not found."
        echo "[*] Install UFW to enable firewall remediation."
        exit 1
    fi

    while read -r ip; do
        if ufw deny from "$ip" &>/dev/null; then
            (( ++BLOCKED ))
        fi
    done < <(awk '{print $2}' Attacker_origin.txt)

    echo "[+] Added $BLOCKED UFW deny rule(s)."
else
    echo ""
    echo "[!] Remediation skipped: Root privileges required."
    echo "[*] Re-run with sudo to add UFW deny rules."
fi
