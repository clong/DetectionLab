#! /usr/bin/env bash

# This script is meant to verify that DetectionLab was built successfully.
# Only MacOS and Linux are supported. Use post_build_checks.ps1 for Windows.
# If you encounter issues, feel free to open an issue at
# https://github.com/clong/DetectionLab/issues

ERROR=$(tput setaf 1; echo -n "  [!]"; tput sgr0)
GOODTOGO=$(tput setaf 2; echo -n "  [✓]"; tput sgr0)

# A series of checks to ensure important services are responsive after the build completes.
post_build_checks() {
  SPLUNK_CHECK=0
  FLEET_CHECK=0
  ATA_CHECK=0
  VELOCIRAPTOR_CHECK=0
  GUACAMOLE_CHECK=0
  # If the curl operation fails, we'll just leave the variable equal to 0
  # This is needed to prevent the script from exiting if the curl operation fails
  SPLUNK_CHECK=$(curl -ks -m 2 https://192.168.38.105:8000/en-US/account/login?return_to=%2Fen-US%2F | grep -c 'This browser is not supported by Splunk')
  FLEET_CHECK=$(curl -ks -m 2 https://192.168.38.105:8412 | grep -c 'Kolide Fleet')
  ATA_CHECK=$(curl --fail --write-out "%{http_code}" -ks https://192.168.38.103 -m 2)
  VELOCIRAPTOR_CHECK=$(curl -ks -m 2 https://192.168.38.105:9999 | grep -c 'app.html')
  GUACAMOLE_CHECK=$(curl -ks -m 2 'http://192.168.38.105:8080/guacamole/#/' | grep -c 'Apache Software')
  [[ $ATA_CHECK == 401 ]] && ATA_CHECK=1
  
  echo "[*] Verifying that Splunk is running and reachable..."
  if [ "$SPLUNK_CHECK" -lt 1 ]; then
    (echo >&2 "${ERROR} Warning: Splunk was unreachable and may not have installed correctly.")
  else
    (echo >&2 "${GOODTOGO} Splunk is running and reachable.")
  fi

  echo ""
  echo "[*] Verifying that Fleet is running and reachable..."
  if [ "$FLEET_CHECK" -lt 1 ]; then
    (echo >&2 "${ERROR} Warning: Fleet was unreachable and may not have installed correctly.")
  else
    (echo >&2 "${GOODTOGO} Fleet is running and reachable.")
  fi

  echo ""
  echo "[*] Verifying that Microsoft ATA is running and reachable..."
  if [ "$ATA_CHECK" -lt 1 ]; then
    (echo >&2 "${ERROR} Warning: Microsoft ATA was unreachable and may not have installed correctly.")
  else
    (echo >&2 "${GOODTOGO} Microsoft ATA is running and reachable.")
  fi
  
  echo ""
  echo "[*] Verifying that the Velociraptor service is running and reachable..."
  if [ "$VELOCIRAPTOR_CHECK" -lt 1 ]; then
    (echo >&2 "${ERROR} Warning: Velociraptor was unreachable and may not have installed correctly.")
  else
    (echo >&2 "${GOODTOGO} Velociraptor is running and reachable.")
  fi
  
  echo ""
  echo "[*] Verifying that Guacamole is running and reachable..."
  if [ "$GUACAMOLE_CHECK" -lt 1 ]; then
    (echo >&2 "${ERROR} Warning: Guacamole was unreachable and may not have installed correctly.")
  else
    (echo >&2 "${GOODTOGO} Guacamole is running and reachable.")
  fi
}

post_build_checks
exit 0
