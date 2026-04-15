#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: ./resource_usage_detector.sh <CPU_THRESHOLD> <MEM_THRESHOLD>"
    exit 1
fi

cpu_threshold="$1"
mem_threshold="$2"

ps -eo pid,comm,%cpu,%mem --no-headers | while read -r pid comm cpu mem
do
    # ignore the ps command itself
    if [ "$comm" = "ps" ]; then
        continue
    fi

    cpu_alert=$(awk -v c="$cpu" -v t="$cpu_threshold" 'BEGIN {if (c > t) print 1; else print 0}')
    mem_alert=$(awk -v m="$mem" -v t="$mem_threshold" 'BEGIN {if (m > t) print 1; else print 0}')

    if [ "$cpu_alert" -eq 1 ]; then
        echo "WARNING: suspicious CPU usage: $comm (PID: $pid)"
    fi

    if [ "$mem_alert" -eq 1 ]; then
        echo "WARNING: suspicious memory usage: $comm (PID: $pid)"
    fi
done
