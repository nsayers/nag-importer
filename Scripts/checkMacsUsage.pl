#!/usr/bin/perl -w

use strict;
use Data::Dumper;


my $concentrator = "";

if(defined($ARGV[0])) {
  $concentrator = uc($ARGV[0]);
} else {
  print STDERR "Usage: $0 <con_cen_trator_name>\n";
  exit 1;
}

if($concentrator =~ /^(.*)\-MDU$/) {
  $concentrator = $1;
}

# MS_D2_S1, BH_Core_S1 etc
if($concentrator =~ /^[A-Z0-9]{2}\_[A-Z0-9]{2,}\_[A-Z0-9]{2}$/) {
  # SDN or Core
  print "OK: [$concentrator] is not a concentrator\n";
  exit 0;
}

my $now = time();
my $path = '/usr/local/tmp';
my $file = qq{$path/$concentrator.macsusage};
my $data = {};
my $VAR1 = undef; # needed because strict throws a warning on the eval below otherwise

if(! -e $file) {
  print "WARNING: Unrecognized concentrator [$concentrator]\n";
  exit 1;
}
#
#
# file is created/updated every 5 minutes when /usr/local/bin/packetshaping/macDBUpdate.pl runs
#
open(FILE,"$file") or do { print "WARNING: Failed to open $file $!"; exit 1; };
{
  local $/;
  $data = eval <FILE>;
}
close(FILE);

my $updatetime = $data->{'updated'};
my $timestamp = localtime($updatetime);

my $difftime = $now - $updatetime;
# 1 hours since last updated = warn, since it updates every 5 minutes
if( $difftime > 3600) {
  print "CRITICAL: No updates since $timestamp\n";
  exit 2;
}
# 3 hours since last updated = crit
if( $difftime > 10800) {
  print "CRITICAL: No updates since $timestamp\n";
  exit 1;
}

my $status = $data->{'status'};
my $highport = $data->{'highport'};
my $highcount = $data->{'highcount'};
my $critthresh = $data->{'critthresh'};
my $warnthresh = $data->{'warnthresh'};
my $portlimit = $data->{'portlimit'};

my $perf = qq{|usage=$highcount;0;0;0;$critthresh};

if($status eq 'OK') {
  print "OK: High=$highcount used on port: $highport - (Max: $portlimit) All Ports are OK";
  print "$perf\n";
  exit 0;
}

# if we're still here, something is very wrong
# .. and there may be multiple ports with warn/crit status so...


my %warnports = ();
my %critports = ();

%warnports = %{$data->{'warnports'}} if defined($data->{'warnports'});
%critports = %{$data->{'critports'}} if defined($data->{'critports'});

my @WARNING = ();
my @CRITICAL = ();
my $maccount = 0;
my $tcid = 0;
my $x = 1;

foreach my $wport (keys %warnports) {
  next if $wport eq "";
  #next if $wport eq "175"; # bug smash
  if($wport eq "175") {
    next;
  }
  $maccount = $data->{$wport}->{'count'};
  $tcid = $data->{$wport}->{'tcid'};
  push(@WARNING,qq{port:$wport tcid:$tcid macs:$maccount/$critthresh used/max});
}
foreach my $cport (keys %critports) {
  next if $cport eq "";
  #next if $cport eq "175"; # bug smash
  if($cport eq "175") {
    next;
  }
  $maccount = $data->{$cport}->{'count'};
  $tcid = $data->{$cport}->{'tcid'};
  push(@CRITICAL,qq{port:$cport tcid:$tcid macs:$maccount/$critthresh used/max});
}

if( ($#WARNING < 0) && ($#CRITICAL < 0) ) {
  # bug smash
  print "OK: High=$highcount used on port: $highport - (Max: $portlimit) All Ports are OK";
  print "$perf\n";
  exit 0;
} else {
  print STDERR $#WARNING . ":" . $#CRITICAL . "\n";
}

if($status eq 'CRIT') {
  print "CRITICAL: " . join(',',@CRITICAL);
  if($#WARNING > 0) {
    print "( also warning: " . join(',',@WARNING);
  }
  print "$perf\n";
  exit 2;
}
if($status eq 'WARN') {
  print "WARNING: " . join(',',@WARNING) . "$perf\n";
  exit 1;
}
# still here?
print "WARNING: [$status] Joe sucks at perl";
print "$perf\n"; # because sure, why not?
exit 1;