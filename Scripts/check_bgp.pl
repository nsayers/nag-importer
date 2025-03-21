#!/usr/bin/perl
# nagios: +epn
#
# check_bgp - nagios plugin
#
# Copyright (C) 2006 Larry Low
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Report bugs to:  llow0@yahoo.com
#
# Primary MIB reference - BGP4-MIB
#
# Version 0.4
#  - added snmpv3 support
# Version 0.3
#  - fixed $snmp was not checked for being defined
# Version 0.2
#  - added conformed with ePN
#
use strict;
use warnings;
use lib qw(/usr/lib/nagios/plugins /usr/lib64/nagios/plugins);
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
    print ("ERROR: Plugin took too long to complete (alarm)\n");
    exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

$PROGNAME = "check_bgp.pl";
sub print_help ();
sub print_usage ();
use POSIX qw(floor);
sub seconds_to_string($);

my ($opt_h,$opt_V);
my $community = "public";
my $snmp_version = 2;
my ($hostname,$bgppeer);;

use Getopt::Long;
&Getopt::Long::config('bundling');
GetOptions(
    "V"   => \$opt_V,   "version"    => \$opt_V,
    "h"   => \$opt_h,   "help"       => \$opt_h,
    "C=s" => \$community,       "community=s" => \$community,
    "H=s" => \$hostname,        "hostname=s" => \$hostname,
    "p=s" => \$bgppeer, "peer=s" => \$bgppeer,
    "v=i" => \$snmp_version,"snmp_version=i" => \$snmp_version
);
# -h & --help print help
if ($opt_h) { print_help(); exit $ERRORS{'OK'}; }
# -V & --version print version
if ($opt_V) { print_revision($PROGNAME,'$Revision: 0.4 $ '); exit $ERRORS{'OK'}; }
# Invalid hostname print usage
if (!utils::is_hostname($hostname)) { print_usage(); exit $ERRORS{'UNKNOWN'}; }
# No BGP peer specified, print usage
if (!defined($bgppeer)) { print_usage(); exit $ERRORS{'UNKNOWN'}; }

# Setup SNMP object
use Net::SNMP qw(INTEGER OCTET_STRING IPADDRESS OBJECT_IDENTIFIER NULL);
my ($snmp, $snmperror);
if ($snmp_version == 2) {
    ($snmp, $snmperror) = Net::SNMP->session(
        -hostname => $hostname,
        -version => 'snmpv2c',
        -community => $community
    );
} elsif ($snmp_version == 3) {
    my ($v3_username,$v3_password,$v3_protocol,$v3_priv_passphrase,$v3_priv_protocol) = split(":",$community);
    my @auth = ();
    if (defined($v3_password)) { push(@auth,($v3_password =~ /^0x/) ? 'authkey' : 'authpassword',$v3_password); }
    if (defined($v3_protocol)) { push(@auth,'authprotocol',$v3_protocol); }
    if (defined($v3_priv_passphrase)) { push(@auth,($v3_priv_passphrase =~ /^0x/) ? 'privkey' : 'privpassword',$v3_priv_passphrase); }
    if (defined($v3_priv_protocol)) { push(@auth,'privprotocol',$v3_priv_protocol); }

    ($snmp, $snmperror) = Net::SNMP->session(
        -hostname => $hostname,
        -version => 'snmpv3',
        -username => $v3_username,
        @auth
    );
} else {
    ($snmp, $snmperror) = Net::SNMP->session(
        -hostname => $hostname,
        -version => 'snmpv1',
        -community => $community
    );
}

if (!defined($snmp)) {
    print ("UNKNOWN - SNMP error: $snmperror\n");
    exit $ERRORS{'UNKNOWN'};
}

my $state = 'UNKNOWN';
my $output = "$bgppeer status retrieval failed.";
# Begin plugin check code
{
    my $bgpPeerState = "1.3.6.1.2.1.15.3.1.2";
    my $bgpPeerAdminStatus = "1.3.6.1.2.1.15.3.1.3";
    my $bgpPeerRemoteAs = "1.3.6.1.2.1.15.3.1.9";
    my $bgpPeerLastError = "1.3.6.1.2.1.15.3.1.14";
    my $bgpPeerFsmEstablishedTime = "1.3.6.1.2.1.15.3.1.16";

    my %bgpPeerStates = (
        -1 => 'unknown(-1)',
        1 => 'idle(1)',
        2 => 'connect(2)',
        3 => 'active(3)',
        4 => 'opensent(4)',
        5 => 'openconfirm(5)',
        6 => 'established(6)'
    );

    my %bgpPeerAdminStatuses = (
        1=>'stop(1)',
        2=>'start(2)'
    );

    my %bgpErrorCodes = (
        '01 00' => 'Message Header Error',
        '01 01' => 'Message Header Error - Connection Not Synchronized',
        '01 02' => 'Message Header Error - Bad Message Length',
        '01 03' => 'Message Header Error - Bad Message Type',
        '02 00' => 'OPEN Message Error',
        '02 01' => 'OPEN Message Error - Unsupported Version Number',
        '02 02' => 'OPEN Message Error - Bad Peer AS',
        '02 03' => 'OPEN Message Error - Bad BGP Identifier',
        '02 04' => 'OPEN Message Error - Unsupported Optional Parameter',
        '02 05' => 'OPEN Message Error', #deprecated
        '02 06' => 'OPEN Message Error - Unacceptable Hold Time',
        '03 00' => 'UPDATE Message Error',
        '03 01' => 'UPDATE Message Error - Malformed Attribute List',
        '03 02' => 'UPDATE Message Error - Unrecognized Well-known Attribute',
        '03 03' => 'UPDATE Message Error - Missing Well-known Attribute',
        '03 04' => 'UPDATE Message Error - Attribute Flags Error',
        '03 05' => 'UPDATE Message Error - Attribute Length Erro',
        '03 06' => 'UPDATE Message Error - Invalid ORIGIN Attribute',
        '03 07' => 'UPDATE Message Error', #deprecated
        '03 08' => 'UPDATE Message Error - Invalid NEXT_HOP Attribute',
        '03 09' => 'UPDATE Message Error - Optional Attribute Error',
        '03 0A' => 'UPDATE Message Error - Invalid Network Field',
        '03 0B' => 'UPDATE Message Error - Malformed AS_PATH',
        '04 00' => 'Hold Timer Expired',
        '05 00' => 'Finite State Machine Error',
        '06 00' => 'Cease',
        '06 01' => 'Cease - Maximum Number of Prefixes Reached',
        '06 02' => 'Cease - Administrative Shutdown',
        '06 03' => 'Cease - Peer De-configured',
        '06 04' => 'Cease - Administrative Reset',
        '06 05' => 'Cease - Connection Rejected',
        '06 06' => 'Cease - Other Configuration Change',
        '06 07' => 'Cease - Connection Collision Resolution',
        '06 08' => 'Cease - Out of Resources'
    );

    my @snmpoids;
    push (@snmpoids,"$bgpPeerState.$bgppeer");
    push (@snmpoids,"$bgpPeerAdminStatus.$bgppeer");
    push (@snmpoids,"$bgpPeerRemoteAs.$bgppeer");
    push (@snmpoids,"$bgpPeerLastError.$bgppeer");
    push (@snmpoids,"$bgpPeerFsmEstablishedTime.$bgppeer");
    my $result = $snmp->get_request(
        -varbindlist => \@snmpoids
    );
    if (!defined($result)) {
        my $answer = $snmp->error;
        $snmp->close;
        print ("UNKNOWN: SNMP error: $answer\n");
        exit $ERRORS{'UNKNOWN'};
    }

    if ($result->{"$bgpPeerState.$bgppeer"} ne "noSuchInstance") {
        $output = "$bgppeer (AS".
                $result->{"$bgpPeerRemoteAs.$bgppeer"}.
                ") state is ".
                $bgpPeerStates{$result->{"$bgpPeerState.$bgppeer"}};

        my $lasterror;
        my $lasterrorcode = $result->{"$bgpPeerLastError.$bgppeer"};
        if (hex($lasterrorcode) != 0) {
                $lasterrorcode = substr($lasterrorcode,2,2)." ".substr($lasterrorcode,4,2);
                my ($code,$subcode) = split(" ",$lasterrorcode);
                if (!defined($bgpErrorCodes{$lasterrorcode})) {
                        $lasterror = $bgpErrorCodes{"$code 00"};
                } else {
                        $lasterror = $bgpErrorCodes{$lasterrorcode};
                }
                if (!defined($lasterror)) {
                        $lasterror = "Unknown ($code $subcode)";
                }
        }

        my $establishedtime = seconds_to_string($result->{"$bgpPeerFsmEstablishedTime.$bgppeer"});

        if ($result->{"$bgpPeerState.$bgppeer"} == 6) {
                $state = 'OK';
                $output .= ". Established for $establishedtime.";
        } elsif ($result->{"$bgpPeerAdminStatus.$bgppeer"} == 1) { #stop
                $state = 'WARNING'; # admin down do warning
                $output .= " (administratively down). Last established $establishedtime.";
        } else {
                $state = 'CRITICAL';
                $output .= ". Last established $establishedtime.";
        }

        if (defined($lasterror)) {
                $output .= " Last error \"$lasterror\".";
        }
    }
}
print "$state - $output\n";
exit $ERRORS{$state};

sub print_help() {
    print_revision($PROGNAME,'$Revision: 0.4 $ ');
    print "Copyright (c) 2006 Larry Low\n";
    print "This program is licensed under the terms of the\n";
    print "GNU General Public License\n(check source code for details)\n";
    print "\n";
    printf "Check BGP peer status via SNMP.\n";
    print "\n";
    print_usage();
    print "\n";
    print " -H (--hostname)     Hostname to query - (required)\n";
    print " -C (--community)    SNMP read community or v3 auth (defaults to public)\n";
    print "                     (v3 specified as username:authpassword:... )\n";
    print "                       username = SNMPv3 security name\n";
    print "                       authpassword = SNMPv3 authentication pass phrase (or hexidecimal key)\n";
    print "                       authprotocol = SNMPv3 authentication protocol (md5 (default) or sha)\n";
    print "                       privpassword = SNMPv3 privacy pass phrase (or hexidecmal key)\n";
    print "                       privprotocol = SNMPv3 privacy protocol (des (default) or aes)\n";
    print " -v (--snmp_version) 1 for SNMP v1\n";
    print "                     2 for SNMP v2c (default)\n";
    print "                     3 for SNMP v3\n";
    print " -p {--peer}         IP of BGP Peer\n";
    print " -V (--version)      Plugin version\n";
    print " -h (--help)         usage help\n";
    print "\n";
    support();
}

sub print_usage() {
    print "Usage: \n";
    print "  $PROGNAME -H <HOSTNAME> [-C <community>] -p <bgppeer>\n";
    print "  $PROGNAME [-h | --help]\n";
    print "  $PROGNAME [-V | --version]\n";
}

sub seconds_to_string($) {
    my $time = shift;
    my $timestr = "";
    if ($time > (365.24225*24*60*60)) {
        my $years = floor($time / (365.24225*24*60*60));
        $time -= $years*365.24225*24*60*60;
        $timestr .= $years."y";
    }
    if ($time > (24*60*60)) {
        my $days = floor($time / (24*60*60));
        $time -= $days*24*60*60;
        $timestr .= $days."d";
    }
    if ($time > (60*60)) {
        my $hours = floor($time / (60*60));
        $time -= $hours*60*60;
        $timestr .= $hours."h";
    }
    if ($time > 60) {
        my $minutes = floor($time / 60);
        $time -= $minutes*60;
        $timestr .= $minutes."m";
    }
    $timestr .= $time."s";
    return $timestr;
}