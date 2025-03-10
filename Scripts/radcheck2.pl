#!/usr/bin/perl -w

use Authen::Radius;
use Getopt::Long;

use vars qw($opt_u $opt_p $opt_r $opt_s $opt_h);

GetOptions
        ("u|user=s"  => \$opt_u,
         "p|password=s" => \$opt_p,
         "r|radius-server=s" => \$opt_r,
         "s|secret=s" => \$opt_s,
         "h|help" => \$opt_h
         );

# 207.115.64.22:1645
# 66.147.196.9:1645

if ((not ($opt_u and $opt_p and $opt_r and $opt_s)) or $opt_h) {
    print "Usage: radcheck [required options]\n";
    print "\n";
    print "Required Options: -u, --user=           username\n";
    print "                  -p, --password=       password\n";
    print "                  -r, --radius-server=  radius server ip and port (server:port)\n";
    print "                  -s, --secret=         radius shared secret\n";
    print "Optional:         -h, --help            this text\n";
    exit;
}

my $r = new Authen::Radius(Host => $opt_r, Secret => $opt_s);

my $u = $opt_u;
my $p = $opt_p;

Authen::Radius->load_dictionary;

#$r->add_attributes (
#                   { Name => '1', Value => $u },
#                   { Name => '2', Value => $p },
#                   { Name => 'Framed-Protocol', Value => 1 }
#                   );

$r->add_attributes (
                    { Name => 'User-Name', Value => $u },
                    { Name => 'Password', Value => $p }
                    );

my $res;
if ($res = $r->send_packet (1)) {
    my $type = $r->recv_packet() or die "FAILED: ".$r->strerror($r->get_error);

    if ($type == 2) {
        for $a ($r->get_attributes) {
            print "attr: name=$a->{'Name'} value=$a->{'Value'}\n";
        }
        print "AUTHENTICATED\n";
    } else {
        for $a ($r->get_attributes) {
            print "attr: name=$a->{'Name'} value=$a->{'Value'}\n";
        }
        print "FAILED\n";
    }
} else {
    print "FAILED TO SEND\n";
}