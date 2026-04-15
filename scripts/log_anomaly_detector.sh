#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: ./log_anomaly_detector.sh <ERROR_THRESHOLD>"
    exit 1
fi

threshold="$1"
max_errors=-1
most_unstable=""

echo "Processing log files..."

for file in ../logs/*.log
do
    count=$(grep -c "ERROR" "$file")
    name=$(basename "$file")

    echo "$name: $count ERROR entries"

    if [ "$count" -gt "$threshold" ]; then
        echo "ALERT: log anomaly detected in $name"
    fi

    if [ "$count" -gt "$max_errors" ]; then
        max_errors="$count"
        most_unstable="$name"
    fi
done

echo "Most unstable log file: $most_unstable ($max_errors ERROR entries)"
