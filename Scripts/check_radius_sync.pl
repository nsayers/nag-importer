#!/usr/bin/perl

#$heating = `/usr/lib/nagios/plugins/check_nrpe -H 216.9.9.168 -c check_sync`;
#chomp($heating);
#$cooling = `/usr/lib/nagios/plugins/check_nrpe -H 216.9.9.87 -c check_sync`;
#chomp($cooling);

$entropy = `/usr/lib/nagios/plugins/check_nrpe -H 64.38.176.82 -c check_sync`;
chomp($entropy);
$syntropy = `/usr/lib/nagios/plugins/check_nrpe -H 216.9.6.47 -c check_sync`;
chomp($syntropy);

#if($heating =~ /^OK\: (.*)$/) {
#       $hmd = $1;
#} else {
#       print "WARNING: Unable to parse output from heating [$heating]\n";
#       exit 1;
#}
#if($cooling =~ /^OK\: (.*)$/) {
#       $cmd = $1;
#} else {
#       print "WARNING: Unable to parse output from cooling [$cooling]\n";
#       exit 1;
#}

if($entropy =~ /^OK\: (.*)$/) {
        $emd = $1;
} else {
        print "WARNING: Unable to parse output from entropy [$entropy]\n";
        exit 1;
}
if($syntropy =~ /^OK\: (.*)$/) {
        $smd = $1;
} else {
        print "WARNING: Unable to parse output from syntropy [$syntropy]\n";
        exit 1;
}
#if($heating ne $cooling) {
#       print "CRITICAL: seanet-clean md5 mismatch, check sync (heating & cooling mismatch)\n";
#       exit 2;
#}
if($entropy ne $syntropy) {
        print "CRITICAL: seanet-clean md5 mismatch, check sync (entropy & syntropy mismatch)\n";
        exit 2;
}
print "OK: files in sync\n";
exit 0;