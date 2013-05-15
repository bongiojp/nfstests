#!/usr/bin/perl -w
use strict;
use IO::Socket;
my $sock = IO::Socket::INET->new(
    PeerHost => '127.0.0.1',
    PeerPort => '10401',
    Proto    => 'tcp');
die "$!" unless $sock;
$sock->autoflush();
$sock->print("type=all_detail,version=3\015\012");
#$sock->print("version=3\015\012");
my $statistics = join('', $sock->getlines());
#print "$statistics\n";
my @statsss = split(/ _/, $statistics);
foreach(@statsss) {
    print "${_}\n";
}
close($sock);
