#!/usr/bin/perl  -w

use strict;

##
#   check_radius2
#   NetSaint modifications by Steve Milton (milton@isomedia.com)
#
#   syntax:  check_radius2 server:port username password secret
#
#   eg: radtest  radtest st\$cky cuttlefish:1645 1645 elephant
#
#####################
#
############################
## Variables customization #  overrides values in the nocollib.pl library
############################
my $prog =  "/etc/ISOMEDIA/nagios/plugins/radcheck2.pl" ;       # location of 'radtest'

############################

-x $prog || die("Could not find executable $prog, exiting");

my %ERRORS=('DEPENDENT'=>4,'UNKNOWN'=>3,'OK'=>0,'WARNING'=>1,'CRITICAL'=>2);
my $serverport = $ARGV[0];
my $username = $ARGV[1];
my $password = $ARGV[2];
my $secret = $ARGV[3];

my $retval = $ERRORS{'UNKNOWN'};
my $msg = "RADIUS UNKNOWN no message set.";

my $execres = `$prog -u $username -p '$password' -r $serverport -s $secret`;
my $auth_cnt = 0;
my $fail_cnt = 0;

if ($execres =~ /AUTHENTICATED/) {
    $auth_cnt++;
} else {
    $fail_cnt++;
}

my $cnt = "($auth_cnt/$fail_cnt)";

if($execres =~ /AUTHENTICATED/) {
    $msg = "RADIUS OK auth verified. $cnt";
    $retval = $ERRORS{'OK'};
} elsif($execres =~ /FAILED/) {
    if($execres =~ /Reply-Message/) {
        $msg = "RADIUS WARNING server replied incorrectly. $cnt";
        $retval = $ERRORS{'WARNING'};
    } else {
        $msg = "RADIUS CRITICAL auth server down. $cnt";
        $retval = $ERRORS{'CRITICAL'};
    }
} else {
    $msg = "RADIUS CRITICAL invalid response from radcheck. $cnt";
    $retval = $ERRORS{'CRITICAL'};
}

print $msg, "\n";
exit $retval;