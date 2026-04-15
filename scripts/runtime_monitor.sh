#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/../reports"
LOG_DIR="$SCRIPT_DIR/../logs"
CLASSIFIER="$SCRIPT_DIR/incident_classifier.sh"

INTERVAL=5
CPU_THRESHOLD=20
ERROR_THRESHOLD=3

mkdir -p "$REPORT_DIR"

if [ ! -x "$CLASSIFIER" ]; then
    echo "Error: incident_classifier.sh not found or not executable."
    exit 1
fi

OUTPUT_FILE="$REPORT_DIR/runtime_monitor_$(date +%Y%m%d_%H%M%S).txt"


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

count_unauthorized() {
    local count=0
    while read -r pid comm
    do
        [ "$comm" = "ps" ] && continue
        [ "$comm" = "runtime_monito" ] && continue
        [ "$comm" = "incident_classi" ] && continue

        if ! is_whitelisted "$comm"; then
            count=$((count + 1))
        fi
    done < <(ps -eo pid,comm --no-headers)
    echo "$count"
}

top_cpu_process() {
    ps -eo pid,comm,%cpu --sort=-%cpu --no-headers | awk '
        $2 != "ps" && $2 != "runtime_monito" {
            print $1, $2, $3
            exit
        }'
}

log_anomaly_status() {
    local anomaly="NO"
    for file in "$LOG_DIR"/*.log
    do
        [ -e "$file" ] || continue
        count=$(grep -c "ERROR" "$file")
        if [ "$count" -gt "$ERROR_THRESHOLD" ]; then
            anomaly="YES"
            break
        fi
    done
    echo "$anomaly"
}

echo "Starting monitoring loop..."
echo "Interval: ${INTERVAL}s"
echo "Output: $OUTPUT_FILE"
echo "Using: ./incident_classifier.sh"
echo "Press Ctrl+C to stop."
echo "----------------------------------------"

{
    echo "===== Monitoring started: $(date '+%Y-%m-%d %H:%M:%S') ====="
} >> "$OUTPUT_FILE"

while true
do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    read -r top_pid top_proc top_cpu <<< "$(top_cpu_process)"
    unauthorized_count=$(count_unauthorized)
    log_anomaly=$(log_anomaly_status)
    status=$("$CLASSIFIER" "$CPU_THRESHOLD" "$ERROR_THRESHOLD")

    line="[$timestamp] TOP_CPU: $top_proc (PID=$top_pid, CPU=${top_cpu}%) | UNAUTHORIZED: $unauthorized_count | LOG_ANOMALY: $log_anomaly | STATUS: $status"

    echo "$line"
    echo "$line" >> "$OUTPUT_FILE"

    sleep "$INTERVAL"
done
