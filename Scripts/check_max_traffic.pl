#!/usr/bin/perl

## I have quickly bastardized this - RR
## no strict.. but that was not my fault at first..

## added perfdata, Feb 4, 2015 - joe

#
# check_traffic v 0.90b - Nagios(r) network traffic monitor plugin
#
# Copyright (c) 2003 Adrian Wieczorek, <ads (at) irc.pila.pl>
#
# Send me bug reports, questions and comments about this plugin.
# Latest version of this software: http://adi.blink.pl/nagios
#
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
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307

$VERSION      = "0.90b";


$ENV{'PATH'}='';
$ENV{'BASH_ENV'}='';
$ENV{'ENV'}='';

$TRAFFIC_FILE = "/tmp/traffic_max";

# SNMP stuff:
$SNMPWALK     = "/usr/bin/snmpwalk";
$SNMPGET      = "/usr/bin/snmpget";
$COMMUNITY    = "tinymouse";



my %STATUS_CODE = (  '-1' => 'UNKNOWN',
                     '0' => 'OK',
                     '1' => 'WARNING',
                     '2' => 'CRITICAL',
                     );

my ($in_bytes,$out_bytes) = 0;
my $warn_i_usage = 85;
my $crit_i_usage = 98;
my $warn_o_usage = 85;
my $crit_o_usage = 98;

if ($#ARGV == -1) {
    &print_usage();
}


# - Initial arguments parsing

ARG:
    while ($ARGV[0] =~ /^-/ ) {
        if ( $ARGV[0] =~/^-H$|^--host/ )
        {
            $host_address = $ARGV[1];
        shift @ARGV;
        shift @ARGV;
        next ARG;
    }
    if ( $ARGV[0] =~/^-i$|^--interface/ )  {
        if ($ARGV[1] !~ /^\d+$/) {
            open (DESCR, "$SNMPWALK -v1 -OQ $host_address -c $COMMUNITY interfaces.ifTable.ifEntry.ifDescr |") || die "Can't check active lines.";
            while(<DESCR>){
                chop;
                if(/ifDescr\.(\d+)\s+=\s+$ARGV[1]/i) {
                    $iface_number = $1;
                    last();
                }
            }
            close(DESCR);
        } else {
            $iface_number = $ARGV[1];
        }
        shift @ARGV;
        shift @ARGV;
        next ARG;
    }
        if ( $ARGV[0] =~/^-wi$/ )
        {
            $warn_i_usage = $ARGV[1];
            shift @ARGV;
            shift @ARGV;
            next ARG;
        }
        if ( $ARGV[0] =~/^-ci$/ )
        {
            $crit_i_usage = $ARGV[1];
            shift @ARGV;
            shift @ARGV;
            next ARG;
        }
        if ( $ARGV[0] =~/^-wo$/ )
        {
            $warn_o_usage = $ARGV[1];
            shift @ARGV;
            shift @ARGV;
            next ARG;
        }
        if ( $ARGV[0] =~/^-co$/ )
        {
            $crit_o_usage = $ARGV[1];
            shift @ARGV;
            shift @ARGV;
            next ARG;
        }

        if ( $ARGV[0] =~/^-HC$/ )
        {
            $HC = $ARGV[1];
            shift @ARGV;
            shift @ARGV;
            next ARG;
        }
        print "Unknown flag: $ARGV[0]\n";
        exit(-1);
    }

if((!$host_address) or (!$iface_number) )    {
    &print_usage();
}



$_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifSpeed.$iface_number`;
m/(\d*)\s$/;
$iface_speed = $1;

if ($debug) {
    print "Speed of Port: $iface_speed\n";
}



$_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifDescr.$iface_number`;
m/STRING:\s(.*)\s$/;
$iface_desc = $1;
if ($debug) {
    print "Port Desc: $iface_desc\n";
}

$_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifAlias.$iface_number`;
m/STRING:\s(.*)\s$/;
$iface_alias = $1;
if ($debug) {
    print "Port Alias: $iface_alias\n";
}

$port_name = $iface_desc;
if ($iface_alias) {    $port_name = $iface_alias;}


if ($HC) {
    $_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifHCInOctets.$iface_number`;
} else {
    $_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifInOctets.$iface_number`;
}

m/(\d*)\s$/;
$in_bytes = $1;


if ($HC) {
    $_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifHCOutOctets.$iface_number`;
} else {
    $_ = `$SNMPGET -v2c $host_address -c $COMMUNITY ifOutOctets.$iface_number`;
}

m/(\d*)\s$/;
$out_bytes = $1;

open(FILE,"<".$TRAFFIC_FILE."_if".$iface_number."_".$host_address);
while($row = <FILE>) {
    @last_values = split(":",$row);
    $last_check_time = $last_values[0];
    $last_in_bytes = $last_values[1];
    $last_out_bytes = $last_values[2];
}
close(FILE);

$update_time = time;

open(FILE,">".$TRAFFIC_FILE."_if".$iface_number."_".$host_address) or die "Can't open $TRAFFIC_FILE for writing: $!";
print FILE "$update_time:$in_bytes:$out_bytes";
close(FILE);


$in_traffic = sprintf("%.2f",($in_bytes-$last_in_bytes)/(time-$last_check_time));
$out_traffic = sprintf("%.2f",($out_bytes-$last_out_bytes)/(time-$last_check_time));


## Bytes to BITS
my $mbps_in = sprintf("%.2f",$in_traffic*8/1000/1000);
my $mbps_out = sprintf("%.2f", $out_traffic*8/1000/1000);

## Bytes to BITS
$in_usage = sprintf("%.2f",( ($in_traffic*8)/$iface_speed)*100);
$out_usage = sprintf("%.2f",( ($out_traffic*8)/$iface_speed)*100);


if($in_traffic > 1024) {
    $in_traffic = sprintf("%.2f",$in_traffic/1024);
    $in_prefix = "k";
    if($in_traffic > 1024)    {
        $in_traffic = sprintf("%.2f",$in_traffic/1024);
        $in_prefix = "M";
    }
}

if($out_traffic > 1024) {
    $out_traffic = sprintf("%.2f",$out_traffic/1024);
    $out_prefix = "k";
    if($out_traffic > 1024)    {
        $out_traffic = sprintf("%.2f",$out_traffic/1024);
        $out_prefix = "M";
    }
}

$in_bytes = sprintf("%.2f",($in_bytes/1024)/1024);
$out_bytes = sprintf("%.2f",($out_bytes/1024)/1024);

#print "Total RX Bytes: $in_bytes MB, Total TX Bytes: $out_bytes MB<br>";

## this is check if we use too much traffic.. use check_min_traffic for opposite
my $code = 0;
if(($in_usage > $crit_i_usage) or ($out_usage > $crit_o_usage)){
    #print "<br>CRITICAL: (".$crit_usage."%) bandwidth utilization.\n";
    $code = 2;
} elsif (($in_usage > $warn_i_usage) or ($out_usage > $warn_o_usage)){
    $code = 2;
}

# perfdata hackery
my $iface_in_name = $iface_desc . "_in";
my $iface_out_name = $iface_desc . "_out";
my $perfdata = qq{|$iface_in_name=$mbps_in $iface_out_name=$mbps_out};
print "$STATUS_CODE{$code}: $iface_desc $port_name - $in_traffic ".$in_prefix."B/s [$mbps_in mbps] (".$in_usage."%) in, $out_traffic ".$out_prefix."B/s [$mbps_out mbps] (".$out_usage."%) out $perfdata\n";
exit($code);


sub print_usage()
{
 print "Usage: check_traffic -H host -i if_number  [-r if_description] [ -w warn ] [ -c crit ]\n\n";
 print "Options:\n";
 print " -H --host STRING or IPADDRESS\n";
 print "   Check interface on the indicated host.\n";
 print " -i --interface INTEGER\n";
 print "   Interface number assigned by SNMP agent. (or the ifDesc and we will find the Integer -- I.E. Port-Channel1)\n";
 print " -wi --warning INTEGER\n";
 print "   % of bandwidth  IN usage necessary to result in warning status\n";
 print " -ci --critical INTEGER\n";
 print "   % of bandwidth  IN usage necessary to result in critical status\n";
 print " -wo --warning INTEGER\n";
 print "   % of bandwidth  OUT usage necessary to result in warning status\n";
 print " -co --critical INTEGER\n";
 print "   % of bandwidth  OUT usage necessary to result in critical status\n";
 print " -HC 1\n";
 print "   Use the HC octets counters -- use if available\n";
 exit(-1);
}