#!/usr/bin/perl

use Fcntl;

if (@ARGV != 5) {
    print "Usage: $0 server exportdir /filename mountdir dbenchlocation\n";
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

$stable_flag = 0;

# Create a new file with contents through dbench
if (! -d $mountdir) {
    `mkdir ${mountdir}`;
}
if (-e "$mountdir/$filename") {
    `rm -rf $mountdir/$filename`;
}

# Restart server to start from scratch
print "Restarting server ...\n";
$result = `ssh -tt root\@${server} service nfs-ganesha-gpfs restart`;
print $result;

# Create file
sleep(.5);
print "Creating file from dbench\n";
`sudo ${dbenchdir}/comm_create ${server} ${exportdir} ${filename}`;
print "${dbenchdir}/comm_create ${server} ${exportdir} ${filename}\n";
sleep(.5);

# Mount server
print "Mounting nfs share\n";
print "sudo mount -o noac -t nfs ${server}:${exportdir} ${mountdir}\n";
`sudo mount -o noac -t nfs ${server}:${exportdir} ${mountdir}`;

# Erase file contents
print "Removing test file contents ...\n";
`echo "not the right contents" > ${mountdir}/${filename}`;

# Unstable write to file
print "Executing unstable write ...\n";
$stable_flag = 0;

print "sudo ${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} ${stable_flag} ./tempfile\n";
$ret = `sudo ${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} ${stable_flag} ./tempfile`;
if ($ret =~ /FAIL/) {
    print $ret;
    exit 1;
}

# Crash server
`ssh -tt root\@${server} killall -s KILL /usr/bin/gpfs.ganesha.nfsd`;

# Restart server
print "Restarting server ...\n";
`ssh -tt root\@${server} service nfs-ganesha-gpfs restart`;

# compare contents from file (server is already mounted)
$output = `cat ${mountdir}/${filename}`;
if (! ($output eq $filecontents)) {
    print "We executed an unstable write and indeed after a crash the write was lost.\n";
} else {
    print "FAIL: We executed an unstable write but the write was saved before the crash!\n";
}

# Restart server
print "Restarting server ...\n";
`ssh -tt root\@${server} service nfs-ganesha-gpfs restart`;

# Erase file contents
print "Removing test file contents ...\n";
`echo "not the right contents" > ${mountdir}/${filename}`;

# Stable write to file
print "Executing stable write ...\n";
$stable_flag = 1;
print "sudo ${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} ${stable_flag} ./tempfile\n";
$ret = `sudo ${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} ${stable_flag} ./tempfile`;
if ($ret =~ /FAIL/) {
    print $ret;
    exit 1;
}

# Crash server
`ssh -tt root\@${server} killall -s KILL /usr/bin/gpfs.ganesha.nfsd`;

# Restart server
`ssh -tt root\@${server} service nfs-ganesha-gpfs restart`;

# compare contents from file (server is already mounted)
$output = `cat ${mountdir}/${filename}`;
if (! ($output eq $filecontents)) {
    print "FAIL: We executed a stable write and after a crash the write was lost.\n";
} else {
    print "We executed an stable write and the write was saved before the crash.\n";
}
