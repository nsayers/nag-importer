#!/usr/bin/perl -w

# Much of this code was poached from Hannes Schulz <mail@hannes-schulz.de>

use strict;
use Net::DNS;
use Getopt::Long;
use Pod::Usage;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

my ($host,$server,$timeout,$wlevel,$clevel,$expect) = ('isomedia.com','207.115.64.172',10,1500,3000,'.');

GetOptions(
    "H=s" => \$host,
    "s=s" => \$server,
    "t=i" => \$timeout,
    "w=i" => \$wlevel,
    "c=i" => \$clevel,
    "a=s" => \$expect
    );

# Set the Alarm
if (!$timeout) { $timeout=10 };
alarm($timeout);
$SIG{ALRM} = sub { print "FAIL: $host \@$server timed out.\n"; exit 2; };

# Do some command line options checking
if (!$server || !$host || !$wlevel || !$clevel || !$expect) {
    print "$0: Not enough arguments.\n";
    exit 3;  # Nagios: unknown
}
if($wlevel>=$clevel){
    print "$0: wlevel is greater clevel!\n";
    exit 3;  # Nagios: unknown
}

# Initialize the DNS Resolver
my $res = Net::DNS::Resolver->new(
                                  nameservers => [$server],
                                  recurse     => 1,
                                  debug       => 0
                                  );

# Start and End time
my ($t0, $t1);

# Get Start Time
$t0 = [gettimeofday];

# Perform the lookup
my $answer = $res->send($host);

# Get End Time
$t1 = [gettimeofday];

# Calculate time elapsed
my $elapsed = int (1000 * tv_interval ( $t0, $t1));

# Generate answer
my $wasok = ($answer->{header}->{rcode} eq "NOERROR");
my $out = $answer->{header}->{rcode} . " (took $elapsed ms) | DurationMS=". $elapsed."\n";

my $rr;
my $got_expected = 0;
my $wrong = '';
my $expect_regex = $expect;
$expect_regex =~ s/\./\\./g;

# Check to see if we got the expected response
foreach $rr ($answer->answer) {
    if ($rr->type eq 'A') {
        if ($rr->address =~ /$expect/i) { $got_expected = 1; }
        else { $wrong .= $rr->address . ' '; }
    }
    if ($rr->type eq 'PTR') {
        if ($rr->ptrdname =~ /$expect/i) { $got_expected = 1; }
        else { $wrong .= $rr->ptrdname . ' '; }
    }
}

if (!$got_expected) {
    print "FAIL: $host \@$server returned wrong answer: $wrong(was expecting $expect)";
    exit 2;
}



# Exit for Nagios
if (!$wasok) { print "FAIL: $host \@$server $out"; exit 2; }            # Nagios: Critical
if ($elapsed > $clevel) { print "FAIL: $host \@$server TOO SLOW: $out"; exit 2; }   # Nagios: Critical
if($elapsed > $wlevel) { print "WARN: $host \@$server TOO SLOW: $out"; exit 1; }   # Nagios: Warning
print "OK: $host \@$server $out";
exit 0;                        # Nagios: OK