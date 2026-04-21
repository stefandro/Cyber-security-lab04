set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${BASE_DIR}/logs"

EXTERNAL_SCRIPT="${SCRIPT_DIR}/external_port_exposure_audit.sh"
SUSPICIOUS_SCRIPT="${SCRIPT_DIR}/suspicious_remote_connection_audit.sh"

# Change these two only if your Lab 4 script names are different
HIGH_CPU_SCRIPT="${SCRIPT_DIR}/high_cpu_process_audit.sh"
LOG_ANOMALY_SCRIPT="${SCRIPT_DIR}/log_anomaly_detector.sh"

CPU_THRESHOLD="${CPU_THRESHOLD:-50.0}"

extract_count() {
    local script_path="$1"
    local pattern="$2"

    if [[ ! -x "$script_path" ]]; then
        echo "0"
        return
    fi

    bash "$script_path" 2>/dev/null \
    | awk -F': ' -v p="$pattern" '
        $0 ~ p {print $2+0; found=1}
        END {if (!found) print 0}
    '
}

count_unexpected_exposed() {
    extract_count "$EXTERNAL_SCRIPT" "UNEXPECTED EXPOSED PORT COUNT"
}

count_suspicious_remote() {
    extract_count "$SUSPICIOUS_SCRIPT" "SUSPICIOUS REMOTE CONNECTION COUNT"
}

count_high_cpu() {
    # Reuse Lab 4 script if present and executable
    if [[ -x "$HIGH_CPU_SCRIPT" ]]; then
        result="$(bash "$HIGH_CPU_SCRIPT" 2>/dev/null || true)"

        parsed="$(printf '%s\n' "$result" \
            | awk -F': ' '
                /HIGH CPU PROCESS COUNT/ {print $2+0; found=1}
                END {if (!found) print ""}
            ')"

        if [[ -n "$parsed" ]]; then
            echo "$parsed"
            return
        fi
    fi

    # Fallback: count processes above CPU threshold
    ps -eo pcpu=,pid=,comm= 2>/dev/null \
    | awk -v t="$CPU_THRESHOLD" '$1+0 > t {c++} END {print c+0}'
}

count_log_anomalies() {
    # Reuse Lab 4 script if present and executable
    if [[ -x "$LOG_ANOMALY_SCRIPT" ]]; then
        result="$(bash "$LOG_ANOMALY_SCRIPT" 2>/dev/null || true)"

        parsed="$(printf '%s\n' "$result" \
            | awk -F': ' '
                /LOG ANOMALY COUNT/ {print $2+0; found=1}
                /LOG ANOMALIES COUNT/ {print $2+0; found=1}
                END {if (!found) print ""}
            ')"

        if [[ -n "$parsed" ]]; then
            echo "$parsed"
            return
        fi
    fi

    # Fallback: treat ERROR log entries as anomalies
    grep -Rhs --include='*.log' 'ERROR' "$LOG_DIR" 2>/dev/null | wc -l
}

unexpected_count="$(count_unexpected_exposed)"
suspicious_count="$(count_suspicious_remote)"
high_cpu_count="$(count_high_cpu)"
log_anomaly_count="$(count_log_anomalies)"

unexpected_state="INACTIVE"
suspicious_state="INACTIVE"
high_cpu_state="INACTIVE"
log_state="INACTIVE"

active_categories=0

if (( unexpected_count > 0 )); then
    unexpected_state="ACTIVE"
    ((active_categories++))
fi

if (( suspicious_count > 0 )); then
    suspicious_state="ACTIVE"
    ((active_categories++))
fi

if (( high_cpu_count > 0 )); then
    high_cpu_state="ACTIVE"
    ((active_categories++))
fi

if (( log_anomaly_count > 0 )); then
    log_state="ACTIVE"
    ((active_categories++))
fi

classification="NORMAL"
if (( active_categories == 1 )); then
    classification="WARNING"
elif (( active_categories >= 2 )); then
    classification="CRITICAL"
fi

echo "=== NETWORK INCIDENT CLASSIFICATION ==="
echo "UNEXPECTED EXPOSED PORTS: $unexpected_state"
echo "SUSPICIOUS REMOTE CONNECTIONS: $suspicious_state"
echo "HIGH CPU PROCESSES: $high_cpu_state"
echo "LOG ANOMALIES: $log_state"
echo "ACTIVE SUSPICIOUS INDICATOR CATEGORIES: $active_categories"
echo "FINAL INCIDENT CLASSIFICATION: $classification"
