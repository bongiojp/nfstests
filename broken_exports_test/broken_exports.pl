#!/usr/bin/perl

if (@ARGV != 2) {
    print "Usage: $0 server exportdir\n";
    exit(0);
}

my $server = $ARGV[0];
my $exportdir = $ARGV[1];
my $testdir = "./broken_exports_test";

`mkdir ${testdir}`;

print "sudo mount -t nfs ${server}:${exportdir} ${testdir}\n";
$result = `sudo mount -t nfs ${server}:${exportdir} ${testdir} 2>&1`;
if ($result) {
    print "FAIL: mount of export ${exportdir} from server ${server} failed.\n";
    print "output: ${result}\n";
    exit(1);
}

print "sudo umount ${testdir}\n";
$result = `sudo umount ${testdir} 2>&1`;
if ($result) {
    print "FAIL: umount of export ${exportdir} from server ${server} failed.\n";
    print "output: ${result}\n";
    exit(1);
}

print "sudo mount -t nfs ${server}:${exportdir}/this/should/never/be/a/real/path ${testdir}\n";
$result = `sudo mount -t nfs ${server}:${exportdir}/this/should/never/be/a/real/path ${testdir} 2>&1`;
if (! $result) {
    print "FAIL: mount of export ${exportdir}/this/should/never/be/a/real/path from server ${server} succeeded but should have failed.\n";
    print "output: ${result}\n";
    exit(1);
}

print "sudo mount -t nfs ${server}:${exportdir} ${testdir}\n";
$result = `sudo mount -t nfs ${server}:${exportdir} ${testdir} 2>&1`;
if ($result) {
    print "FAIL: mount of export ${exportdir} from server ${server} failed.\n";
    print "output: ${result}\n";
    exit(1);
}

print "sudo umount ${testdir}\n";
$result = `sudo umount ${testdir} 2>&1`;
if ($result) {
    print "FAIL: umount of export ${exportdir} from server ${server} failed.\n";
    print "output: ${result}\n";
    exit(1);
}

print "SUCCESS! TEST COMPLETE.\n";
