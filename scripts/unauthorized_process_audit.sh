#!/bin/bash

authorized_count=0
unauthorized_count=0


whitelist=(
  "bash"
  "sleep"
  "systemd"
  "systemd-journal"
  "systemd-resolve"
  "systemd-logind"
  "systemd-timesyn"
  "systemd-udevd"
  "rsyslogd"
  "unattended-upgr"
  "dbus-daemon"
  "cron"
  "ps"
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

ps -eo pid,comm --no-headers | while read -r pid comm
do
    if is_whitelisted "$comm"; then
        echo "AUTHORIZED PROCESS: $comm (PID: $pid)"
    else
        echo "UNAUTHORIZED PROCESS: $comm (PID: $pid)"
    fi
done

echo
authorized_count=$(ps -eo comm --no-headers | while read -r comm
do
    if is_whitelisted "$comm"; then
        echo 1
    fi
done | wc -l)

unauthorized_count=$(ps -eo comm --no-headers | while read -r comm
do
    if ! is_whitelisted "$comm"; then
        echo 1
    fi
done | wc -l)

echo "TOTAL AUTHORIZED: $authorized_count"
echo "TOTAL UNAUTHORIZED: $unauthorized_count"
