#!/usr/bin/perl

use Fcntl qw/:seek :flock/;

if (@ARGV != 5) {
    print "Usage: $0 server exportdir /filename mountdir typeoflock dbenchlocation\n";
    exit(0);
}

$server = $ARGV[0];
$exportdir = $ARGV[1];
$filename = $ARGV[2];
$mountdir = $ARGV[3];
$dbenchdir = $ARGV[4];

$filecontents = "adsfuashdflaushflashfaslefhasfeasfea
asfrawetqwr2321351251nbktu3nfku3qnfrq@!46t!T!TqergeqrV@ yv32q%YV452
%C3q3t4QTQtcq3t4xq3TQt4cq\n\n\nasdasdsafsad\t\tadsfasdfawesd\n@%QTAQWFEAs\nsdasd";
$len = length($filecontents);

`echo \"${filecontents}\" > ./tempfile`;

# Create a new file with contents through dbench
if (! -d $mountdir) {
    `mkdir ${mountdir}`;
}
if (-e "$mountdir/$filename") {
    `rm -rf $mountdir/$filename`;
}

sleep(.5);
print "Creating file from dbench\n";
`${dbenchdir}/comm_create ${server} ${exportdir} ${filename}`;
print "${dbenchdir}/comm_create ${server} ${exportdir} ${filename}\n";
sleep(.5);
`${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} 0 ./tempfile`;
print "${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} 0 ./tempfile\n";

# Mount through nfs kernel server and lock the new file
print "Mounting file\n";
`mount -o noac -t nfs ${server}:${exportdir} ${mountdir}`;
print "Opening and locking file\n";
open(my $FILE, "<", "$mountdir/$filename") or die "FAIL: Cannot open file: $mountdir/$filename\n";

# Read
print "Reading from file\n";
$readcontents = "";
seek($FILE, 0, SEEK_SET);
while (<$FILE>) {
    $readcontents .= $_;
}

# Compare if contents are the same as earlier
if (! ($readcontents eq $filecontents)) {
    print "FAIL: Contents read from file are not the same as what was previously written.\n";
    exit(1);
}

if (-e "$mountdir/$filename") {
    print "File currently exists.\n";
}

# Remove the file through dbench
print "Removing file through dbench\n";
`${dbenchdir}/comm_remove ${server} ${exportdir} ${filename}`;

if (-e "$mountdir/$filename") {
    print "FAIL: File should have been deleted!\n";
    exit(1);
} else {
    print "File deleted as it should have been.\n";
}

print "Closing file\n";
close($FILE);

if (-e "$mountdir/$filename") {
    print "FAIL: File still exists after closing the file!\n";
    exit(1);
} else {
    print "File was deleted after closing the file descriptor.\n";
}

`umount -l ${mountdir}`;
print "SUCCESS\n"
