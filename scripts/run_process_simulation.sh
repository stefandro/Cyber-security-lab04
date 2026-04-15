#!/bin/bash

echo "Starting process simulation..."

# normal processes
sleep 1000 &
echo $! > /tmp/lab4_sleep.pid

bash -c 'while true; do sleep 0.5; done' &
echo $! > /tmp/lab4_loop.pid

# suspicious high CPU process
yes > /dev/null &
echo $! > /tmp/lab4_yes.pid

# additional normal-looking process
bash -c 'sleep 1000' &
echo $! > /tmp/lab4_service.pid

echo "Simulation started."
