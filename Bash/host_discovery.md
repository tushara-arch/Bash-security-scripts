# Network Host Discovery Wrapper (Bash)

##  Overview
This script is a Bash wrapper for `nmap`, designed to perform rapid, reliable ping sweeps across a specified CIDR range. It is built with a heavy emphasis on strict input validation and clean, terminal-friendly output.

Building this script was an exercise in understanding edge cases and the importance of sanitizing inputs in security tooling — specifically, what happens when bad data reaches a scanning engine silently.

##  Features
* **Strict Input Validation:** Mathematically verifies IPv4 and CIDR notation before execution to prevent tool crashes or unintended network behavior.
* **Privilege Awareness:** Automatically detects the user's execution privileges. If run as `root`, it leverages Layer 2 ARP requests (`-PR`) to bypass local host firewalls.
* **Smart Output Formatting:** Utilizes `printf` for clean, tabular data presentation and ANSI color codes for logging (which automatically disable if output is piped to a file).
* **Fail-Fast Design:** Verifies all dependencies (like `nmap`) before attempting to run.

##  Usage

Make the script executable:
```bash
chmod +x host_discovery.sh
```

Run the script against a target subnet:

### Standard execution (TCP fallback)
```bash
./host_discovery.sh 192.168.1.0/24
```

### Recommended execution (Utilizes ARP for local subnets)
```bash
sudo ./host_discovery.sh 192.168.1.0/24
```

---

##  The Development Journey: Lessons Learned
### 1. The Danger of Silent Failures
* **The Mistake:** Initially, I relied on a simple structural Regular Expression to validate the IP, assuming `nmap` would handle mathematically impossible IPs (like `999.999.999.999/24`). To keep the terminal output clean, I piped `nmap` errors to a black hole using `2>/dev/null`.
* **The Result:** The script created a dangerous "false negative." If a user typed a bad IP, `nmap` would fail silently, and the script would output `[!] No live hosts found`, misleading the operator into thinking the subnet was empty rather than realizing the scan never ran.
* **The Fix:** I implemented strict mathematical validation in native Bash *before* the `nmap` command. The script now parses the IP address into individual octets and verifies they do not exceed `255`, ensuring bad data never reaches the scanning engine.

### 2. Privilege-Based Tactics
* **The Mistake:** My early versions executed standard ping sweeps (`-sn`) regardless of the user. 
* **The Result:** Modern operating systems (like Windows Defender) routinely drop standard ICMP or TCP requests, leading to inaccurate asset discovery on local networks.
* **The Fix:** I added an `$EUID` check to determine if the operator is running as root. If they are, the script dynamically injects the `-PR` and `-PE` flags to utilize ARP discovery. ARP-based discovery is generally more reliable on local subnets because hosts must typically respond to ARP requests in order to communicate on the network, resulting in a significantly more accurate asset inventory.

### 3. Separation of Logic and Presentation
* **The Mistake:** Dumping raw variables to the screen using `echo`.
* **The Fix:** Transitioned to using `printf` with strict width parameters (e.g., `%-5s`) to ensure columns perfectly align regardless of the length of the IP address, alongside a TTY check to ensure logging colors don't corrupt saved text files.

## What Comes Next
The list of live hosts produced by this script is the starting point for further enumeration. Because the output is cleanly formatted, it can be piped directly into subsequent tooling — port scanning, service fingerprinting, or fed into the `asset change monitor.sh` to establish a baseline of what is running on each discovered host. 
