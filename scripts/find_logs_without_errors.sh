#!/bin/bash
for file in logs/*.log; do
    errors=$(awk '$3=="ERROR"{c++} END{print c+0}' "$file")
    if [ "$errors" -eq 0 ]; then
        echo "$(basename "$file")"
    fi
done
