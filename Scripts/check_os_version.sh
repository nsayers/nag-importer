#!/bin/bash
# Version 1.01
# By Neil


strversion=`cat /proc/version | awk '{print $3 " : " $0}'`

echo "Kernel -" ${strversion%')'}

exit 0  