
set -uo pipefail

OUTPUT="$(
{
    ss -H -ltnp 2>/dev/null | awk '
    {
        proto = "tcp"
        local_ep = $4
        proc = "-"
        pid = "-"

        if (match($0, /users:\(\("([^"]+)"/, a)) proc = a[1]
        if (match($0, /pid=([0-9]+)/, b)) pid = b[1]

        print "LISTENING SERVICE: " proto " " local_ep " " proc " " pid
    }'

    ss -H -lunp 2>/dev/null | awk '
    {
        proto = "udp"
        local_ep = $4
        proc = "-"
        pid = "-"

        if (match($0, /users:\(\("([^"]+)"/, a)) proc = a[1]
        if (match($0, /pid=([0-9]+)/, b)) pid = b[1]

        print "LISTENING SERVICE: " proto " " local_ep " " proc " " pid
    }'
}
)"

if [[ -z "$OUTPUT" ]]; then
    echo "NO LISTENING SERVICES DETECTED"
    echo "LISTENING SERVICE COUNT: 0"
    exit 0
fi

printf '%s\n' "$OUTPUT"
echo "LISTENING SERVICE COUNT: $(printf '%s\n' "$OUTPUT" | wc -l)"
