#!/bin/bash

# Main entry point for Wi-Fi Security Auditor

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Set directory variables
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_DIR

# Ensure terminal is cleared and colors reset on any exit (normal, crash, or Ctrl+C)
trap 'tput sgr0 2>/dev/null || echo -ne "\e[0m"; clear' EXIT INT TERM

# Check dependencies
MISSING_DEPS=""
for dep in dialog jq curl airmon-ng airodump-ng aircrack-ng iw timeout; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS="$MISSING_DEPS $dep"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "Warning: Missing dependencies:$MISSING_DEPS"
    read -p "Would you like to try installing them? (requires sudo) [y/N] " install_choice
    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y dialog jq curl aircrack-ng wireless-tools iw iproute2
        elif command -v yum &> /dev/null; then
            sudo yum install -y dialog jq curl aircrack-ng wireless-tools iw iproute
        else
            echo "Unsupported package manager. Please install missing dependencies manually."
            exit 1
        fi
    else
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
fi

# Source configuration
if [ -f "$BASE_DIR/config.sh" ]; then
    source "$BASE_DIR/config.sh"
else
    echo "Error: config.sh not found."
    exit 1
fi

# Ensure reports directories exist
mkdir -p "$BASE_DIR/$REPORT_DIR"
mkdir -p "$BASE_DIR/$REPORT_DIR/pending_ai"

view_reports() {
  local reports=()
  for f in "$BASE_DIR/$REPORT_DIR"/wifi_full_audit_*.txt; do
    [ -e "$f" ] || continue
    reports+=("$(basename "$f")" "")
  done

  if [ ${#reports[@]} -eq 0 ]; then
    dialog --title "View Reports" --msgbox "No reports found." 8 40
    return
  fi

  while true; do
    choice=$(dialog --clear --title "View Reports" --menu "Select a report to view:" 20 70 12 "${reports[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      break
    fi
    dialog --title "Report: $choice" --textbox "$BASE_DIR/$REPORT_DIR/$choice" 22 80
  done
}

retry_pending_ai() {
  local pending=()
  for f in "$BASE_DIR/$REPORT_DIR/pending_ai"/wifi_full_audit_*.txt; do
    [ -e "$f" ] || continue
    pending+=("$(basename "$f")" "")
  done

  if [ ${#pending[@]} -eq 0 ]; then
    dialog --title "Pending AI Analysis" --msgbox "No pending reports found." 8 40
    return
  fi

  while true; do
    choice=$(dialog --clear --title "Pending AI Analysis" --menu "Select a report to analyze:" 20 70 12 "${pending[@]}" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      break
    fi
    
    local pending_file="$BASE_DIR/$REPORT_DIR/pending_ai/$choice"
    local original_report="$BASE_DIR/$REPORT_DIR/$choice"
    
    dialog --infobox "Sending $choice to AI for analysis. Please wait..." 5 60
    
    local tmp_ai
    tmp_ai=$(mktemp)
    
    WIFI_PROMPT="You are an expert Wi-Fi security auditor. Analyze the following Wi-Fi security audit data and provide: 1) a security score from 0 to 100, 2) critical vulnerabilities, 3) attack vectors and weak configuration details, 4) recommended remediation steps. Keep the output concise, use bullet points, and include the score clearly labeled."

    if bash "$BASE_DIR/ai/agent.sh" "$pending_file" "$WIFI_PROMPT" > "$tmp_ai" 2>&1; then
      local AI_OUTPUT
      AI_OUTPUT=$(cat "$tmp_ai")
      
      # Remove the old "AI Analysis Failed" text from original report
      sed -i '/--- AI Analysis ---/,$d' "$original_report"
      
      echo "--- AI Analysis ---" >> "$original_report"
      echo "$AI_OUTPUT" >> "$original_report"
      
      rm -f "$pending_file"
      rm -f "$tmp_ai"
      
      dialog --title "AI Analysis Complete" --msgbox "Successfully retrieved AI analysis and updated the report!" 8 60
      dialog --title "Audit Report & AI Analysis" --textbox "$original_report" 22 80
      
      # Refresh pending list
      pending=()
      for f in "$BASE_DIR/$REPORT_DIR/pending_ai"/wifi_full_audit_*.txt; do
        [ -e "$f" ] || continue
        pending+=("$(basename "$f")" "")
      done
      if [ ${#pending[@]} -eq 0 ]; then
        break
      fi
    else
      local err
      err=$(cat "$tmp_ai")
      rm -f "$tmp_ai"
      dialog --title "AI Analysis Failed" --msgbox "Failed to retrieve AI analysis:\n\n$err" 15 70
    fi
  done
}

# Main Menu Loop
while true; do
  MENU_CHOICE=$(dialog --clear --title "AI Network Analyzer" --menu "Main Menu" 15 50 4 \
    1 "Start Automated Wi-Fi Audit" \
    2 "View Previous Reports" \
    3 "Retry Pending AI Analysis" \
    0 "Exit" 3>&1 1>&2 2>&3)
  
  if [ $? -ne 0 ] || [ "$MENU_CHOICE" == "0" ]; then
    break
  fi

  case "$MENU_CHOICE" in
    1) bash "$BASE_DIR/tools/wifi_auto_audit.sh" ;;
    2) view_reports ;;
    3) retry_pending_ai ;;
  esac
done
