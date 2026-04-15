#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLASSIFIER="$SCRIPT_DIR/incident_classifier.sh"

INTERVAL=5
CPU_THRESHOLD=20
ERROR_THRESHOLD=3

if [ ! -x "$CLASSIFIER" ]; then
    echo "Error: incident_classifier.sh not found or not executable."
    exit 1
fi

rank_status() {
    case "$1" in
        NORMAL) echo 0 ;;
        WARNING) echo 1 ;;
        CRITICAL) echo 2 ;;
        *) echo -1 ;;
    esac
}

previous_status=$("$CLASSIFIER" "$CPU_THRESHOLD" "$ERROR_THRESHOLD")

echo "Starting escalation monitoring..."
echo "Interval: ${INTERVAL}s"
echo "Initial status: $previous_status"
echo "Press Ctrl+C to stop."

while true
do
    sleep "$INTERVAL"

    current_status=$("$CLASSIFIER" "$CPU_THRESHOLD" "$ERROR_THRESHOLD")

    previous_rank=$(rank_status "$previous_status")
    current_rank=$(rank_status "$current_status")

    if [ "$current_rank" -gt "$previous_rank" ]; then
        echo "ESCALATION DETECTED:"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "From: $previous_status"
        echo "To: $current_status"
        exit 0
    fi

    previous_status="$current_status"
done
