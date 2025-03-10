#!/bin/bash
# Version 1.01
# By Neil


hostname=`cat /etc/hostname`

if [[ "$hostname" == "$1" ]]; then 
	echo "IP resolving to correct host -" ${hostname%')'}
	exit 0
else 
	echo "IP resolving to wrong host -" ${hostname%')'}
    exit 2
fi