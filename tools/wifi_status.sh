#!/bin/bash

set -e

print_usage() {
  echo "Usage: $0 [wireless-interface]"
  exit 1
}

detect_interface() {
  local iface
  iface=$(iw dev 2>/dev/null | awk '$1 == "Interface" {print $2; exit}')
  if [ -n "$iface" ] && iwgetid "$iface" >/dev/null 2>&1; then
    echo "$iface"
    return
  fi

  if command -v nmcli >/dev/null 2>&1; then
    iface=$(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '$2 == "wifi" && $3 == "connected" {print $1; exit}')
    if [ -n "$iface" ]; then
      echo "$iface"
      return
    fi
  fi

  if [ -z "$iface" ]; then
    iface=$(iw dev 2>/dev/null | awk '$1 == "Interface" {print $2; exit}')
  fi
  echo "$iface"
}

iface="$1"
if [ -z "$iface" ]; then
  iface=$(detect_interface)
fi

if [ -z "$iface" ]; then
  echo "Error: No wireless interface found."
  exit 1
fi

ssid=$(iwgetid "$iface" -r 2>/dev/null || true)
bssid=$(iwgetid "$iface" -a 2>/dev/null | awk -F'Access Point: ' '{print $2}' | head -n1 | xargs || true)
channel=$(iw dev "$iface" info 2>/dev/null | awk '/channel/ {print $2; exit}')
if [ -z "$channel" ]; then
  channel=$(iwlist "$iface" channel 2>/dev/null | awk -F'Current Channel:' '/Current Frequency/ {print $2; exit}' | xargs)
fi
signal=$(iwconfig "$iface" 2>/dev/null | grep -i --color=never 'signal level' | head -n1 | sed -E 's/.*Signal level=([^ ]+).*/\1/')
mode=$(iw dev "$iface" info 2>/dev/null | awk '/type/ {print $2; exit}')
ip_addr=$(ip -4 addr show dev "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -n1)

security="unknown"
if [ -n "$ssid" ] && command -v nmcli >/dev/null 2>&1; then
  security=$(nmcli -t -f SSID,SECURITY dev wifi | grep -F "$ssid" | head -n1 | cut -d: -f2 || true)
fi

if [ -z "$security" ] && [ -n "$ssid" ]; then
  security=$(sudo iwlist "$iface" scan 2>/dev/null | awk -v ssid="$ssid" '
    /Cell / {found=0}
    /ESSID:/ {if ($0 ~ ssid) found=1}
    found && /IE: WPA2/ {print "WPA2"; exit}
    found && /IE: WPA/ {print "WPA"; exit}
    found && /Encryption key:on/ {enc=1}
    END { if (enc) print "WEP" }
  ' | head -n1 || true)
fi

[ -z "$ssid" ] && ssid="<not connected>"
[ -z "$bssid" ] && bssid="<unknown>"
[ -z "$channel" ] && channel="<unknown>"
[ -z "$signal" ] && signal="<unknown>"
[ -z "$mode" ] && mode="<unknown>"
[ -z "$ip_addr" ] && ip_addr="<none>"
[ -z "$security" ] && security="<unknown>"

cat <<EOF
Interface: $iface
Mode: $mode
ESSID: $ssid
BSSID: $bssid
Channel: $channel
Signal: $signal
Security: $security
IP Address: $ip_addr
EOF
