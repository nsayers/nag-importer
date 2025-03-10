#!/bin/bash
##
## Stupid check status of gearman for orphaned checks and warn if above 1 but go critical above 4
## Version 1.01
## By the mad eyes of Neil


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

line_count=$(grep -ir 'service check orphaned' /var/spool/nagios/status.dat | wc -l)
if [ "$line_count" -gt 5 ]; then
    echo "CRITICAL:  gearmand has too many orphaned checks"
    exit $STATE_CRITICAL
elif [ "$line_count" -gt 1 ] && [ "$line_count" -lt 4 ]; then
    echo "WARNING:  gearmand has orphaned checks"
    exit $STATE_CRITICAL
else 
    echo "OK:  Gearmand working as intended"
    exit $STATE_OK
fi
