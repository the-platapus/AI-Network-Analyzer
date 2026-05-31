#!/bin/bash
echo "--- Active Connections and Listening Ports ---"
if command -v ss &> /dev/null; then
    ss -tulpn 2>/dev/null | head -n 30
elif command -v netstat &> /dev/null; then
    netstat -tulpn 2>/dev/null | head -n 30
else
    echo "ss and netstat commands not found."
fi
