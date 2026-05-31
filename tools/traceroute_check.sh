#!/bin/bash
HOST=$1
if [ -z "$HOST" ]; then
    HOST=$DEFAULT_HOST
fi

echo "--- Traceroute ($HOST) ---"
if command -v traceroute &> /dev/null; then
    traceroute -m 15 "$HOST" 2>&1
else
    echo "traceroute command not found."
fi
