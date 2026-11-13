#!/usr/bin/env bash

#Strict error handling
set -euo pipefail

# 1. Input Validation
# Check if the user provided exactly one argument (the CVE ID)
if [ $# -ne 1 ]; then
    echo "Usage: $0 <CVE-ID>"
    echo "Example: $0 CVE-2021-44228"
    exit 1
fi


if ! command -v jq &>/dev/null
then
    echo "[!] Command not found. Install with: sudo apt install jq for Debain/Ubuntu"
    echo "You can download using whatever package manager your distribution support"
    exit 1
fi


# Store the provided CVE ID in a variable
CVE_ID=$1

if [[ ! "$CVE_ID" =~ ^CVE-[0-9]{4}-[0-9]{4,}$ ]]; then
    echo "[!] Invalid CVE ID format. Example: CVE-2021-44228"
    exit 1
fi

# Define the NVD API v2 endpoint URL
URL="https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=${CVE_ID}"


echo "Querying NVD API for ${CVE_ID}..."

# 2. Fetching the Data
# Use curl to send a GET request.
# -s suppresses the progress bar so we only capture the raw JSON response.
RESPONSE=$(curl -s -X GET "$URL")


# 3. Error Handling
# Check if the API returned any results using jq
RESULTS_COUNT=$(echo "$RESPONSE" | jq -r '.totalResults')

if [ "$RESULTS_COUNT" == "0" ] || [ -z "$RESULTS_COUNT" ]; then
    echo "Error: CVE not found, invalid format, or API rate limit exceeded."
    exit 1
fi

# 4. Parsing the JSON with jq
# Extract the English description.
DESCRIPTION=$(echo "$RESPONSE" | jq -r '.vulnerabilities[0].cve.descriptions[] | select(.lang=="en") | .value')

# Extract the Base Score.
# Fallback chain for CVSS Base Score (v4.0 -> v3.1 -> v3.0 -> v2)
SCORE=$(echo "$RESPONSE" | jq -r '
  .vulnerabilities[0].cve.metrics |
  .cvssMetricV40[0].cvssData.baseScore //
  .cvssMetricV31[0].cvssData.baseScore //
  .cvssMetricV30[0].cvssData.baseScore //
  .cvssMetricV2[0].cvssData.baseScore //
  "No score available"
')

# Extract the Severity rating.
SEVERITY=$(echo "$RESPONSE" | jq -r '
  .vulnerabilities[0].cve.metrics |
  .cvssMetricV40[0].cvssData.baseSeverity //
  .cvssMetricV31[0].cvssData.baseSeverity //
  .cvssMetricV30[0].cvssData.baseSeverity //
  .cvssMetricV2[0].baseSeverity //
  "Unknown"
')

# 5. Output the results
echo ""
echo "========================================"
echo " CVE ID:      $CVE_ID"
echo " CVSS Score:  $SCORE ($SEVERITY)"
echo "========================================"
echo " Description:"
echo " $DESCRIPTION"
echo "========================================"
