#!/bin/bash

# Main entry point for Wi-Fi Security Auditor

# Set directory variables
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_DIR

# Check dependencies
MISSING_DEPS=""
for dep in dialog jq curl airmon-ng airodump-ng aircrack-ng iw iwgetid timeout; do
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

# Ensure reports directory exists
mkdir -p "$BASE_DIR/$REPORT_DIR"

# Run the automated Wi-Fi security audit
bash "$BASE_DIR/tools/wifi_auto_audit.sh"
