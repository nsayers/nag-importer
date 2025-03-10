#!/usr/bin/perl

# Cobled together through the mad eyes of
# Neil Sayers
#

#use strict;
#use warnings;
use utf8;
use Getopt::Long qw(GetOptions);
use DBI;
use Data::Dumper;
use experimental 'smartmatch';
use feature 'say';
use POSIX qw(strftime);
use File::Path qw(make_path);

my $count=1;
my @arr;
my $all = '\*';
my $exclude = '"!"';

my $current_date = strftime("%Y-%m-%d", localtime());

my $log_file = "/tmp/nagios-script_$current_date.log";

open(my $fh, '>>', $log_file) or die "Could not open '$log_file' for writing: $!";
my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime());  # Get the current timestamp
my $log_entry = "[$timestamp] This is a log message for $current_date.\n";
print $fh $log_entry;

my @donotattempt = ('nagios.cfg'|'cgi.cfg'|'ndo2db.cfg'|'ndomod.cfg'|'nrpe.cfg'|'resource.cfg');

GetOptions(
  'file|f=s' => \$infile,
  'method|m=s' => \$method,
  'output|o=s' => \$output,
  'type|t=s' => \$type,
  'stout|s=s' => \$stout,
  'host|h=s' => \$host_name,
  'debug|v' => \$debug,
  'help|?' => sub { HelpMessage() },
)  or die HelpMessage();

my @chars = ('0'..'9', 'A'..'F');
my $len = 12;
my $outfile;
while($len--){ $outfile .= $chars[rand @chars] };

# assign the values in the accessDB file to the variables
my $database = 'nagios';
my $host = '127.0.0.1';
my $username = 'nagioscfg';
my $password = '{removed}';

#DATA SOURCE NAME
$dsn = "DBI:mysql:$database:$host:3306";

# make connection to database
my %attr = (PrintError=>0,RaiseError=>1 );
my $dbh = DBI->connect($dsn, $username, $password,\%attr);

print "$infile\n";
print $fh "$infile\n";

if ($infile =~ /^(nagios.cfg|cgi.cfg|ndo2db.cfg|ndomod.cfg|nrpe.cfg|resource.cfg)$/) {
    print "I NEED TO DIE, I don't want to process these files.";
    print $fh "I NEED TO DIE, I don't want to process these files.\n";
    exit;
}



if($infile ne '') {
    readFile($infile);
} elsif($method eq 'fixup' && $type eq 'host') {
        mysqlFixHost();
        exit;
} elsif($method eq 'fixup' && $type eq 'service') {
        mysqlFixServiceHost();
        exit;
} elsif($method eq 'fixup' && $type eq 'contact') {
        mysqlFixContact();
        exit;
} elsif($method eq 'fixup' && $type eq 'servicegroup') {
        mysqlFixServiceGroup();
        exit;
} elsif($method eq 'fixup') {
        mysqlFixHost();
        mysqlFixServiceHost();
        exit;
} elsif($method eq 'output' && $type eq 'full') {
    if($host_name ne 'all') {
            $toutput .= mysqlGetHost($host_name);
            $toutput .= mysqlGetHostDep($host_name);
            $toutput .= mysqlGetHostEsc($host_name);
            $toutput .= mysqlGetHostExt($host_name);
            $toutput .= mysqlGetService($host_name);
            $toutput .= mysqlGetServiceDep($host_name);
            $toutput .= mysqlGetServiceExt($host_name);
            $toutput .= mysqlGetServiceEsc($host_name);
            $toutput .= mysqlGetCustService($host_name);
            $toutput .= mysqlGetCustServiceDep($host_name);
            $toutput .= mysqlGetCustServiceExt($host_name);
            $toutput .= mysqlGetCustServiceEsc($host_name);
            $toutput .= mysqlGetHardwareService($host_name);
            $toutput .= mysqlGetHardwareDep($host_name);
            $toutput .= mysqlGetHardwareServiceEsc($host_name);
            $toutput .= mysqlGetOtherService($host_name);
            $toutput .= mysqlGetOtherDep($host_name);
        #} else {
        #    $toutput .= mysqlGetAll();
        #}
        if(defined($debug)) { print "$toutput\n"; }
    } elsif($host_name eq '' || $host_name eq 'all') {
        # Sort the hosts first.
        my $sqlq = "SELECT host_name,directory from host where host_name != ''";
        my $sta = $dbh->prepare($sqlq);
        $sta->execute() or die $DBI::errstr;
        while(@row = $sta->fetchrow_array()) {
            if(defined($debug)) { print $row['1']."/".$row['0']."\n"; }
            $toutput = '';
            $toutput .= mysqlGetHost($row['host_name']);
            $toutput .= mysqlGetHostDep($row['host_name']);
            $toutput .= mysqlGetHostEsc($row['host_name']);
            $toutput .= mysqlGetHostExt($row['host_name']);
            $toutput .= mysqlGetService($row['host_name']);
            $toutput .= mysqlGetServiceDep($row['host_name']);
            $toutput .= mysqlGetServiceExt($row['host_name']);
            $toutput .= mysqlGetServiceEsc($row['host_name']);
            $toutput .= mysqlGetCustService($row['host_name']);
            $toutput .= mysqlGetCustServiceDep($row['host_name']);
            $toutput .= mysqlGetCustServiceExt($row['host_name']);
            $toutput .= mysqlGetCustServiceEsc($row['host_name']);
            $toutput .= mysqlGetHardwareService($row['host_name']);
            $toutput .= mysqlGetHardwareDep($row['host_name']);
            $toutput .= mysqlGetHardwareServiceEsc($row['host_name']);
            $toutput .= mysqlGetOtherService($row['host_name']);
            $toutput .= mysqlGetOtherDep($row['host_name']);
            if($toutput ne '' && $stout eq 'file') {
                my $stoutdir = $row['1']."/";
                my $stoutfile = $row['0'];
                $stoutfile =~ s/\s+$//;
                $stoutfile =~ s/ /-/g;

                if(defined($debug)) { print "directory: $stoutdir\n"; print "file : $stoutfile\n"; }

                unless (-d $stoutdir) {
                    make_path($stoutdir) or die "Failed to create directory: $!";
                }
                open (FH, '>' , $stoutdir."/".$stoutfile.'.cfg') or die $!;
                print FH $toutput;
                close (FH);
            } else {
                print $toutput;
            }
        }
    }
} elsif($method eq 'output' && $type eq 'contact') {
    $toutput .= mysqlGetContact();
    if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'contactgrp') {
    $toutput .= mysqlGetContactGrp();
    if(defined($debug)) { print "$toutput\n"; }

} elsif($method eq 'output' && $type eq 'host') {
        if(defined($host_name)) {
            $toutput .= mysqlGetHost($host_name);
            $toutput .= mysqlGetHostDep($host_name);
            $toutput .= mysqlGetHostEsc($host_name);
            $toutput .= mysqlGetHostExt($host_name);
        } else {
            print "all called for\n";
            $toutput = mysqlGetAll();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'hostonly') {
        if(defined($host_name)) {
            $toutput .= mysqlGetHost($host_name);
        } else {
            print "all called for\n";
            $toutput .= mysqlGetAll();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'hostdep') {
        if(defined($host_name)) {
            $toutput .= mysqlGetHostDep($host_name);
        } else {
            $toutput .= mysqlGetHostDep();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'hostesc') {
        if(defined($host_name)) {
            $toutput .= mysqlGetHostEsc($host_name);
        } else {
            $toutput .= mysqlGetHostEsc();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'hostext') {
        if(defined($host_name)) {
            $toutput .= mysqlGetHostExt($host_name);
        } else {
            $toutput .= mysqlGetHostExt();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'hostgrp') {
        if(defined($host_name)) {
            $toutput .= mysqlGetHostGrp($host_name);
        } else {
            $toutput .= mysqlGetHostGrp();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'service') {
        if(defined($host_name)) {
            $toutput .= mysqlGetService($host_name);
            $toutput .= mysqlGetCustService($host_name);
        } else {
            $toutput .= mysqlGetService();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'servicedep') {
        if(defined($host_name)) {
            $toutput .= mysqlGetServiceDep($host_name);
            $toutput .= mysqlGetCustServiceDep($host_name);
        } else {
            $toutput .= mysqlGetServiceDep();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'serviceesc') {
        if(defined($host_name)) {
            $toutput .= mysqlGetServiceEsc($host_name);
            $toutput .= mysqlGetCustServiceEsc($host_name);
        } else {
            $toutput .= mysqlGetServiceEsc();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'serviceext') {
        if(defined($host_name)) {
            $toutput .= mysqlGetServiceExt($host_name);
            $toutput .= mysqlGetCustServiceExt($host_name);
        } else {
            $toutput .= mysqlGetServiceExt();
        }
        if(defined($debug)) { print "$toutput\n"; }
} elsif($method eq 'output' && $type eq 'servicegrp') {
        if(defined($host_name)) {
            $toutput .= mysqlGetServiceGrp($host_name);
        } else {
            $toutput .= mysqlGetServiceGrp();
        }
        if(defined($debug)) { print "$toutput\n"; }

} else {
    print "No method defined.\n\n";
    HelpMessage();
    exit;
}

if(defined($toutput)){
        if($toutput ne '' && $stout eq 'file') {
            my $stoutfile = $host_name;
            open (FH, '>' , $stoutfile.'.cfg') or die $!;
            print FH $toutput;
            close (FH);
        } else {
            print $toutput;
        }
}


if($method eq 'print') {
        mysqlPrint();
        exit;
} elsif($method eq 'import') {
        mysqlInsert();
        exit;
}

sub readFile {
    my $file = $_[0];
    open(IN,$file) or die "Error with infile $file: $!\n";
    my @data=<IN>;
    close(IN);

    foreach my $line (@data) {
        chomp($line);
        $line=~ s/^\s+//;
        if ($line =~ /^\#\# /) {
            $category = substr($line,3);
        }
        next if $line =~ /\#\#/;

        if($line eq "") {
            next;
        } elsif($line =~ /^\#/) {
            next;
        } else {
            if ($line =~ /^define/) {
                my @definition = split(' ',$line);
                if($definition[1] =~ /\}\z/) {
                    $chomped = chomp($definition[1]);
                    push @arr, "$chomped`";
                    next;
                } else {
                    $definition[1] =~ s/[^a-zA-Z0-9,]//g;
                    push @arr, "$definition[1]`";
                    next;
                }

            } elsif ($line !~ /}/) {
                my @definition = split(' ',$line, 2);
                push(@arr, "$definition[0]`");
                push(@arr, "$definition[1]`");
                next;
            } else {
                push @arr, "category`$category`";
                # Put the file path in the array
                if(grep {$_ eq 'host' || $_ ne 'directory'} @arr ) {
                        push(@arr, 'directory`');
                        $dir = $file;
                        $dir =~ s|/[^/]+$||;
                        push(@arr, $dir);
                }

                push @arr, "\n";
            }

        }
    }
    system('mkdir -p /tmp/nagios');
    open (FILE, ">> /tmp/nagios/$outfile") || die "problem opening $outfile\n";
    print FILE @arr;
    close(FILE);
}


sub mysqlPrint {
     my $tempfile = '/tmp/nagios/'.$outfile;
     open(IN,$tempfile) or die "Error with file $outfile: $!\n";
     my @data=<IN>;
     close(IN);

    foreach my $line (@data) {
        chomp($line);
        my @recarray = split('`', $line);
        $type = shift(@recarray);
        my $def = '';
        my $val = '';
        my $up = '';
        for (my $i = 0; $i < @recarray; $i += 2) {
            if(grep(/^$def$/, @recarray)) {
                print "$def duplicate";
            } else {
                $def .= ",`".@recarray[$i]."`";
                $val .= ",'".@recarray[$i + 1]."'";
                $up .= ",`".@recarray[$i]."` = '".@recarray[$i + 1]."'";
            }
        }
        $def =~ s/^.//;
        $val =~ s/^.//;
        $up =~ s/^.//;
        print "INSERT INTO ".$type." ";
        print " (".$def.")\n";
        print " \tVALUES ";
        print " (".$val.")\n";
    }
}

sub mysqlInsert {
    my $tempfile = '/tmp/nagios/'.$outfile;
    open(IN,$tempfile) or die "Error with file $outfile: $!\n";
    my @data=<IN>;
    close(IN);

    foreach my $line (@data) {
        chomp($line);
        my @recarray = split('`', $line);
        $type = shift(@recarray);
        my $def = '';
        my $val = '';
        my $up = '';
        for (my $i = 0; $i < @recarray; $i += 2) {
            $def .= ",`".@recarray[$i]."`";
            $val1 = @recarray[$i + 1];
            $val1 =~ s/'/"/g;
            #$val1 = lc($val1);
            $val .= ",'".$val1."'";
            $up .= ",`".@recarray[$i]."` = \'".$val1."\'";
        }
        $def =~ s/^.//;
        $val =~ s/^.//;
        $up =~ s/^.//;
        my $sql = "INSERT INTO ".$type." (".$def.")";
        $sql .= " VALUES (".$val.") ";
        print $fh "$sql \n";
        my $stmt = $dbh->prepare($sql);
                $stmt->execute() or die "file failed: $infile\n SQL command: $sql\nError: $DBI::errstr";
                $stmt->finish();
    }
}

sub mysqlFixContact {
    # Sort the hosts first.
    my $sqlq = "SELECT contactgroup_name,members,id FROM contactgroup WHERE members != ''";
    my $stmt = $dbh->prepare($sqlq);
        $stmt->execute() or die $DBI::errstr;
        while(my @row = $stmt->fetchrow_array()){
            my @members = split(',', $row[1]);
            if ( grep( /^$\*$/, @members)) {
                print "fuck it, put this on all contacts\n";
            } else {
                foreach(@members) {
                    my $sqlsq = "SELECT contactgroups,id FROM contact WHERE contact_name = '$_'";
                    my $stmt1 = $dbh->prepare($sqlsq);
                    $stmt1->execute() or die $DBI::errstr;
                    while(my @row1 = $stmt1->fetchrow_array()){
                        if($row1[0] != '') {
                            $contactgroup = $row1[0].",".$row[0];
                        } else {
                            $contactgroup = $row[0];
                        }
                        print "UPDATE contact SET contactgroups = '$contactgroup' where id = '$row1[1]'\n";
                    }
                    $stmt1->finish();
                }
            }
        print "Then delete the contactgroup members\n";
        print "UPDATE contactgroup SET members = '' where id = '$row[2]'\n\n";
        }
        $stmt->finish();
}

sub mysqlFixHost {
    # Sort the hosts first.
    my $sqlq = "SELECT hostgroup_name,members,id FROM hostgroup WHERE members != ''";
    my $stmt = $dbh->prepare($sqlq);
    $stmt->execute() or die $DBI::errstr;
    while(my @row = $stmt->fetchrow_array()){
        my @members = split(',', $row[1]);
        if ( grep( /^$all$/, @members)) {
            @members = grep {!/$all/} @members;
            my @hostcombine = '';
            foreach(@members) {
                my $host = substr($_, 1);
                push @hostcombine, "(host_name NOT LIKE '%$host%') AND ";
            }
                $hoststr = join( ' ', @hostcombine);
                my $sqlsq = "SELECT hostgroups,id FROM host WHERE $hoststr ( id >= '1' )";
                if(defined($debug)) { print "$sqlsq\n"; }
                my $stmt1 = $dbh->prepare($sqlsq);
                $stmt1->execute() or die $DBI::errstr;
                while(my @row1 = $stmt1->fetchrow_array()){
                    @hostgroups = split (/,/, $row1[0]);
                    push(@hostgroups, $row[0]) unless $row[0] ~~ @hostgroups;
                    $hostgroup = join(',', @hostgroups);
                    my $qu1 = "UPDATE host SET hostgroups = '$hostgroup' where id = '$row1[1]'\n";
                    my $st1 = $dbh->prepare($qu1);
                    $st1->execute() or die $DBI::errstr;
                    $st1->finish();

                }
                $stmt1->finish();
        } else {
            foreach(@members) {
                my $sqlsq = "SELECT hostgroups,id FROM host WHERE host_name = '$_'";
                my $stmt1 = $dbh->prepare($sqlsq);
                $stmt1->execute() or die $DBI::errstr;
                while(my @row1 = $stmt1->fetchrow_array()){
                    @hostgroups = split (/,/, $row1[0]);
                    push(@hostgroups, $row[0]) unless $row[0] ~~ @hostgroups;
                    $hostgroup = join(',', @hostgroups);
                    my $qu1 = "UPDATE host SET hostgroups = '$hostgroup' where id = '$row1[1]'\n";
                    print "$qu1\n";
                    my $st1 = $dbh->prepare($qu1);
                    $st1->execute() or die $DBI::errstr;
                    $st1->finish();

                }
                $stmt1->finish();
            }
        }
    my $qu2 = "UPDATE hostgroup SET members = '' where id = '$row[2]'\n\n";
    my $st2 = $dbh->prepare($qu2);
    $st2->execute() or die $DBI::errstr;
    $st2->finish();
    }
    $stmt->finish();
}

sub mysqlFixServiceHost {
    my $out = '';
    # Sort the duplicate host entries
    my $sqlq = "SELECT host_name,hostgroup_name,name,alias,check_command,service_description,display_name,servicegroups,is_volatile,initial_state,max_check_attempts,check_interval,normal_check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,enable_predictive_service_dependency_checks,check_period,obsess_over_service,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,failure_prediction_enabled,contacts,contact_groups,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,register,parallelize_check,id,`use` FROM service WHERE host_name LIKE '\%\,\%'";
    my $stmt = $dbh->prepare($sqlq);
    $stmt->execute() or die $DBI::errstr;
    my @columns = ( host_name,hostgroup_name,name,alias,check_command,service_description,display_name,servicegroups,is_volatile,initial_state,max_check_attempts,check_interval,normal_check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,enable_predictive_service_dependency_checks,check_period,obsess_over_service,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,failure_prediction_enabled,contacts,contact_groups,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,register,parallelize_check);
    while(my @row = $stmt->fetchrow_array()){
        my @members = split(',', $row[0]);
        foreach(@members) {
            my $si = '';
            my $vi = '';
            if(defined($row[0])) { $si .= '`host_name`,'; $vi .= "'$_',"};
            if(defined($row[1])) { $si .= '`hostgroup_name`,'; $vi .= "'$row[1]',"; }
            if(defined($row[2])) { $si .= '`name`,'; $vi .= "'$row[2]',"; }
            if(defined($row[3])) { $si .= '`alias`,'; $vi .= "'$row[3]',"; }
            if(defined($row[4])) { $si .= '`check_command`,'; $vi .= "'$row[4]',"; }
            if(defined($row[5])) { $si .= '`service_description`,'; $vi .= "'$row[5]',"; }
            if(defined($row[6])) { $si .= '`display_name`,'; $vi .= "'$row[6]',"; }
            if(defined($row[7])) { $si .= '`servicegroups`,'; $vi .= "'$row[7]',"; }
            if(defined($row[8])) { $si .= '`is_volatile`,'; $vi .= "'$row[8]',"; }
            if(defined($row[9])) { $si .= '`initial_state`,'; $vi .= "'$row[9]',"; }
            if(defined($row[10])) { $si .= '`max_check_attempts`,'; $vi .= "'$row[10]',"; }
            if(defined($row[11])) { $si .= '`check_interval`,'; $vi .= "'$row[11]',"; }
            if(defined($row[12])) { $si .= '`normal_check_interval`,'; $vi .= "'$row[12]',"; }
            if(defined($row[13])) { $si .= '`retry_interval`,'; $vi .= "'$row[13]',"; }
            if(defined($row[14])) { $si .= '`retry_check_interval`,'; $vi .= "'$row[14]',"; }
            if(defined($row[15])) { $si .= '`active_checks_enabled`,'; $vi .= "'$row[15]',"; }
            if(defined($row[16])) { $si .= '`passive_checks_enabled`,'; $vi .= "'$row[16]',"; }
            if(defined($row[17])) { $si .= '`enable_predictive_service_dependency_checks`,'; $vi .= "'$row[17]',"; }
            if(defined($row[18])) { $si .= '`check_period`,'; $vi .= "'$row[18]',"; }
            if(defined($row[19])) { $si .= '`obsess_over_service`,'; $vi .= "'$row[19]',"; }
            if(defined($row[20])) { $si .= '`check_freshness`,'; $vi .= "'$row[20]',"; }
            if(defined($row[21])) { $si .= '`freshness_threshold`,'; $vi .= "'$row[21]',"; }
            if(defined($row[22])) { $si .= '`event_handler`,'; $vi .= "'$row[22]',"; }
            if(defined($row[23])) { $si .= '`event_handler_enabled`,'; $vi .= "'$row[23]',"; }
            if(defined($row[24])) { $si .= '`low_flap_threshold`,'; $vi .= "'$row[24]',"; }
            if(defined($row[25])) { $si .= '`high_flap_threshold`,'; $vi .= "'$row[25]',"; }
            if(defined($row[26])) { $si .= '`flap_detection_enabled`,'; $vi .= "'$row[26]',"; }
            if(defined($row[27])) { $si .= '`flap_detection_options`,'; $vi .= "'$row[27]',"; }
            if(defined($row[28])) { $si .= '`process_perf_data`,'; $vi .= "'$row[28]',"; }
            if(defined($row[29])) { $si .= '`retain_status_information`,'; $vi .= "'$row[29]',"; }
            if(defined($row[30])) { $si .= '`retain_nonstatus_information`,'; $vi .= "'$row[30]',"; }
            if(defined($row[31])) { $si .= '`notification_interval`,'; $vi .= "'$row[31]',"; }
            if(defined($row[32])) { $si .= '`first_notification_delay`,'; $vi .= "'$row[32]',"; }
            if(defined($row[33])) { $si .= '`notification_period`,'; $vi .= "'$row[33]',"; }
            if(defined($row[34])) { $si .= '`notification_options`,'; $vi .= "'$row[34]',"; }
            if(defined($row[35])) { $si .= '`notifications_enabled`,'; $vi .= "'$row[35]',"; }
            if(defined($row[36])) { $si .= '`failure_prediction_enabled`,'; $vi .= "'$row[36]',"; }
            if(defined($row[37])) { $si .= '`contacts`,'; $vi .= "'$row[37]',"; }
            if(defined($row[38])) { $si .= '`contact_groups`,'; $vi .= "'$row[38]',"; }
            if(defined($row[39])) { $si .= '`stalking_options`,'; $vi .= "'$row[39]',"; }
            if(defined($row[40])) { $si .= '`notes`,'; $vi .= "'$row[40]',"; }
            if(defined($row[41])) { $si .= '`notes_url`,'; $vi .= "'$row[41]',"; }
            if(defined($row[42])) { $si .= '`action_url`,'; $vi .= "'$row[42]',"; }
            if(defined($row[43])) { $si .= '`icon_image`,'; $vi .= "'$row[43]',"; }
            if(defined($row[44])) { $si .= '`icon_image_alt`,'; $vi .= "'$row[44]',"; }
            if(defined($row[45])) { $si .= '`register`,'; $vi .= "'$row[45]',"; }
            if(defined($row[46])) { $si .= '`parallelize_check`,'; $vi .= "'$row[46]',"; }
            if(defined($row[48])) { $si .= '`use`,'; $vi .= "'$row[48]',"; }

            chop($si);
            chop($vi);
            $stmt1 = "INSERT INTO service ($si) VALUES ($vi)";
            if(defined($debug)) { $out .= $stmt1; }
            my $s1 = $dbh->prepare($stmt1);
            $s1->execute() or die $DBI::errstr;
        }
        $stmt2 = "UPDATE service SET host_name = '' where id = $row[47]";
        my $s2 = $dbh->prepare($stmt2);
        $s2->execute() or die $DBI::errstr;
    }
    $stmt->finish();
    return $out;
}

sub mysqlFixServiceGroup {
    # Sort the duplicate servicegroup member entries
    my $sqlq = "SELECT servicegroup_name,members,id FROM servicegroup WHERE members LIKE '\%\,\%'";
    my $stmt = $dbh->prepare($sqlq);
    $stmt->execute() or die $DBI::errstr;
    while(my @row = $stmt->fetchrow_array()){
        my @members = split(',', $row[1]);
        my $up = '';
        for (my $i = 0; $i < @members; $i += 2) {
            $up .= "$row[0] servicegroup needs to be added to @members[$i] service @members[$i + 1]\n";
            my $sqlq1 = "SELECT id,servicegroups FROM service WHERE (host_name = '@members[$i]') and (service_description = '@members[$i + 1]')";
            my $stmt1 = $dbh->prepare($sqlq1);
            $stmt1->execute() or die $DBI::errstr;
            while(my @row1 = $stmt1->fetchrow_array()){
                @servicegroups = split (/,/, $row1[1]);
                push(@servicegroups, $row[0]) unless $row[0] ~~ @servicegroups;
                $servicegroup = join(',', @servicegroups);
                my $qu1 = "UPDATE service SET servicegroups = '$servicegroup' where id = '$row1[0]'\n";
                print "$qu1\n";
                #my $st1 = $dbh->prepare($qu1);
                #$st1->execute() or die $DBI::errstr;
                #$st1->finish();
            }
        }
        $qu2 = "UPDATE servicegroup SET members = '' where id = $row[2]";
        #my $st2 = $dbh->prepare($qu2);
        #$st2->execute() or die $DBI::errstr;
        #$st2->finish();
        print "$qu2\n\n";
    }
    $stmt->finish();
}

sub mysqlGetAll {
    my $aoutput = "";
    # Sort the hosts first.
    my $sqlq = "SELECT host_name from host where host_name != '' ";
    my $sta = $dbh->prepare($sqlq);
    $sta->execute() or die $DBI::errstr;
    while(my @row = $sta->fetchrow_array()){
        $aoutput .= mysqlGetHost($row[0]);
        $aoutput .= mysqlGetHostEsc($row[0]);
        $aoutput .= mysqlGetHostExt($row[0]);
        #$aoutput .= mysqlGetService($row[0]);
    }

    return $aoutput;

}

sub mysqlGetContact {
    my $contactout = "";
    # Sort the services first.
    my $sqlq = "SELECT contact_name,alias,`use` as u,name,contactgroups,host_notifications_enabled,service_notifications_enabled,host_notification_period,service_notification_period,host_notification_options,service_notification_options,host_notification_commands,service_notification_commands,hostgroup_members,servicegroup_members,contactgroup_members,email,pager,addressx,can_submit_commands,retain_status_information,retain_nonstatus_information,_PROWL,_PROWL_PRIO_UP,_PROWL_PRIO_OK,_PROWL_PRIO_DOWN,_PROWL_PRIO_WARN,_PROWL_PRIO_CRIT,_PROWL_PRIO_UNK,notes,notes_url,action_url,register FROM contact WHERE id >= '1' order by name";
    if(defined($debug)) { $contactout .= "# $sqlq\n"; }
    my $stc = $dbh->prepare($sqlq);
    $stc->execute() or die $DBI::errstr;
        $contactout .= "################## \n";
        $contactout .= "## contact definition\n";
    while(my @row = $stc->fetchrow_array()){
        $contactout .= "define contact {\n";
        if($row['0'] ne '') { $contactout .= "\tcontact_name                           $row['0']\n"; }
        if($row['1'] ne '') { $contactout .= "\talias                                  $row['1']\n"; }
        if($row['2'] ne '') { $contactout .= "\tuse                                    $row['2']\n"; }
        if($row['3'] ne '') { $contactout .= "\tname                                   $row['3']\n"; }
        if($row['4'] ne '') { $contactout .= "\tcontactgroups                          $row['4']\n"; }
        if($row['5'] ne '') { $contactout .= "\thost_notifications_enabled             $row['5']\n"; }
        if($row['6'] ne '') { $contactout .= "\tservice_notifications_enabled          $row['6']\n"; }
        if($row['7'] ne '') { $contactout .= "\thost_notification_period               $row['7']\n"; }
        if($row['8'] ne '') { $contactout .= "\tservice_notification_period            $row['8']\n"; }
        if($row['9'] ne '') { $contactout .= "\thost_notification_options              $row['9']\n"; }
        if($row['10'] ne '') { $contactout .= "\tservice_notification_options           $row['10']\n"; }
        if($row['11'] ne '') { $contactout .= "\thost_notification_commands             $row['11']\n"; }
        if($row['12'] ne '') { $contactout .= "\tservice_notification_commands          $row['12']\n"; }
        if($row['13'] ne '') { $contactout .= "\thostgroup_members                      $row['13']\n"; }
        if($row['14'] ne '') { $contactout .= "\tservicegroup_members                   $row['14']\n"; }
        if($row['15'] ne '') { $contactout .= "\tcontactgroup_members                   $row['15']\n"; }
        if($row['16'] ne '') { $contactout .= "\temail                                  $row['16']\n"; }
        if($row['17'] ne '') { $contactout .= "\tpager                                  $row['17']\n"; }
        if($row['18'] ne '') { $contactout .= "\taddressx                               $row['18']\n"; }
        if($row['19'] ne '') { $contactout .= "\tcan_submit_commands                    $row['19']\n"; }
        if($row['20'] ne '') { $contactout .= "\tretain_status_information              $row['20']\n"; }
        if($row['21'] ne '') { $contactout .= "\tretain_nonstatus_information           $row['21']\n"; }
        if($row['22'] ne '') { $contactout .= "\t_PROWL                                 $row['22']\n"; }
        if($row['23'] ne '') { $contactout .= "\t_PROWL_PRIO_UP                         $row['23']\n"; }
        if($row['24'] ne '') { $contactout .= "\t_PROWL_PRIO_OK                         $row['24']\n"; }
        if($row['25'] ne '') { $contactout .= "\t_PROWL_PRIO_DOWN                       $row['25']\n"; }
        if($row['26'] ne '') { $contactout .= "\t_PROWL_PRIO_WARN                       $row['26']\n"; }
        if($row['27'] ne '') { $contactout .= "\t_PROWL_PRIO_CRIT                       $row['27']\n"; }
        if($row['28'] ne '') { $contactout .= "\t_PROWL_PRIO_UNK                        $row['28']\n"; }
        if($row['29'] ne '') { $contactout .= "\tnotes                                  $row['29']\n"; }
        if($row['30'] ne '') { $contactout .= "\tnotes_url                              $row['30']\n"; }
        if($row['31'] ne '') { $contactout .= "\taction_url                             $row['31']\n"; }
        if($row['32'] ne '') { $contactout .= "\tregister                               $row['32']\n"; }
        $contactout .= "}\n\n";
    }
    $contactout .= "\n\n";
    return $contactout;
}


sub mysqlGetContactGrp {
    my $contactout = "";
    # Sort the services first.
    my $sqlq = "SELECT contactgroup_name,alias,`use` as u,name,members,notes,notes_url,action_url,register FROM contactgroup WHERE id >= '1' order by name";
    if(defined($debug)) { $contactout .= "# $sqlq\n"; }
    my $stc = $dbh->prepare($sqlq);
    $stc->execute() or die $DBI::errstr;
        $contactout .= "################## \n";
        $contactout .= "## contact group definition\n";
    while(my @row = $stc->fetchrow_array()){
        $contactout .= "define contactgroup {\n";
        if($row['0'] ne '') { $contactout .= "\tcontactgroup_name                      $row['0']\n"; }
        if($row['1'] ne '') { $contactout .= "\talias                                  $row['1']\n"; }
        if($row['2'] ne '') { $contactout .= "\tuse                                    $row['2']\n"; }
        if($row['3'] ne '') { $contactout .= "\tname                                   $row['3']\n"; }
        if($row['4'] ne '') { $contactout .= "\tmembers                                $row['4']\n"; }
        if($row['5'] ne '') { $contactout .= "\tnotes                                  $row['5']\n"; }
        if($row['6'] ne '') { $contactout .= "\tnotes_url                              $row['6']\n"; }
        if($row['7'] ne '') { $contactout .= "\taction_url                             $row['7']\n"; }
        if($row['8'] ne '') { $contactout .= "\tregister                               $row['8']\n"; }
        $contactout .= "}\n\n";
    }
    $contactout .= "\n\n";
    return $contactout;
}


sub mysqlGetHost {
    $limithost = @_[0];
    if($limithost eq '') { return; }
    my $hostout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,alias,display_name,address,parents,hostgroups,check_command,initial_state,max_check_attempts,check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,check_period,obsess_over_host,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,contacts,contact_groups,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,vrml_image,statusmap_image,2d_coords,3d_coords,register,`_ADDRESS6`,`_WORKER` FROM host WHERE host_name = '$limithost' AND id >= '1' order by id";
    if(defined($debug)) { $hostout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $hostout .= "################## \n";
        $hostout .= "## host definition\n";
    while(my @row = $stq->fetchrow_array()){
        $hostout .= "define host {\n";
        if($row['0'] ne '') { $hostout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $hostout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $hostout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $hostout .= "\talias                                          $row['3']\n"; }
        if($row['4'] ne '') { $hostout .= "\tdisplay_name                                   $row['4']\n"; }
        if($row['5'] ne '') { $hostout .= "\taddress                                        $row['5']\n"; }
        if($row['47'] ne '') { $hostout .= "\t_ADDRESS6                                       $row['47']\n"; }
        if($row['6'] ne '') { $hostout .= "\tparents                                        $row['6']\n"; }
        if($row['7'] ne '') { $hostout .= "\thostgroups                                     $row['7']\n"; }
        if($row['8'] ne '') { $hostout .= "\tcheck_command                                  $row['8']\n"; }
        if($row['9'] ne '') { $hostout .= "\tinitial_state                                  $row['9']\n"; }
        if($row['10'] ne '') { $hostout .= "\tmax_check_attempts                             $row['10']\n"; }
        if($row['11'] ne '') { $hostout .= "\tcheck_interval                                 $row['11']\n"; }
        if($row['12'] ne '') { $hostout .= "\tretry_interval                                 $row['12']\n"; }
        if($row['13'] ne '') { $hostout .= "\tretry_check_interval                           $row['13']\n"; }
        if($row['14'] ne '') { $hostout .= "\tactive_checks_enabled                          $row['14']\n"; }
        if($row['15'] ne '') { $hostout .= "\tpassive_checks_enabled                         $row['15']\n"; }
        if($row['16'] ne '') { $hostout .= "\tcheck_period                                   $row['16']\n"; }
        if($row['17'] ne '') { $hostout .= "\tobsess_over_host                               $row['17']\n"; }
        if($row['18'] ne '') { $hostout .= "\tcheck_freshness                                $row['18']\n"; }
        if($row['19'] ne '') { $hostout .= "\tfreshness_threshold                            $row['19']\n"; }
        if($row['20'] ne '') { $hostout .= "\tevent_handler                                  $row['20']\n"; }
        if($row['21'] ne '') { $hostout .= "\tevent_handler_enabled                          $row['21']\n"; }
        if($row['22'] ne '') { $hostout .= "\tlow_flap_threshold                             $row['22']\n"; }
        if($row['23'] ne '') { $hostout .= "\thigh_flap_threshold                            $row['23']\n"; }
        if($row['24'] ne '') { $hostout .= "\tflap_detection_enabled                         $row['24']\n"; }
        if($row['25'] ne '') { $hostout .= "\tflap_detection_options                         $row['25']\n"; }
        if($row['26'] ne '') { $hostout .= "\tprocess_perf_data                              $row['26']\n"; }
        if($row['27'] ne '') { $hostout .= "\tretain_status_information                      $row['27']\n"; }
        if($row['28'] ne '') { $hostout .= "\tretain_nonstatus_information                   $row['28']\n"; }
        if($row['29'] ne '') { $hostout .= "\tcontacts                                       $row['29']\n"; }
        if($row['30'] ne '') { $hostout .= "\tcontact_groups                                 $row['30']\n"; }
        if($row['31'] ne '') { $hostout .= "\tnotification_interval                          $row['31']\n"; }
        if($row['32'] ne '') { $hostout .= "\tfirst_notification_delay                       $row['32']\n"; }
        if($row['33'] ne '') { $hostout .= "\tnotification_period                            $row['33']\n"; }
        if($row['34'] ne '') { $hostout .= "\tnotification_options                           $row['34']\n"; }
        if($row['35'] ne '') { $hostout .= "\tnotifications_enabled                          $row['35']\n"; }
        if($row['36'] ne '') { $hostout .= "\tstalking_options                               $row['36']\n"; }
        if($row['37'] ne '') { $hostout .= "\tnotes                                          $row['37']\n"; }
        if($row['38'] ne '') { $hostout .= "\tnotes_url                                      $row['38']\n"; }
        if($row['39'] ne '') { $hostout .= "\taction_url                                     $row['39']\n"; }
        if($row['40'] ne '') { $hostout .= "\ticon_image                                     $row['40']\n"; }
        if($row['41'] ne '') { $hostout .= "\ticon_image_alt                                 $row['41']\n"; }
        if($row['42'] ne '') { $hostout .= "\tvrml_image                                     $row['42']\n"; }
        if($row['43'] ne '') { $hostout .= "\tstatusmap_image                                $row['43']\n"; }
        if($row['44'] ne '') { $hostout .= "\t2d_coords                                      $row['44']\n"; }
        if($row['45'] ne '') { $hostout .= "\t3d_coords                                      $row['45']\n"; }
        if($row['46'] ne '') { $hostout .= "\tregister                                       $row['46']\n"; }
        if($row['48'] ne '') { $hostout .= "\t_WORKER                                        $row['48']\n"; }
        $hostout .= "}\n\n";
    }
    $hostout .= "\n\n";
    return $hostout;
}

sub mysqlGetHostDep {
    $limithost = @_[0];
    my $hostout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,dependent_host,dependent_hostgroup_name,hostgroup_name,inherits_parent,execution_failure_criteria,notification_failure_criteria,dependency_period,notes,notes_url,action_url FROM hostdependency WHERE host_name = '$limithost' AND id >= '1' order by name";
    if(defined($debug)) { $hostout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $hostout .= "################## \n";
        $hostout .= "## host dependency\n";
    while(my @row = $stq->fetchrow_array()){
        $hostout .= "define hostdependency {\n";
        if($row['0'] ne '') { $hostout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $hostout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $hostout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $hostout .= "\tdependent_host                                 $row['3']\n"; }
        if($row['4'] ne '') { $hostout .= "\tdependent_hostgroup_name                       $row['4']\n"; }
        if($row['5'] ne '') { $hostout .= "\thostgroup_name                                 $row['5']\n"; }
        if($row['6'] ne '') { $hostout .= "\tinherits_parent                                $row['6']\n"; }
        if($row['7'] ne '') { $hostout .= "\texecution_failure_criteria                     $row['7']\n"; }
        if($row['8'] ne '') { $hostout .= "\tnotification_failure_criteria                  $row['8']\n"; }
        if($row['9'] ne '') { $hostout .= "\tdependency_period                              $row['9']\n"; }
        if($row['10'] ne '') { $hostout .= "\tnotes                                          $row['10']\n"; }
        if($row['11'] ne '') { $hostout .= "\tnotes_url                                      $row['11']\n"; }
        if($row['12'] ne '') { $hostout .= "\taction_url                                     $row['12']\n"; }
        $hostout .= "}\n\n";
    }
    $hostout .= "\n\n";
    return $hostout;
}

sub mysqlGetHostEsc {
    $limithost = @_[0];
    my $hostout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,hostgroup_name,contacts,contact_groups,first_notification,last_notification,notification_interval,escalation_period,escalation_options,notes,notes_url,action_url,register FROM hostescalation WHERE host_name = '$limithost' AND id >= '1' order by name";
    if(defined($debug)) { $hostout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $hostout .= "################## \n";
        $hostout .= "## host escalation\n";
    while(my @row = $stq->fetchrow_array()){
        $hostout .= "define hostescalation {\n";
        if($row['0'] ne '') { $hostout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $hostout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $hostout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $hostout .= "\thostgroup_name                                 $row['3']\n"; }
        if($row['4'] ne '') { $hostout .= "\tcontacts                                       $row['4']\n"; }
        if($row['5'] ne '') { $hostout .= "\tcontact_groups                                 $row['5']\n"; }
        if($row['6'] ne '') { $hostout .= "\tfirst_notification                             $row['6']\n"; }
        if($row['7'] ne '') { $hostout .= "\tlast_notification                              $row['7']\n"; }
        if($row['8'] ne '') { $hostout .= "\tnotification_interval                          $row['8']\n"; }
        if($row['9'] ne '') { $hostout .= "\tescalation_period                              $row['9']\n"; }
        if($row['10'] ne '') { $hostout .= "\tescalation_options                             $row['10']\n"; }
        if($row['11'] ne '') { $hostout .= "\tnotes                                          $row['11']\n"; }
        if($row['12'] ne '') { $hostout .= "\tnotes_url                                      $row['12']\n"; }
        if($row['13'] ne '') { $hostout .= "\taction_url                                     $row['13']\n"; }
        if($row['14'] ne '') { $hostout .= "\tregister                                       $row['14']\n"; }
        $hostout .= "}\n\n";
    }
        $hostout .= "\n\n";
    return $hostout;
}

sub mysqlGetHostExt {
    $limithost = @_[0];
    my $hostout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,notes,notes_url,action_url,icon_image,icon_image_alt,vrml_image,statusmap_image,2d_coords,3d_coords,register FROM hostextinfo WHERE host_name = '$limithost' AND id >= '1' order by name";
    if(defined($debug)) { $hostout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $hostout .= "################## \n";
        $hostout .= "## host extinfo\n";
    while(my @row = $stq->fetchrow_array()){
        $hostout .= "define hostextinfo {\n";
        if($row['0'] ne '') { $hostout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $hostout .= "\thost_name                                      $row['1']\n"; }
        if($row['2'] ne '') { $hostout .= "\tuse                                            $row['2']\n"; }
        if($row['3'] ne '') { $hostout .= "\tname                                           $row['3']\n"; }
        if($row['4'] ne '') { $hostout .= "\tnotes                                          $row['4']\n"; }
        if($row['5'] ne '') { $hostout .= "\tnotes_url                                      $row['5']\n"; }
        if($row['6'] ne '') { $hostout .= "\taction_url                                     $row['6']\n"; }
        if($row['7'] ne '') { $hostout .= "\ticon_image                                     $row['7']\n"; }
        if($row['8'] ne '') { $hostout .= "\ticon_image_alt                                 $row['8']\n"; }
        if($row['9'] ne '') { $hostout .= "\tvrml_image                                     $row['9']\n"; }
        if($row['10'] ne '') { $hostout .= "\tstatusmap_image                                $row['10']\n"; }
        if($row['11'] ne '') { $hostout .= "\t2d_coords                                      $row['11']\n"; }
        if($row['12'] ne '') { $hostout .= "\t3d_coords                                      $row['12']\n"; }
        if($row['13'] ne '') { $hostout .= "\tregister                                       $row['13']\n"; }
        $hostout .= "}\n\n";
    }
        $hostout .= "\n\n";
    return $hostout;
}

sub mysqlGetHostGrp {
    $limithost = @_[0];
    my $hostout = "";
    # Set the title, so people will be warned.
    my $hostout .= '##########\n# YOU WILL BE FLOGGED IF YOU ENTER MEMBERS HERE, add the group to the host definition';

    # Sort the services first.
    if($limithost ne ''){
        $sqlq = "SELECT `hostgroup_name`,`use`,`name`,`alias`,members,hostgroup_members,servicegroup_members,contactgroup_members,notes,notes_url,action_url,register FROM hostgroup WHERE hostgroup_name = '$limithost' AND id >= '1' order by hostgroup_name";
    } else {
        $sqlq = "SELECT `hostgroup_name`,`use`,`name`,`alias`,members,hostgroup_members,servicegroup_members,contactgroup_members,notes,notes_url,action_url,register FROM hostgroup WHERE id >= '1' order by hostgroup_name";
    }
    if(defined($debug)) { $hostout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
    while(my @row = $stq->fetchrow_array()){
        $hostout .= "define hostgroup {\n";
        if($row['0'] ne '') { $hostout .= "\thostgroup_name                                 $row['0']\n"; }
        if($row['1'] ne '') { $hostout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $hostout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $hostout .= "\talias                                          $row['3']\n"; }
        if($row['4'] ne '') { $hostout .= "\tmembers                                        $row['4']\n"; }
        if($row['5'] ne '') { $hostout .= "\thostgroup_members                              $row['5']\n"; }
        if($row['6'] ne '') { $hostout .= "\tservicegroup_members                           $row['6']\n"; }
        if($row['7'] ne '') { $hostout .= "\tcontactgroup_members                           $row['7']\n"; }
        if($row['8'] ne '') { $hostout .= "\tnotes                                          $row['8']\n"; }
        if($row['9'] ne '') { $hostout .= "\tnotes_url                                      $row['9']\n"; }
        if($row['10'] ne '') { $hostout .= "\taction_url                                     $row['10']\n"; }
        if($row['11'] ne '') { $hostout .= "\tregister                                       $row['11']\n"; }
        $hostout .= "}\n\n";
    }
        $hostout .= "\n\n";
    return $hostout;
}


sub mysqlGetService {
    $limitservice = @_[0];
    if($limitservice eq '') { return; }
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`hostgroup_name`,`use`,`name`,`alias`,service_description,display_name,servicegroups,is_volatile,check_command,initial_state,max_check_attempts,check_interval,normal_check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,enable_predictive_service_dependency_checks,check_period,obsess_over_service,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,failure_prediction_enabled,contacts,contact_groups,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,register,parallelize_check FROM service WHERE host_name = '$limitservice' AND (category = 'Service Definition' OR category = 'service definition') AND id >= '1' order by service_description";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
    $serviceout .= "################## \n";
    $serviceout .= "## service definitions\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define service {\n";
        if($row['5'] ne '') { $serviceout .= "\tservice_description                            $row['5']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tname                                           $row['3']\n"; }
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\thostgroup_name                                 $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tuse                                            $row['2']\n"; }
        if($row['4'] ne '') { $serviceout .= "\talias                                          $row['4']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdisplay_name                                   $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tservicegroups                                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tis_volatile                                    $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tcheck_command                                  $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinitial_state                                  $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tmax_check_attempts                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tcheck_interval                                 $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnormal_check_interval                          $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tretry_interval                                 $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tretry_check_interval                           $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\tactive_checks_enabled                          $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tpassive_checks_enabled                         $row['17']\n"; }
        if($row['18'] ne '') { $serviceout .= "\tenable_predictive_service_dependency_checks    $row['18']\n"; }
        if($row['19'] ne '') { $serviceout .= "\tcheck_period                                   $row['19']\n"; }
        if($row['20'] ne '') { $serviceout .= "\tobsess_over_service                            $row['20']\n"; }
        if($row['21'] ne '') { $serviceout .= "\tcheck_freshness                                $row['21']\n"; }
        if($row['22'] ne '') { $serviceout .= "\tfreshness_threshold                            $row['22']\n"; }
        if($row['23'] ne '') { $serviceout .= "\tevent_handler                                  $row['23']\n"; }
        if($row['24'] ne '') { $serviceout .= "\tevent_handler_enabled                          $row['24']\n"; }
        if($row['25'] ne '') { $serviceout .= "\tlow_flap_threshold                             $row['25']\n"; }
        if($row['26'] ne '') { $serviceout .= "\thigh_flap_threshold                            $row['26']\n"; }
        if($row['27'] ne '') { $serviceout .= "\tflap_detection_enabled                         $row['27']\n"; }
        if($row['28'] ne '') { $serviceout .= "\tflap_detection_options                         $row['28']\n"; }
        if($row['29'] ne '') { $serviceout .= "\tprocess_perf_data                              $row['29']\n"; }
        if($row['30'] ne '') { $serviceout .= "\tretain_status_information                      $row['30']\n"; }
        if($row['31'] ne '') { $serviceout .= "\tretain_nonstatus_information                   $row['31']\n"; }
        if($row['32'] ne '') { $serviceout .= "\tnotification_interval                          $row['32']\n"; }
        if($row['33'] ne '') { $serviceout .= "\tfirst_notification_delay                       $row['33']\n"; }
        if($row['34'] ne '' and $row['34'] ne '24x7') { $serviceout .= "\tnotification_period                            $row['34']\n"; }
        if($row['35'] ne '') { $serviceout .= "\tnotification_options                           $row['35']\n"; }
        if($row['36'] ne '') { $serviceout .= "\tnotifications_enabled                          $row['36']\n"; }
        if($row['37'] ne '') { $serviceout .= "\tfailure_prediction_enabled                     $row['37']\n"; }
        if($row['38'] ne '') { $serviceout .= "\tcontacts                                       $row['38']\n"; }
        if($row['39'] ne '') { $serviceout .= "\tcontact_groups                                 $row['39']\n"; }
        if($row['40'] ne '') { $serviceout .= "\tstalking_options                               $row['40']\n"; }
        if($row['41'] ne '') { $serviceout .= "\tnotes                                          $row['41']\n"; }
        if($row['42'] ne '') { $serviceout .= "\tnotes_url                                      $row['42']\n"; }
        if($row['43'] ne '') { $serviceout .= "\taction_url                                     $row['43']\n"; }
        if($row['44'] ne '') { $serviceout .= "\ticon_image                                     $row['44']\n"; }
        if($row['45'] ne '') { $serviceout .= "\ticon_image_alt                                 $row['45']\n"; }
        if($row['46'] ne '') { $serviceout .= "\tregister                                       $row['46']\n"; }
        if($row['47'] ne '') { $serviceout .= "\tparallelize_check                              $row['47']\n"; }
        $serviceout .= "}\n\n";
    }
        $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetServiceDep {
    $limitservice = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,dependent_host_name,dependent_hostgroup_name,servicegroup_name,dependent_servicegroup_name,dependent_service_description,hostgroup_name,service_description,inherits_parent,execution_failure_criteria,notification_failure_criteria,dependency_period,notes,notes_url,action_url,register FROM servicedependency WHERE host_name = '$limitservice' AND (category = 'Service Dependency' OR category = 'service dependency') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## service dependency\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define servicedependency {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tdependent_host_name                            $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tdependent_hostgroup_name                       $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tservicegroup_name                              $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdependent_servicegroup_name                    $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tdependent_service_description                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\thostgroup_name                                 $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tservice_description                            $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinherits_parent                                $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\texecution_failure_criteria                     $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotification_failure_criteria                  $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tdependency_period                              $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tnotes                                          $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tnotes_url                                      $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\taction_url                                     $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tregister                                       $row['17']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetServiceEsc {
    $limithost = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,hostgroup_name,service_description,contacts,contact_groups,first_notification,last_notification,notification_interval,escalation_period,escalation_options,notes,notes_url,action_url,register FROM serviceescalation WHERE host_name = '$limithost' AND (category = 'Service Definition' OR category = 'service definition')AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## service escalation\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define hostescalation {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\thostgroup_name                                 $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tservice_description                            $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tcontacts                                       $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tcontact_groups                                 $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tfirst_notification                             $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tlast_notification                              $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tnotification_interval                          $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tescalation_period                              $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tescalation_options                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotes                                          $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnotes_url                                      $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\taction_url                                     $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tregister                                       $row['15']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetServiceExt {
    $limithost = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,service_description,`use`,`name`,notes,notes_url,action_url,icon_image,icon_image_alt,register FROM serviceextinfo WHERE host_name = '$limithost' AND (category = 'Service Extinfo' OR category = 'service extinfo') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## service extinfo\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define serviceextinfo {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tservice_description                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tuse                                            $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tname                                           $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tnotes                                          $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tnotes_url                                      $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\taction_url                                     $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\ticon_image                                     $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\ticon_image_alt                                 $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tregister                                       $row['9']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetCustService {
    $limitservice = @_[0];
    if($limitservice eq '') { return; }
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`hostgroup_name`,`use`,`name`,`alias`,service_description,display_name,servicegroups,is_volatile,check_command,initial_state,max_check_attempts,check_interval,normal_check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,enable_predictive_service_dependency_checks,check_period,obsess_over_service,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,failure_prediction_enabled,contacts,contact_groups,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,register,parallelize_check FROM service WHERE host_name = '$limitservice' AND (category = 'Custom Service Definition' OR category = 'custom service definition' OR category = 'Custom Service' OR category = 'custom service') AND id >= '1' order by service_description";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
    $serviceout .= "################## \n";
    $serviceout .= "## custom service definitions\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define service {\n";
        if($row['5'] ne '') { $serviceout .= "\tservice_description                            $row['5']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tname                                           $row['3']\n"; }
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\thostgroup_name                                 $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tuse                                            $row['2']\n"; }
        if($row['4'] ne '') { $serviceout .= "\talias                                          $row['4']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdisplay_name                                   $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tservicegroups                                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tis_volatile                                    $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tcheck_command                                  $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinitial_state                                  $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tmax_check_attempts                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tcheck_interval                                 $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnormal_check_interval                          $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tretry_interval                                 $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tretry_check_interval                           $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\tactive_checks_enabled                          $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tpassive_checks_enabled                         $row['17']\n"; }
        if($row['18'] ne '') { $serviceout .= "\tenable_predictive_service_dependency_checks    $row['18']\n"; }
        if($row['19'] ne '') { $serviceout .= "\tcheck_period                                   $row['19']\n"; }
        if($row['20'] ne '') { $serviceout .= "\tobsess_over_service                            $row['20']\n"; }
        if($row['21'] ne '') { $serviceout .= "\tcheck_freshness                                $row['21']\n"; }
        if($row['22'] ne '') { $serviceout .= "\tfreshness_threshold                            $row['22']\n"; }
        if($row['23'] ne '') { $serviceout .= "\tevent_handler                                  $row['23']\n"; }
        if($row['24'] ne '') { $serviceout .= "\tevent_handler_enabled                          $row['24']\n"; }
        if($row['25'] ne '') { $serviceout .= "\tlow_flap_threshold                             $row['25']\n"; }
        if($row['26'] ne '') { $serviceout .= "\thigh_flap_threshold                            $row['26']\n"; }
        if($row['27'] ne '') { $serviceout .= "\tflap_detection_enabled                         $row['27']\n"; }
        if($row['28'] ne '') { $serviceout .= "\tflap_detection_options                         $row['28']\n"; }
        if($row['29'] ne '') { $serviceout .= "\tprocess_perf_data                              $row['29']\n"; }
        if($row['30'] ne '') { $serviceout .= "\tretain_status_information                      $row['30']\n"; }
        if($row['31'] ne '') { $serviceout .= "\tretain_nonstatus_information                   $row['31']\n"; }
        if($row['32'] ne '') { $serviceout .= "\tnotification_interval                          $row['32']\n"; }
        if($row['33'] ne '') { $serviceout .= "\tfirst_notification_delay                       $row['33']\n"; }
        if($row['34'] ne '' and $row['34'] ne '24x7') { $serviceout .= "\tnotification_period                            $row['34']\n"; }
        if($row['35'] ne '') { $serviceout .= "\tnotification_options                           $row['35']\n"; }
        if($row['36'] ne '') { $serviceout .= "\tnotifications_enabled                          $row['36']\n"; }
        if($row['37'] ne '') { $serviceout .= "\tfailure_prediction_enabled                     $row['37']\n"; }
        if($row['38'] ne '') { $serviceout .= "\tcontacts                                       $row['38']\n"; }
        if($row['39'] ne '') { $serviceout .= "\tcontact_groups                                 $row['39']\n"; }
        if($row['40'] ne '') { $serviceout .= "\tstalking_options                               $row['40']\n"; }
        if($row['41'] ne '') { $serviceout .= "\tnotes                                          $row['41']\n"; }
        if($row['42'] ne '') { $serviceout .= "\tnotes_url                                      $row['42']\n"; }
        if($row['43'] ne '') { $serviceout .= "\taction_url                                     $row['43']\n"; }
        if($row['44'] ne '') { $serviceout .= "\ticon_image                                     $row['44']\n"; }
        if($row['45'] ne '') { $serviceout .= "\ticon_image_alt                                 $row['45']\n"; }
        if($row['46'] ne '') { $serviceout .= "\tregister                                       $row['46']\n"; }
        if($row['47'] ne '') { $serviceout .= "\tparallelize_check                              $row['47']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetCustServiceDep {
    $limitservice = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,dependent_host_name,dependent_hostgroup_name,servicegroup_name,dependent_servicegroup_name,dependent_service_description,hostgroup_name,service_description,inherits_parent,execution_failure_criteria,notification_failure_criteria,dependency_period,notes,notes_url,action_url,register FROM servicedependency WHERE host_name = '$limitservice' AND (category = 'Custom Service Dependency' OR category = 'custom service dependency') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## custom service dependency\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define servicedependency {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tdependent_host_name                            $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tdependent_hostgroup_name                       $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tservicegroup_name                              $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdependent_servicegroup_name                    $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tdependent_service_description                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\thostgroup_name                                 $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tservice_description                            $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinherits_parent                                $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\texecution_failure_criteria                     $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotification_failure_criteria                  $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tdependency_period                              $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tnotes                                          $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tnotes_url                                      $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\taction_url                                     $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tregister                                       $row['17']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetCustServiceEsc {
    $limithost = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,hostgroup_name,service_description,contacts,contact_groups,first_notification,last_notification,notification_interval,escalation_period,escalation_options,notes,notes_url,action_url,register FROM serviceescalation WHERE host_name = '$limithost' AND (category = 'Custom Service' OR category = 'custom service' OR category = 'Custom Service Defininition' OR category = 'custom service definition') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## custom service escalation\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define serviceescalation {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\thostgroup_name                                 $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tservice_description                            $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tcontacts                                       $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tcontact_groups                                 $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tfirst_notification                             $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tlast_notification                              $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tnotification_interval                          $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tescalation_period                              $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tescalation_options                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotes                                          $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnotes_url                                      $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\taction_url                                     $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tregister                                       $row['15']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetCustServiceExt {
    $limithost = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,service_description,`use`,`name`,notes,notes_url,action_url,icon_image,icon_image_alt,register FROM serviceextinfo WHERE host_name = '$limithost' AND (category = 'Custom Service Extinfo' OR category = 'custom service extinfo') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## custom service extinfo\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define serviceextinfo {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tservice_description                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tuse                                            $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tname                                           $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tnotes                                          $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tnotes_url                                      $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\taction_url                                     $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\ticon_image                                     $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\ticon_image_alt                                 $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tregister                                       $row['9']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetServiceGrp {
    $limithost = @_[0];
    my $serviceout = "";
    # Set the title, so people will be warned.
    my $hostout .= '##########\n# YOU WILL BE FLOGGED IF YOU ENTER MEMBERS HERE, add the group to the service definition';

    # Sort the services first.
    if($limithost ne ''){
        $sqlq = "SELECT `servicegroup_name`,`alias`,`members`,`use`,`name`,`hostgroup_members`,`servicegroup_members`,`contactgroup_members`,`notes`,`notes_url`,`action_url`,`register` FROM servicegroup WHERE servicegroup_name = '$limithost' AND id >= '1' order by servicegroup_name";
    } else {
        $sqlq = "SELECT `servicegroup_name`,`alias`,`members`,`use`,`name`,`hostgroup_members`,`servicegroup_members`,`contactgroup_members`,`notes`,`notes_url`,`action_url`,`register` FROM servicegroup WHERE id >= '1' order by servicegroup_name";
    }
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define hostgroup {\n";
        if($row['0'] ne '') { $serviceout .= "\tservicegroup_name                              $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\talias                                          $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tmembers                                        $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\talias                                          $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tmembers                                        $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tuse                                            $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tname                                           $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\thostgroup_members                              $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tservicegroup_members                           $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tcontactgroup_members                           $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tnotes                                         $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tnotes_url                                     $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\taction_url                                    $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tregister                                      $row['13']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}


sub mysqlGetHardwareService {
    $limitservice = @_[0];
    if($limitservice eq '') { return; }
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`hostgroup_name`,`use`,`name`,`alias`,service_description,display_name,servicegroups,is_volatile,check_command,initial_state,max_check_attempts,check_interval,normal_check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,enable_predictive_service_dependency_checks,check_period,obsess_over_service,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,failure_prediction_enabled,contacts,contact_groups,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,register,parallelize_check FROM service WHERE host_name = '$limitservice' AND (category = 'Hardware' OR category = 'hardware' OR category = 'Hardware Service Definition' OR category = 'hardware service definition') AND id >= '1' order by service_description";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
    $serviceout .= "################## \n";
    $serviceout .= "## Hardware service definitions\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define service {\n";
        if($row['5'] ne '') { $serviceout .= "\tservice_description                            $row['5']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tname                                           $row['3']\n"; }
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\thostgroup_name                                 $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tuse                                            $row['2']\n"; }
        if($row['4'] ne '') { $serviceout .= "\talias                                          $row['4']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdisplay_name                                   $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tservicegroups                                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tis_volatile                                    $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tcheck_command                                  $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinitial_state                                  $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tmax_check_attempts                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tcheck_interval                                 $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnormal_check_interval                          $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tretry_interval                                 $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tretry_check_interval                           $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\tactive_checks_enabled                          $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tpassive_checks_enabled                         $row['17']\n"; }
        if($row['18'] ne '') { $serviceout .= "\tenable_predictive_service_dependency_checks    $row['18']\n"; }
        if($row['19'] ne '') { $serviceout .= "\tcheck_period                                   $row['19']\n"; }
        if($row['20'] ne '') { $serviceout .= "\tobsess_over_service                            $row['20']\n"; }
        if($row['21'] ne '') { $serviceout .= "\tcheck_freshness                                $row['21']\n"; }
        if($row['22'] ne '') { $serviceout .= "\tfreshness_threshold                            $row['22']\n"; }
        if($row['23'] ne '') { $serviceout .= "\tevent_handler                                  $row['23']\n"; }
        if($row['24'] ne '') { $serviceout .= "\tevent_handler_enabled                          $row['24']\n"; }
        if($row['25'] ne '') { $serviceout .= "\tlow_flap_threshold                             $row['25']\n"; }
        if($row['26'] ne '') { $serviceout .= "\thigh_flap_threshold                            $row['26']\n"; }
        if($row['27'] ne '') { $serviceout .= "\tflap_detection_enabled                         $row['27']\n"; }
        if($row['28'] ne '') { $serviceout .= "\tflap_detection_options                         $row['28']\n"; }
        if($row['29'] ne '') { $serviceout .= "\tprocess_perf_data                              $row['29']\n"; }
        if($row['30'] ne '') { $serviceout .= "\tretain_status_information                      $row['30']\n"; }
        if($row['31'] ne '') { $serviceout .= "\tretain_nonstatus_information                   $row['31']\n"; }
        if($row['32'] ne '') { $serviceout .= "\tnotification_interval                          $row['32']\n"; }
        if($row['33'] ne '') { $serviceout .= "\tfirst_notification_delay                       $row['33']\n"; }
        if($row['34'] ne '' and $row['34'] ne '24x7') { $serviceout .= "\tnotification_period                            $row['34']\n"; }
        if($row['35'] ne '') { $serviceout .= "\tnotification_options                           $row['35']\n"; }
        if($row['36'] ne '') { $serviceout .= "\tnotifications_enabled                          $row['36']\n"; }
        if($row['37'] ne '') { $serviceout .= "\tfailure_prediction_enabled                     $row['37']\n"; }
        if($row['38'] ne '') { $serviceout .= "\tcontacts                                       $row['38']\n"; }
        if($row['39'] ne '') { $serviceout .= "\tcontact_groups                                 $row['39']\n"; }
        if($row['40'] ne '') { $serviceout .= "\tstalking_options                               $row['40']\n"; }
        if($row['41'] ne '') { $serviceout .= "\tnotes                                          $row['41']\n"; }
        if($row['42'] ne '') { $serviceout .= "\tnotes_url                                      $row['42']\n"; }
        if($row['43'] ne '') { $serviceout .= "\taction_url                                     $row['43']\n"; }
        if($row['44'] ne '') { $serviceout .= "\ticon_image                                     $row['44']\n"; }
        if($row['45'] ne '') { $serviceout .= "\ticon_image_alt                                 $row['45']\n"; }
        if($row['46'] ne '') { $serviceout .= "\tregister                                       $row['46']\n"; }
        if($row['47'] ne '') { $serviceout .= "\tparallelize_check                              $row['47']\n"; }
        $serviceout .= "}\n\n";
    }
        $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetHardwareDep {
    $limitservice = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,dependent_host_name,dependent_hostgroup_name,servicegroup_name,dependent_servicegroup_name,dependent_service_description,hostgroup_name,service_description,inherits_parent,execution_failure_criteria,notification_failure_criteria,dependency_period,notes,notes_url,action_url,register FROM servicedependency WHERE host_name = '$limitservice' AND (category = 'Hardware Service Dependency' OR category = 'hardware service dependency') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## hardware service dependency\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define servicedependency {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tdependent_host_name                            $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tdependent_hostgroup_name                       $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tservicegroup_name                              $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdependent_servicegroup_name                    $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tdependent_service_description                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\thostgroup_name                                 $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tservice_description                            $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinherits_parent                                $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\texecution_failure_criteria                     $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotification_failure_criteria                  $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tdependency_period                              $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tnotes                                          $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tnotes_url                                      $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\taction_url                                     $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tregister                                       $row['17']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetHardwareServiceEsc {
    $limithost = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,hostgroup_name,service_description,contacts,contact_groups,first_notification,last_notification,notification_interval,escalation_period,escalation_options,notes,notes_url,action_url,register FROM serviceescalation WHERE host_name = '$limithost' AND (category = 'Hardware Service' OR category = 'dardware service' OR category = 'Hardware Service Defininition' OR category = 'hardware service definition') AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## Hardware service escalation\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define serviceescalation {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\thostgroup_name                                 $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tservice_description                            $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tcontacts                                       $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tcontact_groups                                 $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tfirst_notification                             $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tlast_notification                              $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tnotification_interval                          $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tescalation_period                              $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tescalation_options                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotes                                          $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnotes_url                                      $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\taction_url                                     $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tregister                                       $row['15']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}


sub mysqlGetOtherService {
    $limitservice = @_[0];
    if($limitservice eq '') { return; }
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`hostgroup_name`,`use`,`name`,`alias`,service_description,display_name,servicegroups,is_volatile,check_command,initial_state,max_check_attempts,check_interval,normal_check_interval,retry_interval,retry_check_interval,active_checks_enabled,passive_checks_enabled,enable_predictive_service_dependency_checks,check_period,obsess_over_service,check_freshness,freshness_threshold,event_handler,event_handler_enabled,low_flap_threshold,high_flap_threshold,flap_detection_enabled,flap_detection_options,process_perf_data,retain_status_information,retain_nonstatus_information,notification_interval,first_notification_delay,notification_period,notification_options,notifications_enabled,failure_prediction_enabled,contacts,contact_groups,stalking_options,notes,notes_url,action_url,icon_image,icon_image_alt,register,parallelize_check FROM service WHERE host_name = '$limitservice' AND category IS NULL AND id >= '1' order by service_description";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
    $serviceout .= "################## \n";
    $serviceout .= "## Other / Uncategorized service definitions\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define service {\n";
        if($row['5'] ne '') { $serviceout .= "\tservice_description                            $row['5']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tname                                           $row['3']\n"; }
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\thostgroup_name                                 $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tuse                                            $row['2']\n"; }
        if($row['4'] ne '') { $serviceout .= "\talias                                          $row['4']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdisplay_name                                   $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tservicegroups                                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\tis_volatile                                    $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tcheck_command                                  $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinitial_state                                  $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\tmax_check_attempts                             $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tcheck_interval                                 $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tnormal_check_interval                          $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tretry_interval                                 $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tretry_check_interval                           $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\tactive_checks_enabled                          $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tpassive_checks_enabled                         $row['17']\n"; }
        if($row['18'] ne '') { $serviceout .= "\tenable_predictive_service_dependency_checks    $row['18']\n"; }
        if($row['19'] ne '') { $serviceout .= "\tcheck_period                                   $row['19']\n"; }
        if($row['20'] ne '') { $serviceout .= "\tobsess_over_service                            $row['20']\n"; }
        if($row['21'] ne '') { $serviceout .= "\tcheck_freshness                                $row['21']\n"; }
        if($row['22'] ne '') { $serviceout .= "\tfreshness_threshold                            $row['22']\n"; }
        if($row['23'] ne '') { $serviceout .= "\tevent_handler                                  $row['23']\n"; }
        if($row['24'] ne '') { $serviceout .= "\tevent_handler_enabled                          $row['24']\n"; }
        if($row['25'] ne '') { $serviceout .= "\tlow_flap_threshold                             $row['25']\n"; }
        if($row['26'] ne '') { $serviceout .= "\thigh_flap_threshold                            $row['26']\n"; }
        if($row['27'] ne '') { $serviceout .= "\tflap_detection_enabled                         $row['27']\n"; }
        if($row['28'] ne '') { $serviceout .= "\tflap_detection_options                         $row['28']\n"; }
        if($row['29'] ne '') { $serviceout .= "\tprocess_perf_data                              $row['29']\n"; }
        if($row['30'] ne '') { $serviceout .= "\tretain_status_information                      $row['30']\n"; }
        if($row['31'] ne '') { $serviceout .= "\tretain_nonstatus_information                   $row['31']\n"; }
        if($row['32'] ne '') { $serviceout .= "\tnotification_interval                          $row['32']\n"; }
        if($row['33'] ne '') { $serviceout .= "\tfirst_notification_delay                       $row['33']\n"; }
        if($row['34'] ne '' and $row['34'] ne '24x7') { $serviceout .= "\tnotification_period                            $row['34']\n"; }
        if($row['35'] ne '') { $serviceout .= "\tnotification_options                           $row['35']\n"; }
        if($row['36'] ne '') { $serviceout .= "\tnotifications_enabled                          $row['36']\n"; }
        if($row['37'] ne '') { $serviceout .= "\tfailure_prediction_enabled                     $row['37']\n"; }
        if($row['38'] ne '') { $serviceout .= "\tcontacts                                       $row['38']\n"; }
        if($row['39'] ne '') { $serviceout .= "\tcontact_groups                                 $row['39']\n"; }
        if($row['40'] ne '') { $serviceout .= "\tstalking_options                               $row['40']\n"; }
        if($row['41'] ne '') { $serviceout .= "\tnotes                                          $row['41']\n"; }
        if($row['42'] ne '') { $serviceout .= "\tnotes_url                                      $row['42']\n"; }
        if($row['43'] ne '') { $serviceout .= "\taction_url                                     $row['43']\n"; }
        if($row['44'] ne '') { $serviceout .= "\ticon_image                                     $row['44']\n"; }
        if($row['45'] ne '') { $serviceout .= "\ticon_image_alt                                 $row['45']\n"; }
        if($row['46'] ne '') { $serviceout .= "\tregister                                       $row['46']\n"; }
        if($row['47'] ne '') { $serviceout .= "\tparallelize_check                              $row['47']\n"; }
        $serviceout .= "}\n\n";
    }
        $serviceout .= "\n\n";
    return $serviceout;
}

sub mysqlGetOtherDep {
    $limitservice = @_[0];
    my $serviceout = "";
    # Sort the services first.
    my $sqlq = "SELECT `host_name`,`use`,`name`,dependent_host_name,dependent_hostgroup_name,servicegroup_name,dependent_servicegroup_name,dependent_service_description,hostgroup_name,service_description,inherits_parent,execution_failure_criteria,notification_failure_criteria,dependency_period,notes,notes_url,action_url,register FROM servicedependency WHERE host_name = '$limitservice' AND category IS NULL AND id >= '1' order by name";
    if(defined($debug)) { $serviceout .= "# $sqlq\n"; }
    my $stq = $dbh->prepare($sqlq);
    $stq->execute() or die $DBI::errstr;
        $serviceout .= "################## \n";
        $serviceout .= "## Other / Uncategorized service dependency\n\n";
    while(my @row = $stq->fetchrow_array()){
        $serviceout .= "define servicedependency {\n";
        if($row['0'] ne '') { $serviceout .= "\thost_name                                      $row['0']\n"; }
        if($row['1'] ne '') { $serviceout .= "\tuse                                            $row['1']\n"; }
        if($row['2'] ne '') { $serviceout .= "\tname                                           $row['2']\n"; }
        if($row['3'] ne '') { $serviceout .= "\tdependent_host_name                            $row['3']\n"; }
        if($row['4'] ne '') { $serviceout .= "\tdependent_hostgroup_name                       $row['4']\n"; }
        if($row['5'] ne '') { $serviceout .= "\tservicegroup_name                              $row['5']\n"; }
        if($row['6'] ne '') { $serviceout .= "\tdependent_servicegroup_name                    $row['6']\n"; }
        if($row['7'] ne '') { $serviceout .= "\tdependent_service_description                  $row['7']\n"; }
        if($row['8'] ne '') { $serviceout .= "\thostgroup_name                                 $row['8']\n"; }
        if($row['9'] ne '') { $serviceout .= "\tservice_description                            $row['9']\n"; }
        if($row['10'] ne '') { $serviceout .= "\tinherits_parent                                $row['10']\n"; }
        if($row['11'] ne '') { $serviceout .= "\texecution_failure_criteria                     $row['11']\n"; }
        if($row['12'] ne '') { $serviceout .= "\tnotification_failure_criteria                  $row['12']\n"; }
        if($row['13'] ne '') { $serviceout .= "\tdependency_period                              $row['13']\n"; }
        if($row['14'] ne '') { $serviceout .= "\tnotes                                          $row['14']\n"; }
        if($row['15'] ne '') { $serviceout .= "\tnotes_url                                      $row['15']\n"; }
        if($row['16'] ne '') { $serviceout .= "\taction_url                                     $row['16']\n"; }
        if($row['17'] ne '') { $serviceout .= "\tregister                                       $row['17']\n"; }
        $serviceout .= "}\n\n";
    }
    $serviceout .= "\n\n";
    return $serviceout;
}

sub HelpMessage {

  print "NAME\n";
  print "\n";
  print "Nagios config manipulator\n";
  print "\n";
  print "SYNOPSIS\n";
  print "\n";
  print "  --file,-f     Specify the file you would like to run this program against. \n";
  print "                                 \n";
  print "  --method,-m Specify the method of action being taken\n";
  print "                   import  insert into the database, updating any existing records\n";
  print "                   fixup   Fix some issues that are typical with admins, removing duplicates and fixing up records\n";
  print "                           --type,-t Specify the type to fix\n";
  print "                                   contact    change only the contacts and contactgroups\n";
  print "                                   host       change only the hosts and hostgroups\n";
  print "                                   service    change only the services and servicegroups\n";
  print "                   output  output the database, use not required\n";
  print "                           --type,-t Specify the type to output\n";
  print "                                   full       All record types (default)\n";
  print "                                   host       output all things host definition\n";
  print "                                   hostonly   output only the host definition\n";
  print "                                   hostdep    output only the hostdependency\n";
  print "                                   hostesc    output only the hostescalation\n";
  print "                                   hostgrp    output only the hostgroup\n";
  print "                                   service    output only the services definition\n";
  print "                           --host,-h Specify the host to output\n";
  print "                                   all        all hosts (default)\n";
  print "                                   {host_name} exact name of the host to output\n";
  print "                                 \n";
  print "                           --stout,-s  Specify the type of output\n";
  print "                                   print      just print what we think is happening here (default)\n";
  print "                                   file       export to a file or files, depending on what output that you have choosen\n";
  print "  --help,-?    Print this help\n";
  print "\n\n";
  print " EXAMPLE";
  print " Single config file";
  print " nagios.pl --file /etc/nagios/host.cfg --method import\n";
  print " \n";
  print " All .cfg files in a directory\n";
  print " find /etc/nagios/conf.d -type f -name \"\*.cfg\" -exec /usr/bin/perl /usr/local/bin/nagios.pl --file {} --method import \\; >> output5.log\n";
  print " \n";
  print " Output the details for a host to the single file that is usable with nagios\n";
  print " ./nagios.pl --method output --type full --stout file --host www.isomedia.com\n";
  print " or ALL hosts into new files in /etc/nagios/conf.d folder\n";
  print " nagios.pl --method output --type full --host all --stout file\n";
  print "\n";
  print "VERSION\n";
  print "\n";
  print "1.20 - 4/23/2024\n";
  print "\n";
  exit;
}


close($fh) or warn "Could not close '$log_file': $!";