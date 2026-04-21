set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORTS_DIR="${BASE_DIR}/reports"

EXTERNAL_SCRIPT="${SCRIPT_DIR}/external_port_exposure_audit.sh"
LISTEN_SCRIPT="${SCRIPT_DIR}/listening_service_audit.sh"
ESTAB_SCRIPT="${SCRIPT_DIR}/established_connection_audit.sh"
SUSPICIOUS_SCRIPT="${SCRIPT_DIR}/suspicious_remote_connection_audit.sh"
CLASSIFIER_SCRIPT="${SCRIPT_DIR}/network_incident_classifier.sh"

SNAPSHOT_SCRIPT="${SCRIPT_DIR}/network_snapshot.sh"
MISSION_REPORT_SCRIPT="${SCRIPT_DIR}/mission_network_security_report.sh"

MODE="${1:-single}"
INTERVAL="${2:-10}"

mkdir -p "$REPORTS_DIR"

usage() {
    cat <<EOF
Usage:
  ./network_security_pipeline.sh single
  ./network_security_pipeline.sh monitor <interval_seconds>
  ./network_security_pipeline.sh snapshot
  ./network_security_pipeline.sh report
EOF
}

timestamp_human() {
    date '+%Y-%m-%d %H:%M:%S'
}

timestamp_file() {
    date '+%y-%m-%d-%H-%M-%S'
}

validate_script() {
    local script_path="$1"
    local label="$2"
    local required="${3:-yes}"

    if [[ ! -f "$script_path" ]]; then
        if [[ "$required" == "yes" ]]; then
            echo "ERROR: missing required script: $label ($script_path)" >&2
            return 1
        else
            echo "WARNING: optional script not found: $label ($script_path)" >&2
            return 0
        fi
    fi

    if [[ ! -x "$script_path" ]]; then
        chmod +x "$script_path" 2>/dev/null || true
    fi

    if [[ ! -x "$script_path" ]]; then
        if [[ "$required" == "yes" ]]; then
            echo "ERROR: script is not executable: $label ($script_path)" >&2
            return 1
        else
            echo "WARNING: optional script is not executable: $label ($script_path)" >&2
            return 0
        fi
    fi

    return 0
}

validate_dependencies() {
    validate_script "$EXTERNAL_SCRIPT" "external_port_exposure_audit.sh" yes || return 1
    validate_script "$LISTEN_SCRIPT" "listening_service_audit.sh" yes || return 1
    validate_script "$ESTAB_SCRIPT" "established_connection_audit.sh" yes || return 1
    validate_script "$SUSPICIOUS_SCRIPT" "suspicious_remote_connection_audit.sh" yes || return 1
    validate_script "$CLASSIFIER_SCRIPT" "network_incident_classifier.sh" yes || return 1

    validate_script "$SNAPSHOT_SCRIPT" "network_snapshot.sh" no || true
    validate_script "$MISSION_REPORT_SCRIPT" "mission_network_security_report.sh" no || true
}

extract_count_from_text() {
    local text="$1"
    local pattern="$2"

    printf '%s\n' "$text" | awk -F': ' -v p="$pattern" '
        $0 ~ p {print $2+0; found=1}
        END {if (!found) print 0}
    '
}

extract_classification_from_text() {
    local text="$1"

    printf '%s\n' "$text" | awk -F': ' '
        /FINAL INCIDENT CLASSIFICATION/ {print $2; found=1}
        END {if (!found) print "UNKNOWN"}
    '
}

run_script_capture() {
    local script_path="$1"
    bash "$script_path" 2>/dev/null || true
}

collect_core_outputs() {
    EXTERNAL_OUT="$(run_script_capture "$EXTERNAL_SCRIPT")"
    LISTEN_OUT="$(run_script_capture "$LISTEN_SCRIPT")"
    ESTAB_OUT="$(run_script_capture "$ESTAB_SCRIPT")"
    SUSPICIOUS_OUT="$(run_script_capture "$SUSPICIOUS_SCRIPT")"
    CLASSIFIER_OUT="$(run_script_capture "$CLASSIFIER_SCRIPT")"

    LISTEN_COUNT="$(extract_count_from_text "$LISTEN_OUT" "LISTENING SERVICE COUNT")"
    ESTAB_COUNT="$(extract_count_from_text "$ESTAB_OUT" "ESTABLISHED CONNECTION COUNT")"
    EXPOSED_COUNT="$(extract_count_from_text "$EXTERNAL_OUT" "UNEXPECTED EXPOSED PORT COUNT")"
    SUSPICIOUS_COUNT="$(extract_count_from_text "$SUSPICIOUS_OUT" "SUSPICIOUS REMOTE CONNECTION COUNT")"
    CLASS_STATE="$(extract_classification_from_text "$CLASSIFIER_OUT")"
}

create_snapshot_file() {
    local ts out_file
    ts="$(timestamp_file)"
    out_file="${REPORTS_DIR}/network_snapshot-${ts}.txt"

    if [[ -x "$SNAPSHOT_SCRIPT" ]]; then
        bash "$SNAPSHOT_SCRIPT" > "$out_file" 2>/dev/null || true
        if [[ -s "$out_file" ]]; then
            echo "$out_file"
            return
        fi
    fi

    rm -f "$out_file"
    echo "NOT GENERATED"
}

create_report_file() {
    local output report_path
    if [[ ! -x "$MISSION_REPORT_SCRIPT" ]]; then
        echo "NOT GENERATED"
        return
    fi

    output="$(bash "$MISSION_REPORT_SCRIPT" 2>/dev/null || true)"
    report_path="$(printf '%s\n' "$output" | awk -F': ' '/REPORT SAVED TO/ {print $2; exit}')"

    if [[ -n "$report_path" ]]; then
        echo "$report_path"
    else
        echo "NOT GENERATED"
    fi
}

write_single_summary() {
    local out_file snapshot_ref report_ref
    out_file="${REPORTS_DIR}/network_security_pipeline-single-$(timestamp_file).txt"

    snapshot_ref="NOT GENERATED"
    report_ref="NOT GENERATED"

    if [[ -x "$SNAPSHOT_SCRIPT" ]]; then
        snapshot_ref="$(create_snapshot_file)"
    fi

    cat > "$out_file" <<EOF
=== NETWORK SECURITY PIPELINE ===
TIME: $(timestamp_human)
MODE: single

[SUMMARY]
LISTENING SERVICES: $LISTEN_COUNT
ESTABLISHED CONNECTIONS: $ESTAB_COUNT
UNEXPECTED EXPOSED PORTS: $EXPOSED_COUNT
SUSPICIOUS REMOTE CONNECTIONS: $SUSPICIOUS_COUNT
FINAL INCIDENT CLASSIFICATION: $CLASS_STATE

[MODULE OUTPUTS]
--- external_port_exposure_audit.sh ---
$EXTERNAL_OUT

--- listening_service_audit.sh ---
$LISTEN_OUT

--- established_connection_audit.sh ---
$ESTAB_OUT

--- suspicious_remote_connection_audit.sh ---
$SUSPICIOUS_OUT

--- network_incident_classifier.sh ---
$CLASSIFIER_OUT

[REFERENCES]
SNAPSHOT FILE: $snapshot_ref
MISSION REPORT FILE: $report_ref

[FINAL STATUS]
PIPELINE COMPLETED SUCCESSFULLY
EOF

    cat "$out_file"
    echo
    echo "PIPELINE OUTPUT SAVED TO: $out_file"
}

write_snapshot_mode() {
    local snapshot_ref out_file
    out_file="${REPORTS_DIR}/network_security_pipeline-snapshot-$(timestamp_file).txt"
    snapshot_ref="$(create_snapshot_file)"

    cat > "$out_file" <<EOF
=== NETWORK SECURITY PIPELINE ===
TIME: $(timestamp_human)
MODE: snapshot

[REFERENCES]
SNAPSHOT FILE: $snapshot_ref

[FINAL STATUS]
PIPELINE COMPLETED SUCCESSFULLY
EOF

    cat "$out_file"
    echo
    echo "PIPELINE OUTPUT SAVED TO: $out_file"
}

write_report_mode() {
    local report_ref out_file
    out_file="${REPORTS_DIR}/network_security_pipeline-report-$(timestamp_file).txt"
    report_ref="$(create_report_file)"

    cat > "$out_file" <<EOF
=== NETWORK SECURITY PIPELINE ===
TIME: $(timestamp_human)
MODE: report

[REFERENCES]
MISSION REPORT FILE: $report_ref

[FINAL STATUS]
PIPELINE COMPLETED SUCCESSFULLY
EOF

    cat "$out_file"
    echo
    echo "PIPELINE OUTPUT SAVED TO: $out_file"
}

write_monitor_mode() {
    local out_file
    out_file="${REPORTS_DIR}/network_security_pipeline-monitor-$(timestamp_file).txt"

    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -le 0 ]]; then
        echo "ERROR: monitor interval must be a positive integer." >&2
        exit 1
    fi

    echo "Monitoring pipeline started."
    echo "Interval: ${INTERVAL}s"
    echo "Output file: $out_file"
    echo "Press Ctrl+C to stop safely."

    trap 'echo; echo "Monitoring pipeline stopped safely."; exit 0' INT TERM

    while true; do
        collect_core_outputs

        {
            echo "=== PIPELINE ITERATION ==="
            echo "TIME: $(timestamp_human)"
            echo "LISTENING SERVICES: $LISTEN_COUNT"
            echo "ESTABLISHED CONNECTIONS: $ESTAB_COUNT"
            echo "UNEXPECTED EXPOSED PORTS: $EXPOSED_COUNT"
            echo "SUSPICIOUS REMOTE CONNECTIONS: $SUSPICIOUS_COUNT"
            echo "FINAL INCIDENT CLASSIFICATION: $CLASS_STATE"
            echo
        } | tee -a "$out_file"

        sleep "$INTERVAL"
    done
}

main() {
    validate_dependencies || exit 1

    case "$MODE" in
        single)
            collect_core_outputs
            write_single_summary
            ;;
        monitor)
            write_monitor_mode
            ;;
        snapshot)
            write_snapshot_mode
            ;;
        report)
            write_report_mode
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main
