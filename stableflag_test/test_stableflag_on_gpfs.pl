#!/usr/bin/perl

# It is assumed that we are testing when Ganesha has Commits enabled
# and is not using the ganesha write buffer.

use Fcntl;

if (@ARGV != 4) {
    print "Usage: $0 server exportdir /filename dbenchlocation\n";
    exit(0);
}

$server = $ARGV[0];
$exportdir = $ARGV[1];
$filename = $ARGV[2];
$dbenchdir = $ARGV[3];

$local_tracedir = "./mmfs.traces";

# Create temp file to give the comm_write command something to write.
$filecontents = "adsfuashdflaushflashfaslefhasfeasfea
asfrawetqwr2321351251nbktu3nfku3qnfrq@!46t!T!TqergeqrV@ yv32q%YV452
%C3q3t4QTQtcq3t4xq3TQt4cq\n\n\nasdasdsafsad\t\tadsfasdfawesd\n@%QTAQWFEAs\nsdasd";
$len = length($filecontents);
`echo \"${filecontents}\" > ./tempfile`;

#commands
$starttrace = "ssh -tt root\@${server} \"/usr/lpp/mmfs/bin/mmtracectl --set --trace-gen-subdir=/tmp/mmfs --trace=io && /usr/lpp/mmfs/bin/mmtracectl --start\"";
$stoptrace = "ssh -tt root\@${server} \"/usr/lpp/mmfs/bin/mmtracectl --off\"";
$scptrace = "scp root\@${server}:/tmp/mmfs/*/* ./${local_tracedir}";
$removeremotetraces = "ssh -tt root\@${server} rm -rf /tmp/mmfs/*";
$removelocaltraces = "rm -rf ./${local_tracedir}; mkdir ./${local_tracedir}";

$restartganesha = "ssh -tt root\@${server} service nfs-ganesha-gpfs restart";
$createremotefile = "sudo ${dbenchdir}/comm_create ${server} ${exportdir} ${filename}";
$mountganesha = "sudo mount -o noac -t nfs ${server}:${exportdir} ${mountdir}";
$nfs_stable_write = "sudo ${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} 1 ./tempfile";
$nfs_unstable_write = "sudo ${dbenchdir}/comm_write ${server} ${exportdir} ${filename} 0 ${len} 0 ./tempfile";
$nfs_commit = "sudo ${dbenchdir}/comm_commit ${server} ${exportdir} ${filename}";

# Restart server to start from scratch
print "Restarting server\n";
$result = `${restartganesha}`;
print $result;

# Create file
sleep(.5);
print "Creating file from dbench\n";
print $createremotefile . "\n";
$result = `${createremotefile}`;
print $result;
sleep(.5);

##############################################################################
## unstable write test
##############################################################################

# Restart server
print "Restarting server\n";
$result = `${restartganesha}`;
print $result;

# Remove old traces
print "Removing old traces\n";
$result = `${removeremotetraces}`;
print $result . "\n";
$result = `${removelocaltraces}`;
print $result . "\n";

# Start new trace
print "Starting new trace\n";
print "${starttrace}\n";
$result = `${starttrace}`;
print $result . "\n";

# Unstable write to file
print "Executing unstable write\n";
print $nfs_unstable_write . "\n";
$result = `${nfs_unstable_write}`;
if ($result =~ /FAIL/) {
    print $result;
    exit 1;
}

# Stop new trace
sleep(1);
print "Stopping the trace\n";
print "${stoptrace}\n";
$result = `${stoptrace}`;
print $result . "\n";

# Retrieve the trace
print "Retrieving the trace\n";
print "${scptrace}\n";
$result = `${scptrace}`;
print $result . "\n";
$result = `cat ${local_tracedir}/*`;

# Search for write and fsync
if ($result =~ m/.*WRITE.*/) {
    if ($result =~ m/.*FSYNC.*/) {
	print "FAIL: GPFS registered a WRITE op with an FSYNC op after an unstable write request.\n";
	exit 1;
    } else {
	print "SUCCESS: GPFS registered a WRITE op without an FSYNC op.\n";
    }
} else {
    print "FAIL: GPFS did not register a WRITE op after an unstable write request.\n";
    exit 1;
}

##############################################################################
## commit test
##############################################################################

# Remove old traces
print "Removing old traces\n";
$result = `${removeremotetraces}`;
print $result . "\n";
$result = `${removelocaltraces}`;
print $result . "\n";

# Start new trace
print "Starting new trace\n";
print "${starttrace}\n";
$result = `${starttrace}`;
print $result . "\n";

# Unstable write to file
print "Executing commit\n";
print $nfs_commit . "\n";
$result = `${nfs_commit}`;
if ($result =~ /FAIL/) {
    print $result;
    exit 1;
}

# Stop new trace
sleep(1);
print "Stopping the trace\n";
print "${stoptrace}\n";
$result = `${stoptrace}`;
print $result . "\n";

# Retrieve the trace
print "Retrieving the trace\n";
print "${scptrace}\n";
$result = `${scptrace}`;
print $result . "\n";
$result = `cat ${local_tracedir}/*`;

# Search for fsync
if ($result =~ m/.*FSYNC.*/) {
    print "SUCCESS: GPFS registered an FSYNC op after a Commit request.\n";
    exit 1;
} else {
    print "FAIL: GPFS did not register an FSYNC op after a Commit request.\n";
}

##############################################################################
## stable test
##############################################################################


# Restart server
print "Restarting server\n";
$result = `${restartganesha}`;
print $result;

# Remove old traces
print "Removing old traces\n";
$result = `${removeremotetraces}`;
print $result . "\n";
$result = `${removelocaltraces}`;
print $result . "\n";

# Start new trace
print "Starting new trace\n";
print "${starttrace}\n";
$result = `${starttrace}`;
print $result . "\n";

# Unstable write to file
print "Executing stable write\n";
print $nfs_stable_write . "\n";
$result = `${nfs_stable_write}`;
if ($result =~ /FAIL/) {
    print $result;
    exit 1;
}

# Stop new trace
sleep(1);
print "Stopping the trace\n";
print "${stoptrace}\n";
$result = `${stoptrace}`;
print $result . "\n";

# Retrieve the trace
print "Retrieving the trace\n";
print "${scptrace}\n";
$result = `${scptrace}`;
print $result . "\n";
$result = `cat ${local_tracedir}/*`;

# Search for write and fsync
if ($result =~ m/.*WRITE.*/) {
    if ($result =~ m/.*FSYNC.*/) {
	print "SUCCESS: GPFS registered a WRITE op with an FSYNC op after a stable write request.\n";
	exit 1;
    } else {
	print "FAIL: GPFS registered a WRITE op without an FSYNC op after a stable write request.\n";
    }
} else {
    print "FAIL: GPFS did not register a WRITE op after a stable write request.\n";
    exit 1;
}

