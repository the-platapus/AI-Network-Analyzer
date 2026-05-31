#!/bin/bash
echo "--- Speed Test ---"
TEST_FILE="http://ipv4.download.thinkbroadband.com/10MB.zip"
echo "Downloading 10MB test file to measure speed..."
if command -v curl &> /dev/null; then
    curl -o /dev/null -s -w "Download Speed: %{speed_download} Bytes/sec\nTotal Time: %{time_total} seconds\n" "$TEST_FILE"
else
    echo "curl command not found."
fi
