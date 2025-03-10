#!/usr/bin/perl -w

use strict;
use Net::POP3;
use Getopt::Long;
&Getopt::Long::config('auto_abbrev');
$| = 1;

my %ERRORS = ('UNKNOWN' , '-1',
              'OK' , '0',
              'WARNING', '1',
              'CRITICAL', '2');

my $hostname = '';
my $username = '';
my $password = '';
my $verbose = 1;
my $result = -1;

my $status = GetOptions("hostname=s" => \$hostname,
                        "username=s" => \$username,
                        "password=s" => \$password,
                        "verbose!"   => \$verbose);

if (($status == 0) or (not $hostname) or (not $username) or (not $password))
{
    print "Usage: check_pop3_auth [options]\n";
    print "        -h, --hostname=           hostname\n";
    print "        -u, --username=           username\n";
    print "        -p, --password=           password\n";
    print "        --verbose                 show status output (default)\n";
    print "        --noverbose               show 1 line status\n";
    exit;
}

$verbose and print "Connecting to $hostname...\n";
my $timeout = 10;
my $pop3 = Net::POP3->new($hostname, Timeout => $timeout);

if (not defined $pop3) {
    print "Failed to connect in $timeout seconds\n";
    exit $ERRORS{'CRITICAL'};
}
$verbose and print "Logging in as: $username...\n";
$result = $pop3->login($username,$password);

if ($result) {
    $result = $ERRORS{'OK'};
    print "OK\n";
} else {
    $result = $ERRORS{'CRITICAL'};
    print "CRITICAL\n";
}
$pop3->quit;
exit $result;
