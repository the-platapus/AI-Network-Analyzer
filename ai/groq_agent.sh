#!/bin/bash

# Read input from stdin or argument
INPUT_DATA=""
if [ -p /dev/stdin ]; then
    INPUT_DATA=$(cat)
elif [ -n "$1" ] && [ -f "$1" ]; then
    INPUT_DATA=$(cat "$1")
else
    INPUT_DATA="$1"
fi

if [ -z "$INPUT_DATA" ]; then
    echo "Error: No data provided for AI analysis."
    exit 1
fi

if [ "$GROQ_API_KEY" == "your-groq-api-key-here" ] || [ -z "$GROQ_API_KEY" ]; then
    echo "Error: GROQ_API_KEY is not configured in config.sh"
    exit 1
fi

# Escape JSON for curl using jq
ESCAPED_DATA=$(jq -Rs . <<< "$INPUT_DATA")

SYSTEM_PROMPT="You are an expert network security analyst. Analyze the following network diagnostics data and provide: 1) Critical issues found, 2) Security risks, 3) Performance problems, 4) Exact fix commands for each issue. Be concise and use bullet points."
ESCAPED_SYSTEM=$(jq -Rs . <<< "$SYSTEM_PROMPT")

# Build JSON payload
PAYLOAD=$(cat <<EOF
{
  "model": "$GROQ_MODEL",
  "messages": [
    {
      "role": "system",
      "content": ${ESCAPED_SYSTEM}
    },
    {
      "role": "user",
      "content": ${ESCAPED_DATA}
    }
  ]
}
EOF
)

# Make API call
RESPONSE=$(curl -s -X POST "$GROQ_API_URL" \
     -H "Authorization: Bearer $GROQ_API_KEY" \
     -H "Content-Type: application/json" \
     -d "$PAYLOAD")

# Parse response
AI_MESSAGE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

if [ "$AI_MESSAGE" == "null" ] || [ -z "$AI_MESSAGE" ]; then
    echo "Error calling Groq API: $(echo "$RESPONSE" | jq -r '.error.message // empty')"
else
    echo "$AI_MESSAGE"
fi
