#!/bin/bash
awk '{print $3}' logs/*.log | sort | uniq -c
