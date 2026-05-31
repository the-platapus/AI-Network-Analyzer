#!/bin/bash
HOST=$1
if [ -z "$HOST" ]; then
    HOST=$DEFAULT_HOST
fi

echo "--- Port Scan ($HOST) ---"
if command -v nmap &> /dev/null; then
    nmap -p 22,80,443,3306,8080 "$HOST" | grep -E "^(22|80|443|3306|8080)/"
else
    echo "nmap command not found. Attempting bash TCP connect scan."
    for port in 22 80 443 3306 8080; do
        timeout 1 bash -c "</dev/tcp/$HOST/$port" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "$port/tcp open"
        else
            echo "$port/tcp closed"
        fi
    done
fi
