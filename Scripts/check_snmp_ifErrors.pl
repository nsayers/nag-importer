#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
#use Net::Appliance::Session; # used to reset errors.. bad idea and not using
use Net::Ping;
use Net::SNMP;
use Net::SNMP::Interfaces;


my $debug = 0;
my $is_wwp = 0; ## stupid way of changing port index to portNum (since wwp doesn't use ifAlias

my $community = 'bigbrother';
my $snmp_cro = 'bigbrother';
my $snmp_p_cro = '6r82h7';
my $snmpg_bin = 'snmpget -v2c -c';

my $skip = ();
$skip->{'207.115.94.158'}->{80} = 'EskimoNorth Old Equipment';
$skip->{'207.115.94.179'}->{29} = 'EskimoNorth Old Equipment';

# temporary for terminal ports we know full well about
$skip->{'207.115.94.162'}->{168} = 'rt 2892555';
$skip->{'207.115.94.162'}->{36} = 'redwolf camera';


my $warn_packet_loss = 1; ## percentage of packet loss on any port for WARNING
my $crit_packet_loss = 5; ## percentage of packet loss on any port for CRITICAL

my $min_mon = 60;  ## this is the MINinum time between checks to continue.. we will error if we monitor it to fast (for nagios)

my $error_FILE = "/tmp/snmp_error_stats";

my $info = "UNK: how did this fail? $0\n";
my $exit_code = 3;

my $host = shift;
my $tcom = shift;

my $ports = shift;
my @ports;
my $checked_string;
if ($ports) {    @ports = split(",",$ports);}



if ($tcom) {    $community = $tcom;}

($info,$exit_code) = &checkinterfaces($host);
print $info;
exit ($exit_code);


sub checkinterfaces {
    my $host = shift;

#    my $p = Net::Ping->new("icmp");
#    ## dur - check if this is valid host
#
#    how about you do what i fucking tell you to do and I will decide if its
#    valid or not?
#
#    if (!$p->ping($host,2)) {
#       print "UNKNOWN: $host failed ping check\n";
#       exit(3);
#    }

    my $stat_file = $error_FILE . "_HOST_" . $host;
    if ($ports) {
        $stat_file .= "ports_$ports";
    }
    my $stats = ();
    if (-e $stat_file) {
        open(FILE,"<". $stat_file);
        while(my $row = <FILE>) {
            #print $row;
            my @v = split(":",$row);

            $stats->{$v[0]}->{'index'} = $v[0];
            $stats->{$v[0]}->{'inerr'} = $v[1];
            $stats->{$v[0]}->{'outerr'} = $v[2];
            $stats->{$v[0]}->{'port_alias'} = $v[3];
            $stats->{$v[0]}->{'port_name'} = $v[4];
            $stats->{$v[0]}->{'inPkts'} = $v[5];
            $stats->{$v[0]}->{'outPkts'} = $v[6];
            $stats->{$v[0]}->{'time'} = $v[7];
        }
        close(FILE);
    }


    #print Dumper($stats);


    my $interfaces = Net::SNMP::Interfaces->new(Hostname => $host,
                                                Community => $community,
                                                Version => 'v2c',

                                                );
    if(!$interfaces) {
      print "UNKNOWN: snmp connection to $host failed\n";
      exit(3);
    }
    my @inter = $interfaces->all_interfaces();
    my $info;
    my $error;
    #my $e = -1; ## unknown <-- no, it really fucking isn't
    my $e = 3; ## <--- THAT is "unknown" to nagios
    my $has_error = 0;


    my $save_file = 1;
    open(FILE,">". $stat_file . '.TMP') or die "Can't open $stat_file for writing: $!";


    my $mon_sec = 0;
    my $checked_ports = 0;

    for my $i (@inter) {


        #print $i->index . "\n";
        my $inPkts = 0;
        my $outPkts = 0;
        ## use the HC if available..

        if ($skip->{$host}->{$i->index}) {
            if ($debug) { print "Skipping " . $i->name . " skip list " . $skip->{$host}->{$i->index};     }

            next;
        }

        if ($i->ifInBroadcastPkts !~ /^\d+$/) {
            if ($debug) { print "Skipping " . $i->name . " NO PKTS counters\n";               }
            next;
        } else {
            $checked_ports++;
            if ( $i->ifHCInUcastPkts && $i->ifHCInUcastPkts =~ /^\d+$/) {
                $inPkts = $i->ifHCInUcastPkts+$i->ifHCInMulticastPkts+$i->ifHCInBroadcastPkts;
            } else {
                $inPkts = $i->ifInUcastPkts+$i->ifInMulticastPkts+$i->ifInBroadcastPkts;
            }

            ## use the HC if available..
            if ($i->ifHCOutUcastPkts && $i->ifHCOutUcastPkts =~ /^\d+$/) {
                #if ($i->ifHCOutUcastPkts && $i->ifHCOutMulticastPkts && $i->ifHCOutBroadcastPkts) {
                $outPkts = $i->ifHCOutUcastPkts+$i->ifHCOutMulticastPkts+$i->ifHCOutBroadcastPkts;
            } else {
                $outPkts = $i->ifOutUcastPkts+$i->ifOutMulticastPkts+$i->ifOutBroadcastPkts;
            }
        }


        my $port_name = $i->name;
        my $inerr = $i->ifInErrors;
        my $outerr = $i->ifOutErrors;
        #my $in_oct = $i->ifInOctets;
        #my $out_oct = $i->ifInOctets;
        my $index = $i->index;
        my $port_alias = $i->index;
        my ($orig_port,$wwp_port);
        if (!$is_wwp && $i->ifAlias && $i->ifAlias !~ /noSuch/i) {
            $port_alias = $i->index . ' ' . $i->ifAlias;
        } else {
            ($orig_port,$wwp_port) = &fixWWPport($i->index);
            $port_alias = $wwp_port;
        }




        ## the FILE requires ":" -- so replace any vars containing ":"
        $port_alias =~ s/:/;/g;
        $inerr =~ s/:/;/g;
        $outerr =~ s/:/;/g;
        $port_alias =~ s/:/;/g;
        $port_name =~ s/:/;/g;
        $inPkts =~ s/:/;/g;
        $outPkts =~ s/:/;/g;

        print FILE  "$index:$inerr:$outerr:$port_alias:$port_name:$inPkts:$outPkts:" . time() . ":\n";
        if (!ref $stats->{$index}) {
            $has_error  = 1;
            $error =  "We don't have any stats for $host - check $stat_file -- this might be the first run...\n";
            #$e = -1;
            $e = 3;
            next;
        }

        my ($last_inerr,$last_outerr,$time_diff,$last_inPkts,$last_outPkts) = (0,0,0,0,0);
        if ($stats->{$index} && $stats->{$index}->{'time'}) {
            $time_diff =  time()-$stats->{$index}->{'time'};
            $last_inerr =  $stats->{$index}->{'inerr'};
            $last_outerr = $stats->{$index}->{'outerr'};
            $last_outPkts =  $stats->{$index}->{'outPkts'};
            $last_inPkts = $stats->{$index}->{'inPkts'};

        }

        if ($ports) {
            if(!grep $_ eq $wwp_port, @ports) {
                $checked_ports--;
                next;
            } else { $checked_string .= "$wwp_port,";   }
        }

        $mon_sec = $time_diff; ## time in seconds between first/last check
        if ($mon_sec < $min_mon) {
            #print "Skipping: time is less than 60 seconds -- setting this as an error\n";
            #$error = "Monitored time is less that $min_mon seconds ($mon_sec) .. we need more of a window to get the percentage\n";
            $has_error  = 1;
            $e = 2;
            ## DO NOT save file if we are below monitoring time.. if it's ZERO, we nee to save
            if ($mon_sec > 0) {         $save_file = 0;     }
            #next;
        }

        my $drop_in =  $inerr-$last_inerr;     ## total IN  dropped packets between checks;
        my $drop_out =   $outerr-$last_outerr; ## total OUT dropped packets between checks;

        my ($in_packet_loss,$out_packet_loss,$diff_lostIn,$diff_lostOut) = (0,0,0,0);

        # let's avoid dividing by zero OK?
        if($time_diff < 1) {
          $debug && print STDERR "\nAdjusted time_diff from [$time_diff] to 0.01\n";
          $time_diff = 0.01;
        }
        my $in_psec = sprintf("%.02f",$drop_in/$time_diff);      ## error packets per second IN
        my $out_psec = sprintf("%.02f",$drop_out/$time_diff);    ## error packet per second OUT
        my $diff_inPkts = $inPkts-$last_inPkts;                  ## Total packets IN  between checks
        my $diff_outPkts = $outPkts-$last_outPkts;               ## Total Packets OUT between checks

        $diff_lostIn = $diff_inPkts-($diff_inPkts-$drop_in);     ## Total packets lost IN  between checks
        $diff_lostOut = $diff_outPkts-($diff_outPkts-$drop_out); ## Total packets lost OUT between checks

        if ($debug) {
            #print Dumper($stats->{$i->index});
                print "PORT  $index,$port_alias $port_name\n";
                print "          : IN / OUT\n";
                print "last Pkts: $last_inPkts/$last_outPkts\n";
                print " now Pkts: $inPkts/$outPkts\n";
                print "Total Pkts: $diff_inPkts/$diff_outPkts\n";
                print " Lost Pkts: $diff_lostIn/$diff_lostOut\n";
                print " Last Error: $last_inerr/$last_outerr\n";
                print "  Cur Error: $inerr/$outerr\n";
                print " Diff Error: $drop_in/$drop_out -- $time_diff seconds\n";
                print " Errors Sec: $in_psec/ $out_psec\n\n";
                print "Packet Loss: $in_packet_loss / $out_packet_loss\n";
                print "$stat_file\n";
            }


        ## if we have dropped packets-- we continue to check for threshold monitoring
        if ($drop_in > 0 || $drop_out > 0 ) {

            ## if out errors - set the IN Percentage Loss (packet loss)
            if ($drop_in && ($diff_lostIn > 0 && $diff_inPkts > 0))  {
                # $drop_in  ## total dropped 20
                # $diff_inPkts ## total_inpackets - 100
                #$diff_lostIn  Total packets lost IN  between checks 20
                $in_packet_loss = sprintf("%.02f",($diff_lostIn/$diff_inPkts)*100);
                ## possible the oids are not updated quick enough and counters are greater giver over 100% loss, which someone will comment on ( i know this )
                if ($in_packet_loss > 100) { $in_packet_loss = 100; }
            }
            ## if out errors - set the OUT Percentage Loss (packet_loss)
            if ($drop_out && ($diff_lostOut > 0 && $diff_outPkts > 0))  {
                $out_packet_loss = sprintf("%.02f",($diff_lostOut/$diff_outPkts)*100);
                ## possible the oids are not updated quick enough and counters are greater giver over 100% loss, which someone will comment on ( i know this )
                if ($out_packet_loss > 100) { $out_packet_loss = 100; }
            }


            if ($debug) {
                print Dumper($stats->{$i->index});
                print "PORT  $index,$port_alias $port_name\n";
                print "          : IN / OUT\n";
                print "last Pkts: $last_inPkts/$last_outPkts\n";
                print " now Pkts: $inPkts/$outPkts\n";
                print "Total Pkts: $diff_inPkts/$diff_outPkts\n";
                print " Lost Pkts: $diff_lostIn/$diff_lostOut\n";
                print " Last Error: $last_inerr/$last_outerr\n";
                print "  Cur Error: $inerr/$outerr\n";
                print " Diff Error: $drop_in/$drop_out -- $time_diff seconds\n";
                print " Errors Sec: $in_psec/ $out_psec\n\n";
                print "Packet Loss: $in_packet_loss / $out_packet_loss\n";
                print "$stat_file\n";
            }


            if ($in_packet_loss >= $crit_packet_loss  ||   $out_packet_loss >= $crit_packet_loss ) {
                $has_error  = 1;
                $e = 2; ## exit code = CRIT
            }
            elsif ($in_packet_loss >= $warn_packet_loss  ||   $out_packet_loss >= $warn_packet_loss ) {
                $has_error  = 1;
                $e = 1; ## exit code = warn
            }

            ## old style which didn't count for actual packet loss.. just errors a second
            ## port is in Error
            #       if ($in_psec >= $crit_sec || $out_psec >= $crit_sec) {
            #           $has_error  = 1;
            #           $e = 2; ## exit code = CRIT
            #       }
            #       ## port is in warning
            #       elsif ($in_psec >= $warn_sec || $out_psec >= $warn_sec) {
            #           $has_error  = 1;
            #           #$error .= "[PORT $port_tel - $in_psec/$out_psec Errors/Sec (total: $inerr/$outerr ) - $port_name]";
            #           if ($e < 2) { $e = 1; } ## set error code to warning -- only if we don't have a higher error alrady
            #       }

            if ($has_error) {
                my $display;
                my $display_diff;
                if ($drop_in > 0 ) {
                    #$display_diff = "in:$drop_in,";
                    $display_diff = "$diff_lostIn ($drop_in err) of $diff_inPkts lost";
                    $display = "Packet Loss:$in_packet_loss\%,";
                    $display .= "in:$in_psec,";


                }
                if ($drop_out > 0 ) {
                    $display_diff = "$diff_lostOut ($drop_out err) of $diff_outPkts lost";
                    #$display_diff = "in:$drop_out,";
                    $display = "Packet Loss:$out_packet_loss\%,";
                    $display .= "out:$out_psec,";

                }
                $display =~ s/,$//;
                $display_diff =~ s/,$//;

                $error .= "[port $port_alias, $display/sec, $display_diff over $time_diff sec (err in:$inerr/out:$outerr) $port_name]";
            }
        }
    }
    close(FILE);

    $checked_ports .= ' checked ports';
    if ($checked_string) {
        $checked_string =~ s/,$//;
        $checked_ports .= " ($checked_string)";
    }

    if ($save_file) {
        if ($debug) {       print "saving file\n";   }
        system("mv " . $stat_file . ".TMP $stat_file");
    }

    if ($has_error) {
        if (!$save_file && !$error) {
            $error .= "$checked_ports: NO Errors. Monitor time between checks is less than $min_mon. (critical for nagios so we don't flap nagios)";
        }
        if ($e > 1)     {$info = "CRIT: ";}
        elsif ($e == 1) {$info = "WARN: ";}
        else            {$info = "UNK: "; }

        $info .=  "$error\n";
    } else {
        $e = 0; ## no errros - OK
        $info = "OK: $checked_ports: Zero or less than $warn_packet_loss\% Packet Loss over $mon_sec seconds\n";
    }
    return ($info,$e);
}


sub TelnetConcentrator() {
    my ($switch,$cmd) = @_;
    my $s = Net::Appliance::Session->new(
                                         Host      => $switch,
                                         Transport => 'Telnet',
                                         );
    my $username = 'su';
    my $passwd = 'loCkHe3d71';
    $s->connect(Name => $username, Password => $passwd);
    my $oldhandler = $SIG{CHLD};
    delete $SIG{CHLD};
    #print $cmd;

    my @output = $s->cmd($cmd);
    $s->close;
    return @output;
}





sub fixWWPport() {
    my ($port) = @_;
    my $port_display = $port;
    if ($port =~ /^[\d]+/) {
        if ($port < 10001) {
            $port_display = 'local' . $port;
                $port = $port+10000;
        } else {
            $port_display = $port-10000;
        }
        $port =~ s/\s//g;
    }
    return ($port,$port_display);
}


sub GetLocalType() {
    ## Remote Switch Type
    my ($ip,$type) = @_;
    my $oid = 'SNMPv2-MIB::sysDescr.0';
    my $query = "$ip $oid";
    my $output = &SNMPGquery($query,$type);
    if ($output =~ /$oid\s=\sSTRING:\s(.*)/i) {
        return $1;
    }
}


sub SNMPGquery() {
    my ($query,$type,$OID_only) = @_;
    my $community = $snmp_cro;
    if (defined($type) && $type =~ /portal/i) {
        $community = $snmp_p_cro;
    }
    if ($OID_only) {
        $community .= ' -On ';
    }
    my $cmd = "$snmpg_bin $community $query";
    if ($debug > 0) {
        print "\n " . $cmd . "\n";
    }
    my $output = `$cmd`;
    if ($debug > 1) {
        chomp($output);
        print "DEBUG: $output \n";

    }
    return $output;
}