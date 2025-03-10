#!/usr/bin/perl

use strict;

use WWW::Curl::Easy;

my $curl = WWW::Curl::Easy->new;

my $DEBUG = 0;
if(defined($ARGV[0])) {
  if($ARGV[0]) {
    $DEBUG = 1;
  }
}
#Dirty duplicate of vars and code done for quick change of check
#my $url = 'https://my.siproutes.com/charts/11351/avg_rate_per_minute/';
my $url = 'https://lcr.thinq.com/charts/11351/avg_rate_per_minute/';
my $url2 = 'https://lcr.thinq.com/charts/11351/daily_spend/';
my $raw = "";
my $raw2 = "";

my $value = 0;
my $value2 = 0;

# average value returned should be between 0.004 and 0.006
my $warn = 0.010;
my $crit = 0.015;

$curl->setopt(CURLOPT_HEADER,1);
$curl->setopt(CURLOPT_URL, $url);
# old perl is old
open(my $fileb, ">", \$raw);

$curl->setopt(CURLOPT_WRITEDATA,$fileb);

my $retcode = $curl->perform;
my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);

if ( ($retcode != 0) || ($response_code != 200) ) {
  # failed to get updated data
  print "WARNING: Unable to retrieve siproute data [$retcode]:[$response_code]\n";
  exit 1;
}

$curl->setopt(CURLOPT_URL, $url2);
# old perl is old
open(my $fileb2, ">", \$raw2);

$curl->setopt(CURLOPT_WRITEDATA,$fileb2);

my $retcode2 = $curl->perform;
my $response_code2 = $curl->getinfo(CURLINFO_HTTP_CODE);

if ( ($retcode2 != 0) || ($response_code2 != 200) ) {
  # failed to get updated data
  print "WARNING: Unable to retrieve siproute data [$retcode]:[$response_code]\n";
  exit 1;
}

# if we're here we have to actually, you know, work :(
if($raw =~ /set label\=\"Avg\" value=\"(.*)\"\/\>\<\/chart/) {
  $value = $1;
} else {
  if($DEBUG) { print STDERR "Parse error, unable to determine current value\n[$raw]\n"; }
  print "WARNING: Parse error, unable to determine siproute value\n";
  exit 1;
}
if($raw2 =~ /<set value\=\"([\d\.]*)\"\/\>\<\/dataset\>\<\/chart/) {
  $value2 = $1;
} else {
  if($DEBUG) { print STDERR "Parse error, unable to determine current value\n[$raw2]\n"; }
  print "WARNING: Parse error, unable to determine siproute value\n";
  exit 1;
}
if($value >= $crit) {
  print "CRITICAL: siproute average $value, compromise! today $value2 | average=$value\n";
  exit 2;
}
if($value >= $warn) {
  print "WARNING: siproute average $value, possibly compromised. today $value2 | average=$value\n";
  exit 1;
}
print "OK: siproute average $value Spent today $value2| average=$value\n";
exit 0;