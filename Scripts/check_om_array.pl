#!/usr/bin/perl -w
#
# Usage similar to :~/ omreport storage vdisk


use strict;
use Getopt::Long qw(GetOptions);

my $bin = "/opt/dell/srvadmin/bin/omreport";
my $exitcode = 0;
my $controller;
my $vdisk;
my $debug;

GetOptions(
    'c=s' => \$controller,
    'd=s' => \$vdisk,
    'v' => \$debug,
#    '?' => sub { HelpMessage() },
)  or die HelpMessage();

if (@ARGV == 0) {
  get_controllers();
}

sub get_controllers {
  $ENV{'LC_ALL'} = 'C';  # Set locale for lvs call
  my @conoutput = `$bin storage controller | grep -E '^ID|Status|Current Controller Mode'`;
  my @controllers;

 print @conoutput
 # for my $conline (@conoutput) {
#
#    if ($conline =~ m#^(?:\s+)?(.*):(.*):(.*):(.*):(.*)#x) {
#      my $con = {
#        'ID'          	=> $1,
#        'Status'        => $2,
#        'Mode'          => $3,
#      };
#      push @controllers, $con;
#    }
#  }

#  return @thinpools;
}

sub HelpMessage {

    print "\n";
    print "NAME\n";
    print "\n";
    print "check_om_array\n";
    print "\n";
    print "SYNOPSIS\n";
    print "\n";
    print "   -c         Controller to test against, if not defined it will check all \n";
    print "   -d         VirtualDisk to test against, if not defined it will check all \n";
    print "   -v         Debug the process of running, but actually run the application\n";
    print "   -?         Print this help\n";
    print "\n\n";
    print " EXAMPLE";
    print " Single config file";
    print " /usr/lib/nagios/plugins/check_om_array.pl -c 0 -d 0 \n";
    print "\n";
    print "VERSION\n";
    print "\n";
    print "1.00\n";
    print "\n";
    exit;
}


  
# No warning.  It's either less than limit, or more than limit.
#if (($procup <= $limit) && ($procup > 0)) {
#  print "CRITICAL: Rebooted! Uptime is less than $limit secs ($procup = $uptime)\n";
#  $exitcode = 2;
#} elsif ($procup > $limit) {
#  print "OK: Uptime exceeds $limit secs ($procup = $uptime)\n";
#  $exitcode = 0;
#} else {
#  print "UNKNOWN: Something odd happened. Uptime is $procup seconds\n";
#  $exitcode = 3;
#}
  
exit($exitcode);

