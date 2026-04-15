#!/bin/bash
pattern="$1"
if [ -z "$pattern" ]; then
    echo "Usage: $0 <INFO|WARN|ERROR>"
    exit 1
fi
report="reports/pattern_report.txt"
echo "PATTERN REPORT: $pattern" > "$report"
for file in logs/*.log; do
    count=$(awk -v p="$pattern" '$3==p{c++} END{print c+0}' "$file")
    echo "$(basename "$file"): $count" >> "$report"
done
cat "$report"
