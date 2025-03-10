#!/bin/bash
#
# check_rhel_lastupdate.sh
#
# Number of days since last update on RHEL, CentOS or Fedora servers
# Author: Bratislav STOJKOVIC 
# E-mail:bratislav.stojkovic@gmail.com
# Version: 0.2
# Last Modified: September 2013

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo 'Revision: 0.2'`
. $PROGPATH/utils.sh

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

print_usage() {
        echo "Usage: $PROGNAME -u <number_of_updates_thr> -w <warning_thr> -c <critical_thr>"
}

print_revision() {
        echo $PROGNAME $REVISION
        echo ""
        echo "This plugin calculates number of days since last update"
        echo ""
        exit 0
}

if [ $# -eq 1 ] && ([ "$1" == "-h" ] || [ "$1" == "--help" ]); then
        print_usage
        exit "$STATE_OK"
elif [ $# -lt 6 ]; then
        print_usage
        exit "$STATE_OK"
fi

while test -n "$1"; do
case "$1" in
        --help)
                print_usage
                exit 0
                ;;
        -h)
                print_usage
                exit 0
                ;;
        -V)
                print_revision $PROGNAME $REVISION
                exit 0
                ;;
        -u)
            NOF_UPDATES=$2
            shift
            ;;

        -w)
            WARNING=$2
            shift
            ;;
        -c)
            CRITICAL=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
esac
shift
done

for i in `rpm -qa --queryformat '%{INSTALLTIME}\n' |sort -n `;do  date -d @$i +"%y%m%d";done > /tmp/update_date

TMPDATE1=`cat /tmp/update_date | tail -1`
DATE1=
DATE2=`date +%s`
until [[ -n $DATE1 ]] || [[ -z $TMPDATE1 ]];
   do
   NOF_LINES=`grep $TMPDATE1 /tmp/update_date | wc -l`
#	echo $NOF_LINES
   if [[ "$NOF_UPDATES" -gt "$NOF_LINES" ]]; then
        grep -v "$TMPDATE1" /tmp/update_date > /tmp/update_date_1
        cat /tmp/update_date_1 > /tmp/update_date
        TMPDATE1=`cat /tmp/update_date | tail -1`
   else
        DATE1=`cat /tmp/update_date | tail -1`
        break
        fi
  done
rm -f /tmp/update_date*

if [[ -z "$DATE1" ]]; then
   echo "UNKNOWN: Try to decrease number of last updates parameter (-u)."
   exit $STATE_UNKNOWN
else
  DATE1=`date -d $DATE1 +%s`
  LAST_UPDATE=$(( ($DATE2-$DATE1)/86400 ))
fi
# Check latest kernel thet is applied

KERNEL_INSTALLED=`ls /boot| grep ^vmlinuz| tail -1 | awk -F"vmlinuz-" '{print $2}' | awk -F".x86_64" '{print $1}'`
KERNEL_BOOT=`uname -r| awk -F".x86_64" '{print $1}'`
KERNEL_INSTALLED_BDT=`rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE} %{BUILDTIME}\n'  kernel| grep $KERNEL_INSTALLED | awk '{print $2}'`
KERNEL_BOOT_BDT=`rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE} %{BUILDTIME}\n'  kernel| grep $KERNEL_BOOT | awk '{print $2}'`
KERNEL_INSTALLED_BUILDDATE=`date -d @\$KERNEL_INSTALLED_BDT +%d-%b-%Y`
KERNEL_BOOT_BUILDDATE=`date -d @\$KERNEL_BOOT_BDT +%d-%b-%Y`

if [[ $LAST_UPDATE -gt $CRITICAL ]]; then
   echo "CRITICAL: $LAST_UPDATE days since last update. KERNEL: $KERNEL_BOOT from $KERNEL_BOOT_BUILDDATE"
   exit $STATE_CRITICAL
elif [[ $LAST_UPDATE -gt $WARNING ]]; then
   echo "WARNING: $LAST_UPDATE days since last update. KERNEL: $KERNEL_BOOT from $KERNEL_BOOT_BUILDDATE" 
   exit $STATE_WARNING
elif [[ $LAST_UPDATE -le $WARNING ]] && [[ "$KERNEL_INSTALLED" = "$KERNEL_BOOT" ]]; then
   echo "OK: $LAST_UPDATE days since last update. KERNEL: $KERNEL_BOOT from $KERNEL_BOOT_BUILDDATE"
   exit $STATE_OK
elif [[ $LAST_UPDATE -le $WARNING ]] && [[ "$KERNEL_INSTLLED" != "$KERNEL_BOOT" ]]; then
   echo "CRITICAL: $LAST_UPDATE days since last update. KERNEL: "$KERNEL_INSTALLED" from "$KERNEL_INSTALLED_BUILDDATE", needs restart."
   exit $STATE_CRITICAL
fi
