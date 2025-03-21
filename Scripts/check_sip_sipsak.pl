#!/usr/bin/perl

##
# check_sip - (c) 2005-2006 O'Shaughnessy Evans <shaug+nagios at aloha.net>
#
# Check the responsiveness of a SIP server.
#
# $Id: check_sip,v 1.5 2006/09/29 22:48:07 shaug Exp $
#
# Requires sipsak; see sipsak.org for more info.
##

require 5.004;
use strict;
use POSIX;
use Getopt::Long qw(:config no_ignore_case);
use Sys::Hostname;

use lib '/usr/local/libexec/nagios';
use utils qw($TIMEOUT %ERRORS &print_revision &support);

use vars qw($ME $VERSION $Contact $Expires %Flags $Help $Host $Contact_Host
            $Password $Port $Proxy $REG_Mode @Sipsak_Cmd $Usage $User $URI
            $Verbose);

BEGIN {
  $VERSION = '0.'. (split(' ', '$Id: check_sip,v 1.5 2006/09/29 22:48:07 shaug Exp $'))[2];
  $ME = 'check_sip_sipsak';

  # command to get connection state; 1st %s is for extra args, second is SIP URI
  @Sipsak_Cmd = qw(/usr/local/bin/sipsak --nagios-warn 2 --nagios-code -v);
#  @Sipsak_Cmd = qw(/home/abennett/sipsak --nagios-code -v);
  $User = '';
  $Password = '';
  $Port = 5060;
  $Proxy = '';
#  $Expires = 300;
  $Expires = 45;
  $Contact_Host = hostname();
  $REG_Mode = 0;

  $Usage = "$ME -H host [-c contact] [-P proxy] [-p port] [-u user] [-U uri] [-v]";
  $Help = <<EOhelp;
  $ME:  Nagios plugin to check a SIP server

Usage:
  $ME [<flags>] -H host [-c contact_uri] [-P proxy] [-p port] [-u user] [-a pass] [-e exp] [-v]
  $ME [<flags>] -U sip_uri [-c contact_uri] [-P proxy] [-a pass] [-e exp] [-v]
  $ME --help
  $ME --man
  $ME --version

Options:
  --contact|c   Contact URI to use in register (def <given user>\@$Contact_Host).
  --expires|e   Set an expiration time for registrations (def $Expires).
  --hostname|H  Name of the host running the SIP server.
  --password|a  Auth password to specify when sending a username.
  --port|p      Port on which the SIP service should be running (def $Port).
  --proxy|P     Outbound proxy hostname; use if different than SIP URI host.
  --user|u      Username to include in the SIP uri.
  --uri|U       Full sip:user\@host[:port] URI.
  --verbose|-v  Show details of progress (give more than once for more info).
  --help        Show this usage text.
  --man         Show the comprehensive documentation.
  --version     Show the version ($VERSION).

  Normal behavior is to send an OPTIONS request to the SIP server.
  If a username is given, though, either through --user or --uri, the
  script will attempt to register with the server given in the SIP URI.

EOhelp
}

# handle the command-line
$Verbose = 0;
GetOptions('verbose|v+'   => \$Verbose,
           'version|V'    => \$Flags{version},
           'help|h'       => \$Flags{help},
           'man|m'        => \$Flags{man},
           'contact|c=s'  => \$Contact,
           'expires|e=i'  => \$Expires,
           'hostname|H=s' => \$Host,
           'password|a=s' => \$Password,
           'port|p=s'     => \$Port,
           'proxy|P=s'    => \$Proxy,
           'user|u=s'     => \$User,
           'uri|U=s'      => \$URI,
          )
 or die($Usage);
if ($Flags{version}) {
    print_revision($ME, $VERSION);
    exit 0;
}
elsif ($Flags{help}) {
    print $Help;
    exit 0;
}
elsif ($Flags{man}) {
    use Pod::Usage;
    pod2usage(-verbose => 2, -exitval => 0);
}

if (!$URI and !$Host) {
    print "ERROR:  Sorry, but a hostname or full URI must be given.\n\n".
          $Usage;
    exit $ERRORS{UNKNOWN};
}
elsif ($Host and ! utils::is_hostname($Host)) {
    print "ERROR:  Sorry, but \"$Host\" doesn't look like a host name.\n\n".
          $Usage;
    exit $ERRORS{UNKNOWN};
}

if (!$URI) {
    $URI = "sip:". ($User ? "$User\@" : ''). "$Host:$Port";
}

# add -v flags to sipsak according to the verbosity given on the command line
for (my $v = 0; $v < $Verbose; $v++) {
    push @Sipsak_Cmd, '-v';
}

# if the URI contains a username, we're running in REGISTER mode and we
# need to add some parameters to our sipsak command line
if ($URI =~ /\@/) {
    $REG_Mode = 1;

    push @Sipsak_Cmd, '-U';
    if (defined($Expires)) {
        push @Sipsak_Cmd, '--expires', $Expires;
    }

    if (!$Contact) {
        $Contact = "sip:$User\@$Contact_Host";
    }
    if (defined($Contact)) {
        $Contact = 'sip:'. $Contact unless $Contact =~ /^sip(s)?:/i;
        push @Sipsak_Cmd, '--contact', $Contact;
    }

    if ($Password) {
        push @Sipsak_Cmd, '--password', $Password;
    }
}

# add a proxy to the sipsak command line if one was given
if ($Proxy) {
    push @Sipsak_Cmd, '--outbound-proxy', $Proxy;
}

push @Sipsak_Cmd, '--sip-uri', $URI;
print "executing:  ". join(' ', @Sipsak_Cmd). "\n" if $Verbose;
my $cmd = join(' ', @Sipsak_Cmd);
my @out = `$cmd 2>&1`;
print "output is:\n\n@out\n" if $Verbose;
chomp @out;
my ($status) = grep(/^SIP\s/, @out);
chomp $status;

my ($state, $answer);
if ($status =~ /^SIP(\/[\d.]+ 2\d\d)? OK/i) {
    $state = $ERRORS{OK};
    $answer = $status;
}
else {
    $state = $ERRORS{CRITICAL};
    $answer = "$status (\"...$out[-2]\")";
}

print "Searching known error codes... " if $Verbose > 2;
foreach my $errname (keys %ERRORS) {
    print " $errname" if $Verbose > 2;
    if ($state == $ERRORS{$errname}) {
        print "\n" if $Verbose > 2;
        print "SIP $errname: $answer\n";
        last;
    }
}
exit $state;