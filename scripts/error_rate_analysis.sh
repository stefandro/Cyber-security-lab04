#!/bin/bash
max_rate=-1
max_file=""
for file in logs/*.log; do
    total=$(wc -l < "$file")
    errors=$(awk '$3=="ERROR"{c++} END{print c+0}' "$file")
    rate=$(awk -v e="$errors" -v t="$total" 'BEGIN{ if(t==0) printf "0.0000"; else printf "%.4f", e/t }')
    echo "$(basename "$file"): total=$total ERROR=$errors rate=$rate"
    greater=$(awk -v a="$rate" -v b="$max_rate" 'BEGIN{print (a>b)?1:0}')
    if [ "$greater" -eq 1 ]; then
        max_rate="$rate"
        max_file="$(basename "$file")"
    fi
done
echo "Highest error rate: $max_file ($max_rate)"
