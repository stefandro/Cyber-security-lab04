#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/../reports"
LOG_DIR="$SCRIPT_DIR/../logs"
CLASSIFIER="$SCRIPT_DIR/incident_classifier.sh"

CPU_THRESHOLD=20
ERROR_THRESHOLD=3

mkdir -p "$REPORT_DIR"


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

generated_at="$(date '+%Y-%m-%d_%H-%M-%S')"
OUTPUT_FILE="$REPORT_DIR/mission_runtime_security_report_${generated_at}.txt"

# -----------------------------
# Log analysis
# -----------------------------
processed_logs=0
total_errors=0
max_errors=-1
most_unstable=""
log_anomaly=0

for file in "$LOG_DIR"/*.log
do
    [ -e "$file" ] || continue

    processed_logs=$((processed_logs + 1))
    count=$(grep -c "ERROR" "$file")
    name=$(basename "$file")

    total_errors=$((total_errors + count))

    if [ "$count" -gt "$max_errors" ]; then
        max_errors="$count"
        most_unstable="$name"
    fi

    if [ "$count" -gt "$ERROR_THRESHOLD" ]; then
        log_anomaly=1
    fi
done

if [ "$processed_logs" -eq 0 ]; then
    echo "No log files found in $LOG_DIR"
    exit 1
fi

# -----------------------------
# Process analysis
# -----------------------------
active_processes=$(ps -e --no-headers | wc -l)

read -r top_pid top_proc top_cpu <<< "$(ps -eo pid,comm,%cpu --sort=-%cpu --no-headers | awk '
    $2 != "ps" && $2 != "mission_runtime" && $2 != "incident_classi" {
        print $1, $2, $3
        exit
    }'
)"

if [ -z "$top_proc" ]; then
    top_pid="N/A"
    top_proc="N/A"
    top_cpu="0.0"
fi

unauthorized_count=0
high_cpu_count=0

while read -r pid comm cpu
do
    [ "$comm" = "ps" ] && continue
    [ "$comm" = "mission_runtime" ] && continue
    [ "$comm" = "incident_classi" ] && continue

    cpu_alert=$(awk -v c="$cpu" -v t="$CPU_THRESHOLD" 'BEGIN { if (c > t) print 1; else print 0 }')
    if [ "$cpu_alert" -eq 1 ]; then
        high_cpu_count=$((high_cpu_count + 1))
    fi

    if ! is_whitelisted "$comm"; then
        unauthorized_count=$((unauthorized_count + 1))
    fi
done < <(ps -eo pid,comm,%cpu --no-headers)

# -----------------------------
# Final classification
# Prefer reusing incident_classifier.sh
# -----------------------------
status=""

if [ -f "$CLASSIFIER" ]; then
    status=$(bash "$CLASSIFIER" "$CPU_THRESHOLD" "$ERROR_THRESHOLD" 2>/dev/null | tail -n 1)
fi

if [ -z "$status" ]; then
    indicators=0
    [ "$high_cpu_count" -gt 0 ] && indicators=$((indicators + 1))
    [ "$unauthorized_count" -gt 0 ] && indicators=$((indicators + 1))
    [ "$log_anomaly" -eq 1 ] && indicators=$((indicators + 1))

    if [ "$indicators" -eq 0 ]; then
        status="NORMAL"
    elif [ "$indicators" -eq 1 ]; then
        status="WARNING"
    else
        status="CRITICAL"
    fi
fi

# -----------------------------
# Report output
# -----------------------------
{
    echo "MISSION RUNTIME SECURITY REPORT"
    echo "Generated at: $generated_at"
    echo
    echo "Processed log files: $processed_logs"
    echo "Active processes: $active_processes"
    echo "Unauthorized processes: $unauthorized_count"
    echo "High CPU processes: $high_cpu_count"
    echo "ERROR entries: $total_errors"
    echo "Most unstable log: $most_unstable"
    echo "Top CPU process: $top_proc"
    echo "Incident classification: $status"
} > "$OUTPUT_FILE"

echo "Report saved to: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
