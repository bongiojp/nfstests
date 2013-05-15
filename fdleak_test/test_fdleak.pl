#!/usr/bin/perl                                           

my $server = $ARGV[0];
my $exportdir = $ARGV[1];
my $mountdir = $ARGV[2];

# check if we have way too many file descriptors open
$result = `ssh ${server} "ps aux | grep /usr/bin/gpfs.ganesha.nfsd"`;
if ($result =~ /^root\s+(\d+)\s.*/) {
    $pid = $1;
} else {
    die "FAIL: Couldn't find pid of nfs process to check number of open fds.\n";
}

$result = `ssh ${server} "cat /etc/ganesha/gpfs.ganesha.main.conf"`;
if ($result =~ /.*Max_Fd\s*=\s*(\d+)\s*;.*/) {
    $maxfd = $1;
} else {
    die "FAIL: Couldn't find Max_Fd parameter in GPFS man config file.\n";
}

print "Pid of Ganesha: ${pid}\n";
print "Maximum fd's: ${maxfd}\n";
$result = `ssh ${server} "ls -l /proc/${pid}/fd | wc -l"`;
print "BEGINNING OF TEST -> Number of open fd's: ${result}\n";

$iterations = $maxfd*3;
for(0 .. ${iterations}) {
    open(FILE, ">${mountdir}/filelalala") or die "Can't open rename.c\n";
    print FILE "laaaaaaaalaaaaaaalaaaaaaa\n";
    close(FILE);
    `rm -f ${mountdir}/filelalala `;
}

$result = `ssh ${server} "ls -l /proc/${pid}/fd | wc -l"`;
print "END OF TEST -> Number of open fd's: ${result}\n";

if ($result > $maxfd) {
    print "FAIL: We accumulated more file descriptors than we should have.\n";
} else {
    print "SUCCESS: Normal amount of file descriptors at end of test.\n";
}
