set -uo pipefail


OUTPUT="$(
ss -H -tnp state established 2>/dev/null | awk '
{
    local_ep = $5
    remote_ep = $6
    proc = "-"
    pid = "-"

    if (match($0, /users:\(\("([^"]+)"/, a)) proc = a[1]
    if (match($0, /pid=([0-9]+)/, b)) pid = b[1]

    print "ESTABLISHED CONNECTION: " local_ep " -> " remote_ep " " proc " " pid
}'
)"

if [[ -z "$OUTPUT" ]]; then
    echo "NO ESTABLISHED CONNECTIONS DETECTED"
    echo "ESTABLISHED CONNECTION COUNT: 0"
    exit 0
fi

printf '%s\n' "$OUTPUT"
echo "ESTABLISHED CONNECTION COUNT: $(printf '%s\n' "$OUTPUT" | wc -l)"
