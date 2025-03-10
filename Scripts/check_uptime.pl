#!/usr/bin/perl -w
  
  use strict;
  my $proc_uptime = "/proc/uptime";
  my $exitcode; 
  my $state;
  
  if (@ARGV == 0) {
    die "Usage: check_uptime.pl UPTIME_MINUTES\n";
  }
  
  # Uptime limit, in minutes, set by command line argument.
  my $num = sprintf("%d", $ARGV[0]);
  $num += 0;
  my $limit = $num * 60;
  
  open(UT, $proc_uptime);
  my $procup = <UT>;
  close(UT);
  
  chomp $procup;
  $procup =~ s/\.[0-9]{2}\s+.*//;
  
  my $days = int( $procup / 86400 );
  my $seconds = $procup % 86400;
  my $hours = int( $seconds / 3600 );
  $seconds = $procup % 3600;
  my $minutes = int( $seconds / 60 );
  $seconds = $procup % 60;
  
  my $uptime = "$days day" . ($days > 1 ? "s" : "") if $days;
  $uptime .= "" . ($days ? ", " : "") . "$hours hr" . ($hours > 1 ? "s" : "") if $hours;
  $uptime .= "" . ($days || $hours ? ", " : "") . "$minutes min" . ($minutes > 1 ? "s" : "") if $minutes;
  $uptime .= "" . ($days || $hours || $minutes ? ", " : "") . "$seconds sec" . ($procup > 1 ? "s" : "") if $procup;
  
  # No warning.  It's either less than limit, or more than limit.
  if (($procup <= $limit) && ($procup > 0)) {
    print "CRITICAL: Rebooted! Uptime is less than $limit secs ($procup = $uptime)\n";
    $exitcode = 2;
  } elsif ($procup > $limit) {
    print "OK: Uptime exceeds $limit secs ($procup = $uptime)\n";
    $exitcode = 0;
  } else {
    print "UNKNOWN: Something odd happened. Uptime is $procup seconds\n";
    $exitcode = 3;
  }
  
  exit($exitcode);

