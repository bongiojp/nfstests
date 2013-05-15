#!/usr/bin/perl

if (@ARGV != 3) {
    print "Usage: $0 server exportdir dbenchlocation\n";
    exit(0);
}

my $server = $ARGV[0];
my $exportdir = $ARGV[1];
my $dbenchdir = $ARGV[2];
my $testdir = "readdirplus_test";

$result = `ssh root\@${server} mkdir ${exportdir}/${testdir} 2>&1`;
$result = `ssh root\@${server} "for i in 1 2 3 4 5 a b c d e foo bar tea time a1r1gh7 ; do touch ${exportdir}/${testdir}/\\\$i ; done" 2>&1`;
$result = `ssh root\@${server} "for i in 8 9 10 z y z ; do mkdir ${exportdir}/${testdir}/\\\$i ; done" 2>&1`;
$result = `${dbenchdir}/comm_readdirplus ${server} ${exportdir} /${testdir} 2>&1`;

@lines = split(/\n/, $result);
my $filename;
my $fhandle;
my $count=0;
my $filecount=0;

my $pass=0;
my $fail=0;

foreach(@lines) {
    $count++;

    if ($_ =~ m/filename:\s(.+).*/) {
	$filename = $1;
	$count = 0;
    }
    elsif ($_ =~ m/filehandle:\s(.+).*/) {
	if ($count > 1) {
	    print "FAIL: Could not complete LOOKUP request for /${testdir}:\n $result2\n";
	    $fail++;
	    next;
	}
	$filecount++;
	$filehandle = $1;
	chomp($filename);
	chomp ($filehandle);

	my $result2 = `${dbenchdir}/comm_lookup ${server} ${exportdir} ${filename} 2>&1`;
	print "${dbenchdir}/comm_lookup ${server} ${exportdir} ${filename} 2>&1\n";
	print "READDIRPLUS: $filehandle\n";

	if ($filehandle =~ /^\0+$/) {
	    print "FAIL: Invalid file handle from READDIRPLUS\n";
	    $fail++;
	    next;
	}

	my @lines2 = split(/\n/, $result2);
	my $filename2;
	my $filehandle2;
	if ($lines2[0] =~ m/filename:\s(.+).*/) {
	    $filename2 = $1; chomp($filename2);
	    if ($lines2[1] =~ m/filehandle:\s(.+).*/) {
		$filehandle2 = $1; chomp($filehandle2);
		print "LOOKUP: $filehandle2\n";
		if ( ! ($filehandle2 eq $filehandle) ) {
		    print "FAIL: The filehandles reported by LOOKUP and READDIRPLUS are not the same for ${filename}\n";
		    $fail++;
		    next;
		}
	    } else {
		print "FAIL: Could not complete LOOKUP request for /${testdir}:\n $result2\n";
		$fail++;
		next;
	    }
	} else {
	    print "FAIL: Could not complete LOOKUP request for /${testdir}:\n $result2\n";
	    $fail++;
	    next;
	}
    }
    $pass++;
}

print $pass . "/" . ($pass + $fail) . " tests succeeded.\n";


