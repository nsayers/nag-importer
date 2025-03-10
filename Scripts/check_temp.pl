#!/usr/bin/perl -w
# sensorname is mapped to a sensor id in /etc/sensormap,
# sensorsids are mapped to a sensor number in /etc/.digitemprc
# digitemp -c /etc/.digitemprc -s /dev/ttyS0 -i will rebuild
# the map for the sensor number to sensor ids, which needs to be done if there is
# any change in the connection order, additions, or subtractions of the sensors.
# the sensorname map only needs to be changed if a sensor is added or removed,
# and you want this check to be able to see it.
#
# modified 4/14/20 by SteveM to allow for negative temp values - indicates that the
# temperatures are considered minimums rather than maximums.

use strict;
use DBI; # to insert sensor data . Dacsis
use Data::Dumper;

my $max_tries = 10;  ## how many tries to wait for the sensore to become available.
my $sleep = 2;       ## sleep intervals betweek the max_tries


my $debug = 1;
my @args = @ARGV;
my $sensor = shift;
my @sensorlist;
my %sensormap;

&printcrit("no arguments") if(@args != 1);
&loadsensorlist;
&printcrit("no defined sensors.") if(!@sensorlist);
&loadsensormap;

if($sensor eq "sensorlist") {
    my @keys = keys %sensormap;
    foreach(sort(@keys))     {
        print "sensor: name    : $_\n";
        print "        number  : ${$sensormap{$_}}{'NUM'}\n";
        print "        id      : ${$sensormap{$_}}{'ID'}\n";
        print "        warning : ${$sensormap{$_}}{'WARN'}\n";
        print "        critical: ${$sensormap{$_}}{'CRIT'}\n\n";
    }
    exit;
} elsif ($sensor eq "all" || $sensor eq "db") {
    my @keys = keys %sensormap;
    my $errorlevel = 0;
    my $message = "";
    my $data = {};
    foreach(sort(@keys)) {
        my ($F,$C,$serial,$id) = &getsensorval($_);
        my $temp = $F;


        $data->{$serial}->{'wF'} =  ${$sensormap{$_}}{'CRIT'};
    $data->{$serial}->{'F'} = $F;
    $data->{$serial}->{'C'} = $C;
    $data->{$serial}->{'extraInfo'} = ${$sensormap{$_}}{'INFO'};

if(!$temp)        {
            $message .= "CRITICAL: $_ - no answer\n";
            $errorlevel = 2;
        } elsif ( $temp > ${$sensormap{$_}}{'CRIT'}) {
        $message .= "CRITICAL: $_ - $temp F\n";
        $errorlevel = 2;
    } elsif ($temp > ${$sensormap{$_}}{'WARN'}) {
    $message .= "WARNING: $_ - $temp F\n";
    $errorlevel = 1 if(!$errorlevel);
        } else {
            $message .= "TEMP OK: $_ - $temp F\n";
        }
    }

if ($sensor eq "db" && ref($data)) {
 foreach my $serial (keys %{$data}) {
     my $t = $data->{$serial};
&insertSensorData($serial,$t->{'F'},$t->{'C'},$t->{'wF'},$t->{'extraInfo'});
}
exit;

} else {
    print $message;
    exit $errorlevel;
}
}

&printcrit("'$sensor' not in sensor map") if(!exists $sensormap{$sensor});

my ($temp) = &getsensorval($sensor);

if(!$temp)
{
    &printcrit("$sensor - no answer");
} elsif(${$sensormap{$sensor}}{'CRIT'} > 0) {
    if($temp > ${$sensormap{$sensor}}{'CRIT'}) {
        &printcrit("$sensor - $temp F | $sensor=$temp"."F;${$sensormap{$sensor}}{'WARN'};${$sensormap{$sensor}}{'CRIT'}");
    } elsif($temp > ${$sensormap{$sensor}}{'WARN'}) {
        &printwarn("$sensor - $temp F | $sensor=$temp"."F;${$sensormap{$sensor}}{'WARN'};${$sensormap{$sensor}}{'CRIT'}");
    } else {
        &printok("$sensor - $temp F | $sensor=$temp"."F;${$sensormap{$sensor}}{'WARN'};${$sensormap{$sensor}}{'CRIT'}");
    }
} else {
    if($temp < abs(${$sensormap{$sensor}}{'CRIT'})) {
        &printcrit("$sensor - $temp F | $sensor=$temp"."F;${$sensormap{$sensor}}{'WARN'};${$sensormap{$sensor}}{'CRIT'}");
    } elsif($temp < abs(${$sensormap{$sensor}}{'WARN'})) {
        &printwarn("$sensor - $temp F | $sensor=$temp"."F;${$sensormap{$sensor}}{'WARN'};${$sensormap{$sensor}}{'CRIT'}");
    } else {
        &printok("$sensor - $temp F | $sensor=$temp"."F;${$sensormap{$sensor}}{'WARN'};${$sensormap{$sensor}}{'CRIT'}");
    }
}

##### subs #####

sub loadsensorlist
{
    open DIGIRC, "/etc/.digitemprc" or
        &printcrit("Could not open /etc/.digitemprc");

    while(<DIGIRC>)
    {
        # Seriously? You only check the first 4 pairs? Out of 8 possible?
        # Think some of these might SHARE those first 4 pairs?
        # #THANKYOUROB
        # there is no reason not to use the entire serial
        if(/^ROM (\d+) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2}) 0x([\da-fA-F]{2})/)
        {
            push @sensorlist, uc $2.uc $3.uc $4.uc $5 . uc $6 . uc $7 . uc $8 . uc $9;
            #print STDERR '[' . uc $2.uc $3.uc $4.uc $5 . uc $6 . uc $7 . uc $8 . uc $9 . '] Added' . "\n";
        }
    }



    close DIGIRC;
}

sub loadsensormap
{
    open MAP, "/etc/sensormap" or
        &printcrit("Could not open /etc/sensormap");

    while(<MAP>)
    {
        if(/^([^\#]+)=(\w+),(\-*\w+),(\-*\w+),(.+)/)        {

            if(&getsensornum($2) eq "ERR") {
              #foreach(0..$#sensorlist) {
              #  print STDERR "Sensor: $sensorlist[$_]\n";
              #}
              &printcrit("sensor $2 ($1) not in digitemp config.");
            }
            $sensormap{$1} = {'NUM' => &getsensornum($2),
                              'WARN' => $3,
                              'CRIT' => $4,
                              'ID' => $2,
                              'INFO' => $5
                              };
        }
    }

    &printcrit("No sensors defined in sensor map") if(!keys %sensormap);

    close MAP;
}

sub getsensornum
{
    my $sensor = uc shift;

    foreach(0..$#sensorlist)
    {
        return $_ if($sensor eq $sensorlist[$_]);
    }
    return "ERR";
}

sub printcrit
{
    my @output = @_;

    print "TEMP CRITICAL: ", @output, "\n";
    exit 2;
}

sub printwarn
{
    my @output = @_;

    print "TEMP WARNING: ", @output, "\n";
    exit 1;
}

sub printok
{
    my @output = @_;

    print "TEMP OK: ", @output, "\n";
    exit 0;
}

sub getsensorval
{
    my $sensor = shift;
    my $cmd = "sudo /usr/local/bin/digitemp -s/dev/ttyS0 -c/etc/.digitemprc -t ${$sensormap{$sensor}}{'NUM'}";
    #my $cmd = "sudo /usr/local/bin/digitemp -c /etc/.digitemprc -t ${$sensormap{$sensor}}{'NUM'}";
    #print STDERR qq{$cmd}."\n";
    #my @output = `$cmd`;



    my $execres = `$cmd 2>&1`;

    if($execres =~ /ttyS\d+\s+is locked|Write\sCOM\sFailed/i) {
        my $count = 0;
        while($execres =~ /ttyS\d+\s+is locked|Write\sCOM\sFailed/i) {
            #print "serial is locked by another process sleeping 2 sec -- retry \# $count\n ";
            $count++;
            sleep($sleep);
            $execres = `$cmd 2>&1`;
            if ($count > $max_tries) {
                print "CRITICAL: $execres\n";
                exit(2);
            }
        }
    }

    my @output = split(/\n/, $execres);
    foreach my $line (@output)    {
        if($line =~ /sn:([^\s]+).*Sensor (\d+)\s+C:\s(\d+\.\d+)\s+F:\s+(\d+\.\d+)/) {
            my $serial = $1;
            my $id = $2;
            my $C = $3;
            my $F = $4;

            #        if(/F: (\d+\.\d+)/)        {
            return ($F,$C,$serial,$id);
            #return $1;
        }
    }
    return 0;
}


sub insertSensorData() {
    my $dbh = DBI->connect("DBI:mysql:dbname=dacsis;host=chunk.isomedia.com;port=3306", "tempSensor", ".knurd1208.!",);
    my ($sn,$f,$c,$wF,$eI) = @_;
    $wF = 90;
    my $rem_server = 'iso_W2505-66.113.104.36';
    my $statement = "insert into sensorMap (`serial`,`fahrenheit`,`celsius`,`warnF`,`extraInfo`,`lastUpdate`,`remote_server`) values ('$sn',$f,$c,$wF,'$eI',now(),'$rem_server' ) " .
        " ON DUPLICATE KEY UPDATE `fahrenheit` = $f, `celsius` = $c, `remote_server` ='$rem_server', `lastUpdate` = now() ";
    if ($debug>0) { print "\n$statement\n";}
    my $sth = $dbh->prepare($statement)
        or die "Can't prepare $statement: $dbh- >errstr\n";
    $sth->execute();
    if ($sth->rows > 0) {
        if ($debug>0) {print "Success\n";}
    } else {
        if ($debug>0) {print "Failue\n";}
    }
}



my $rem_server = 'iso_W2505-66.113.104.36'


DBI:mysql:dbname=dacsis;host=chunk.isomedia.com;port=3306", "tempSensor", ".knurd1208.!",);



define service{
        use                             generic-service         ; Name of service template to use

        host_name                       bhmon
        service_description             TEMP-Thermostats
        is_volatile                     0
        check_period                    24x7
        max_check_attempts              10
        normal_check_interval           10
        retry_check_interval            2
        contact_groups                  hfnadmins,hfnfacility
        notification_interval           15
        notification_period             24x7
        notification_options            w,u,c,r
        notes                           MAC 2670F98000000075
        check_command                   check_nrpe_arg!check_tempsensor!thermostats
        action_url                      https://highmon3.isomedia.com/pnp4nagios/graph?host=$HOSTNAME$&srv=$SERVICEDESC$
        }

define service{
        use                             generic-service         ; Name of service template to use

        host_name                       bhmon
        service_description             TEMP-Wall-Unit
        is_volatile                     0
        check_period                    24x7
        max_check_attempts              10
        normal_check_interval           10
        retry_check_interval            2
        contact_groups                  hfnadmins,hfnfacility
        notification_interval           15
        notification_period             24x7
        notification_options            w,u,c,r
        notes                           MAC 268A17810000003F
        check_command                   check_nrpe_arg!check_tempsensor!wall-unit
        action_url                      https://highmon3.isomedia.com/pnp4nagios/graph?host=$HOSTNAME$&srv=$SERVICEDESC$
        }

define service{
        use                             generic-service         ; Name of service template to use
        host_name                       bhmon
        service_description             TEMP-Ceiling-Unit
        is_volatile                     0
        check_period                    24x7
        max_check_attempts              10
        normal_check_interval           10
        retry_check_interval            2
        contact_groups                  hfnadmins,hfnfacility
        notification_interval           15
        notification_period             24x7
        notification_options            w,u,c,r
        notes                           MAC 2645F98000000073
        check_command                   check_nrpe_arg!check_tempsensor!ceiling-unit
        action_url                      https://highmon3.isomedia.com/pnp4nagios/graph?host=$HOSTNAME$&srv=$SERVICEDESC$
        }

define service{
        use                             generic-service         ; Name of service template to use
        host_name                       bhmon
        service_description             TEMP-HVAC-1_Duct-3
        is_volatile                     0
        check_period                    24x7
        max_check_attempts              10
        normal_check_interval           10
        retry_check_interval            2
        contact_groups                  hfnadmins,hfnfacility
        notification_interval           15
        notification_period             24x7
        notification_options            w,u,c,r
        notes                           MAC 26A30A810000008F
        check_command                   check_nrpe_arg!check_tempsensor!hvac-1-duct-3
        action_url                      https://highmon3.isomedia.com/pnp4nagios/graph?host=$HOSTNAME$&srv=$SERVICEDESC$
        }
