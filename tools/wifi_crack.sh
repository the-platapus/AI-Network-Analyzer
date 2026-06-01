#!/bin/bash

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <capture-file.cap> <wordlist.txt>"
  exit 1
fi

cap_file="$1"
wordlist="$2"

if [ ! -f "$cap_file" ]; then
  echo "Error: Capture file not found: $cap_file"
  exit 1
fi

if [ ! -f "$wordlist" ]; then
  echo "Error: Wordlist file not found: $wordlist"
  exit 1
fi

echo "Running aircrack-ng against $cap_file using wordlist $wordlist"
sudo aircrack-ng -w "$wordlist" "$cap_file"
