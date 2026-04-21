#!/bin/bash

set -u

PID_FILE="network_simulation_pids.txt"

echo "Starting network simulation..."

# Clear old PID file
> "$PID_FILE"

store_pid() {
  echo "$1" >> "$PID_FILE"
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

cleanup_old_processes() {
  if [ -f "$PID_FILE" ]; then
    echo "Previous PID file detected. Attempting cleanup first..."
    while read -r pid; do
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
    > "$PID_FILE"
  fi
}

start_listener_nc() {
  local port="$1"
  # Persistent listener loop
  (
    while true; do
      nc -l 127.0.0.1 "$port" >/dev/null 2>&1
      sleep 1
    done
  ) &
  store_pid "$!"
}

start_listener_python() {
  local port="$1"
  (
    while true; do
      python3 - <<PY
import socket
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", $port))
s.listen(1)
conn, addr = s.accept()
try:
    conn.recv(1024)
except Exception:
    pass
conn.close()
s.close()
PY
      sleep 1
    done
  ) &
  store_pid "$!"
}

start_listener() {
  local port="$1"
  if have_command nc; then
    start_listener_nc "$port"
  elif have_command python3; then
    start_listener_python "$port"
  else
    echo "ERROR: neither nc nor python3 is available."
    exit 1
  fi
}

start_local_client_nc() {
  local host="$1"
  local port="$2"
  local interval="$3"
  (
    while true; do
      echo "ping" | nc "$host" "$port" >/dev/null 2>&1
      sleep "$interval"
    done
  ) &
  store_pid "$!"
}

start_local_client_python() {
  local host="$1"
  local port="$2"
  local interval="$3"
  (
    while true; do
      python3 - <<PY
import socket
try:
    s = socket.socket()
    s.settimeout(1)
    s.connect(("$host", $port))
    s.sendall(b"ping")
    s.close()
except Exception:
    pass
PY
      sleep "$interval"
    done
  ) &
  store_pid "$!"
}

start_local_client() {
  local host="$1"
  local port="$2"
  local interval="$3"
  if have_command nc; then
    start_local_client_nc "$host" "$port" "$interval"
  elif have_command python3; then
    start_local_client_python "$host" "$port" "$interval"
  else
    echo "ERROR: neither nc nor python3 is available."
    exit 1
  fi
}

start_external_client_nc() {
  local host="$1"
  local port="$2"
  local interval="$3"
  (
    while true; do
      nc -w 1 "$host" "$port" < /dev/null > /dev/null 2>&1
      sleep "$interval"
    done
  ) &
  store_pid "$!"
}

start_external_client_python() {
  local host="$1"
  local port="$2"
  local interval="$3"
  (
    while true; do
      python3 - <<PY
import socket
try:
    s = socket.socket()
    s.settimeout(1)
    s.connect(("$host", $port))
    s.close()
except Exception:
    pass
PY
      sleep "$interval"
    done
  ) &
  store_pid "$!"
}

start_external_client() {
  local host="$1"
  local port="$2"
  local interval="$3"
  if have_command nc; then
    start_external_client_nc "$host" "$port" "$interval"
  elif have_command python3; then
    start_external_client_python "$host" "$port" "$interval"
  else
    echo "ERROR: neither nc nor python3 is available."
    exit 1
  fi
}

cleanup_old_processes

echo "Starting expected listening services..."
start_listener 5000
start_listener 6000

echo "Starting unexpected listening service..."
start_listener 9999

echo "Creating local established connections..."
start_local_client 127.0.0.1 5000 2
start_local_client 127.0.0.1 9999 3

echo "Creating non-local outbound communication..."
# A simple external target that commonly accepts TCP/80
start_external_client 1.1.1.1 80 5

echo "Starting CPU-heavy process..."
yes > /dev/null &
store_pid "$!"

echo "----------------------------------------"
echo "Network simulation started."
echo "Expected listening ports: 5000, 6000"
echo "Unexpected exposed port: 9999"
echo "Suspicious outbound target: 1.1.1.1:80"
echo "PID file: $PID_FILE"
echo "Use ./stop_network_simulation.sh to stop the simulation."
echo "----------------------------------------"
