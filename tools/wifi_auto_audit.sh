#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config.sh"

if [ -z "$REPORT_DIR" ]; then
  REPORT_DIR="reports"
fi

# ---------------------------------------------------------------------------
# Global state — updated by capture_audit_data so the EXIT trap can restore
# the system regardless of which exit path is taken (normal, error, Ctrl-C…)
# ---------------------------------------------------------------------------
MONITOR_IFACE_ACTIVE=""   # set to the monitor iface name when active
NM_WAS_STOPPED=false       # true when we stopped NetworkManager

cleanup() {
  # Stop monitor mode if it is still running
  if [ -n "$MONITOR_IFACE_ACTIVE" ]; then
    sudo airmon-ng stop "$MONITOR_IFACE_ACTIVE" >/dev/null 2>&1 || true
    MONITOR_IFACE_ACTIVE=""
  fi
  # Restart NetworkManager if we were the ones who stopped it
  if [ "$NM_WAS_STOPPED" = true ]; then
    sudo systemctl start NetworkManager >/dev/null 2>&1 || true
    NM_WAS_STOPPED=false
    sleep 2   # give NM a moment to reconnect before the terminal returns
  fi
}

# Register cleanup on every possible exit path
trap cleanup EXIT INT TERM ERR

is_tool_installed() {
  command -v "$1" >/dev/null 2>&1
}

detect_connected_wireless_interface() {
  local iface
  if is_tool_installed nmcli; then
    iface=$(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '$2 == "wifi" && $3 == "connected" {print $1; exit}')
    if [ -n "$iface" ]; then
      echo "$iface"
      return
    fi
  fi

  iface=$(iw dev 2>/dev/null | awk '$1 == "Interface" {print $2; exit}')
  if [ -n "$iface" ] && iwgetid "$iface" >/dev/null 2>&1; then
    echo "$iface"
    return
  fi

  echo ""
}

detect_any_wireless_interface() {
  local iface
  iface=$(iw dev 2>/dev/null | awk '$1 == "Interface" {print $2; exit}')
  echo "$iface"
}

build_network_menu() {
  local iface="$1"
  local IFS=$'\n'
  local line
  local count=1
  menu=()
  net_entries=()

  if is_tool_installed nmcli; then
    while read -r line; do
      local ssid bssid channel security
      IFS=':' read -r ssid bssid channel security <<< "$line"
      [ -z "$ssid" ] && ssid="<hidden>"
      [ -z "$security" ] && security="OPEN"
      menu+=("$count" "SSID: $ssid | BSSID: $bssid | Ch: $channel | Sec: $security")
      net_entries[$count]="$ssid|$bssid|$channel|$security"
      count=$((count + 1))
      if [ $count -gt 20 ]; then
        break
      fi
    done < <(nmcli -t -f SSID,BSSID,CHAN,SECURITY device wifi list)
  fi

  if [ ${#menu[@]} -eq 0 ]; then
    local scan_output
    scan_output=$(sudo iwlist "$iface" scan 2>/dev/null || true)
    if [ -z "$scan_output" ]; then
      return 1
    fi

    local bssid="" essid="" channel="" enc=""
    while IFS= read -r line; do
      if [[ "$line" =~ Cell ]]; then
        if [ -n "$bssid" ]; then
          [ -z "$essid" ] && essid="<hidden>"
          [ -z "$enc" ] && enc="OPEN"
          menu+=("$count" "SSID: $essid | BSSID: $bssid | Ch: $channel | Sec: $enc")
          net_entries[$count]="$essid|$bssid|$channel|$enc"
          count=$((count + 1))
          bssid="" essid="" channel="" enc=""
        fi
        bssid=$(echo "$line" | awk -F'Cell ' '{print $2}' | awk '{print $2}')
      elif [[ "$line" =~ ESSID: ]]; then
        essid=$(echo "$line" | sed -E 's/.*ESSID:"(.*)"/\1/')
      elif [[ "$line" =~ Channel: ]]; then
        channel=$(echo "$line" | sed -E 's/.*Channel:([0-9]+).*/\1/')
      elif [[ "$line" == *"Encryption key:on"* ]]; then
        enc="WEP/Protected"
      elif [[ "$line" == *"IE: WPA2"* ]]; then
        enc="WPA2"
      elif [[ "$line" == *"IE: WPA"* ]]; then
        enc="WPA"
      fi
    done <<< "$scan_output"

    if [ -n "$bssid" ]; then
      [ -z "$essid" ] && essid="<hidden>"
      [ -z "$enc" ] && enc="OPEN"
      menu+=("$count" "SSID: $essid | BSSID: $bssid | Ch: $channel | Sec: $enc")
      net_entries[$count]="$essid|$bssid|$channel|$enc"
    fi
  fi

  if [ ${#menu[@]} -eq 0 ]; then
    return 1
  fi

  return 0
}

choose_network_target() {
  local iface="$1"
  local current_iface="$2"
  local choice
  local menu=()

  if [ -n "$current_iface" ]; then
    menu+=("current" "Use currently connected Wi-Fi")
  fi
  menu+=("other" "Choose another available Wi-Fi network")

  choice=$(dialog --clear --title "Wi-Fi Audit Target" --menu "Select the Wi-Fi network to audit:" 12 70 2 "${menu[@]}" 3>&1 1>&2 2>&3)
  local rc=$?
  if [ $rc -ne 0 ]; then
    exit 1
  fi
  echo "$choice"
}

parse_network_entry() {
  local entry="$1"
  IFS='|' read -r ssid bssid channel security <<< "$entry"
  echo "$ssid|$bssid|$channel|$security"
}

collect_wifi_status() {
  local iface="$1"
  bash "$BASE_DIR/tools/wifi_status.sh" "$iface"
}

capture_audit_data() {
  local iface="$1"
  local bssid="$2"
  local channel="$3"
  local tmpdir="$4"

  local monitor_iface="$iface"

  if ! iw dev "$iface" info 2>/dev/null | grep -q 'type monitor'; then
    # Gracefully stop NetworkManager instead of using 'airmon-ng check kill'
    # so we can restart it cleanly afterwards via the EXIT trap.
    sudo systemctl stop NetworkManager >/dev/null 2>&1 || true
    NM_WAS_STOPPED=true
    sudo airmon-ng start "$iface" >/dev/null 2>&1 || true
    monitor_iface="${iface}mon"
    # Record the active monitor interface so the EXIT trap can stop it
    MONITOR_IFACE_ACTIVE="$monitor_iface"
  fi

  local csv_file="$tmpdir/audit-01.csv"
  local cap_file="$tmpdir/audit-01.cap"

  sudo timeout 30 airodump-ng --bssid "$bssid" -c "$channel" --write "$tmpdir/audit" "$monitor_iface" >/dev/null 2>&1 &
  local dump_pid=$!
  sleep 8
  sudo aireplay-ng --deauth 5 -a "$bssid" "$monitor_iface" >/dev/null 2>&1 || true
  wait "$dump_pid" || true

  if [ -f "$cap_file" ]; then
    echo "Capture file: $cap_file"
  else
    echo "Capture file not created."
  fi

  if [ -f "$csv_file" ]; then
    echo "Recon CSV: $csv_file"
  else
    echo "Recon CSV not created."
  fi

  # Cleanup is handled by the EXIT trap — no inline teardown needed here.
}

extract_wifi_info() {
  local iface="$1"
  local bssid="$2"
  local channel="$3"
  local tmpdir="$4"
  local csv_file="$tmpdir/audit-01.csv"

  echo "--- Scan Summary ---"
  if [ -f "$csv_file" ]; then
    awk -F',' 'NR > 2 && $1 ~ /:/ {printf "BSSID: %s | Channel: %s | Privacy: %s | Auth: %s | ESSID: %s\n", $1, $4, $6, $8, $14}' "$csv_file" | head -n 20
  else
    echo "No CSV output from airodump-ng."
  fi

  local cap_file="$tmpdir/audit-01.cap"
  if [ -f "$cap_file" ]; then
    echo "";
    echo "--- Handshake Check ---"
    sudo aircrack-ng "$cap_file" 2>&1 | grep -E 'WPA handshake|No packet' || true
  else
    echo "";
    echo "No capture file available for handshake inspection."
  fi
}

if ! is_tool_installed dialog; then
  echo "Error: dialog is required for interactive selection."
  exit 1
fi

mkdir -p "$BASE_DIR/$REPORT_DIR"

while true; do
  connected_iface=$(detect_connected_wireless_interface)
  scan_iface=$(detect_any_wireless_interface)
  selection=$(choose_network_target "$connected_iface" "$connected_iface")

  target_ssid=""
  target_bssid=""
  target_channel=""
  target_security=""

  if [ "$selection" == "current" ]; then
    # re-detect connected iface in case state changed while menu displayed
    connected_iface=$(detect_connected_wireless_interface)
    if [ -z "$connected_iface" ]; then
      dialog --title "Error" --msgbox "No connected Wi-Fi network detected." 10 60
      continue
    fi

  # Collect status but don't let failures abort the whole script
  target_details=$(collect_wifi_status "$connected_iface" 2>/dev/null || true)
  target_ssid=$(echo "$target_details" | awk -F': ' '/^ESSID:/ {print $2}')
  target_bssid=$(echo "$target_details" | awk -F': ' '/^BSSID:/ {print $2}')
  target_channel=$(echo "$target_details" | awk -F': ' '/^Channel:/ {print $2}')
  target_security=$(echo "$target_details" | awk -F': ' '/^Security:/ {print $2}')

  # Fallback to nmcli for connected network info if available
  if [ -z "$target_ssid" ] && command -v nmcli >/dev/null 2>&1; then
    nm_entry=$(nmcli -t -f IN-USE,SSID,BSSID,CHAN,SECURITY dev wifi list | awk -F: '$1 == "*" {print $2"|"$3"|"$4"|"$5; exit}')
    if [ -n "$nm_entry" ]; then
      IFS='|' read -r target_ssid target_bssid target_channel target_security <<< "$nm_entry"
    fi
  fi
else
  if ! build_network_menu "$scan_iface"; then
    dialog --title "Error" --msgbox "Could not find available Wi-Fi networks. Ensure your wireless interface can scan." 10 60
    continue
  fi
  other_choice=$(dialog --clear --title "Available Networks" --menu "Select a Wi-Fi target to audit:" 20 70 10 "${menu[@]}" 3>&1 1>&2 2>&3)
  if [ $? -ne 0 ]; then
    exit 0  # If user cancels network selection, exit the script
  fi
  
  entry="${net_entries[$other_choice]}"
  if [ -z "$entry" ]; then
    dialog --title "Error" --msgbox "Failed to read selected network details." 10 60
    continue
  fi
  IFS='|' read -r target_ssid target_bssid target_channel target_security <<< "$entry"
fi

if [ -z "$target_bssid" ] || [ -z "$target_channel" ]; then
  dialog --title "Error" --msgbox "Could not determine target BSSID or channel for the selected network." 10 60
  continue
fi

report_file="$BASE_DIR/$REPORT_DIR/wifi_full_audit_$(date +%Y-%m-%d_%H-%M).txt"
tmp_out=$(mktemp)

echo "Wi-Fi Automated Security Audit" > "$tmp_out"
echo "Date: $(date)" >> "$tmp_out"
echo "Target SSID: $target_ssid" >> "$tmp_out"
echo "Target BSSID: $target_bssid" >> "$tmp_out"
echo "Target Channel: $target_channel" >> "$tmp_out"
echo "Security: $target_security" >> "$tmp_out"
echo "----------------------------------------" >> "$tmp_out"

echo "--- Local Interface Details ---" >> "$tmp_out"
if [ -n "$connected_iface" ]; then
  collect_wifi_status "$connected_iface" >> "$tmp_out" 2>&1
else
  echo "No connected wireless interface detected." >> "$tmp_out"
fi

echo "" >> "$tmp_out"
echo "--- Wi-Fi Scan and Capture ---" >> "$tmp_out"

tmpdir=$(mktemp -d)
capture_audit_data "$scan_iface" "$target_bssid" "$target_channel" "$tmpdir" >> "$tmp_out" 2>&1

echo "" >> "$tmp_out"
extract_wifi_info "$scan_iface" "$target_bssid" "$target_channel" "$tmpdir" >> "$tmp_out" 2>&1

echo "" >> "$tmp_out"
echo "--- Raw Scan Files ---" >> "$tmp_out"
echo "Capture folder: $tmpdir" >> "$tmp_out"
echo "Audit CSV: $tmpdir/audit-01.csv" >> "$tmp_out"
echo "Capture file: $tmpdir/audit-01.cap" >> "$tmp_out"

# Explicitly restore network so we have internet for the AI analysis
dialog --infobox "Restoring Wi-Fi and waiting for internet connection for AI analysis..." 5 60
cleanup
sleep 5 # Give NM time to reconnect to the known Wi-Fi network

echo "" >> "$tmp_out"
echo "--- AI Analysis ---" >> "$tmp_out"

WIFI_PROMPT="You are an expert Wi-Fi security auditor. Analyze the following Wi-Fi security audit data and provide: 1) a security score from 0 to 100, 2) critical vulnerabilities, 3) attack vectors and weak configuration details, 4) recommended remediation steps. Keep the output concise, use bullet points, and include the score clearly labeled."

# Attempt AI analysis
if bash "$BASE_DIR/ai/agent.sh" "$tmp_out" "$WIFI_PROMPT" > "${tmp_out}_ai" 2>&1; then
  AI_OUTPUT=$(cat "${tmp_out}_ai")
  echo "$AI_OUTPUT" >> "$tmp_out"
  cp "$tmp_out" "$report_file"
  dialog --title "Audit Complete" --msgbox "Automated Wi-Fi audit finished. Report saved to:\n$report_file" 12 70
else
  AI_OUTPUT=$(cat "${tmp_out}_ai")
  echo "AI Analysis Failed. Output:" >> "$tmp_out"
  echo "$AI_OUTPUT" >> "$tmp_out"
  echo "The raw report was queued for future AI analysis." >> "$tmp_out"
  
  cp "$tmp_out" "$report_file"
  
  # Save to pending directory for future batch processing/analysis
  PENDING_DIR="$BASE_DIR/$REPORT_DIR/pending_ai"
  mkdir -p "$PENDING_DIR"
  cp "$tmp_out" "$PENDING_DIR/$(basename "$report_file")"
  
  dialog --title "Audit Complete (AI Pending)" --msgbox "Audit finished, but AI analysis failed (e.g., missing API key or no internet).\n\nReport saved to:\n$report_file\n\nQueued in $REPORT_DIR/pending_ai for future analysis." 15 70
fi

done
