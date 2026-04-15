#!/bin/bash
max=-1
noisiest=""
for file in logs/*.log; do
    count=$(awk '$3=="WARN" || $3=="ERROR"{c++} END{print c+0}' "$file")
    echo "$(basename "$file"): $count"
    if [ "$count" -gt "$max" ]; then
        max="$count"
        noisiest="$(basename "$file")"
    fi
done
echo "Noisiest satellite: $noisiest"
