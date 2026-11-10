#!/usr/bin/env bash

# Strict error handling
set -euo pipefail

# Disable ANSI colors if stdout is piped or redirected
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
else
    GREEN=''; YELLOW=''; RED=''; RESET=''
fi

log_info()  { echo -e "${GREEN}[+]${RESET} $*"; }
log_warn()  { echo -e "${YELLOW}[!]${RESET} $*" >&2; }
log_error() { echo -e "${RED}[-]${RESET} $*" >&2; }

# Validate argument count
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <CIDR>"
    echo "e.g. $0 192.168.10.0/24"
    exit 1
fi

# Verify dependencies
if ! command -v nmap &>/dev/null; then
    log_error "nmap not found. Install with: sudo apt install nmap"
    exit 2
fi

CIDR="$1"

# Validate structural CIDR format
if [[ ! "$CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]{1,2})$ ]]; then
    log_error "Invalid CIDR format: $CIDR"
    exit 3
fi

# Separate IP and subnet prefix
IP="${CIDR%/*}"
MASK="${CIDR#*/}"

# Validate prefix length (force base-10 to prevent octal errors on leading zeros)
if (( 10#$MASK > 32 )); then
    log_error "Invalid subnet mask /$MASK. Must be between 0 and 32."
    exit 3
fi

# Validate individual IPv4 octets (0-255)
IFS="." read -r o1 o2 o3 o4 <<< "$IP"
if (( 10#$o1 > 255 || 10#$o2 > 255 || 10#$o3 > 255 || 10#$o4 > 255 )); then
    log_error "Invalid IP address: $IP (Octets cannot exceed 255)"
    exit 3
fi

# Check execution privileges for raw socket access
if [[ $EUID -ne 0 ]]; then
    log_warn "Running without root privileges; ARP discovery disabled (falling back to TCP probes). Run with sudo for accurate local subnet results."
fi

# Execute ping sweep and store live hosts in an array
mapfile -t Host_Alive < <(nmap -sn "$CIDR" -oG - | awk '/Up/{print $2}')

if [[ ${#Host_Alive[@]} -eq 0 ]]; then
    log_info "No live hosts found on $CIDR"
    exit 0
fi

printf "\n%-5s %s\n" "No." "IP Address"
printf "%-5s %s\n" "---" "----------"

i=1
for ip in "${Host_Alive[@]}"; do
    printf "%-5s %s\n" "$i" "$ip"
    ((++i))
done

echo ""
log_info "${#Host_Alive[@]} host(s) up on $CIDR"
