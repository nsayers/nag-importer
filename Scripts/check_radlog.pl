#!/bin/perl
use strict;
use DateTime;
use DateTime::Duration;
use DateTime::Format::DateParse;

#Mon Dec 21 14:09:32 2020 : Auth: (100836) Login OK: [lag-1:200.1140/no-good-dirty-rotten-passw0rd] (from client la2-gateway port 0)
#Wed Dec  2 09:59:40 2020 : Auth: (186115) Login incorrect (pap: Cleartext password does not match "known good" password): [lag-1:200.1787/no-good-dirty-rotten-passw0rd] (from client la2-gateway port 0)

open (LAST, "tail -n100 /var/log/radius/radius.log |") or die "failed to tail logfile";
my ($start, $end, %codes, $code, $timestamp);
while (my $line = <LAST>) {
    ($timestamp) = $line =~ /^\S+\s(.*?) : /;

    if ($line =~ /Login OK:/) {
        $code = "SUCCESS";
    } elsif ($line =~ /Login incorrect/) {
        $code = "FAILURE";
    } else {
        $code = "OTHER";
    }

    if ($start eq '') {
        $start = DateTime::Format::DateParse->parse_datetime($timestamp);
    }
    $end = DateTime::Format::DateParse->parse_datetime($timestamp);
    $codes{$code}++;
}
my $elapsed = ($end->epoch - $start->epoch) / 60;
my $success = $codes{'SUCCESS'}/$elapsed;
my $failure = $codes{'FAILURE'}/$elapsed;
my $total = $codes{'SUCCESS'} + $codes{'FAILURE'};

my $exit = 3;
my $status = 'UNKNOWN';
if ($success < 2) {
    $status = 'CRIT';
    $exit = 2;
} elsif ($failure * $elapsed > 60) { # if 60% of sample are failures
    $status = 'WARN';
    $exit = 1;
} else {
    $status = 'OK';
    $exit = 0;
}

printf "%s - RADIUS Success/Fail (%0.1f/%0.1f) per minute | success_rate=%0.1f; fail_rate=%0.1f; total=%i; elapsed=%i\n", $status, $success, $failure, $success, $failure, $total, $elapsed;
exit($exit);