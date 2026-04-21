#!/bin/bash

set -u

PID_FILE="network_simulation_pids.txt"

if [ ! -f "$PID_FILE" ]; then
  echo "No PID file found. Nothing to stop."
  exit 0
fi

echo "Stopping network simulation..."

while read -r pid; do
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    echo "Stopped PID $pid"
  fi
done < "$PID_FILE"

# Give processes a moment to exit cleanly
sleep 1

# Force kill if something is still alive
while read -r pid; do
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    echo "Force-stopped PID $pid"
  fi
done < "$PID_FILE"

rm -f "$PID_FILE"

echo "All simulation processes stopped."
