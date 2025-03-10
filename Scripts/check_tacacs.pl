#!/usr/bin/perl

##
# sudo yum install perl-Net-Telnet telnet cpan
# cpan install Net::Telnet::Cisco
##

use strict;
use Net::Telnet::Cisco; # for cisco router/switches
my $cmd = 'show version';
my $host = 'red-core.isomedia.com';
my $session = Net::Telnet::Cisco->new(Host => $host,
                                      errmode => 'return',
                                      timeout => '3',
                                      );
#$session->errmode('return');
if ($session->login('tacacs_check', '3r0d3s')) {
    $session->close;
    print "OK: Login Successful to $host\n";
    exit(0);
} else {
    print "CRITICAL: Login FAILED to $host\n";
    exit(2);
}
print "UNKNOWN: Login FAILED to $host\n";
exit(1);