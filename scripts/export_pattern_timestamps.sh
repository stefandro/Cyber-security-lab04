#!/bin/bash
pattern="$1"
if [ -z "$pattern" ]; then
    echo "Usage: $0 <INFO|WARN|ERROR>"
    exit 1
fi
report="reports/pattern_timestamps.txt"
: > "$report"
for file in logs/*.log; do
    awk -v p="$pattern" '$3==p{print $1, $2}' "$file" >> "$report"
done
echo "Saved to $report"
