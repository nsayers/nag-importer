#!/usr/bin/perl -sW
#
# This is a nagios check to SSH into a Dell DRAC5 management card
# to check the status of the hardware



# CHANGE LOG
# ----------
#  2011/08/28	njeffrey	Script created



# NOTES
# -----
#
# This script has only been tested against a Dell DRAC5 card with BIOS version 1.3
# in a Dell PowerEdge 1950 server.
#
# Other DRAC cards may have slightly different output, which would require minor tweaks to this script.
#
# This script attempts to "fail gracefully" by using "Unknown" for values it cannot figure out.



#
#
# PREREQUISITES
# -------------
#   1) It is assumed that this script is run on the nagios server as the "nagios" userid
#
#   2) The following perl modules must be installed on the nagios server.  
#         perl -MCPAN -e 'install Net::SSH::Perl'
#         perl -MCPAN -e 'install Math::BigInt::Pari'	#co-requisite for Net::SSH::Perl when using ssh protocol 2
#
#
#   3) You will need to create a read-only account on the DRAC.  It is assumed 
#      that you will not have SSH keys available, so this script has a hardcoded
#      username and password.
#
#
#   4) You will need to manually ssh from the nagios server to each monitored DRAC to update
#      the known_hosts file on the nagios server.  Example shown below:
#         $ ssh administrator@dellserv1-drac
#         DSA key fingerprint d6:74:15:62:f3:09:31:09:65:a2:23:56:4b:e0:6b:16.
#         The authenticity of host 'dellserv1-drac (10.0.0.42)' can't be established
#         Are you sure you want to continue connecting (yes/no)? yes
#         Warning: Permanently added '10.0.0.42' (RSA) to the list of known hosts.
#
#
#
#   5) You will need a section similar to the following in the commands.cfg file on the nagios server.
#      # ---------------------------------------------------------------------------
#      # 'check_dell_drac5' command definition
#      define command {
#             command_name    check_dell_drac5
#             command_line    $USER1$/check_dell_drac5 $HOSTADDRESS$ $ARG1$ $ARG2$
#             }
#
#
#
#   6) You will need a section similar to the following in the services.cfg file on the nagios server.
#      # command format is "check_dell_drac5" if you want to use the username/password hardcoded in the script
#      # to provide your own username/password, use "check_dell_drac5!username!password"
#      define service {
#              use                             generic-24x7-service
#              host_name                       dellserver2-drac.example.com
#              service_description             DRAC
#              check_command                   check_dell_drac5
#              }
#
#
#
#   7) We don't want to use the built-in administrator account on the DRAC, just because
#      this script has a hard-coded username/password.  You will need to create a low-privilege
#      account on the DRAC.  Here's how you can do that from the command line:
#           ssh administrator@drac
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminUserName monitor
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminPassword monitor123
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminPrivilege 0x00000001
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminEnable 1
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminIpmiLanPrivilege 2
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminIpmiSerialPrivilege 15
#           racadm config -g cfgUserAdmin -i 3 -o cfgUserAdminSolEnable 0
#           exit




#
#
# TROUBLESHOOTING
# ---------------
# 1) Confirm you can ssh from the nagios server to each DRAC with the password in this script
# 2) Confirm there are no firewalls preventing ssh logins from the nagios server to the DRAC
# 3) If you get an error message like the following:
#       Return code of 13 is out of bounds
#    It means that the nagios process mis-reads the $HOME environment variable as /root instead of /home/nagios
#    You can fix this by manually setting $ENV{'HOME'} = '/home/nagios';  
#
# 
#
# Usage:       /usr/local/nagios/libexec/check_dell_drac hostname 
#
# Dependencies: Net::SSH::Perl     perl module
#               Math::BigInt::Pari perl module




#
#
use strict;							#enforce good coding practices
use Net::SSH::Perl;						#use external perl module

my ($host,$ssh,$ssh_userid,%params);
my ($verbose,%drac);
my ($nslookup,$nslookup_status,$cmd);
my ($OK,$WARN,$CRITICAL,$UNKNOWN,$CHECK_NAME);
my ($out,$err,$exit);

#declare variables
$host                    = "";					#initialize variable
$ssh                     = "";					#initialize variable
$params{user}            = "monitor";				#userid to login to DRAC 
$params{password}        = "monitor123";			#password to login to DRAC 
$params{port}            = 22;					#port that ssh daemon on router listens on
$params{protocol}        = 2;					#SSH protocol versions to use when connecting
$params{timeout}         = 5;					#seconds to timeout a connection
$nslookup                = "/usr/bin/nslookup";			#location of binary on nagios server
$nslookup_status         = "";					#flag for checking to see if nslookup test succeeds
$verbose                 = "no";				#for debugging (yes=show more print output) 
$out                     = "";					#placeholder for STDOUT
$err                     = "";					#placeholder for STDERR
$exit                    = "";					#placeholder for exit status of ssh commands
$ENV{'HOME'}             = '/home/nagios';			#set shell env variable to nagios user home dir
$CHECK_NAME              = "DRAC checks"; 			#name of nagios check
$drac{name}              = "Unknown";				#initialize variable
$drac{dedicated}         = "Unknown";                           #initialize variable
$drac{resetcapability}   = "Unknown";                           #initialize variable
$drac{enabledstate}      = "Unknown";                           #initialize variable
$drac{requestedstate}    = "Unknown";                           #initialize variable
$drac{enableddefault}    = "Unknown";                           #initialize variable
$drac{healthstate}       = "Unknown";                           #initialize variable
$drac{operationalstatus} = "Unknown";                           #initialize variable
$drac{description}       = "Unknown";                           #initialize variable
$drac{elementname}       = "Unknown";                           #initialize variable

#
# Nagios return codes
#
$OK=            0;                            		  	#this script returns a value to nagios for processing
$WARN=          1;                          		    	#this script returns a value to nagios for processing
$CRITICAL=      2;                              		#this script returns a value to nagios for processing
$UNKNOWN=       3;                              		#this script returns a value to nagios for processing


sub sanity_checks {
   print "running sanity_checks subroutine \n" if ($verbose eq "yes");
   # 
   # confirm user specified a command line parameter for the hostname
   #  
   if( ! defined( $ARGV[0] ) ) {
      print "$CHECK_NAME CRITICAL  - no hostname supplied.  USAGE: $0 router_host_name \n";
      exit $CRITICAL;
   }						#end of if block
   if( defined( $ARGV[0] ) ) {
      $host = $ARGV[0];				#assign meaningful variable name
   }						#end of if block
   #
   # see if user provided (optional) userid (defaults to value hardcoded in script)
   #  
   if( defined( $ARGV[1] ) ) {
      $params{user} = $ARGV[1];			#assign meaningful variable name
      #
      # confirm userid contains only valid characters
      unless ( $params{port} =~ /^[a-zA-Z0-9]+$/ ) {
         print "$CHECK_NAME CRITICAL: user-provided username $params{user} may only contain characters a-zA-Z0-9. \n";
         exit $CRITICAL;
      }						#end of unless block
   }						#end of if block
   #
   # see if user provided (optional) password (defaults to value hardcoded in script)
   #  
   if( defined( $ARGV[2] ) ) {
      $params{password} = $ARGV[2];			#assign meaningful variable name
      #
   }						#end of if block
   #
   # confirm nslookup exists
   if ( ! -f "$nslookup" ) {
      print "$CHECK_NAME WARN: Cannot find $nslookup \n";
      exit $WARN;					#exit script
   }						#end of if block
   if ( ! -x "$nslookup" ) {
      print "$CHECK_NAME WARN: $nslookup is not executable by the current user\n";
      exit $WARN;				#exit script
   }						#end of if block
}						#end of subroutine





sub check_name_resolution {
   #
   # confirm valid name resolution exists for $host
   # HINT: If you are in a small environment without DNS, just 
   #       comment out the call to this subroutine at the bottom of this script
   #
   print "running check_name_resolution subroutine \n" if ($verbose eq "yes");
   if( ! open( NSLOOKUP, "$nslookup $host 2>&1|" ) ) {
      warn "WARNING: nslookup $host failed: $!\n";
      return 0;
   }
   while (<NSLOOKUP>) {                        					#read a line from STDIN
      if (/failed/) {								#look for error message from nslookup
         $nslookup_status = "failed";						#set flag value for $nslookup variable
      }										#end of if block
      if (/SERVFAIL/) {								#look for error message from nslookup
         $nslookup_status = "failed";						#set flag value for $nslookup variable
      }										#end of if block
      if (/NXDOMAIN/) {								#look for error message from nslookup
         $nslookup_status = "failed";						#set flag value for $nslookup variable
      }										#end of if block
   }										#end of while loop
   close NSLOOKUP;								#close filehandle
   if ( $nslookup_status eq "failed" ) {					#check for flag value
      print "$CHECK_NAME CRITICAL: no name resolution for $host - please add $host to DNS \n";
      exit $CRITICAL;
   }										#end of if block
}





sub ssh_to_drac {
   #
   # ssh into remote host 
   #
   print "running ssh_to_drac subroutine \n" if ($verbose eq "yes");
   print "opening ssh connection to $host \n" if ($verbose eq "yes");
   eval { 
      $ssh = Net::SSH::Perl->new($host,%params);
   };
   if ($@) {
      warn "$CHECK_NAME WARN - could not connect to $host with username $params{user}.  Please check credentials. $@\n";
   }
   eval { 
      $ssh->login( $params{userid}, $params{password} );
   };
   if ($@) {
      print "$CHECK_NAME CRITICAL - could not connect to $host with username $params{user}.  Please check credentials. $@\n";
      exit $CRITICAL;
   }
}							#end of subroutine






sub get_hardware_status {
   #
   print "running get_hardware_status subroutine \n" if ($verbose eq "yes");
   #
   # The output of the "smclp show system1" command should give output similar to:
   #
   #   $ smclp show system1
   #
   #   /system1:
   #
   #     Targets:
   #       logs1
   #   
   #     Properties:
   #       CreationClassName       = CIM_ComputerSystem
   #       Name                    = 39MH5F1
   #       NameFormat              = other
   #       Dedicated               = 0
   #       ResetCapability         = 4
   #       EnabledState            = 2 
   #       RequestedState          = 12
   #       EnabledDefault          = 2
   #       HealthState             = 5
   #       OperationalStatus       = 2
   #       Description             = PowerEdge 1950
   #       ElementName             = esx01.example.com
   #   
   #   
   #
   #
   print "running check_hardware subroutine \n" if ($verbose eq "yes");
   #
   $cmd = "smclp show system1";				#define command to be run
   print "running $cmd \n" if ($verbose eq "yes");
   ($out, $err, $exit) = $ssh->cmd($cmd);
   #
   # If there was nothing on STDOUT in the above command, put a dummy value
   # into the $out variable to ensure we don't get an error message when 
   # we try to use an undefined variable.
   $out = "blah blah blah" unless $out;
   #
   # At this point, the $out variable should have multiple lines of text.
   # Let's split each line out into an array element to make them 
   # easier to work with.
   #   
   my @lines = split /\n/, $out;				#split each line into array element
   #
   # loop through each element in the array to determine the hardware details
   foreach (@lines) {
      $drac{name}              = $1 if ( /^ +Name += +([a-zA-Z0-9]+)/ );
      $drac{dedicated}         = $1 if ( /^ +Dedicated += +([0-9]+)/ );
      $drac{resetcapability}   = $1 if ( /^ +ResetCapability += +([0-9]+)/ );
      $drac{enabledstate}      = $1 if ( /^ +EnabledState += +([0-9]+)/ );
      $drac{requestedstate}    = $1 if ( /^ +RequestedState += +([0-9]+)/ );
      $drac{enableddefault}    = $1 if ( /^ +EnabledDefault += +([0-9]+)/ );
      $drac{healthstate}       = $1 if ( /^ +HealthState += +([0-9]+)/ );
      $drac{operationalstatus} = $1 if ( /^ +OperationalStatus += +([0-9]+)/ );
      $drac{description}       = $1 if ( /^ +Description += +([a-zA-Z0-9 ]+)/ );
      $drac{elementname}       = $1 if ( /^ +ElementName += +([a-zA-Z0-9\. ]+)/ );
   }								#end of foreach loop
   #
   # change the numeric codes to human-readable values
   #
   # ResetCapability Defines the reset methods available on the system 
   # The desired value is 4=Enabled
   $drac{resetcapability} = "Other"           if $drac{resetcapability} eq "1";
   $drac{resetcapability} = "Unknown"         if $drac{resetcapability} eq "2";
   $drac{resetcapability} = "Disabled"        if $drac{resetcapability} eq "3";
   $drac{resetcapability} = "Enabled"         if $drac{resetcapability} eq "4";
   $drac{resetcapability} = "Not Implemented" if $drac{resetcapability} eq "5";
   print "ResetCapability=$drac{resetcapability} \n" if ($verbose eq "yes");
   #
   #
   # EnabledState Indicates the enabled/disabled states of the system.
   # The desired value is 2=Enabled
   $drac{enabledstate} = "Unknown"             if $drac{enabledstate} eq "0";
   $drac{enabledstate} = "Other"               if $drac{enabledstate} eq "1";
   $drac{enabledstate} = "Enabled"             if $drac{enabledstate} eq "2";
   $drac{enabledstate} = "Disabled"            if $drac{enabledstate} eq "3";
   $drac{enabledstate} = "Shutting Down"       if $drac{enabledstate} eq "4";
   $drac{enabledstate} = "Not Applicable"      if $drac{enabledstate} eq "5";
   $drac{enabledstate} = "Enabled but Offline" if $drac{enabledstate} eq "6";
   $drac{enabledstate} = "In Test"             if $drac{enabledstate} eq "7";
   $drac{enabledstate} = "Deferred"            if $drac{enabledstate} eq "8";
   $drac{enabledstate} = "Quiesce"             if $drac{enabledstate} eq "9";
   $drac{enabledstate} = "Starting"            if $drac{enabledstate} eq "10";
   print "EnabledState=$drac{enabledstate} \n" if ($verbose eq "yes");
   #
   #
   # EnabledDefault Indicates the default startup configuration for the enabled state of the system. 
   # By default, the system is "Enabled" (value=2).
   $drac{enableddefault} = "Enabled"             if $drac{enableddefault} eq "2";
   $drac{enableddefault} = "Disabled"            if $drac{enableddefault} eq "3";
   $drac{enableddefault} = "Not Applicable"      if $drac{enableddefault} eq "4";
   $drac{enableddefault} = "Enabled but Offline" if $drac{enableddefault} eq "5";
   $drac{enableddefault} = "No Default"          if $drac{enableddefault} eq "6";
   print "EnabledDefault=$drac{enableddefault} \n" if ($verbose eq "yes");
   #
   #
   # RequestedState Indicates the last requested or desired state for the system.
   $drac{requestedstate} = "Enabled"        if $drac{requestedstate} eq "2";
   $drac{requestedstate} = "Disabled"       if $drac{requestedstate} eq "3";
   $drac{requestedstate} = "Shut Down"      if $drac{requestedstate} eq "4";
   $drac{requestedstate} = "No Change"      if $drac{requestedstate} eq "5";
   $drac{requestedstate} = "Offline"        if $drac{requestedstate} eq "6";
   $drac{requestedstate} = "Test"           if $drac{requestedstate} eq "7";
   $drac{requestedstate} = "Deferred"       if $drac{requestedstate} eq "8";
   $drac{requestedstate} = "Quiesce"        if $drac{requestedstate} eq "9";
   $drac{requestedstate} = "Reboot"         if $drac{requestedstate} eq "10";
   $drac{requestedstate} = "Reset"          if $drac{requestedstate} eq "11";
   $drac{requestedstate} = "Not Applicable" if $drac{requestedstate} eq "12";
   print "RequestedState=$drac{requestedstate} \n" if ($verbose eq "yes");
   #
   #
   # HealthState Indicates the current health of the system
   # The desired value is 5=OK
   $drac{healthstate} = "Unknown"               if $drac{healthstate} eq "0";
   $drac{healthstate} = "OK"                    if $drac{healthstate} eq "5";
   $drac{healthstate} = "Degraded/Warning"      if $drac{healthstate} eq "10";
   $drac{healthstate} = "Minor Failure"         if $drac{healthstate} eq "15";
   $drac{healthstate} = "Major Failure"         if $drac{healthstate} eq "20";
   $drac{healthstate} = "Critical Failure"      if $drac{healthstate} eq "30";
   $drac{healthstate} = "Non-recoverable Error" if $drac{healthstate} eq "35";
   print "HealthState=$drac{healthstate} \n" if ($verbose eq "yes");
   #
   #
   # OperationalStatus indicates the current status of the system
   # The desired value is 2=OK
   $drac{operationalstatus} = "Unknown"                    if $drac{operationalstatus} eq "0";
   $drac{operationalstatus} = "Other"                      if $drac{operationalstatus} eq "1";
   $drac{operationalstatus} = "OK"                         if $drac{operationalstatus} eq "2";
   $drac{operationalstatus} = "Degraded"                   if $drac{operationalstatus} eq "3";
   $drac{operationalstatus} = "Stressed"                   if $drac{operationalstatus} eq "4";
   $drac{operationalstatus} = "Predictive Failure"         if $drac{operationalstatus} eq "5";
   $drac{operationalstatus} = "Error"                      if $drac{operationalstatus} eq "6";
   $drac{operationalstatus} = "Non-Recoverable Error"      if $drac{operationalstatus} eq "7";
   $drac{operationalstatus} = "Starting"                   if $drac{operationalstatus} eq "8";
   $drac{operationalstatus} = "Stopping"                   if $drac{operationalstatus} eq "9";
   $drac{operationalstatus} = "Stoped"                     if $drac{operationalstatus} eq "10";
   $drac{operationalstatus} = "In Service"                 if $drac{operationalstatus} eq "11";
   $drac{operationalstatus} = "No Contact"                 if $drac{operationalstatus} eq "12";
   $drac{operationalstatus} = "Lost Communication"         if $drac{operationalstatus} eq "13";
   $drac{operationalstatus} = "Aborted"                    if $drac{operationalstatus} eq "14";
   $drac{operationalstatus} = "Dormant"                    if $drac{operationalstatus} eq "15";
   $drac{operationalstatus} = "Supporting Entity in Error" if $drac{operationalstatus} eq "16";
   $drac{operationalstatus} = "Completed"                  if $drac{operationalstatus} eq "17";
   $drac{operationalstatus} = "Power Mode"                 if $drac{operationalstatus} eq "18";
   print "OperationalStatus=$drac{operationalstatus} \n" if ($verbose eq "yes");
   #
   #
   # Dedicated is an enumeration indicating whether the system is a special-purpose system or general-purpose system.
   # Most normal servers will be "0" or "Not Dedicated"
   $drac{dedicated}= "Not Dedicated"         if $drac{dedicated} eq "0";
   $drac{dedicated}= "Unknown"               if $drac{dedicated} eq "1";
   $drac{dedicated}= "Other"                 if $drac{dedicated} eq "2";
   $drac{dedicated}= "Storage"               if $drac{dedicated} eq "3";
   $drac{dedicated}= "Router"                if $drac{dedicated} eq "4";
   $drac{dedicated}= "Switch"                if $drac{dedicated} eq "5";
   $drac{dedicated}= "Layer 3 Switch"        if $drac{dedicated} eq "6";
   $drac{dedicated}= "CentralOffice Switch"  if $drac{dedicated} eq "7";
   $drac{dedicated}= "Hub"                   if $drac{dedicated} eq "8";
   $drac{dedicated}= "Access Server"         if $drac{dedicated} eq "9";
   $drac{dedicated}= "Firewall"              if $drac{dedicated} eq "10";
   $drac{dedicated}= "Print"                 if $drac{dedicated} eq "11";
   $drac{dedicated}= "I/O"                   if $drac{dedicated} eq "12";
   $drac{dedicated}= "Web Caching"           if $drac{dedicated} eq "13";
   $drac{dedicated}= "Management"            if $drac{dedicated} eq "14";
   $drac{dedicated}= "Block Server"          if $drac{dedicated} eq "15";
   $drac{dedicated}= "File Server"           if $drac{dedicated} eq "16";
   $drac{dedicated}= "Mobile User Device"    if $drac{dedicated} eq "17";
   $drac{dedicated}= "Repeater"              if $drac{dedicated} eq "18";
   $drac{dedicated}= "Bridge/Extender"       if $drac{dedicated} eq "19";
   $drac{dedicated}= "Gateway"               if $drac{dedicated} eq "20";
   $drac{dedicated}= "Storage Virtualizer"   if $drac{dedicated} eq "21";
   $drac{dedicated}= "Media Library"         if $drac{dedicated} eq "22";
   $drac{dedicated}= "Extender Node"         if $drac{dedicated} eq "23";
   $drac{dedicated}= "NAS Head"              if $drac{dedicated} eq "24";
   $drac{dedicated}= "Self-Contained NAS"    if $drac{dedicated} eq "25";
   $drac{dedicated}= "UPS"                   if $drac{dedicated} eq "26";
   $drac{dedicated}= "IP Phone"              if $drac{dedicated} eq "27";
   $drac{dedicated}= "Management Controller" if $drac{dedicated} eq "28";
   $drac{dedicated}= "Chassis Manager"       if $drac{dedicated} eq "29";
   print "Dedicated=$drac{dedicated} \n" if ($verbose eq "yes");
}								#end of subroutine





sub look_for_errors {
   #
   print "running look_for_errors subroutine \n" if ($verbose eq "yes");
   #
   # By the time we get here, we already have all the details about the hardware.
   # Let's look at the hardware status and alert on any problems found.
   # 
   unless ( $drac{resetcapability} eq "Enabled" ) {
      print "$CHECK_NAME WARN - DRAC cannot be reset.  ResetCapability=$drac{resetcapability} HealthState=$drac{healthstate} Hardware=$drac{description} ParentHost=$drac{elementname} ServiceTag=$drac{name}\n";
     exit $WARN;
   }								#end of unless block
   # 
   unless ( $drac{enabledstate} eq "Enabled" ) {
      print "$CHECK_NAME WARN - EnabledState is $drac{enabledstate}  ResetCapability=$drac{resetcapability} HealthState=$drac{healthstate} Hardware=$drac{description} ParentHost=$drac{elementname} ServiceTag=$drac{name}\n";
     exit $WARN;
   }								#end of unless block
   # 
   unless ( $drac{enableddefault} eq "Enabled" ) {
      print "$CHECK_NAME WARN - EnabledDefault is $drac{enableddefault}.  This value should be set to 2=Enabled so the machine will power up normally at boot time.   ResetCapability=$drac{resetcapability} HealthState=$drac{healthstate} Hardware=$drac{description} ParentHost=$drac{elementname} ServiceTag=$drac{name}\n";
     exit $WARN;
   }								#end of unless block
   #
   unless ( $drac{healthstate} eq "OK" ) {
      print "$CHECK_NAME WARN - HealthState=$drac{healthstate}.  Please investigate.  ResetCapability=$drac{resetcapability} HealthState=$drac{healthstate} Hardware=$drac{description} ParentHost=$drac{elementname} ServiceTag=$drac{name}\n";
     exit $WARN;
   }								#end of unless block
   #
   unless ( $drac{operationalstatus} eq "OK" ) {
      print "$CHECK_NAME WARN - OperationalStatus=$drac{operationalstatus}.  Please investigate.  ResetCapability=$drac{resetcapability} HealthState=$drac{healthstate} Hardware=$drac{description} ParentHost=$drac{elementname} ServiceTag=$drac{name}\n";
     exit $WARN;
   }								#end of unless block



}								#end of subroutine




sub all_clear {
   #
   # we only get this far if there were no problems
   #
   print "$CHECK_NAME OK - HealthState=$drac{healthstate} OperationalStatus=$drac{operationalstatus} Hardware=$drac{description} ParentHost=$drac{elementname} ServiceTag=$drac{name}\n";
   exit $OK;

}                                                                       #end of subroutine





# --  main body of script -------------------------------------------------
sanity_checks;
#check_name_resolution;
ssh_to_drac;
get_hardware_status;
look_for_errors;
all_clear;
