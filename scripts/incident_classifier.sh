#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: ./incident_classifier.sh <CPU_THRESHOLD> <ERROR_THRESHOLD>"
    exit 1
fi

cpu_threshold="$1"
error_threshold="$2"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"


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


high_cpu=0
while read -r pid comm cpu
do
    [ "$comm" = "ps" ] && continue
    cpu_alert=$(awk -v c="$cpu" -v t="$cpu_threshold" 'BEGIN { if (c > t) print 1; else print 0 }')
    if [ "$cpu_alert" -eq 1 ]; then
        high_cpu=1
        break
    fi
done < <(ps -eo pid,comm,%cpu --no-headers)


unauthorized_present=0
while read -r pid comm
do
    [ "$comm" = "ps" ] && continue
    [ "$comm" = "incident_classi" ] && continue

    if ! is_whitelisted "$comm"; then
        unauthorized_present=1
        break
    fi
done < <(ps -eo pid,comm --no-headers)


log_anomaly=0
for file in "$LOG_DIR"/*.log
do
    [ -e "$file" ] || continue
    count=$(grep -c "ERROR" "$file")
    if [ "$count" -gt "$error_threshold" ]; then
        log_anomaly=1
        break
    fi
done

indicators=$((high_cpu + unauthorized_present + log_anomaly))

if [ "$indicators" -eq 0 ]; then
    echo "NORMAL"
elif [ "$indicators" -eq 1 ]; then
    echo "WARNING"
else
    echo "CRITICAL"
fi
