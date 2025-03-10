#!/usr/bin/perl
use strict;
use warnings;

# Check if correct number of arguments is passed
if (@ARGV != 3) {
    die "Usage: $0 <state> <state_type> <attempt>\n";
}

# Assign command line arguments to variables
my ($state, $state_type, $attempt) = @ARGV;

# What state is the nagios gearman service in?
if ($state eq 'OK') {
    # The service just came back up, so don't do anything...
    exit 0;
} elsif ($state eq 'WARNING') {
    # We don't really care about warning states, since the service is probably still running...
    exit 0;
} elsif ($state eq 'UNKNOWN') {
    # We don't know what might be causing an unknown error, so don't do anything...
    exit 0;
} elsif ($state eq 'CRITICAL') {
    # Aha! The service appears to have a problem - perhaps we should restart the server...

    # Is this a "soft" or a "hard" state?
    if ($state_type eq 'SOFT') {
        # We're in a "soft" state, meaning that Nagios is in the middle of retrying the
        # check before it turns into a "hard" state and contacts get notified...

        # What check attempt are we on? We don't want to restart the nagios services on the first
        # check, because it may just be a fluke!
        if ($attempt == 3) {
            # Wait until the check has been tried 3 times before restarting the nagios server.
            # If the check fails on the 4th time (after we restart the nagios server), the state
            # type will turn to "hard" and contacts will be notified of the problem.
            # Hopefully this will restart the nagios server successfully, so the 4th check will
            # result in a "soft" recovery. If that happens no one gets notified because we
            # fixed the problem!
            print "Restarting gearman services (3rd soft critical state)...\n";
            # Call system to restart the appropriate services
            system('sudo /sbin/service gearmand restart');
            system('sudo /sbin/service nagios restart');
            system('sudo /sbin/service mod-gearman-worker restart');
        }
    } elsif ($state_type eq 'HARD') {
        # The nagios service somehow managed to turn into a hard error without getting fixed.
        # It should have been restarted by the code above, but for some reason it didn't.
        # Let's give it one last try, shall we?
        # Note: Contacts have already been notified of a problem with the service at this
        # point (unless you disabled notifications for this service)
        print "Restarting HTTP service...\n";
        # Call system to restart the appropriate services
        system('sudo /sbin/service gearmand restart');
        system('sudo /sbin/service nagios restart');
        system('sudo /sbin/service mod-gearman-worker restart');
    }
}

exit 0;
