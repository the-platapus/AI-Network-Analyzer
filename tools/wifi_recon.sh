#!/bin/bash

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <wireless-interface> [duration-seconds]"
  exit 1
fi

iface="$1"
duration="${2:-25}"

if ! iw dev "$iface" info >/dev/null 2>&1; then
  echo "Error: Interface $iface not found or is not wireless."
  exit 1
fi

monitor_iface="$iface"
if ! iw dev "$iface" info 2>/dev/null | grep -q 'type monitor'; then
  sudo airmon-ng check kill >/dev/null 2>&1 || true
  sudo airmon-ng start "$iface" >/dev/null 2>&1 || true
  monitor_iface="${iface}mon"
fi

tmpdir=$(mktemp -d)
output_csv="$tmpdir/recon-01.csv"

sudo timeout "$duration" airodump-ng --write-interval 5 --output-format csv -w "$tmpdir/recon" "$monitor_iface" >/dev/null 2>&1 || true

if [ ! -f "$output_csv" ]; then
  echo "Error: airodump-ng did not produce output."
  if [ "$monitor_iface" != "$iface" ]; then
    sudo airmon-ng stop "$monitor_iface" >/dev/null 2>&1 || true
  fi
  exit 1
fi

cat <<EOF
Wi-Fi Reconnaissance Results
Interface: $monitor_iface
Capture duration: ${duration}s
Output CSV: $output_csv

Nearby APs:
EOF

awk -F',' 'NR > 2 && $1 ~ /:/ {printf "BSSID: %s | Channel: %s | Privacy: %s | Auth: %s | ESSID: %s\n", $1, $4, $6, $8, $14}' "$output_csv" | head -n 20

if [ "$monitor_iface" != "$iface" ]; then
  sudo airmon-ng stop "$monitor_iface" >/dev/null 2>&1 || true
fi

echo ""
echo "Saved capture files to: $tmpdir"
echo "Review the CSV file for full AP and station details."
