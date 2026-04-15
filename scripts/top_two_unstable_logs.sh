#!/bin/bash
for file in logs/*.log; do
    count=$(awk '$3=="ERROR"{c++} END{print c+0}' "$file")
    echo "$(basename "$file"): $count"
done | sort -t':' -k2,2nr | head -n 2
