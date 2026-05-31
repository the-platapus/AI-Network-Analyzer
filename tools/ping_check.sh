#!/bin/bash
HOST=$1
if [ -z "$HOST" ]; then
    HOST=$DEFAULT_HOST
fi

echo "--- Ping Check ($HOST) ---"
output=$(ping -c 10 "$HOST" 2>&1)
if [ $? -eq 0 ]; then
    packet_loss=$(echo "$output" | grep -o "[0-9\.]*% packet loss" | awk '{print $1}')
    avg_latency=$(echo "$output" | grep -oP '(?<=min/avg/max/mdev = )[0-9.]*/[0-9.]*/' | cut -d '/' -f 2)
    if [ -z "$avg_latency" ]; then
        # Fallback if regex fails based on ping version
        avg_latency=$(echo "$output" | grep "min/avg/max" | awk -F'/' '{print $5}')
    fi
    echo "Average Latency: ${avg_latency} ms"
    echo "Packet Loss: ${packet_loss}"
    echo ""
    echo "Raw Output:"
    echo "$output"
else
    echo "Ping failed for $HOST"
    echo "$output"
fi
