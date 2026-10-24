#!/bin/bash
# Send live custom quota to Boring Notch via local port 9876

PLAN="${1:-Google AI Pro}"
GEMINI_WEEKLY="${2:-0.85}"
GEMINI_5H="${3:-0.78}"
RESET_5H="${4:-Resets in 2h 40m}"
RESET_WEEKLY="${5:-Resets in 5d 14h}"

PAYLOAD=$(cat <<EOF
{
  "planName": "$PLAN",
  "geminiWeeklyRemaining": $GEMINI_WEEKLY,
  "geminiWeeklyResetText": "$RESET_WEEKLY",
  "geminiFiveHourRemaining": $GEMINI_5H,
  "geminiFiveHourResetText": "$RESET_5H",
  "claudeWeeklyRemaining": 1.0,
  "claudeWeeklyResetText": "Full quota (7d)",
  "claudeFiveHourRemaining": 1.0,
  "claudeFiveHourResetText": "Full quota (5h)"
}
EOF
)

# 1. Update quota.json files
mkdir -p "$HOME/.gemini/antigravity-ide"
mkdir -p "$HOME/Library/Application Support/boringNotch"
echo "$PAYLOAD" > "$HOME/.gemini/antigravity-ide/quota.json"
echo "$PAYLOAD" > "$HOME/Library/Application Support/boringNotch/antigravity_quota.json"

# 2. Push via socket to Boring Notch
echo "$PAYLOAD" | nc 127.0.0.1 9876

echo "✅ Live quota updated and transmitted to Boring Notch!"
