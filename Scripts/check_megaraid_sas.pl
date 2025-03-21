#!/usr/bin/perl -w

# check_megaraid_sas Nagios plugin
# Copyright (C) 2007  Jonathan Delgado, delgado@molbio.mgh.harvard.edu
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 
# 
# Nagios plugin to monitor the status of volumes attached to a LSI Megaraid SAS 
# controller, such as the Dell PERC5/i and PERC5/e. If you have any hotspares 
# attached to the controller, you can specify the number you should expect to 
# find with the '-s' flag.
#
# The paths for the Nagios plugins lib and MegaCli may need to me changed.
#
# Code for correct RAID level reporting contributed by Frode Nordahl, 2009/01/12.
# Some other code contributed by Morty Abzug, 2015-05-20
#
# $Author: delgado $
# $Revision: #12 $ $Date: 2010/10/18 $

use strict;
use Getopt::Long;
use lib qw(/usr/lib/nagios/plugins /usr/lib64/nagios/plugins); # possible pathes to your Nagios plugins and utils.pm
use utils qw(%ERRORS);

my $megaclibin = '/usr/sbin/megacli';  # the full path to your MegaCli binary
my $megacli = "$megaclibin";      # how we actually call MegaCli
my $megapostopt = '-NoLog';            # additional options to call at the end of MegaCli arguments

my ($adapters);
my $hotspares = 0;
my $hotsparecount = 0;
my $pdbad = 0;
my $pdcount = 0;
my $mediaerrors = 0;
my $mediaallow = 0;
my $consistency_check_is_ok = 0;
my $missing_is_ok = 0;
my $no_battery_is_ok = 0;
my $prederrors = 0;
my $predallow = 0;
my $othererrors = 0;
my $otherallow = 0;
my $result = '';
my $status = 'OK';
my $sudo;
my $checkbbu = 0;
my $bbu_charge_no_warning = 0;
my $check_cache;
my $do_help;

# handle options
Getopt::Long::Configure("bundling");
GetOptions(
  "b|bbu_check" => \$checkbbu,
  "B|bbu_charge_no_warning" => \$bbu_charge_no_warning,
  "c|cache_check" => \$check_cache,
  "h|help" => \$do_help,
  "m|media_allow=i" => \$mediaallow,
    "consistency_check_is_ok" => \$consistency_check_is_ok,
    "missing_is_ok" => \$missing_is_ok,
    "no_battery_is_ok" => \$no_battery_is_ok,
  "o|other_allow=i" => \$otherallow,
  "p|pred_allow=i" => \$predallow,
  "s|hotspares=i" => \$hotspares,
    "sudo" => \$sudo,
  );

if ( $do_help ) {
	print "Usage: $0 [-s number] [-m number] [-o number]\n";
	print "       -b check Battery Back Up status\n";
        print "       -B battery back up charging state is not a warning\n";
        print "       -c check that current cache policy matches default policy\n";
	print "       -m is the number of media errors to ignore\n";
        print "       --consistency_check_is_ok  consistency checks are OK\n";
        print "       --missing_is_ok  test returns OK if MegaCli is not present\n";
        print "       --no_battery_is_ok  lack of a battery is not a problem\n";
	print "       -p is the predictive error count to ignore\n";
	print "       -o is the number of other disk errors to ignore\n";
	print "       -s is how many hotspares are attached to the controller\n";
        print "       --sudo  should sudo be enabled\n";
	exit;
}

sub max_state ($$) {
	my ($current, $compare) = @_;
	
	if (($compare eq 'CRITICAL') || ($current eq 'CRITICAL')) {
		return 'CRITICAL';
	} elsif ($compare eq 'OK') {
		return $current;
	} elsif ($compare eq 'WARNING') {
		return 'WARNING';
	} elsif (($compare eq 'UNKNOWN') && ($current eq 'OK')) {
		return 'UNKNOWN';
	} else {
		return $current;
	}
}

sub exitreport ($$) {
	my ($status, $message) = @_;
	
	print STDOUT "$status: $message\n";
	exit $ERRORS{$status};
}


# Some sanity checks that you actually have something where you think MegaCli is
if (! -e $megaclibin) {
        if ($missing_is_ok) {
                exitreport($status, "$megaclibin is not present, missing_is_ok set")
        } else {
	        exitreport('UNKNOWN',"error: $megaclibin does not exist");
        }
}

$megacli="sudo $megacli" if $sudo;

# Get the number of RAID controllers we have
open (ADPCOUNT, "$megacli -adpCount $megapostopt |")  
	|| exitreport('UNKNOWN',"error: Could not execute $megacli -adpCount $megapostopt");

while (<ADPCOUNT>) {
	if ( m/Controller Count:\s*(\d+)/ ) {
		$adapters = $1;
		last;
	}
}
close ADPCOUNT;

exitreport('UNKNOWN',"error: unable to get controller count")
  if !defined $adapters;

ADAPTER: for ( my $adp = 0; $adp < $adapters; $adp++ ) {
	$result .= "$adp:";
	# Get the Battery Back Up state for this adapter
	my ($bbustate);
	if ($checkbbu) {
		open (BBUGETSTATUS, "$megacli -AdpBbuCmd -GetBbuStatus -a$adp $megapostopt |") 
			|| exitreport('UNKNOWN', "error: Could not execute $megacli -AdpBbuCmd -GetBbuStatus -a$adp $megapostopt");
		
		my ($bbucharging, $bbufullycharged, $bburelativecharge, $bbuexitcode);
		my ($batterystate, $batteryreplacement, $issohgood);
		while (<BBUGETSTATUS>) {
			# Charging Status
			if ( m/Charging Status\s*:\s*(\w+)/i ) {
				$bbucharging = $1;
			} elsif ( m/Battery State\s*:\s*(\w+.*)/i) { # sometimes contains a space
			        $batterystate = $1;
			} elsif ( m/Fully Charged\s*:\s*(\w+)/i ) {
				$bbufullycharged = $1;
			} elsif ( m/Relative State of Charge\s*:\s*(\w+)/i ) {
				$bburelativecharge = $1;
			} elsif ( m/Exit Code\s*:\s*(\w+)/i ) {
				$bbuexitcode = $1;
			} elsif ( m/^\s*Battery Replacement required\s*:\s(\w+)\s*$/i) {
				$batteryreplacement = $1;
			} elsif ( m/^\s*isSOHGood\s*:\s*(\w+)\s*$/i) {
				$issohgood = $1;
			}
		}
		close BBUGETSTATUS;

		# Determine the BBU state
		if ( !defined $bbuexitcode || $bbuexitcode ne '0x00' ) {
                        if (!$no_battery_is_ok) {
			  $bbustate = 'NOT FOUND';
			  $status = max_state($status, 'CRITICAL');
                        } else {
			  $bbustate = 'not found which could be ok';
                        }
		} elsif ( lc $batteryreplacement ne 'no' ) {
			$bbustate = 'battery needs replacing';
			$status = max_state($status, 'CRITICAL');
		} elsif ( defined $issohgood && lc $issohgood ne 'yes' ) {
			$bbustate = 'battery SOH is not good';
			$status = max_state($status, 'CRITICAL');
		} elsif ( $bbucharging ne 'None' && !$bbu_charge_no_warning) {
			$bbustate = 'Charging (' . $bburelativecharge . '%)';
			$status = max_state($status, 'WARNING');
		} elsif ( defined $bbufullycharged && $bbufullycharged ne 'Yes' && !$bbu_charge_no_warning) {
			# some adapters don't report on "Fully Charged", so
			# it's OK if it's not defined.
			$bbustate = 'Not Charging (' . $bburelativecharge . '%)';
			$status = max_state($status, 'WARNING');
		} elsif ( defined $batterystate && $batterystate ne 'Optimal' &&
                           $batterystate ne 'Operational') {
		        $bbustate = $batterystate;
			$status = max_state($status, 'WARNING');
		} else {
			$bbustate = 'Charged (' . $bburelativecharge . '%)';
		}
	        $result .= "BBU $bbustate:";
	}

	# Get the number of logical drives on this adapter
	open (LDGETNUM, "$megacli -LdGetNum -a$adp $megapostopt |") 
		|| exitreport('UNKNOWN', "error: Could not execute $megacli -LdGetNum -a$adp $megapostopt");
	
	my ($ldnum);
	while (<LDGETNUM>) {
		if ( m/Number of Virtual drives configured on adapter \d:\s*(\d+)/i ) {
			$ldnum = $1;
			last;
		}
	}
	close LDGETNUM;
	
	LDISK: for ( my $ld = 0; $ld < $ldnum; $ld++ ) {
		# Get info on this particular logical drive
		open (LDINFO, "$megacli -LdInfo -L$ld -a$adp $megapostopt |") 
			|| exitreport('UNKNOWN', "error: Could not execute $megacli -LdInfo -L$ld -a$adp $megapostopt ");
		
		my $consistency_output = '';
		my ($size, $unit, $raidlevel, $ldpdcount, $state, $spandepth, $consistency_percent, $consistency_minutes);
		my $current_cache_policy;
		my $default_cache_policy;
		while (<LDINFO>) {
			if ( m/^Size\s*:\s*((\d+\.?\d*)\s*(MB|GB|TB))/ ) {
				$size = $2;
				$unit = $3;
				# Adjust MB to GB if that's what we got
				if ( $unit eq 'MB' ) {
					$size = sprintf( "%.0f", ($size / 1024) );
					$unit= 'GB';
				}
			} elsif ( m/State\s*:\s*(\w+)/ ) {
				$state = $1;
				if ( $state ne 'Optimal' ) {
					$status = max_state($status, 'CRITICAL');
				}
			} elsif ( m/Number Of Drives\s*(per span\s*)?:\s*(\d+)/ ) {
				$ldpdcount = $2;
			} elsif ( m/Span Depth\s*:\s*(\d+)/ ) {
				$spandepth = $1;
                        } elsif ( m/^\s*Default Cache Policy\s*:\s*(.*)/ ) {
                                $default_cache_policy=$1;
                        } elsif ( m/^\s*Current Cache Policy\s*:\s*(.*)/ ) {
                                $current_cache_policy=$1;
			} elsif ( m/RAID Level\s*: Primary-(\d)/ ) {
				$raidlevel = $1;
			} elsif ( m/\s+Check Consistency\s+:\s+Completed\s+(\d+)%,\s+Taken\s+(\d+)\s+min/ ) {
				$consistency_percent = $1;
				$consistency_minutes = $2;
			}
		}
		close LDINFO;

		# Report correct RAID-level and number of drives in case of Span configurations
		if ($ldpdcount && $spandepth > 1) {
			$ldpdcount = $ldpdcount * $spandepth;
			if ($raidlevel < 10) {
				$raidlevel = $raidlevel . "0";
			}
		}
		
 		if ($consistency_percent) {
 			$status = max_state($status, 'WARNING')
                          if !$consistency_check_is_ok;
 			$consistency_output = "CC ${consistency_percent}% ${consistency_minutes}m:";
 		}
  		
		if ($check_cache) {
		  if (defined($current_cache_policy) &&
                      defined($default_cache_policy) &&
                      $default_cache_policy eq $current_cache_policy) {
                    $result .= "cache policy $current_cache_policy:";
                  } elsif (!defined($current_cache_policy)) {
                    $result .= "cache policy UNKNOWN:";
                    $status = max_state($status, 'UNKNOWN');
                  } elsif (!defined($default_cache_policy)) {
                    $result .= "cache policy $current_cache_policy, default UNKNOWN:";
                    $status = max_state($status, 'UNKNOWN');
                  } else {
                    $result .= "cache policy $current_cache_policy, SHOULD BE $default_cache_policy:";
                    $status = max_state($status, 'WARNING');
		  }
                }

 		$result .= "$ld:RAID-$raidlevel:$ldpdcount drives:$size$unit:$consistency_output$state ";
	} #LDISK
	close LDINFO;
	
	# Get info on physical disks for this adapter
	open (PDLIST, "$megacli -PdList  -a$adp $megapostopt |") 
		|| exitreport('UNKNOWN', "error: Could not execute $megacli -PdList -a$adp $megapostopt ");
	
	my ($slotnumber,$fwstate);
	PDISKS: while (<PDLIST>) {
		if ( m/Slot Number\s*:\s*(\d+)/ ) {
			$slotnumber = $1;
			$pdcount++;
		} elsif ( m/(\w+) Error Count\s*:\s*(\d+)/ ) {
			if ( $1 eq 'Media') {
				$mediaerrors += $2;
			} else {
				$othererrors += $2;
			}
		} elsif ( m/Predictive Failure Count\s*:\s*(\d+)/ ) {
			$prederrors += $1;
		} elsif ( m/Firmware state\s*:\s*(\w+)/ ) {
			$fwstate = $1;
			if ( $fwstate eq 'Hotspare' ) {
				$hotsparecount++;
			} elsif ( $fwstate eq 'Online' ) {
				# Do nothing
			} elsif ( $fwstate eq 'JBOD' ) {
				# Do nothing
			} elsif ( $fwstate eq 'Unconfigured' ) {
				# A drive not in anything, or a non drive device
				$pdcount--;
			} elsif ( $slotnumber != 255 ) {
				$pdbad++;
				$status = max_state($status, 'CRITICAL');
			}
		}
	} #PDISKS
	close PDLIST;
}

$result .= "Drives:$pdcount ";

# Any bad disks?
if ( $pdbad ) {
	$result .= "$pdbad Bad Drives ";
}

my $errorcount = $mediaerrors + $prederrors + $othererrors;
# Were there any errors?
if ( $errorcount ) {
	$result .= "($errorcount Errors: $mediaerrors media, $prederrors predictive, $othererrors other) ";
	if ( ( $mediaerrors > $mediaallow ) || 
	     ( $prederrors > $predallow )   || 
	     ( $othererrors > $otherallow ) ) {
		$status = max_state($status, 'WARNING');
	}
}

# Do we have as many hotspares as expected (if any)
if ( $hotspares ) {
	if ( $hotsparecount < $hotspares ) {
		$status = max_state($status, 'WARNING');
		$result .= "Hotspare(s):$hotsparecount (of $hotspares)";
	} else {
		$result .= "Hotspare(s):$hotsparecount";
	}
}

exitreport($status, $result);