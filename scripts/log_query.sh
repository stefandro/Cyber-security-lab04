#!/bin/bash

input="$1"
pattern="$2"
mode="$3"

if [ -z "$input" ]; then
    echo "Usage:"
    echo "  $0 <file_or_pattern>"
    echo "  $0 <file_or_pattern> <INFO|WARN|ERROR>"
    echo "  $0 <file_or_pattern> <INFO|WARN|ERROR> report"
    exit 1
fi

files=( $input )

if [ ! -e "${files[0]}" ]; then
    echo "No matching files found for: $input"
    exit 1
fi

count_info() {
    awk '$3=="INFO"{c++} END{print c+0}' "$@"
}

count_warn() {
    awk '$3=="WARN"{c++} END{print c+0}' "$@"
}

count_error() {
    awk '$3=="ERROR"{c++} END{print c+0}' "$@"
}

count_pattern() {
    local p="$1"
    shift
    awk -v pat="$p" '$3==pat{c++} END{print c+0}' "$@"
}

generate_report() {
    local report="reports/dynamic_report.txt"
    echo "DYNAMIC REPORT" > "$report"
    echo "Total entries: $(cat "$@" | wc -l)" >> "$report"
    echo "INFO: $(count_info "$@")" >> "$report"
    echo "WARN: $(count_warn "$@")" >> "$report"
    echo "ERROR: $(count_error "$@")" >> "$report"
    echo "Saved to $report"
}

if [ -z "$pattern" ]; then
    echo "Total lines: $(cat "${files[@]}" | wc -l)"
else
    echo "$pattern matches: $(count_pattern "$pattern" "${files[@]}")"
fi

if [ "$mode" = "report" ]; then
    generate_report "${files[@]}"
fi
