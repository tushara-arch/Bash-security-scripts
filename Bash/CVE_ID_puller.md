# CVE Info Puller

## Overview
A simple Bash script that queries the National Vulnerability Database (NVD) API v2 to retrieve basic information about a specific vulnerability directly from the command line. 

Instead of navigating the NVD website manually, this tool uses `curl` to fetch the data and `jq` to parse the JSON response, outputting only the CVSS score, severity rating, and description.

## Features
* **REST API Interaction:** Uses `curl` to execute HTTP GET requests against the NVD API, utilizing silent flags (`-s`) to keep terminal output clean.
* **JSON Parsing:** Employs `jq` filters, arrays, and object traversal to extract specific data points from the NVD's nested JSON payload.
* **Fallback Logic:** Handles inconsistencies in historical vulnerability data by utilizing `jq` fallback operators (`//`) to pivot between available CVSS metrics, seamlessly cascading from CVSS v4.0 down to v2.
* **In-Memory Processing:** Captures the API response payload in a Bash variable, allowing multiple `jq` parsing passes without re-querying the API and hitting rate limits.

## Prerequisites
This script relies on standard Unix utilities. Ensure they are installed on your system before running.
* `curl`
* `jq`

## Usage

**1. Make the script executable:**
```bash
chmod +x cve-puller.sh
```

**2. Run the tool against a specific CVE:**
Pass a CVE identifier as the single argument.
```bash
./cve-puller.sh CVE-2024-3094
```

**Example Output:**
<img width="1528" height="319" alt="image" src="https://github.com/user-attachments/assets/aff4a156-b25f-41ea-9049-055ea00c5121" />


## Limitations
* **Weak Input Validation:** Lacks regex verification to ensure the input matches the standard CVE-YYYY-NNNNN format before executing the API call.
* **Incomplete Error Handling:** Ignores HTTP response codes, failing to distinguish between a missing CVE (404), a rate limit block (403), or a server outage (503).
* **Schema Dependency:** Depends on NVD's current JSON schema; a structural change on their end would break the `jq` filters until updated.

## Future Improvements
* **API Key Integration:** Add support for NVD API keys to bypass the strict public rate limit (currently capped at 5 requests / 30 seconds).
* **Bulk Processing:** Implement a loop to ingest a text file of CVEs and query them sequentially with appropriate throttling.

