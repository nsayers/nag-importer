#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Getopt::Long qw(GetOptions);

my $warn;
my $crit;

GetOptions( 
    'w=s' => \$warn,
    'c=s' => \$crit,
)  or die 'Usage: check_lvm_thinpools -w % -c % \n';

#my $warn = 10.0;
#my $crit = 17.0;




sub get_thinpools {
  $ENV{'LC_ALL'} = 'C';  # Set locale for lvs call
  my @lvsoutput = `lvs --noheadings --separator : --select 'lv_attr =~ ^t' -o lv_attr,lv_name,vg_name,data_percent,metadata_percent`;
  my @thinpools;

  for my $lvsline (@lvsoutput) {
    if ($lvsline =~ m#^(?:\s+)?(.*):(.*):(.*):(.*):(.*)#x) {
      my $lv = {
        'lv_attr'          => $1,
        'lv_name'          => $2,
        'vg_name'          => $3,
        'data_percent'     => $4,
        'metadata_percent' => $5,
      };

      push @thinpools, $lv;
    }
  }

  return @thinpools;
}

sub check_thinpools {
  for my $thinpool (get_thinpools()) {
    # Check metadata usage
    if ($thinpool->{metadata_percent} > $crit) {
      add_error(2, "CRITICAL: Meta% of $thinpool->{vg_name}/$thinpool->{lv_name} is $thinpool->{metadata_percent}")
    } elsif ($thinpool->{metadata_percent} > $warn) {
      add_error(1, "WARNING: Meta% of $thinpool->{vg_name}/$thinpool->{lv_name} is $thinpool->{metadata_percent}")
    }

    # Check data usage
    if ($thinpool->{data_percent} > $crit) {
      add_error(2, "CRITICAL: Data% of $thinpool->{vg_name}/$thinpool->{lv_name} is $thinpool->{data_percent}")
    } elsif ($thinpool->{data_percent} > $warn) {
      add_error(1, "WARNING: Data% of $thinpool->{vg_name}/$thinpool->{lv_name} is $thinpool->{data_percent}")
    }
  }

  return;
}

my @errors;

sub add_error {
  my ($exit_code, $message) = @_;

  push @errors, {
    'exit_code' => $exit_code,
    'message'   => $message,
  };

  return;
}

sub aggregate_errors {
  # Sort errors, highest exit code first
  my @sorted_errors = sort { $b->{exit_code} cmp $a->{exit_code} } @errors;
  if (scalar @sorted_errors != 0) {
    for my $error (@sorted_errors) {
      print $error->{message}, "\n";
    }
    exit $sorted_errors[0]->{exit_code};
  }

  return;
}


my $no_thinpools_ok = 0;
Getopt::Long::Configure('bundling');
GetOptions
    ("no-thinpools-ok"  => \$no_thinpools_ok,
     "w=f" => \$warn, "warning=f" => \$warn,
     "c=f" => \$crit, "critical=f" => \$crit)
    or die("Error in command line arguments\n");

my @thinpools = get_thinpools();

# No thinpool found?
if (scalar @thinpools == 0) {
  if ($no_thinpools_ok == 1) {
    print "OK: No thinpools found.\n";
    exit 0;
  } else {
    print "UNKNOWN: No thinpools found.\n";
    exit 3;
  }
} else {
  check_thinpools();
  aggregate_errors();
}

print "OK - All thinpools OK\n";
exit 0;