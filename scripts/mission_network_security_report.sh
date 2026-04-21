set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORTS_DIR="${BASE_DIR}/reports"
LOG_DIR="${BASE_DIR}/logs"

LISTEN_SCRIPT="${SCRIPT_DIR}/listening_service_audit.sh"
ESTAB_SCRIPT="${SCRIPT_DIR}/established_connection_audit.sh"
EXPOSED_SCRIPT="${SCRIPT_DIR}/external_port_exposure_audit.sh"
SUSPICIOUS_SCRIPT="${SCRIPT_DIR}/suspicious_remote_connection_audit.sh"
CLASSIFIER_SCRIPT="${SCRIPT_DIR}/network_incident_classifier.sh"

# Reuse Lab 4 high CPU script if present; otherwise fallback to ps
HIGH_CPU_SCRIPT="${SCRIPT_DIR}/high_cpu_process_audit.sh"
CPU_THRESHOLD="${CPU_THRESHOLD:-50.0}"

mkdir -p "$REPORTS_DIR"

TIMESTAMP_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
TIMESTAMP_FILE="$(date +%y-%m-%d-%H-%M-%S)"
OUT_FILE="${REPORTS_DIR}/mission_network_security_report-${TIMESTAMP_FILE}.txt"

# Optional comparison note can be passed as script arguments
COMPARISON_NOTE="${*:-Compare this report with outputs collected under the other required test conditions.}"

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

extract_classification() {
    if [[ ! -x "$CLASSIFIER_SCRIPT" ]]; then
        echo "UNKNOWN"
        return
    fi

    bash "$CLASSIFIER_SCRIPT" 2>/dev/null \
    | awk -F': ' '
        /FINAL INCIDENT CLASSIFICATION/ {print $2; found=1}
        END {if (!found) print "UNKNOWN"}
    '
}

count_high_cpu() {
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

    ps -eo pcpu=,pid=,comm= 2>/dev/null \
    | awk -v t="$CPU_THRESHOLD" '$1+0 > t {c++} END {print c+0}'
}

count_log_errors() {
    grep -Rhs --include='*.log' 'ERROR' "$LOG_DIR" 2>/dev/null | wc -l
}

top_process_by_established() {
    local result

    result="$(
        ss -H -tnp state established 2>/dev/null | awk '
        {
            proc = "-"
            pid = "-"

            if (match($0, /users:\(\("([^"]+)"/, a)) proc = a[1]
            if (match($0, /pid=([0-9]+)/, b)) pid = b[1]

            # Ignore missing metadata when selecting top process
            if (proc != "-" && pid != "-") {
                key = proc "/" pid
                count[key]++
            }
        }
        END {
            max = 0
            top = ""

            for (k in count) {
                if (count[k] > max) {
                    max = count[k]
                    top = k
                }
            }

            if (max == 0) {
                print "NONE"
            } else {
                print top " (" max ")"
            }
        }'
    )"

    [[ -z "$result" ]] && result="NONE"
    echo "$result"
}

LISTEN_COUNT="$(extract_count "$LISTEN_SCRIPT" "LISTENING SERVICE COUNT")"
ESTAB_COUNT="$(extract_count "$ESTAB_SCRIPT" "ESTABLISHED CONNECTION COUNT")"
EXPOSED_COUNT="$(extract_count "$EXPOSED_SCRIPT" "UNEXPECTED EXPOSED PORT COUNT")"
SUSPICIOUS_COUNT="$(extract_count "$SUSPICIOUS_SCRIPT" "SUSPICIOUS REMOTE CONNECTION COUNT")"
TOP_PROCESS="$(top_process_by_established)"
HIGH_CPU_COUNT="$(count_high_cpu)"
TOTAL_LOG_ERRORS="$(count_log_errors)"
CLASSIFICATION="$(extract_classification)"

cat > "$OUT_FILE" <<EOF
=== MISSION NETWORK SECURITY REPORT ===
TIME: $TIMESTAMP_HUMAN

[NETWORK STATE]
LISTENING SERVICES: $LISTEN_COUNT
ESTABLISHED CONNECTIONS: $ESTAB_COUNT
UNEXPECTED EXPOSED PORTS: $EXPOSED_COUNT
SUSPICIOUS REMOTE CONNECTIONS: $SUSPICIOUS_COUNT
TOP PROCESS BY ESTABLISHED CONNECTIONS: $TOP_PROCESS

[RUNTIME AND LOGS]
HIGH CPU PROCESSES: $HIGH_CPU_COUNT
TOTAL LOG ERRORS: $TOTAL_LOG_ERRORS

[CLASSIFICATION]
FINAL CLASSIFICATION: $CLASSIFICATION

[COMPARISON]
$COMPARISON_NOTE
EOF

cat "$OUT_FILE"
echo
echo "REPORT SAVED TO: $OUT_FILE"
