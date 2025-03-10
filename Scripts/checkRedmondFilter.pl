#!/usr/bin/perl

use strict;
use warnings;

use Iso::SNMP ':all';
use Iso::JSON::Marshaller 'structToJSON';

use constant APC_UNITS => qw(10.180.1.21
                             10.180.1.22
                             10.180.1.23
                             10.180.1.24
                             10.180.1.25
                             10.180.1.26
                             10.180.1.27
                             10.180.1.28);

use constant COMMUNITY => 'elephant';
use constant FLOW_OID => 'PowerNet-MIB::airIRRCUnitStatusFluidFlowUS.0';
use constant VALVE_OID => 'PowerNet-MIB::airIRRCUnitStatusFluidValvePosition.0';

use constant BUILT_IN_THRESHOLD => 9;
use constant VALVE_THRESHOLD => 0;

use constant UNKNOWN  => (3, 'UNKNOWN');
use constant CRITICAL => (2, 'CRITICAL');
use constant WARNING  => (1, 'WARNING');
use constant OK       => (0, 'OK');

use subs 'exit';
sub exit (@);

################
##### Main #####
################

{
    my $threshold = shift || BUILT_IN_THRESHOLD;
    my $debug = shift;

    my $noFlow = 1;

    my @values;
    foreach(APC_UNITS)
    {
        my $gpm = getFluidFlow($_);
        my $valve = getValvePosition($_);
        push @values, $gpm if(defined $gpm && (defined $valve && $valve >= VALVE_THRESHOLD));
        print "Unit: $_, GPM: ", (defined $gpm) ? $gpm : "(undef)", ", Valve Position: ", (defined $valve) ? "$valve\%" : "(undef)", "\n" if($debug);
        $noFlow = 0 if($gpm);
    }

    if($noFlow)
    {
        exit(CRITICAL, "All racks return 0 fluid flow");
    }

    if(!scalar @values)
    {
#       exit(UNKNOWN, "No values returned from rack units");
        exit(OK, "No rack units running at full fluid duty");
    }
    my $average = 0;
    $average += $_ foreach(@values);
    $average /= scalar @values;

    if($average >= $threshold)
    {
        exit(OK, "Average: ", sprintf('%.2f', $average), ", Values: ", join(', ', @values));
    }
    else
    {
        exit(CRITICAL, "Average flow is below threshold, filter probably clogged. (", sprintf('%.2f', $average), " < $threshold)");
    }
}

################
##### Subs #####
################

sub getFluidFlow
{
    my $host = shift;

    my $result = snmpGet($host, COMMUNITY, FLOW_OID);
    return undef if(!defined $result);
    return $result->{value} / 10;
}

sub getValvePosition
{
    my $host = shift;

    my $result = snmpGet($host, COMMUNITY, VALVE_OID);
    return undef if(!defined $result);
    return $result->{value};
}

sub exit (@)
{
    my $exitCode = shift;
    my $description = join('', shift() . ": ", @_);

    print "$description\n";
    CORE::exit($exitCode);
}