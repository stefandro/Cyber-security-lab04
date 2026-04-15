#!/bin/bash
awk '
{
    msg=$4
    for(i=5;i<=NF;i++) msg=msg " " $i
    key=FILENAME SUBSEP msg
    if(!seen[key]++) count[msg]++
}
END{
    for (m in count)
        if (count[m] > 1)
            print m
}' logs/*.log | sort
