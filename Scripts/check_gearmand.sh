#!/bin/bash
##
## Stupid simple check status of gearman and alert if it fails.
## Version 1.01
## By the mad eyes of Neil


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

timeout 30 gearadmin --status
if [ $? -eq 124 ]; then
    echo "FAIL:  gearmand failed with error 124, `gearadmin --getpid`"
    exit $STATE_CRITICAL
else 
    echo "OK:  Gearmand is working properly"
    exit $STATE_OK
fi
