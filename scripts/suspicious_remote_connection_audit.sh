set -uo pipefail

OUTPUT="$(
ss -H -tnp state established 2>/dev/null | awk '
function extract_ip(endpoint, ep) {
    ep = endpoint

    # IPv6 in brackets, e.g. [::1]:443
    if (ep ~ /^\[.*\]:[0-9*]+$/) {
        sub(/^\[/, "", ep)
        sub(/\]:[0-9*]+$/, "", ep)
        return ep
    }

    # IPv4 / host style, e.g. 127.0.0.1:5000
    sub(/:[0-9*]+$/, "", ep)
    return ep
}

function extract_port(endpoint, ep, arr) {
    ep = endpoint

    # bracketed IPv6, e.g. [::1]:443
    if (match(ep, /\]:([0-9*]+)$/, arr)) return arr[1]

    # generic :port at end
    if (match(ep, /:([0-9*]+)$/, arr)) return arr[1]

    return "-"
}

{
    proc = "-"
    pid = "-"
    remote_ep = "-"
    remote_ip = "-"
    remote_port = "-"

    # Find first two endpoint-like tokens; second one is remote endpoint
    n = 0
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^\[.*\]:[0-9*]+$/ || $i ~ /^[^[:space:]]+:[0-9*]+$/) {
            n++
            ep[n] = $i
        }
    }

    if (n >= 2) {
        remote_ep = ep[2]
        remote_ip = extract_ip(remote_ep)
        remote_port = extract_port(remote_ep)
    }

    if (match($0, /users:\(\("([^"]+)"/, a)) proc = a[1]
    if (match($0, /pid=([0-9]+)/, b)) pid = b[1]

    if (remote_ip != "-" && remote_ip != "127.0.0.1" && remote_ip != "::1") {
        print "SUSPICIOUS CONNECTION: " proc " " pid " -> " remote_ip ":" remote_port
    }

    delete ep
}'
)"

if [[ -z "$OUTPUT" ]]; then
    echo "NO SUSPICIOUS REMOTE CONNECTIONS DETECTED"
    echo "SUSPICIOUS REMOTE CONNECTION COUNT: 0"
    exit 0
fi

printf '%s\n' "$OUTPUT"
echo "SUSPICIOUS REMOTE CONNECTION COUNT: $(printf '%s\n' "$OUTPUT" | wc -l)"
