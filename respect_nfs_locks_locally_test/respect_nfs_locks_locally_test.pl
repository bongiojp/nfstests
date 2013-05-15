#!/usr/bin/perl

use Fcntl;

if (@ARGV != 4) {
    print "Usage: $0 server exportdir /filename mountdir\n";
    exit(0);
}

$server = $ARGV[0];
$exportdir = $ARGV[1];
$filename = $ARGV[2];
$mountdir = $ARGV[3];

sleep(.5);
print "Creating file through ssh\n";
sleep(.5);
$bs = 1024;
$count= 10;
$ret = `sudo ssh ${server} dd if=/dev/zero of=${exportdir}/${filename} bs=${bs}k count=${count}`;
`sudo ssh ${server} chmod 0777 ${exportdir}/${filename}`;
$? == 0 or die "FAIL: Could not touch ${exportdir}/${filename} on ${server}\n";

print "Building lock binary through ssh\n";
`sudo scp lock.c ${server}:~/`;
`sudo ssh ${server} gcc -o lock lock.c`;

# Mount Ganesha export 
print "Mounting file\n";
print "sudo mount -o noac,proto=tcp,vers=3 -t nfs ${server}:${exportdir} ${mountdir}\n";
`sudo mount -o noac,proto=tcp,vers=3 -t nfs ${server}:${exportdir} ${mountdir}`;

for(1 .. 10) {
    ########################################################################
    ## Test for shared (READ) Whole lock
    ########################################################################

    print "--- Testing local shared whole-file lock ... $_\n";

    sleep(2); # Test will sometimes fail without this

    # Obtain whole file shared lock on remote machine
    print "sudo ./lock ${mountdir}/${filename} SHARED NOBLOCK 0 0 SLEEP &\n";
    system("sudo ./lock ${mountdir}/${filename} SHARED NOBLOCK 0 0 SLEEP &");

    sleep(2); # Test will sometimes fail without this

    # shared lock, Partial file lock from start
    print "TEST 1: partial file shared lock from start\n";
    $length = int(rand($bs*$count*1024));
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 ${length} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, shared lock locally when there is a nfs,whole-file,shared lock.\n";
    }

    # shared lock, Whole file lock
    print "TEST 2: whole file shared lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 0 NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain whole-file, shared lock locally when there is a nfs,whole-file,shared lock.\n";
    }

    # exclusive lock, Partial file lock
    print "TEST 3: partial file exclusive lock from start\n";
    $length = int(rand($bs*$count*1024));
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${length} NOSLEEP\"`;
    if( $ret =~ m/.*Success.*/) {
	print "output: $ret\n";
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
	print "sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${length} NOSLEEP\"\n";
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,whole-file,shared lock.\n";
    }

    # exclusive lock, Whole file lock
    print "TEST 4: whole file exclusive lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 0 NOSLEEP\"`;
    if( $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
	print "sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 0 NOSLEEP\"\n";
        die "FAIL: Obtained Whole-file, exclusive lock locally when there is a nfs,whole-file,shared lock.\n";
    }

    # Get rid of the local lock on the file.
    print "Killing remote process that is holding the shared lock\n";
    `sudo killall -s KILL lock`;

    ########################################################################
    ## Test for shared (READ) Partial lock
    ########################################################################


    print "--- Testing local shared partial-file lock ... $_\n";

    sleep(2); # Test will sometimes fail without this

    # Obtain partial file shared lock on remote machine
    $start = int(rand($bs*$count*1024 - 500));
    $length = int(rand($bs*$count*1024 - $start_length - 10));
    print "Locking locally at start=${start} for len=${length}\n";
    system("sudo ./lock ${mountdir}/${filename} SHARED NOBLOCK ${start} ${length} SLEEP &");

    sleep(2); # Test will sometimes fail without this

    # shared lock, Overlap in front
    print "TEST 5: partial file shared lock overlapping in front\n";
    $tlength = ${start}+20;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, shared lock locally when there is a nfs,partial-file,shared lock. Lock would overlap in the front of the nfs lock\n";
    }

    # shared lock, Whole file lock
    print "TEST 6: whole file shared lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 0 NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain whole-file, shared lock locally when there is a nfs,partial-file,shared lock.\n";
    }

    # shared lock, Overlap perfectly
    print "TEST 7: partial file shared lock overlapping perfectly\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK ${start} ${length} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, shared lock locally when there is a nfs,partial-file,shared lock. Locks would overlap perfectly.\n";
    }

    # shared lock, Overlap in back
    print "TEST 8: partial file shared lock overlapping in back\n";
    $tstart = $length + $start - 10;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK ${tstart} 20 NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, shared lock locally when there is a nfs,partial-file,shared lock. Back of nfs lock would be overlapped.\n";
    }

    # shared lock, Overlap not at all
    print "TEST 9: partial file shared lock overlapping not at all\n";
    $tlength= $start - 1;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, shared lock locally when there is a nfs,partial-file,shared lock and the locks would not overlap.\n";
    }

    #####################

    # exclusive lock, Overlap in front
    print "TEST 10: partial file exclusive lock overlapping in front\n";
    $tlength = ${start}+20;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
    print "sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${tlength} NOSLEEP\"\n";
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,partial-file,shared lock. Lock would overlap in the front of the nfs lock\n";
    }

    # exclusive lock, Whole file lock
    print "TEST 11: whole file exclusive lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 0 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained whole-file, exclusive lock locally when there is a nfs,partial-file,shared lock.\n";
    }

    # exclusive lock, Overlap perfectly
    print "TEST 12: partial file exclusive lock overlapping perfectly\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK ${start} ${length} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,partial-file,shared lock. Locks would overlap perfectly.\n";
    }

    # exclusive lock, Overlap in back
    print "TEST 13: partial file exclusive lock overlapping in back\n";
    $tstart = $length + $start - 10;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK ${tstart} 20 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,partial-file,shared lock. Back of nfs lock would be overlapped.\n";
    }

    # exclusive lock, Overlap not at all
    print "TEST 14: partial file exclusive lock overlapping not at all\n";
    $tlength= $start - 1;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, exclusive lock locally when there is a nfs,partial-file,shared lock and the locks would not overlap.\n";
    }

    # Get rid of the local lock on the file.
    print "Killing remote process that is holding the shared lock\n";
    `sudo killall -s KILL lock`;

    ########################################################################
    ## Test for exclusive (WRITE) Whole-file lock
    ########################################################################

    print "--- Testing local exclusive whole-file lock ... $_\n";

    sleep(2); # Test will sometimes fail without this

    # Obtain whole file exclusive lock on remote machine
    print "sudo ./lock ${mountdir}/${filename} EXCLUSIVE NOBLOCK 0 0 SLEEP &\n";
    system("sudo ./lock ${mountdir}/${filename} EXCLUSIVE NOBLOCK 0 0 SLEEP&");

    sleep(2); # Test will sometimes fail without this

    # shared lock, Partial file lock from start
    print "TEST 15: partial file shared lock from start\n";
    $length = int(rand($bs*$count*1024));
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 ${length} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, shared lock locally when there is a nfs,whole-file,exclusive lock.\n";
    }

    # shared lock, Whole file lock
    print "TEST 16: whole file shared lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 0 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained whole-file, shared lock locally when there is a nfs,whole-file,exclusive lock.\n";
    }

    # exclusive lock, Partial file lock
    print "TEST 17: partial file exclusive lock from start\n";
    $length = int(rand($bs*$count*1024));
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${length} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	print "output: $ret\n";
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
	print "sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${length} NOSLEEP\"\n";
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,whole-file,exclusive lock.\n";
    }

    # exclusive lock, Whole file lock
    print "TEST 18: whole file exclusive lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 0 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
	print "sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 0 NOSLEEP\"\n";
        die "FAIL: Obtained whole-file, exclusive lock locally when there is a nfs,whole-file,exclusive lock.\n";
    }

    # Get rid of the local lock on the file.
    print "Killing remote process that is holding the shared lock\n";
    `sudo killall -s KILL lock`;

    ########################################################################
    ## Test for exclusive (WRITE) Partial-file lock
    ########################################################################

    print "--- Testing local exclusive partial-file lock ... $_\n";

    sleep(2); # Test will sometimes fail without this

    # Obtain partial file exclusive lock on remote machine
    $start = int(rand($bs*$count*1024 - 500));
    $length = int(rand($bs*$count*1024 - $start_length - 10));
    print "Locking locally at start=${start} for len=${length}\n";
    system("sudo ./lock ${mountdir}/${filename} EXCLUSIVE NOBLOCK ${start} ${length} SLEEP &");

    sleep(2); # Test will sometimes fail without this

    # shared lock, Overlap in front
    print "TEST 19: partial file shared lock overlapping in front\n";
    $tlength = ${start}+20;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, shared lock locally when there is a nfs,partial-file,exclusive lock. Lock would overlap in the front of the nfs lock\n";
    }

    # shared lock, Whole file lock
    print "TEST 20: whole file shared lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 0 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained whole-file, shared lock locally when there is a nfs,partial-file,exclusive lock.\n";
    }

    # shared lock, Overlap perfectly
    print "TEST 21: partial file shared lock overlapping perfectly\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK ${start} ${length} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, shared lock locally when there is a nfs,partial-file,exclusive lock. Locks would overlap perfectly.\n";
    }

    # shared lock, Overlap in back
    print "TEST 22: partial file shared lock overlapping in back\n";
    $tstart = $length + $start - 10;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK ${tstart} 20 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, shared lock locally when there is a nfs,partial-file,exclusive lock. Back of nfs lock would be overlapped.\n";
    }

    # shared lock, Overlap not at all
    print "TEST 23: partial file shared lock overlapping not at all\n";
    $tlength= $start - 1;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} SHARED NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, shared lock locally when there is a nfs,partial-file,exclusive lock and the locks would not overlap.\n";
    }

    #####################

    # exclusive lock, Overlap in front
    print "TEST 24: partial file exclusive lock overlapping in front\n";
    $tlength = ${start}+20;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
    print "sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${tlength} NOSLEEP\"\n";
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,partial-file,exclusive lock. Lock would overlap in the front of the nfs lock\n";
    }

    # exclusive lock, Whole file lock
    print "TEST 25: whole file exclusive lock\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 0 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained whole-file, exclusive lock locally when there is a nfs,partial-file,exclusive lock.\n";
    }

    # exclusive lock, Overlap perfectly
    print "TEST 26: partial file exclusive lock overlapping perfectly\n";
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK ${start} ${length} NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,partial-file,exclusive lock. Locks would overlap perfectly.\n";
    }

    # exclusive lock, Overlap in back
    print "TEST 27: partial file exclusive lock overlapping in back\n";
    $tstart = $length + $start - 10;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK ${tstart} 20 NOSLEEP\"`;
    if($ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Obtained partial-file, exclusive lock locally when there is a nfs,partial-file,exclusive lock. Back of nfs lock would be overlapped.\n";
    }

    # exclusive lock, Overlap not at all
    print "TEST 28: partial file exclusive lock overlapping not at all\n";
    $tlength= $start - 1;
    $ret = `sudo ssh ${server} \"./lock ${exportdir}/${filename} EXCLUSIVE NOBLOCK 0 ${tlength} NOSLEEP\"`;
    if(! $ret =~ m/.*Success.*/) {
	`sudo killall -s KILL lock`;
	`sudo umount -l -f ${mountdir}`;
        die "FAIL: Could not obtain partial-file, exclusive lock locally when there is a nfs,partial-file,exclusive lock and the locks would not overlap.\n";
    }

    # Get rid of the local lock on the file.
    print "Killing remote process that is holding the shared lock\n";
    `sudo killall -s KILL lock`;

}

########################################################################
## All finished
########################################################################
`sudo umount -l -f ${mountdir}`;


print "SUCCESS\n"
