set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORTS_DIR="${BASE_DIR}/reports"

LISTEN_SCRIPT="${SCRIPT_DIR}/listening_service_audit.sh"
ESTAB_SCRIPT="${SCRIPT_DIR}/established_connection_audit.sh"
EXPOSED_SCRIPT="${SCRIPT_DIR}/external_port_exposure_audit.sh"
SUSPICIOUS_SCRIPT="${SCRIPT_DIR}/suspicious_remote_connection_audit.sh"
CLASSIFIER_SCRIPT="${SCRIPT_DIR}/network_incident_classifier.sh"

INTERVAL="${1:-5}"

mkdir -p "$REPORTS_DIR"

OUT_FILE="${REPORTS_DIR}/network_monitor-$(date +%y-%m-%d-%H-%M-%S).txt"

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

echo "Monitoring started."
echo "Interval: ${INTERVAL}s"
echo "Output file: $OUT_FILE"
echo "Press Ctrl+C to stop safely."

trap 'echo; echo "Monitoring stopped safely."; exit 0' INT TERM

while true; do
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    listen_count="$(extract_count "$LISTEN_SCRIPT" "LISTENING SERVICE COUNT")"
    estab_count="$(extract_count "$ESTAB_SCRIPT" "ESTABLISHED CONNECTION COUNT")"
    exposed_count="$(extract_count "$EXPOSED_SCRIPT" "UNEXPECTED EXPOSED PORT COUNT")"
    suspicious_count="$(extract_count "$SUSPICIOUS_SCRIPT" "SUSPICIOUS REMOTE CONNECTION COUNT")"
    class_state="$(extract_classification)"

    line="${timestamp} LISTEN=${listen_count} ESTAB=${estab_count} EXPOSED=${exposed_count} SUSPICIOUS=${suspicious_count} CLASS=${class_state}"

    echo "$line" | tee -a "$OUT_FILE"

    sleep "$INTERVAL"
done
