#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SNAPSHOT_SCRIPT="$SCRIPT_DIR/runtime_snapshot.sh"
REPORT_DIR="$SCRIPT_DIR/../reports"

if [ ! -x "$SNAPSHOT_SCRIPT" ]; then
    echo "Error: runtime_snapshot.sh not found or not executable."
    exit 1
fi

mkdir -p "$REPORT_DIR"

# 1st snapshot
"$SNAPSHOT_SCRIPT" > /dev/null
snapshot1=$(ls -t "$REPORT_DIR"/runtime_snapshot_*.txt | sed -n '1p')

sleep 5

# 2nd snapshot
"$SNAPSHOT_SCRIPT" > /dev/null
snapshot2=$(ls -t "$REPORT_DIR"/runtime_snapshot_*.txt | sed -n '1p')

if [ ! -f "$snapshot1" ] || [ ! -f "$snapshot2" ]; then
    echo "Error: snapshot files not created properly."
    exit 1
fi

top_cpu_1=$(grep "^Top CPU process:" "$snapshot1" | sed 's/^Top CPU process: //')
top_cpu_2=$(grep "^Top CPU process:" "$snapshot2" | sed 's/^Top CPU process: //')

unauth_1=$(grep "^Unauthorized processes:" "$snapshot1" | awk -F': ' '{print $2}')
unauth_2=$(grep "^Unauthorized processes:" "$snapshot2" | awk -F': ' '{print $2}')

status_1=$(grep "^Incident classification:" "$snapshot1" | awk -F': ' '{print $2}')
status_2=$(grep "^Incident classification:" "$snapshot2" | awk -F': ' '{print $2}')

echo "STATE CHANGE DETECTED:"

if [ "$top_cpu_1" = "$top_cpu_2" ]; then
    echo "Top CPU process changed: NO"
else
    echo "Top CPU process changed: YES"
    echo "  $top_cpu_1 -> $top_cpu_2"
fi

if [ "$unauth_1" = "$unauth_2" ]; then
    echo "Unauthorized process count changed: NO"
else
    echo "Unauthorized process count changed: YES ($unauth_1 -> $unauth_2)"
fi

if [ "$status_1" = "$status_2" ]; then
    echo "Incident classification changed: NO"
else
    echo "Incident classification changed: YES ($status_1 -> $status_2)"
fi
