#!/usr/bin/perl  -w

use strict;

##
#   check_radius4
#   NetSaint modifications by Steve Milton (milton@isomedia.com)
#
#   Nagios/radclient re-write November 2020
#
#   syntax:  check_radius4 server[:port] username password secret
#
#   eg: check_radius4 mcp-vip.la2.isofusion.com:1812 nagios nagios password
#
##

my $prog =  "/usr/bin/radclient" ;  # location of 'radclient'

############################

-x $prog || die("Could not find executable $prog, exiting");

my %ERRORS=('DEPENDENT'=>4,'UNKNOWN'=>3,'OK'=>0,'WARNING'=>1,'CRITICAL'=>2);

my $serverport = $ARGV[0];
my $username = $ARGV[1];
my $password = $ARGV[2];
my $secret = $ARGV[3];

my $retval = $ERRORS{'UNKNOWN'};
my $msg = "RADIUS UNKNOWN no message set.";

my $execres = `echo "User-Name='$username', User-Password='$password', NAS-Port-Id='$username'" | $prog $serverport auth $secret`;

if($execres =~ /Received Access-Accept/) {
    $msg = "RADIUS OK auth verified.";
    $retval = $ERRORS{'OK'};
} elsif($execres =~ /Received Access-Reject/) {
    $msg = "RADIUS WARNING auth denied.";
    $retval = $ERRORS{'WARNING'};
} else {
    $msg = "RADIUS CRITICAL invalid response from radcheck.";
    $retval = $ERRORS{'CRITICAL'};
}

print $msg, "\n";
exit $retval;