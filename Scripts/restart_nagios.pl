#!/usr/bin/perl
use strict;
use warnings;

# Define the services to be restarted
my @services = ('gearmand', 'nagios', 'mod-gearman-worker');

# Iterate over each service
foreach my $service (@services) {
    print "Restarting $service...\n";

    # Stop the service
    system("sudo systemctl stop $service");
    if ($? == -1) {
        print "Failed to stop $service: $!\n";
    } else {
        printf "Stop command exited with value %d\n", $? >> 8;
    }

    # Start the service
    system("sudo systemctl start $service");
    if ($? == -1) {
        print "Failed to start $service: $!\n";
    } else {
        printf "Start command exited with value %d\n", $? >> 8;
    }

    print "$service restarted successfully.\n\n";
}
