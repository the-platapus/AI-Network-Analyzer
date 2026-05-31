#!/bin/bash
HOST=$1
if [ -z "$HOST" ]; then
    HOST=$DEFAULT_HOST
fi

echo "--- DNS Lookup ($HOST) ---"
if command -v dig &> /dev/null; then
    echo "[A Records & TTL]"
    dig +nocmd "$HOST" A +noall +answer
    echo ""
    echo "[MX Records]"
    dig +nocmd "$HOST" MX +noall +answer
elif command -v nslookup &> /dev/null; then
    nslookup -type=A "$HOST"
    nslookup -type=MX "$HOST"
else
    echo "dig or nslookup command not found."
fi
