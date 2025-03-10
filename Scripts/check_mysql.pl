#!/usr/bin/perl -w
use Time::localtime;
use File::stat;

my $cur_time = time();

#my $max_time = 129600; # 1 1/2 days... since we backup daily.. should be older thatn 1 1/2 days

my $max_time = 129600 * 10; # kicked up *10 because backups are fubar on this box

#my $max_time = 40; # 1 1/2 days... since we backup daily.. should be older thatn 1 1/2 days
my $MYSQLPATH = "/var/lib/mysql";
my $backupscript = "/etc/cron.daily/backup-mysql.pl";
my $backupdir = "/var/spool/mysql-backups";
#my $backupdir = "/home/joe/mysql-backups";
my $user = "nagios";
my $mysqladmin = "/usr/bin/mysqladmin";
## First Test... is mysql running... if not Critical - not sure what a warning is yet.
my $output;
my $DEBUG = 0;

# Any arguments on the command line enables debugging
if(defined($ARGV[0])) {
  if($ARGV[0] ne "") {
    $DEBUG = 1;
  }
}

my $mysqlsize = 0;

my $check_run = `$mysqladmin -u $user status 2>&1`;
chomp($check_run);
if ($check_run =~ /uptime:/i) {
    $output = $check_run;
} else {
    print "CRITICAL: MySQL is not Running!\n";
    exit(2);
}

## Now since we passed the first test of mysql running.. let's check backups

# Check backup script
if (!-f $backupscript) {
    print "WARNING: $backupscript does not exist... please get backups working!\n";
    exit(1);
}

# Check backup dir
if (!-d $backupdir) {
    print "WARNING: $backupdir does not exist... please get backups working!\n";
    exit(1);
}


## Now check to make sure we have recent backups for each DB
opendir(LIBDIR, $MYSQLPATH) || die "Failed to open MySQL directory: $!";
@dirs = grep { !/^\./ && -d "$MYSQLPATH/$_" } readdir(LIBDIR);
closedir(LIBDIR);

my $merealtime;
foreach $dir (@dirs) {
    next if $dir eq "rt3_test";
    next if $dir eq "rt3";
    my @files = `ls -t $backupdir | egrep \"$dir\\.\"`;
    my $size = @files;
    ## Check to see if DB has backup files... else CRITICAL!
    if ($size > 0) {
        my $bfile = $files[0];
        chomp($bfile);
        my $file = $backupdir . "/" . $files[0];
        chomp($file);
        $filetime = stat($file)->mtime;
        $filesize = stat($file)->size;
        if($bfile =~ /^mysql\.[0-9]((\.gz)?)/) {
          # MySQL min size == 100, since if they're compressed at zero bytes they'll actually grow in size.
          if($filesize < 100) {
            print "CRITICAL: cron backup-mysql script is generating zero byte backups! ($dir = $bfile, $filesize bytes)\n";
            exit(2);
          } else {
            $DEBUG && print STDERR "+++ $dir $bfile size OK: $filesize\n";
            $mysqlsize = $filesize;
          }
        } else {
          $DEBUG && print STDERR "--- $dir $bfile size: $filesize\n";
        }
        my $timediff = $cur_time-$filetime;
        #print "$file ($timediff)\n";
        $merealtime = ctime($filetime);
        ## Check to see if backup is OLD.. if so, CRITICAL!
        if ($timediff > $max_time) {
            $htime = sprintf('%.2f',$timediff/60/60);
            print "WARNING: aaarg!! ME $dir DB is $htime hours old (check ME cron Matey!)\n";
            exit(1);
        }

    }
    ## No backup file was found for the dir.. CRITICAL
    else {
        print "WARNING: Ahoy Matey! ME $dir DB doesn't have backups! aaarg! (ps. check cron for backup-mysql.pl) \n";
        exit(1);
    }

}

## Well I guess we passed every check...
print "OK: BACKUPS found ($merealtime). $output (mysqlsize $mysqlsize)\n";
exit(0);