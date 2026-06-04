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

PROMPT_OVERRIDE="$2"

if [ -z "$INPUT_DATA" ]; then
    echo "Error: No data provided for AI analysis."
    exit 1
fi

if [ "$GOOGLE_API_KEY" == "your-google-api-key-here" ] || [ -z "$GOOGLE_API_KEY" ]; then
    echo "Error: GOOGLE_API_KEY is not configured in config.sh"
    exit 1
fi

if [ -z "$GOOGLE_MODEL" ]; then
    GOOGLE_MODEL="gemini-flash-latest"
fi

if [ -z "$GOOGLE_API_URL" ]; then
    GOOGLE_API_URL="https://generativelanguage.googleapis.com/v1beta/models/$GOOGLE_MODEL:generateContent"
fi

# Escape JSON for curl using jq
ESCAPED_DATA=$(jq -Rs . <<< "$INPUT_DATA")

if [ -n "$PROMPT_OVERRIDE" ]; then
    SYSTEM_PROMPT="$PROMPT_OVERRIDE"
else
    SYSTEM_PROMPT="You are an expert network security analyst. Analyze the following network diagnostics data and provide: 1) Critical issues found, 2) Security risks, 3) Performance problems, 4) Exact fix commands for each issue. Be concise and use bullet points."
fi

ESCAPED_SYSTEM=$(jq -Rs . <<< "$SYSTEM_PROMPT")

# Build JSON payload for Gemini API
PAYLOAD=$(cat <<EOF
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": ${ESCAPED_SYSTEM}
        },
        {
          "text": ${ESCAPED_DATA}
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.2
  }
}
EOF
)

# Make API call
RESPONSE=$(curl -s -X POST "$GOOGLE_API_URL?key=$GOOGLE_API_KEY" \
     -H "Content-Type: application/json" \
     -d "$PAYLOAD")

# Parse response (Gemini returns the text in candidates[0].content.parts[0].text)
AI_MESSAGE=$(echo "$RESPONSE" | jq -r '
  if .candidates then
    .candidates[0].content.parts[0].text
  else
    empty
  end')

if [ "$AI_MESSAGE" == "null" ] || [ -z "$AI_MESSAGE" ]; then
    echo "Error calling Google Gen AI: $(echo "$RESPONSE" | jq -r '.error.message // empty')"
else
    echo "$AI_MESSAGE"
fi
