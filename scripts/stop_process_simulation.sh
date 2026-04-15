#!/bin/bash

echo "Stopping simulated processes..."

for file in /tmp/lab4_sleep.pid /tmp/lab4_loop.pid /tmp/lab4_yes.pid
do
  if [ -f "$file" ]; then
    pid=$(cat "$file")
    kill "$pid" 2>/dev/null
    rm -f "$file"
  fi
done

echo "Simulation stopped."
