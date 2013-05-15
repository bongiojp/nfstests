#!/usr/bin/perl

use Time::HiRes qw(gettimeofday);

if (@ARGV != 2) {
    print "Usage: $0 server dbenchdir\n";
    exit(0);
}

$server = $ARGV[0];
$dbenchdir = $ARGV[1];
$delay = 12;

print `ssh ${server} 'echo "Testing long running task with ${delay} second delay" > /var/log/messages'`;
print `ssh ${server} 'killall -HUP syslogd'`;

print "Setting debug levels\n";
print "snmpset -Os -c ganesha -v 1 sonas12 .1.3.6.1.4.1.12384.999.1.1.12.2.1\n";
print `snmpset -Os -c ganesha -v 1 sonas12 .1.3.6.1.4.1.12384.999.1.1.12.2.1`;
#setting up error injection
print "Injecting delay\n";
print "snmpset -Os -c ganesha -v 1 ${server} .1.3.6.1.4.1.12384.999.1.2.1.2.1 i ${delay}\n";
print `snmpset -Os -c ganesha -v 1 ${server} .1.3.6.1.4.1.12384.999.1.2.1.2.1 i ${delay}`;
print "Showing variable\n";
print "snmpwalk -Os -c ganesha -v 1 ${server} .1.3.6.1.4.1.12384.999.1.2.1\n";
print `snmpwalk -Os -c ganesha -v 1 ${server} .1.3.6.1.4.1.12384.999.1.2.1`;

sleep(.5);

print "Sending first NULL\n";
($ssec, $smsec) = gettimeofday();
$ret = `${dbenchdir}/comm_null ${server}`;
($esec, $emsec) = gettimeofday();
if ($ret =~ /FAIL/) {
    print $ret;
    exit 1;
}
$dsec = $esec - $ssec;
$dmsec = $emsec - $smsec;
if($dmsec < 0) {
	$dsec--;
	$dmsec += 1000000;
}
if ($dsec < $delay) {
	printf("FAIL: First NULL only took %d.%06d seconds\n", $dsec, $dmsec);
	exit 1;
} else {
	printf("First NULL took %d.%06d seconds\n", $dsec, $dmsec);
}

print "Sending second NULL\n";
($ssec, $smsec) = gettimeofday();
$ret = `${dbenchdir}/comm_null ${server}`;
($esec, $emsec) = gettimeofday();
if ($ret =~ /FAIL/) {
    print $ret;
    exit 1;
}
$dsec = $esec - $ssec;
$dmsec = $emsec - $smsec;
if($dmsec < 0) {
	$dsec--;
	$dmsec += 1000000;
}
if ($dsec > 5) {
	printf("FAIL: Second NULL took %d.%06d seconds\n", $dsec, $dmsec);
	exit 1;
} else {
	printf("Second NULL took %d.%06d seconds\n", $dsec, $dmsec);
}

sleep(1);

print "Showing variable\n";
print "snmpwalk -Os -c ganesha -v 1 ${server} .1.3.6.1.4.1.12384.999.1.2.1\n";
print `snmpwalk -Os -c ganesha -v 1 ${server} .1.3.6.1.4.1.12384.999.1.2.1`;

$log = `ssh ${server} grep second /var/log/messages`;
print $log;

@loglines = split(/\n/, $log);
if (@loglines != 4) {
	print "FAIL: wrong number of lines in log file\n";
	exit 1;
}

if ($loglines[0] =~ /Testing long running task with ${delay} second delay/) {
	print "Found first line of log file ok\n";
} else {
	print "FAIL: Missing first line of log file\n";
	exit 1;
}

if ($loglines[1] =~ /\[long_processing\] :DISPATCH: EVENT: Worker#\d+: Function nfs_Null has been running for (\d+).(\d{6}) seconds/) {
	if ($1 == 10 || $1 == 11) {
		printf("Long processing reported at %d.%06d seconds\n", $1, $2);
	} else {
		print "FAIL: long processing EVENT reported the wrong amount of time\n";
		exit 1;
	}
} else {
	print "FAIL: long processing EVENT missing\n";
	exit 1;
}

if ($loglines[2] =~ /\[worker#\d+\] :DISPATCH: EVENT: Function nfs_Null exited with status 0 taking (\d+).(\d{6}) seconds to process/) {
	if ($1 == $delay) {
		printf("Long processing took %d.%06d seconds\n", $1, $2);
	} else {
		print "FAIL: function took a long time EVENT reported the wrong amount of time\n";
		exit 1;
	}
} else {
	print "FAIL: function took a long time EVENT missing\n";
	exit 1;
}

if ($loglines[3] =~ /\[worker#\d+\] :DISPATCH: FULLDEBUG: Function nfs_Null exited with status 0 taking (\d+).(\d{6}) seconds to process/) {
	if ($1 == 0) {
		printf("Normal processing took %d.%06d seconds\n", $1, $2);
	} else {
		print "FAIL: function took time FULLDEBUG reported the wrong amount of time\n";
		exit 1;
	}
} else {
	print "FAIL: function took time FULLDEBUG missing\n";
	exit 1;
}

print "SUCCESS\n";
