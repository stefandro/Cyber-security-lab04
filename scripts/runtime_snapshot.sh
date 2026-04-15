#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/../reports"
LOG_DIR="$SCRIPT_DIR/../logs"
CLASSIFIER="$SCRIPT_DIR/incident_classifier.sh"

CPU_THRESHOLD=20
ERROR_THRESHOLD=3

mkdir -p "$REPORT_DIR"

if [ ! -x "$CLASSIFIER" ]; then
    echo "Error: incident_classifier.sh not found or not executable."
    exit 1
fi

OUTPUT_FILE="$REPORT_DIR/runtime_snapshot_$(date +%Y-%m-%d_%H-%M-%S).txt"

# ίδια whitelist με Task 4
whitelist=(
  "bash"
  "sleep"
  "systemd"
  "systemd-journal"
  "systemd-resolve"
  "systemd-timesyn"
  "systemd-udevd"
  "systemd-logind"
  "rsyslogd"
  "unattended-upgr"
  "dbus-daemon"
  "cron"
  "init-systemd(Ub"
  "init"
  "agetty"
  "SessionLeader"
  "Relay(303)"
  "login"
  "(sd-pam)"
  "(udev-worker)"
)

is_whitelisted() {
    local proc="$1"
    for allowed in "${whitelist[@]}"
    do
        if [ "$proc" = "$allowed" ]; then
            return 0
        fi
    done
    return 1
}

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
total_processes=$(ps -e --no-headers | wc -l)

read -r top_pid top_proc top_cpu <<< "$(ps -eo pid,comm,%cpu --sort=-%cpu --no-headers | awk '
    $2 != "ps" && $2 != "runtime_snapsh" && $2 != "incident_classi" {
        print $1, $2, $3
        exit
    }'
)"

unauthorized_count=0
unauthorized_details=""

while read -r pid comm
do
    [ "$comm" = "ps" ] && continue
    [ "$comm" = "runtime_snapsh" ] && continue
    [ "$comm" = "incident_classi" ] && continue

    if ! is_whitelisted "$comm"; then
        unauthorized_count=$((unauthorized_count + 1))
        unauthorized_details="${unauthorized_details}- PID=$pid PROC=$comm\n"
    fi
done < <(ps -eo pid,comm --no-headers)

total_errors=0
most_unstable=""
max_errors=-1
log_summary=""
log_anomaly=0

for file in "$LOG_DIR"/*.log
do
    [ -e "$file" ] || continue

    count=$(grep -c "ERROR" "$file")
    name=$(basename "$file")

    total_errors=$((total_errors + count))
    log_summary="${log_summary}- $name: $count ERROR entries\n"

    if [ "$count" -gt "$max_errors" ]; then
        max_errors="$count"
        most_unstable="$name"
    fi

    if [ "$count" -gt "$ERROR_THRESHOLD" ]; then
        log_anomaly=1
    fi
done

status=$("$CLASSIFIER" "$CPU_THRESHOLD" "$ERROR_THRESHOLD")

high_cpu_trigger=$(awk -v c="$top_cpu" -v t="$CPU_THRESHOLD" 'BEGIN {if (c > t) print "YES"; else print "NO"}')

if [ "$status" = "NORMAL" ]; then
    summary_text="no suspicious indicators were observed"
elif [ "$status" = "WARNING" ]; then
    summary_text="exactly one suspicious indicator was observed"
else
    summary_text="at least two suspicious indicators were observed simultaneously"
fi

{
    echo "========================================"
    echo "Runtime Security Snapshot"
    echo "========================================"
    echo "Date and time: $timestamp"
    echo "Total active processes: $total_processes"
    echo "Top CPU process: PID=$top_pid PROC=$top_proc CPU=${top_cpu}%"
    echo "Unauthorized processes: $unauthorized_count"
    echo "Total ERROR entries across all logs: $total_errors"
    echo "Incident classification: $status"
    echo "Classification summary: $summary_text"
    echo "----------------------------------------"
    echo "Thresholds:"
    echo "- CPU threshold: ${CPU_THRESHOLD}%"
    echo "- ERROR threshold per log: $ERROR_THRESHOLD"
    echo "----------------------------------------"
    echo "Triggered indicators:"

    if [ "$high_cpu_trigger" = "YES" ]; then
        echo "- high CPU: top process $top_proc (PID=$top_pid) uses ${top_cpu}% > threshold ${CPU_THRESHOLD}%"
    else
        echo "- high CPU: not triggered"
    fi

    if [ "$unauthorized_count" -gt 0 ]; then
        echo "- unauthorized processes detected: $unauthorized_count"
    else
        echo "- unauthorized processes detected: 0"
    fi

    if [ "$log_anomaly" -eq 1 ]; then
        echo "- log anomaly: at least one mission log exceeds ERROR threshold $ERROR_THRESHOLD"
    else
        echo "- log anomaly: not triggered"
    fi

    echo "----------------------------------------"
    echo "Log summary:"
    printf "%b" "$log_summary"
    echo "Most unstable log: $most_unstable ($max_errors ERROR entries)"
    echo "----------------------------------------"
    echo "Unauthorized process details:"
    if [ "$unauthorized_count" -gt 0 ]; then
        printf "%b" "$unauthorized_details"
    else
        echo "- none"
    fi
} > "$OUTPUT_FILE"

echo "Snapshot saved to: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
