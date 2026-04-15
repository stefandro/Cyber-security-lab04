#!/bin/bash
awk '$3!="INFO"{print; c++} END{print "Total non-INFO entries: " c+0}' logs/*.log
