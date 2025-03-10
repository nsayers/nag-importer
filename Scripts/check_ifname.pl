#!/usr/bin/perl

use strict;
use warnings;

use Iso::DebugOutput ':default';
use Iso::SNMP qw(snmpGet snmpWalk);
#use Iso::JSON::Marshaller 'structToJSON';

use constant SNMP_COMMUNITY => "tinymouse";

use constant OID_CATOS_IFALIAS        => ".1.3.6.1.4.1.9.5.1.4.1.1.4";
use constant OID_CATOS_IFINDEX_PORTID => ".1.3.6.1.4.1.9.5.1.4.1.1.11";
use constant OID_ALL_OTHER_IFALIAS    => "ifAlias";
use constant OID_SYS_DESCR            => "sysDescr.0";
use constant OID_IFNAME               => "ifName";
use constant OID_IFDESCR              => "ifDescr";
use constant OID_OPERSTATUS           => "interfaces.ifTable.ifEntry.ifOperStatus";

use constant SNMP_OPER_UP   => 1;
use constant SNMP_OPER_DOWN => 2;

use constant UNKNOWN  => (3, 'UNKNOWN');
use constant CRITICAL => (2, 'CRITICAL');
use constant WARNING  => (1, 'WARNING');
use constant OK       => (0, 'OK');

use constant DEBUG => 0;

# various ways people try to look up interfaces. expand abbreviations.
use constant INT_MAP => {gi => 'GigabitEthernet',
                         fa => 'FastEthernet',
                         te => 'TenGigabitEthernet',
                         po => 'Port-channel',
                         vl => 'Vlan',
                         gigabitethernet => 'GigabitEthernet',
                         fastethernet => 'FastEthernet',
                         tengigabitethernet => 'TenGigabitEthernet',
                         portchannel => 'Port-channel',
                         vlan => 'Vlan',
                         'port-channel' => 'Port-channel'};

use subs 'exit';

sub exit (@);
sub debug (@);

{
    my $host = shift;
    my $query = shift;
    my $community = shift;

    my $ifAliasOID = OID_ALL_OTHER_IFALIAS;
    my $isCatOS;

    if(!defined $host || !length($host))
    {
        exit(UNKNOWN, "No host given on command line");
    }

    if(!defined $query || !length($query))
    {
        exit(UNKNOWN, "No query given on command line");
    }

    if(!defined $community || !length($community))
    {
        $community = SNMP_COMMUNITY;
        debug "No SNMP community given on command line, using built-in default ($community)\n";
    }

    my $response = snmpGet($host, $community, OID_SYS_DESCR, 1);
    # run FTOS specific interface abbreviation fixups.
    if(isFTOS($response))
    {
        debug "Device is running FTOS, attempting interface expansion.\n";
        my ($interfaceType, $interfaceID) = $query =~ /^([^\d\s]+)\s*(\d.*)$/;
        if(defined $interfaceType && defined $interfaceID)
        {
            $interfaceType = INT_MAP->{lc $interfaceType} if(exists INT_MAP->{lc $interfaceType});
            debug "Fixing query from \"$query\" to \"$interfaceType $interfaceID\"\n";
            $query = $interfaceType . " " . $interfaceID;
        }
    }

    # run IOS specific interface abbreviation fixups.
    if(isCisco($response))
    {
        if(isCatOS($response))
        {
            debug "Device is running CatOS, using CatOS ifalias lookups.\n";
            $ifAliasOID = OID_CATOS_IFALIAS;
            $isCatOS = 1;
        }
        else
        {
            debug "Device is not running CatOS, using regular ifAlias lookups.\n";
            debug "Device is running IOS, attempting interface cleanup.\n";
            my ($interfaceType, $interfaceID) = $query =~ /^([^\d\s]+)\s*(\d.*)$/;
            if(defined $interfaceType && defined $interfaceID)
            {
                $interfaceType = INT_MAP->{lc $interfaceType} if(exists INT_MAP->{lc $interfaceType});
                debug "Fixing query from \"$query\" to \"${interfaceType}${interfaceID}\"\n";
                $query = $interfaceType . $interfaceID;
            }
        }
    }

    if(isE7($response))
    {
        my $newQuery = "Ethport $query";
        debug "Device is an E7. Adding Ethport to query.\n";
        debug "Fixing query from \"$query\" to \"$newQuery\"\n";
        $query = $newQuery;
    }

    my $ifIndex;
    my $ifName;
    # query can be an ifName or an ifDescr depending on which admin added it to nagios.
    # ifName is more common, so we'll walk it first.
    my $tempQuery = ($query =~ /\$$/) ? $query : $query . '$';
    $tempQuery = '^' . $tempQuery if($tempQuery !~ /^\^/);
    $response = snmpWalk($host, $community, OID_IFNAME, 0, 1);
    if(!defined $response)
    {
        exit(UNKNOWN, "Unable to query interfaces");
    }
    foreach my $oid (@{$response})
    {
        if($oid->{value} =~ /$tempQuery/i)
        {
            $ifIndex = (split(/\./, $oid->{oid}))[-1];
            $ifName = $oid->{value};
        }
    }
    # now ifDescr if ifName didn't get any hits.
    if(!defined $ifIndex)
    {
        $response = snmpWalk($host, $community, OID_IFDESCR, 0, 1);
        if(!defined $response)
        {
            exit(UNKNOWN, "Unable to query interfaces");
        }
        foreach my $oid (@{$response})
        {
            if($oid->{value} =~ /$tempQuery/i)
            {
                $ifIndex = (split(/\./, $oid->{oid}))[-1];
                $ifName = $oid->{value};
            }
        }
    }
    if(!defined $ifIndex)
    {
        exit(UNKNOWN, "Unable to determine ifIndex of $query");
    }
    debug "ifIndex: $ifIndex\n";

    # alias lookup. CatOS requires special sauce because it's stupid.
    if($isCatOS)
    {
        my $portID;
        $response = snmpWalk($host, $community, OID_CATOS_IFINDEX_PORTID, 0, 1);
        if(!defined $response)
        {
            debug "WARNING: Couldn't lookup port ID from ifIndex on CatOS device.\n";
        }
        else
        {
            foreach my $oid (@{$response})
            {
                if($oid->{value} == $ifIndex)
                {
                    # lol
                    $portID = join('.', (reverse((reverse((split(/\./, $oid->{oid}))))[0 .. 1])));
                    debug "CatOS port id: $portID\n";
                    last;
                }
            }
        }
        $response = snmpGet($host, $community, "$ifAliasOID.$portID", 1);
    }
    else
    {
        $response = snmpGet($host, $community, "$ifAliasOID.$ifIndex", 1);
    }

    my $ifAlias;
    if(!defined $response)
    {
        debug "WARNING: Couldn't look up alias.\n";
        $response->{value} = "UNKNOWN ALIAS";
    }
    $ifAlias = $response->{value};
    debug "ifAlias: $ifAlias\n";

    my $operStatus;
    # query link status
    $response = snmpGet($host, $community, OID_OPERSTATUS . ".$ifIndex", 1);
    if(!defined $response)
    {
        exit(UNKNOWN, "Couldn't query link status");
    }
    if($response->{value} == SNMP_OPER_UP)
    {
        exit(OK, "$ifName ($ifAlias) - UP");
    }
    if($response->{value} == SNMP_OPER_DOWN)
    {
        exit(CRITICAL, "$ifName ($ifAlias) - DOWN");
    }
    exit(UNKNOWN, "$query ($ifAlias) - UNKNOWN($response->{value})");
}

sub isCatOS
{
    my $response = shift;

    return undef if(!defined $response);
    return undef if($response->{type} ne "STRING");

    return 1 if($response->{value} =~ /Cisco Catalyst Operating System/);
    return 0;
}

sub isFTOS
{
    my $response = shift;

    return undef if(!defined $response);
    return undef if($response->{type} ne "STRING");

    return 1 if($response->{value} =~ /Force10/);
    return 0;
}

sub isCisco
{
    my $response = shift;

    return undef if(!defined $response);
    return undef if($response->{type} ne "STRING");

    return 1 if($response->{value} =~ /Cisco/);
    return 0;
}

sub isE7
{
    my $response = shift;

    return undef if(!defined $response);
    return undef if($response->{type} ne "STRING");

    return 1 if($response->{value} =~ /E7/);
    return 0;
}

sub debug (@)
{
    if(DEBUG)
    {
        print STDERR @_;
    }
}

sub exit (@)
{
    my $exitCode = shift;
    my $description = join(' ', shift() . ":", @_);

    print "$description\n";
    CORE::exit($exitCode);
}
