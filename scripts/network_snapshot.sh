set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LISTEN_SCRIPT="${SCRIPT_DIR}/listening_service_audit.sh"
ESTAB_SCRIPT="${SCRIPT_DIR}/established_connection_audit.sh"
EXPOSED_SCRIPT="${SCRIPT_DIR}/external_port_exposure_audit.sh"
SUSPICIOUS_SCRIPT="${SCRIPT_DIR}/suspicious_remote_connection_audit.sh"
CLASSIFIER_SCRIPT="${SCRIPT_DIR}/network_incident_classifier.sh"

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

top_process_by_established() {
    local result

    result="$(
        ss -H -tnp state established 2>/dev/null | awk '
        {
            proc = "-"
            pid = "-"

            if (match($0, /users:\(\("([^"]+)"/, a)) proc = a[1]
            if (match($0, /pid=([0-9]+)/, b)) pid = b[1]

            key = proc "/" pid
            count[key]++
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

timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
listen_count="$(extract_count "$LISTEN_SCRIPT" "LISTENING SERVICE COUNT")"
estab_count="$(extract_count "$ESTAB_SCRIPT" "ESTABLISHED CONNECTION COUNT")"
exposed_count="$(extract_count "$EXPOSED_SCRIPT" "UNEXPECTED EXPOSED PORT COUNT")"
suspicious_count="$(extract_count "$SUSPICIOUS_SCRIPT" "SUSPICIOUS REMOTE CONNECTION COUNT")"
classification="$(extract_classification)"
top_process="$(top_process_by_established)"

echo "=== NETWORK SNAPSHOT ==="
echo "TIME: $timestamp"
echo "LISTENING SERVICES: $listen_count"
echo "ESTABLISHED CONNECTIONS: $estab_count"
echo "UNEXPECTED EXPOSED PORTS: $exposed_count"
echo "SUSPICIOUS REMOTE CONNECTIONS: $suspicious_count"
echo "TOP PROCESS BY ESTABLISHED CONNECTIONS: $top_process"
echo "CLASSIFICATION: $classification"
