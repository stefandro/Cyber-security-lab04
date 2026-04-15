#!/bin/bash
pattern="$1"
if [ -z "$pattern" ]; then
    echo "Usage: $0 \"logs/*.log\""
    exit 1
fi
files=( $pattern )
if [ ! -e "${files[0]}" ]; then
    echo "No matching files found for: $pattern"
    exit 1
fi
processed_files=${#files[@]}
total_entries=$(cat "${files[@]}" | wc -l)
info_count=$(awk '$3=="INFO"{c++} END{print c+0}' "${files[@]}")
warn_count=$(awk '$3=="WARN"{c++} END{print c+0}' "${files[@]}")
error_count=$(awk '$3=="ERROR"{c++} END{print c+0}' "${files[@]}")
max_errors=-1
most_unstable=""
for file in "${files[@]}"; do
    current_errors=$(awk '$3=="ERROR"{c++} END{print c+0}' "$file")
    if [ "$current_errors" -gt "$max_errors" ]; then
        max_errors="$current_errors"
        most_unstable="$(basename "$file")"
    fi
done
report="reports/mission_report.txt"
echo "MISSION REPORT" > "$report"
echo "Processed files: $processed_files" >> "$report"
echo "Total entries: $total_entries" >> "$report"
echo "INFO: $info_count" >> "$report"
echo "WARN: $warn_count" >> "$report"
echo "ERROR: $error_count" >> "$report"
echo "Most unstable log: $most_unstable" >> "$report"
cat "$report"
