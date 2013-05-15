#!/usr/bin/perl

use tests ':all';
use strict;
use warnings;

if (@ARGV < 3) {
    print "There must be at least one node and the export directory.\n";
    print "Usage: ${0} <export directory> <nfs version> <mountdir_base> <node url> ... <node url>\n";
    exit 0;
}

my $iterations = 1;
my $exportdir = shift(@ARGV);
my $mountdir_base = shift(@ARGV);
our @nodes = @ARGV;
our @mountdirs;
my $counter = 0;
my $nfsversion;

sub mydie($){
    print @_;
    print "Unmounting all exports\n";
    foreach(@mountdirs) { `umount -l -f ${_}`; }	
    print "\n-------------------------------------\n";
    print "-- FAILED to complete tests!!";
    print "\n-------------------------------------\n";
    die;
}

sub umountall {
    my @mountdirs = @_;
    foreach(@mountdirs) { `umount -l -f ${_}`; }
}

# capable of mounting nfsv3, nfsv4, or a toggled mix
sub mountall($$\@\@) {
    my $nfsversion = shift(@_);
    my $exportdir = shift(@_);
    my $mountdirs_ref = shift(@_);
    my $nodes_ref = shift(@_);
    my $mixed = 0;

    my @nodes = @$nodes_ref;
    my @mountdirs = @$mountdirs_ref;


    my $counter = 0;

    if ($nfsversion eq "3/4") {
	$mixed = 1;
	$nfsversion = 3;
    }

    foreach(@nodes) {
	my $result;

	if($mixed && $nfsversion == 4) {$nfsversion = 3;}
	elsif($mixed && $nfsversion == 3) {$nfsversion = 4;}

	if ($nfsversion == 3) {
	    print "\tmount -t nfs -o noac,proto=tcp,vers=${nfsversion} ${_}:${exportdir} ${mountdirs[$counter]}\n";
	    $result = `mount -t nfs -o noac,proto=tcp,vers=${nfsversion} ${_}:${exportdir} ${mountdirs[$counter]} 2>&1`;
	}
	if ($nfsversion == 4) {
	    print "\tmount -t nfs4 -o noac,proto=tcp ${_}:${exportdir} ${mountdirs[$counter]}\n";
	    $result = `mount -t nfs4 -o noac,proto=tcp ${_}:${exportdir} ${mountdirs[$counter]} 2>&1`;
	}

	if($result) {
	    umountall(@mountdirs);
	    die "FAIL: Upon a successful mount there should be no output. Mount returned:\n${result}\n";
	}
	$counter++;
    }
}

# Create mount directories and create list of mount directories
print "Using nodes: \n";
foreach(@nodes) {
    print "\t$_\n";
    push(@mountdirs, "${mountdir_base}.${_}");
    `mkdir ${mountdirs[-1]} 2>1`;
}
print "\nUsing Mount directories:\n";
foreach(@mountdirs) {
    print "\t$_\n";
}
print "\n";

######################################################
# all nfsv3 mounts
print "MOUNTING TEST NODES WITH NFSv3 ...\n";
$nfsversion = 3;
mountall($nfsversion, $exportdir, @mountdirs, @nodes);
print "\n";

foreach(0 .. $iterations) {
    (test_createdestroy_loop(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_createdestroy_loop did not pass on nfsv${nfsversion} mounts.\n";
    (test_symlink_loop(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_symlink_loop did not pass on nfsv${nfsversion} mounts.\n";
    (clean_symlink_loop(@mountdirs, @nodes, $exportdir) == $PASS) or die "FAIL: Could not clean environment for test_symlink_loop on nfsv${nfsversion} mounts.\n";
    (test_manysymlink_loop(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_manysymlink_loop did not pass on nfsv${nfsversion} mounts.\n";

    (test_unittest_1(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_1 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_2(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_2 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_3(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_3 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_4(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_4 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_5(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_5 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_6(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_6 did not pass on nfsv${nfsversion} mounts.\n";

    (test_fvt_1(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_fvt_1 did not pass on nfsv${nfsversion} mounts.\n";
    (test_fvt_2(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_fvt_2 did not pass on nfsv${nfsversion} mounts.\n";
    (test_fvt_3(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_fvt_3 did not pass on nfsv${nfsversion} mounts.\n";
    (test_fvt_4(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_fvt_4 did not pass on nfsv${nfsversion} mounts.\n";
}

print "Unmounting all exports\n";
umountall(@mountdirs);

######################################################
# all nfsv4 mounts
print "MOUNTING TEST NODES WITH NFSv3 ...\n";
$nfsversion = 4;
mountall($nfsversion, $exportdir, @mountdirs, @nodes);
print "\n";

foreach(0 .. $iterations) {
    (test_manysymlink_loop(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_manysymlink_loop did not pass on nfsv${nfsversion} mounts.\n";

    (test_unittest_1(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_1 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_2(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_2 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_3(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_3 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_4(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_4 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_5(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_5 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_6(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_6 did not pass on nfsv${nfsversion} mounts..\n";
}

print "Unmounting all exports\n";
umountall(@mountdirs);

######################################################
# one nfsv3 mount one nfsv4 mount

print "MOUNTING TEST NODES WITH NFSv3 _and_ NFSv4 ...\n";
$nfsversion = "3/4";
mountall($nfsversion, $exportdir, @mountdirs, @nodes);
print "\n";

# Tests can assume first mount point is nfsv3 and second mount point is nfsv4.
# It toggles after that point.
foreach(0 .. $iterations) {
    (test_manysymlink_loop(@mountdirs, @nodes, $exportdir) == $PASS) or mydie "FAIL: test_manysymlink_loop did not pass on nfsv${nfsversion} mounts.\n";

    (test_unittest_1(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_1 did not pass on nfsv${nfsversion} mounts.\n";
    (test_unittest_2(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_2 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_3(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_3 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_4(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_4 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_5(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_5 did not pass on nfsv${nfsversion} mounts..\n";
    (test_unittest_6(@mountdirs, @nodes, $exportdir, $FALSE) == $PASS) or mydie "FAIL: test_unittest_6 did not pass on nfsv${nfsversion} mounts..\n";
}


print "Unmounting all exports\n";
umountall(@mountdirs);

######################################################
# all done

print "\n-------------------------------------\n";
print "-- Completed all tests successfully!!";
print "\n-------------------------------------\n";

1;
