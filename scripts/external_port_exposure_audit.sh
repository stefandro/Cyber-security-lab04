
set -uo pipefail

EXPECTED_PORTS=(5000 6000)

TARGET="${1:-$(hostname -I | awk '{print $1}')}"
[[ -z "$TARGET" ]] && TARGET="127.0.0.1"

if ! command -v nmap >/dev/null 2>&1; then
    echo "ERROR: nmap is not installed."
    exit 1
fi

mapfile -t OPEN_PORTS < <(
    nmap -n -Pn -p- "$TARGET" 2>/dev/null \
    | awk '/^[0-9]+\/tcp[[:space:]]+open/ {split($1,a,"/"); print a[1]}' \
    | sort -n
)

UNEXPECTED=()

for port in "${OPEN_PORTS[@]}"; do
    allowed=0
    for expected in "${EXPECTED_PORTS[@]}"; do
        if [[ "$port" == "$expected" ]]; then
            allowed=1
            break
        fi
    done
    (( allowed == 0 )) && UNEXPECTED+=("$port")
done

if (( ${#UNEXPECTED[@]} == 0 )); then
    echo "NO UNEXPECTED EXPOSED PORTS"
else
    for p in "${UNEXPECTED[@]}"; do
        echo "EXPOSED PORT: $p"
    done
fi

echo "UNEXPECTED EXPOSED PORT COUNT: ${#UNEXPECTED[@]}"
