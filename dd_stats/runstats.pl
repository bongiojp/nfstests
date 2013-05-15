#!/usr/bin/perl

my $WORKER=(8,16,32,64,128);
my @SIZE=(2,10,20);
my @DD=(1,2,3,4,5,10,15);
my $LOOP=1;

my $secondserver = "c42.stglabs.ibm.com";

`mkdir /mnt/temp/ddresults`;
foreach(@WORKER) {
    my $workerthr = $_;
    print "\n\n ---------------------------------- \n Testing ${workerthr} worker threads\n";
    `scp -P 1602 gpfs.ganesha.main.conf.${workerthr} 172.31.100.50:/etc/ganesha/gpfs.ganesha.main.conf`;
    `ssh -p 1602 172.31.100.50 /etc/init.d/nfs-ganesha-gpfs restart`;
    sleep 15;

    foreach(@SIZE) {
	my $mysize=$_;
	foreach(@DD) {
	    my $totdd = $_;
	    my $mydd_1 = $_;
	    my $mydd_2 = 0;
	    if ($_ > 1) {
		$mydd_1 = int($_/2);
		$mydd_2 = int($_/2) + $_ % 2;
	    }
	    foreach(1..$LOOP) {
		my $myloop = $_;
		my $output;
		
		if ($mydd_2 == 0) {
		    print "Creating /mnt/temp/ddresults/${mydd_1}dd.${mydd_1}thr.${workerthr}worker.${mysize}GB.${myloop}loop.1 ...\n";
		    `rm -rf /mnt/temp/dd/*`;
		    `perl ./rundd.pl ${mydd_1} ${mysize} /mnt/temp/dd/ &> /mnt/temp/ddresults/${mydd_1}dd.${workerthr}worker.${mysize}GB.${myloop}loop.1`;
		} else {
		    print "Creating /mnt/temp/ddresults/${totdd}dd.${mydd_1}thr.${workerthr}worker.${mysize}GB.${myloop}loop.1 ...\n";
		    print "Creating /mnt/temp/ddresults/${totdd}dd.${mydd_2}thr.${workerthr}worker.${mysize}GB.${myloop}loop.2 ...\n";
		    `rm -rf /mnt/temp/dd/*`;
		    `scp ./rundd.pl ${secondserver}:./`;
		    `perl ./rundd.pl ${mydd_1} ${mysize} /mnt/temp/dd/ &> /mnt/temp/ddresults/${totdd}dd.${mydd_1}thr.${workerthr}worker.${mysize}GB.${myloop}loop.1 &`;
		    `ssh ${secondserver} perl ./rundd.pl ${mydd_2} ${mysize} /mnt/temp/dd/ &> /mnt/temp/ddresults/${totdd}dd.${mydd_2}thr.${workerthr}worker.${mysize}GB.${myloop}loop.2`;
		    
		    $output = `ps aux | grep perl | grep dd`;
		    while($output =~ /.*rundd.pl.*/) {
			print "Waiting for local rundd.pl processes to finish.\n";
			sleep(20);
			$output = `ps aux | grep perl | grep dd`;
			print "ps result: ${output}\n";
		    }
		    
		}
	    }
	}
    }
}
