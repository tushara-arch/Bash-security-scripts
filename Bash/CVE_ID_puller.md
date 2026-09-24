# Phase 3: The API Interactor (Handling JSON & Web)

## Overview
This script queries the National Vulnerability Database (NVD) API v2 to retrieve critical vulnerability intelligence (CVSS metrics, severity, and descriptions) directly from the command line. 

Designed for rapid triage during vulnerability management or SOC alert investigations, this tool utilizes `curl` to interface with the web API and leverages `jq` to parse the massive, deeply nested JSON response. It strips away thousands of lines of raw configuration data (CPEs) to deliver only the most actionable metrics in a clean, terminal-readable format.

## Features
* **REST API Interaction:** Utilizes `curl` to execute HTTP GET requests against the NVD API endpoint, employing silent execution flags (`-s`) to prevent download meters from corrupting data streams.
* **Advanced JSON Parsing:** Employs `jq` filters, arrays, and object traversal to extract specific nodes from a complex, multi-megabyte JSON payload.
* **Data Normalization (Fallback Logic):** Dynamically handles inconsistencies in historical vulnerability data by utilizing `jq` fallback operators (`//`) to seamlessly pivot between CVSS v3.1 and CVSS v2 metrics.
* **Defensive Bash Programming:** Enforces strict input validation to ensure a CVE ID is provided before execution and utilizes parameter expansion (`${CVE_ID}`) to prevent string-boundary variable corruption.
* **In-Memory Processing:** Captures the entire API response payload within a Bash variable via command substitution (`$()`), allowing multiple `jq` parsing passes without triggering rate limits by re-querying the API.

## Skills Demonstrated
- Bash Scripting & Command Substitution
- REST API Integration (`curl`)
- Advanced JSON Data Wrangling (`jq`)
- Threat Intelligence Parsing (NVD, CVSS, CVE)
- Data Normalization & Conditional Logic
- Input Validation & Parameter Expansion

## Usage

**1. Make the script executable:**

```bash
chmod +x cve-puller.sh
```

**2. Run the tool against a specific CVE:**
Pass a valid CVE identifier as the single argument.

```bash
./cve-puller.sh CVE-2021-44228
```

**Example Output:**
```text
Querying NVD API for CVE-2021-44228...

========================================
 CVE ID:      CVE-2021-44228
 CVSS Score:  10.0 (CRITICAL)
========================================
 Description:
 Apache Log4j2 JNDI features used in configuration, log messages, and parameters do not protect against attacker controlled LDAP and other JNDI related endpoints...
========================================
```

---

## Engineering & Refactoring Journey
Building a reliable API interactor required addressing several edge cases inherent to parsing massive, highly variable datasets from public web endpoints. 

### 1. Handling Data Inconsistency (The Fallback Pattern)
Vulnerability schemas evolve. Older vulnerabilities (e.g., from 2012) only carry CVSS v2 scores, while modern vulnerabilities use CVSS v3.0 or v3.1. 

* **The Initial Mistake:** A strict `jq` query targeting `.cvssMetricV31[0].cvssData.baseScore` will return `null` for older CVEs, breaking the script's output.
* **The Solution:** Implementing the `jq` alternative operator (`//`). This acts as a logical OR, allowing the script to attempt the v3.1 path, and if it fails, gracefully fallback to the v2 path without throwing errors.

```bash
SCORE=$(echo "$RESPONSE" | jq -r '.vulnerabilities[0].cve.metrics.cvssMetricV31[0].cvssData.baseScore // .vulnerabilities[0].cve.metrics.cvssMetricV2[0].cvssData.baseScore // "No score available"')
```

### 2. Preventing Variable Boundary Corruption
When appending strings to variables, Bash can easily misinterpret where the variable name ends and the static string begins.

* **The Vulnerability:** Using `$CVE_ID_report.txt` results in Bash searching for a non-existent variable named `CVE_ID_report`, resulting in empty output.
* **The Architecture Standard:** Implementing **Parameter Expansion**. By wrapping the variable in curly braces (`${CVE_ID}`), the script creates a hard boundary, ensuring Bash evaluates the variable correctly before interacting with adjacent characters. This was standardized across the script (e.g., `URL="https://...cveId=${CVE_ID}"`).

### 3. Taming the JSON Payload
The raw JSON returned by the NVD API for a single CVE is massive, largely due to the exhaustive list of Common Platform Enumeration (CPE) configurations (every affected vendor, product, and version). 

To prevent terminal overflow, the data is piped through a highly specific `jq` filter to isolate only the English description.

```bash
# Iterates through the descriptions array and selects only the object matching lang=="en"
DESCRIPTION=$(echo "$RESPONSE" | jq -r '.vulnerabilities[0].cve.descriptions[] | select(.lang=="en") | .value')
```

---

## Enterprise Architecture Limitations & Future Scope
While this script provides immediate value for rapid manual triage, deploying it as part of an automated enterprise pipeline highlights several architectural limitations:

1. **Strict Rate Limiting (Lack of Authentication):** The script currently queries the public, unauthenticated NVD endpoint. NIST strictly limits these requests. In a production environment or tight automation loop, this script will quickly receive HTTP 403 Forbidden errors. 
2. **Single-Execution Bottleneck:** The tool processes one CVE at a time. In a real-world incident response scenario, an analyst may need to triage a Nessus export containing 50+ CVEs. The script lacks a bulk-processing loop to ingest a `.txt` file of CVEs and query them sequentially.
3. **Machine-Readable Output:** Standard output formatted with borders (`======`) is ideal for human eyes but incompatible with SIEM ingestion or SOAR playbooks. 

## Future Improvements
To elevate this tool to an enterprise-grade utility, the following improvements would be required:
* **API Key Integration:** Implement an optional `-k` flag to pass a NIST API key via a `curl` header (`-H "apiKey: $API_KEY"`), dramatically increasing the allowed request threshold.
* **Bulk Processing & Throttling:** Add logic to detect if a file is passed as an argument, loop through the file, and inject a `sleep 6` command between queries to respect NIST's API documentation guidelines.
* **Pipeline Integrations (CSV/JSON Export):** Implement an `--export-csv` flag that skips the visual formatting and writes the parsed data directly to a structured CSV format, allowing the output to be seamlessly piped into other security tools or ingested by Splunk/Elastic.
