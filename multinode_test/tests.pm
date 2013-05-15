package tests;

use strict;
use warnings;
use Time::HiRes qw( usleep );

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
$PASS $FAIL $TRUE $FALSE
test_createdestroy_loop
test_symlink_loop             clean_symlink_loop
test_manysymlink_loop
test_unittest_1 
test_unittest_2 
test_unittest_3 
test_unittest_4 
test_unittest_5 
test_unittest_6 
test_fvt_1
test_fvt_2
test_fvt_3
test_fvt_4

) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
&test_createdestroy_loop
&test_symlink_loop           &clean_symlink_loop
&test_manysymlink_loop
&test_unittest_1
&test_unittest_2
&test_unittest_3
&test_unittest_4
&test_unittest_5
&test_unittest_6
&test_fvt_1
&test_fvt_2
&test_fvt_3
&test_fvt_4
);
our $VERSION = '0.01';

# Exported global variables
our $PASS = 1;
our $FAIL = 0;
our $TRUE = 1;
our $FALSE = 0;
our $UNITTEST_ITERS = 5;

# In a multinode cluster setting, a change on one server has to propagate to
# other servers. There is some delay in this propagation, so for a certain
# period of time servers will be inconsistent. To deal with this case we
# retry a failed request.
our $MAX_RETRY = 5;

sub rand_str {
    my $len = shift(@_);
    my @chars=('a'..'z','A'..'Z','0'..'9','_');
    my $str;
    foreach (1..$len) { $str.=$chars[rand @chars]; }
    return $str;
}

sub comm_retry($$) {
    my ($command, $err_noent) = @_;
    my $retry = $MAX_RETRY;
    my $result;

    while($retry) {
        $result = `${command} 2>&1`;
        if ($result =~ m/.*Stale.*/i) {
            print "\tWARNING: Stale file handle, retrying ...\n";
            $retry--; next;
        }
	if ($result =~m/.*No\ssuch\sfile\sor\sdirectory.*/i
	    && $err_noent) {
	    print "\tWARNING: File not found by server, retrying ...\n";
	    $retry--; next;
	}
        if ($result) {
            print "RESULT: ${result}\n";
            return $FAIL;
        }
        last;
    }
    if ($retry == 0) {
        print "RESULT: ${result}\n";
        return $FAIL;
    }
    return $PASS;
}

# Export functions

# make file, check file exists everywhere
# destroy file, check if file is destroyed everywhere
sub test_createdestroy_loop(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    my $counter = 0;
    my $testdir = "createdestroy_test";

    print "CREATE/DESTROY TEST COMMENCING ... \n";

    print "\tMaking test directory\n";
    `mkdir ${mountdirs[0]}/$testdir`;

    foreach my $changenode(@mountdirs) {
        my $testfile = "test_createdestroy." . rand_str(10);
        # make change
        
        print "\tCreating file ${changenode}/${testdir}/${testfile}\n";
        if (! open(FILE, ">${changenode}/${testdir}/${testfile}")) {
            print "FAIL: Could not open ${changenode}/${testdir}/${testfile}\n";
            return $FAIL;
        }
        print FILE "blah.${testfile}";
        close(FILE);
        
        foreach my $detectnode(@mountdirs) {
            my $input;
            
            print "\tReading file from ${detectnode}/${testdir}\n";
            
            # test change
            if (! open(READFILE, "<${detectnode}/${testdir}/${testfile}")) {
                print "FAIL: Could not open ${detectnode}/${testdir}/${testfile}\n";
                return $FAIL;
            }
            
            $input = <READFILE>;
            # is file created and conain the correct string?
            if (! ($input =~ /blah\.${testfile}\s*/)) {
                print "FAIL: Wrong contents in file ${detectnode}/${testdir}/${testfile}\n";
                print "Read: ${input}\n";
                return $FAIL;
            }

            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                $atime,$mtime,$ctime,$blksize,$blocks)
                = stat("${detectnode}/${testdir}/${testfile}");
        print "stat: dev=$dev ino=$ino mode=$mode nlink=$nlink uid=$uid gid=$gid\n";
            close(READFILE);
        }
        #sleep(1);
        print "\tUnlinking file: ${changenode}/${testdir}/${testfile}\n";
        if (! unlink("${changenode}/${testdir}/${testfile}")) {
            print "FAIL: Could not unlink file ${changenode}/${testdir}/${testfile}\n";
            return $FAIL;
        }
        
        foreach my $detectnode(@mountdirs) {
            my $input;
            
            print "\tChecking if file deleted from ${detectnode}/${testdir}\n";
            
            # test change
            foreach (0 .. $MAX_RETRY) {
                my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                    $atime,$mtime,$ctime,$blksize,$blocks)
                    = stat("${detectnode}/${testdir}/${testfile}");
                if ($ino) {
                    print "\tstat: dev=$dev ino=$ino mode=$mode nlink=$nlink uid=$uid gid=$gid\n";
                    print "\tFile that should be deleted: ${detectnode}/${testdir}/${testfile}\n";
                    if ($_ == $MAX_RETRY) { return $FAIL; }
                    else { print "\tRetrying NFS request.\n"; }
                }
            }
        }
        $counter++;
    }

    print "CREATE/DESTROY TEST COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# make symlink, check symlink exists everywhere
sub test_symlink_loop(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    my $counter = 0;

    print "SYMLINK TEST COMMENCING ... \n";
    foreach my $changenode(@mountdirs) {
        my $symlink;
        my $symsymlink;
        my $testfile;

        $testfile = "${changenode}/test_symlink_loop." . rand_str(10);;
        $symlink = "${testfile}.symlink";
        $symsymlink = "${testfile}.symsymlink";
        foreach(1 .. 100) {        
            if (! open(FILE, ">${testfile}")) {
                print "FAIL: Could not open ${testfile}\n";
                return $FAIL;
            }
            print FILE "s";
            close(FILE);
            if (! symlink($testfile, $symlink)) {
                print "FAIL: Could not create symlink of ${testfile}\n";
                return $FAIL;
            }
            if (! symlink($symlink, $symsymlink)) {
                print "FAIL: Could not create symlink of symlink ${symlink}\n";
                return $FAIL;
            }        
            
            if (! unlink("${symsymlink}")) {
                print "FAIL: Could not unlink ${symsymlink}\n";
                return $FAIL;
            }
            
  
            if (! unlink("${testfile}")) {
                print "FAIL: Could not unlink ${symsymlink}\n";
                return $FAIL;
            }
            
            if (! unlink("${symlink}")) {
                print "FAIL: Could not unlink ${symsymlink}\n";
                return $FAIL;
            }
        }

        print "\tpreparing file to symlink\n";
        if (! open(FILE, ">${testfile}")) {
            print "FAIL: Could not open ${testfile}\n";
            return $FAIL;
        }
        print FILE "symlink test";
        close(FILE);
        
        print "\tCreating symlink of ${testfile}\n";
        if (! symlink($testfile, $symlink)) {
            print "FAIL: Could not create symlink of ${testfile}\n";
            return $FAIL;
        }

        print "\tCreating symlink of symlink ${symlink}\n";
        if (! symlink($symlink, $symsymlink)) {
            print "FAIL: Could not create symlink of symlink ${symlink}\n";
            return $FAIL;
        }        
        
        foreach my $detectnode(@mountdirs) {
            my $testfile_read;
            my $symlink_read;
            my $symsymlink_read;

            print "\tReading from file ${testfile}, symlink ${symlink}, symsymlink ${symsymlink}\n";
            if (! open(SYMSYMLINK, "<${symsymlink}")) {
                print "FAIL: Could not open symlink ${symsymlink}\n";
                return $FAIL;
            }
            if (! open(SYMLINK, "<${symlink}")) {
                print "FAIL: Could not open symlink ${symlink}\n";
                return $FAIL;
            }
            if (! open(TESTFILE, "<${symlink}")) {
                print "FAIL: Could not open file ${testfile}\n";
                return $FAIL;
            }

            print "\tComparing contents of files and symlinks\n";
            $symsymlink_read = <SYMSYMLINK>;
            $symlink_read = <SYMLINK>;
            $testfile_read = <TESTFILE>;

            if (! $symsymlink_read eq $symlink_read) {
                print "FAIL: ${symsymlink} does not have same contents of ${symlink}\n";
                return $FAIL;
            }

            if (! $symlink_read eq $testfile_read) {
                print "FAIL: ${symlink} does not have same contents of ${testfile}\n";
                return $FAIL;
            }

            close(SYMSYMLINK);
            close(SYMLINK);
            close(TESTFILE);
        }

        print "\tUnlinking symlink: ${symlink} \n";
        if (! unlink("${symlink}")) {
            print "FAIL: Could not unlink\n";
            return $FAIL;
        }
        foreach my $detectnode(@mountdirs) {
            print "\tChecking if file is accessible through ${symsymlink} from ${detectnode}\n";
            if (open(READFILE, "<${symlink}")) {
                print "FAIL: Opened a symlink that should be deleted: ${symlink}\n";
                return $FAIL;
            }

#            if (! open(READFILE, "<${symsymlink}")) {
#                print "FAIL: Opened a symlink that should be disconnected: ${symsymlink}\n";
#                return $FAIL;
#            }
        }

        if (! unlink("${symsymlink}")) {
            print "FAIL: Could not unlink ${symsymlink}\n";
            return $FAIL;
        }
        if (! unlink("${testfile}")) {
            print "FAIL: Could not unlink ${symsymlink}\n";
            return $FAIL;
        }
        $counter++;
    }

    print "SYMLINK TEST COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

sub clean_symlink_loop(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    my $counter = 0;

    my $changenode = $mountdirs[0];

    print "CLEANING ENVIRONMENT FOR SYMLINK TEST ...\n";
    foreach(@mountdirs) {
        my $testfile = "${changenode}/test1.${counter}";
        my $symlink = "${testfile}.symlink";
        my $symsymlink = "${testfile}.symsymlink";
        
        unlink("${symsymlink}");
        unlink("${symlink}");
        unlink("${testfile}");
        $counter++;
    }
    print "FINISHED CLEANING ENVIRONMENT FOR SYMLINK TEST ...\n";
    return $PASS;
}

# Many symlinks test ? Actually this isn't many symlinks at once.
# This test helped narrow down conditions for symlink error 
# in specsfs.
sub test_manysymlink_loop(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    my $counter = 0;
    my $iter = 100;

    print "MANY SYMLINK TEST COMMENCING ... \n";
    foreach my $changenode(@mountdirs) {
        my $symlink;
        my $symsymlink;
        my $testfile = "${changenode}/test3.*";

        if (! comm_retry("rm -f ${testfile}", $FALSE)) {
            print "WARNING: Could not delete file ${testfile}.";
        }

        foreach(1 .. $iter) {
            $testfile = "${changenode}/test_manysymlink." . rand_str(10);
            $symlink = "${testfile}.symlink";
            $symsymlink = "${testfile}.symsymlink";

            if (! ($_%20)) {
                print ".";
            }

            `touch ${testfile}`;
            if (! symlink($testfile, $symlink)) {
                print "FAIL: Could not create symlink of ${testfile} 1\n";
                return $FAIL;
            }
            if (! symlink($symlink, $symsymlink)) {
                print "FAIL: Could not create symlink of symlink ${symlink} 2\n";
                return $FAIL;
            }        
            if (! unlink("${symlink}")) {
                print "FAIL: Could not unlink ${symsymlink} 3\n";
                return $FAIL;
            }

            if (! symlink($testfile, $symlink)) {
                print "FAIL: Could not create symlink of testfile ${testfile} 4\n";
                return $FAIL;
            }            
            if (! unlink("${symlink}")) {
                print "FAIL: Could not unlink ${symsymlink} 5\n";
                return $FAIL;
            }
            if (! symlink($symsymlink, $symlink)) {
                print "FAIL: Could not create symlink of symlink ${symsymlink} 6\n";
                return $FAIL;
            }            
            if (! unlink("${testfile}")) {
                print "FAIL: Could not unlink ${testfile} 7\n";
                return $FAIL;
            }
            if (! symlink($symsymlink, $testfile)) {
                print "FAIL: Could not create symlink of symlink ${symsymlink} 8\n";
                return $FAIL;
            }            

            # clean up
            if (! unlink("${symsymlink}")) {
                print "FAIL: Could not unlink ${symsymlink}\n";
                return $FAIL;
            }
            if (! unlink("${testfile}")) {
                print "FAIL: Could not unlink ${symsymlink}\n";
                return $FAIL;
            }
            if (! unlink("${symlink}")) {
                print "FAIL: Could not unlink ${symsymlink}\n";
                return $FAIL;
            }
        }
    }
    print "\n${iter} symlink ops completed\n";
    print "MANY SYMLINK TEST COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# Look to cache\ invalidate\ design.odt document written by Lance Russell
# test 1: touch file, make sure it appears
sub test_unittest_1(\@\@$$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir, $usessh) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;

    my $testdir  = "unittest1";
    my $iter = $UNITTEST_ITERS;
    my $result;

    print "CACHE INVALIDATE UNIT TEST 1 COMMENCING ... \n";
    foreach my $detectnode(@mountdirs) {
        foreach my $changenode(@mountdirs) {
	    if ($detectnode eq $changenode) {next;}
	    print "\n\tDetect node: ${detectnode}\n";
	    print "\tChange node: ${changenode}\n";

            if (! comm_retry("rm -rf ${detectnode}/${testdir}", $FALSE)) {
                print "WARNING: Could not delete directory ${detectnode}/${testdir}.";
            }
	    `rm -rf ${detectnode}/${testdir}`;
	    `rm -rf ${detectnode}/${testdir}`;
#u#sleep(500000);            
            if (! comm_retry("mkdir -p ${detectnode}/${testdir}", $FALSE)) {
                print "FAIL: Could not create directory ${detectnode}/${testdir}.\n";
		return $FAIL;
            }
                    #u#sleep(1500000);
            foreach(1 .. $iter) {
                my $testfile = "unittest1." . rand_str(10);
                $result = `ls -sail ${detectnode}/${testdir}`;
                
                # check if file is already there
                if ($result =~ /.*${testfile}\s*/) {
                    print "FAIL: We found the ${detectnode}/${testdir}/${testfile} before we created the file\n";
                    return $FAIL;
                }
                
                if ($usessh) {
                    print "\tssh ${nodes[0]} touch ${exportdir}/${testdir}/${testfile}\n";
                    $result = `ssh ${nodes[0]} touch ${exportdir}/${testdir}/${testfile} 2>&1`;
                    
                    # Check if ssh command succeeded.
                } else {
		    print "\ttouch ${changenode}/${testdir}/${testfile}\n";
                    if (! comm_retry("touch ${changenode}/${testdir}/${testfile}", $TRUE)) {
			print "FAIL: Could not create file ${changenode}/${testdir}/${testfile}.\n";
			return $FAIL;
		    }
                }

                #u#sleep(50000);
                $result = `ls -sail ${detectnode}/${testdir}`;
                print "\tLooking for ${testfile} on detect node.\n";
                # Test to see if file appears
                if (! ($result =~ /${testfile}\s*/)) {
		    $result = `ls -sail ${detectnode}/${testdir}`;
		    if (! ($result =~ /${testfile}\s*/)) {
			print "ls -sail results: ${result}\n";
			print "FAIL: We did not find the file ${detectnode}/${testdir}/${testfile} that we just created from the server side.\n";
			return $FAIL;
		    }
                }            
            }
        }
    }
    print "CACHE INVALIDATE UNIT TEST 1 COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# test 2: Set mode bits over ssh on server, check mode bits are reflected through ganesha.
sub test_unittest_2(\@\@$$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir, $usessh) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;

    my $testdir  = "unittest2";
    my $iter = $UNITTEST_ITERS;
    my $result;

    print "CACHE INVALIDATE UNIT TEST 2 COMMENCING ... \n";
    foreach my $detectnode(@mountdirs) {
        foreach my $changenode(@mountdirs) {
	    if ($detectnode eq $changenode) {next;}            

            if (! comm_retry("rm -rf ${detectnode}/${testdir}", $FALSE)) {
                print "WARNING: Could not delete directory ${detectnode}/${testdir}.";
            }
            
            if (! comm_retry("mkdir -p ${detectnode}/${testdir}", $FALSE)) {
                print "FAIL: Could not create directory ${detectnode}/${testdir}.\n";
                return $FAIL;
            }
        #u#sleep(1500000);            
            foreach(1 .. $iter) {
                my $testfile = "unittest2." . rand_str(10);
                # Create the file, later we change the mode bits.
                `touch ${detectnode}/${testdir}/${testfile}`;
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                # check if file is already there
                if (! ($result =~ /${testfile}\s*/)) {
                    print "FAIL: We did not find the ${detectnode}/${testdir}/${testfile} we just created.\n";
                    return $FAIL;
                }
                
                if ($usessh) {
                    print "\tssh ${nodes[0]} chmod 777 ${exportdir}/${testdir}/${testfile}\n";
                    $result = `ssh ${nodes[0]} chmod 777 ${exportdir}/${testdir}/${testfile} 2>&1`;
                    
                    # Check if ssh command succeeded.
                } else {
                    `chmod 777 ${changenode}/${testdir}/${testfile} 2>&1`;
                }
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                print "\tLooking for ${testfile} on client side.\n";
                # Test to see if file appears
                if (! ($result =~ /.*\s-rwxrwxrwx\s.*${testfile}.*/)) {
                    print "ls -sail results: ${result}\n";
                    print "FAIL: The file ${detectnode}/${testdir}/${testfile} did not have the expected mode bits of 0777.\n";
                    return $FAIL;
                }            
            }
        }
    }
    print "CACHE INVALIDATE UNIT TEST 2 COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# test 3: write to file over scp, make sure file appears in ganesha w/ proper size.
sub test_unittest_3(\@\@$$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir, $usessh) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    
    my $testdir  = "unittest3";
    my $iter = $UNITTEST_ITERS;
    my $result;
    
    print "CACHE INVALIDATE UNIT TEST 3 COMMENCING ... \n";
    foreach my $detectnode(@mountdirs) {
        foreach my $changenode(@mountdirs) {
	    if ($detectnode eq $changenode) {next;}            
        
            print "\tTesting by making changes on node ${detectnode}.\n";
            if (! comm_retry("rm -rf ${detectnode}/${testdir}", $FALSE)) {
                print "WARNING: Could not delete directory ${detectnode}/${testdir}.";
            }
            
            if (! comm_retry("mkdir -p ${detectnode}/${testdir}", $FALSE)) {
                print "FAIL: Could not create directory ${detectnode}/${testdir}.\n";
                return $FAIL;
            }
        #u#sleep(1500000);            
            foreach(1 .. $iter) {
                my $testfile = "unittest2." . rand_str(10);
                # Create the file, later we change the mode bits.
                `touch ${detectnode}/${testdir}/${testfile}`;
                
                # Check if file is already there
                $result = `ls -sail ${detectnode}/${testdir}`;
                if (! ($result =~ /${testfile}\s*/)) {
                    print "FAIL: We did not find the ${detectnode}/${testdir}/${testfile} we just created.\n";
                    return $FAIL;
                }
                
                if ($usessh) {
                    # Make a change on server
                    print "\tscp /etc/hosts ${nodes[0]}:${exportdir}/${testdir}/${testfile}\n";
                    $result = `scp /etc/hosts ${nodes[0]}:${exportdir}/${testdir}/${testfile}`;
                    
                    # Check if ssh command succeeded.
                } else {
		    print "\tCopying /etc/hosts file to ${changenode}/${testdir}/${testfile}.\n";
                    `cp /etc/hosts ${changenode}/${testdir}/${testfile}`;
                }
                # Check if the change is detectable on client
                $result = `ls -sail ${detectnode}/${testdir}`;
                print "\tLooking for ${detectnode}/${testdir}/${testfile}\n";
                
                # Test to see if file's size changed
                # EXAMPLE: 102161  8 -rw-r--r--   1    root root  685  2012-01-09 04:36 unittest2.BWV9RsEFs_
                           #21193  4 -rw-r--r--   1    root root  685  2012-01-05 14:30 /etc/hosts
		my @lines = split(/\n/, $result);
		my $remote_filesize = 0;

		# Now we parse through each line returned from ls looking
		# for the file we want. Then we parse through each element
		# in that line to find the file size.
		foreach(@lines) {
		    if ($_ =~ /.*${testfile}.*/) {
			my @parts = split(/\s+/, $_);
			my $numroot = 0;
			foreach(@parts) {
			    if ($numroot == 2) { $remote_filesize = $_;	last; }
			    elsif ($_ eq "root") { $numroot++; }
			}
			last;
		    }
		}

                if ($remote_filesize) {                    
                    # Get size of /etc/hosts file
                    my $result2 = `ls -sail /etc/hosts`;
		    # 21193 4 -rw-r--r-- 1 root root 685 2012-01-05 14:30 /etc/hosts
		    my @parts2 = split(/ /, $result2);
		    if ($parts2[6]) {
                        my $local_filesize = $parts2[6];
                        if ($remote_filesize != $local_filesize) {
                            print "FAIL: The file ${detectnode}/${testdir}/${testfile} did not have the same number of bytes as the local file /etc/hosts. Should be ${local_filesize} bytes but it was ${remote_filesize} bytes.\n";
                        }
                    } else {
                        print "ls -sail results: ${result2}\n";
                        print "FAIL: Could not parse the results\n";
                        return $FAIL;
                    }
                } else {
                    print "ls -sail results: ${result}\n";
                    print "FAIL: Could not parse the results\n";
                    return $FAIL;
                }
            }
        }
    }
    print "CACHE INVALIDATE UNIT TEST 3 COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# test 4: Create a hard link over ssh on server, check that the new hardlink
# stats are the exact same as the original filename.
sub test_unittest_4(\@\@$$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir, $usessh) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;

    my $testdir  = "unittest4";
    my $iter = $UNITTEST_ITERS;
    my $result;

    print "CACHE INVALIDATE UNIT TEST 4 COMMENCING ... \n";
    foreach my $detectnode(@mountdirs) {
        foreach my $changenode(@mountdirs) {
	    if ($detectnode eq $changenode) {next;}            

            if (! comm_retry("rm -rf ${detectnode}/${testdir}", $FALSE)) {
                print "WARNING: Could not delete directory ${detectnode}/${testdir}.";
            }
            
            if (! comm_retry("mkdir -p ${detectnode}/${testdir}", $FALSE)) {
                print "FAIL: Could not create directory ${detectnode}/${testdir}.\n";
                return $FAIL;
            }
        #u#sleep(1500000);            
            foreach(1 .. $iter) {
                my $testfile = "unittest4." . rand_str(10);
                my $testlink = "${testfile}.link";
                # Create the file, later we change the mode bits.
                `touch ${detectnode}/${testdir}/${testfile}`;
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                # check if file is already there
                if (! ($result =~ /.*${testfile}.*/)) {
                    print "FAIL: We did not find the ${detectnode}/${testdir}/${testfile} we just created.\n";
                    return $FAIL;
                }
                if ($result =~ /.*${testlink}.*/) {
                    print "FAIL: We found the ${detectnode}/${testdir}/${testlink} before we created it.\n";
                    return $FAIL;                
                }
                
                if ($usessh) {
                    print "\tssh ${nodes[0]} ln ${exportdir}/${testdir}/${testfile} ${exportdir}/${testdir}/${testlink}\n";
                    $result = `ssh ${nodes[0]} ln ${exportdir}/${testdir}/${testfile} ${exportdir}/${testdir}/${testlink} 2>&1`;
                    
                    # Check if ssh command succeeded.
                    if ($result) {
                        
                    }
                } else {
                    print "\tln ${changenode}/${testdir}/${testfile} ${changenode}/${testdir}/${testlink} 2>&1\n";
                    `ln ${changenode}/${testdir}/${testfile} ${changenode}/${testdir}/${testlink} 2>&1`;
                }
                $result = `ls -sail ${detectnode}/${testdir}`;
		#ls -sail results: total 32
		#5809  0 drwxr-xr-x 2 root root   512 May  9  2012 .
		#3 32 drwxr-xr-x 9 root root 32768 May  9 18:03 ..
		#5811  0 -rw-r--r-- 2 root root     0 May  9 18:03 unittest4.HSFREHayJB
		#5811  0 -rw-r--r-- 2 root root     0 May  9 18:03 unittest4.HSFREHayJB.link
		#5812  0 -rw-r--r-- 2 root root     0 May  9 18:03 unittest4.SEgtNF0iXw
		#5812  0 -rw-r--r-- 2 root root     0 May  9 18:03 unittest4.SEgtNF0iXw.link

                print "\tLooking for ${testfile} on client side.\n";
		my @lines = split(/\n/, $result);
		my $testfile_modebits;
		my $testlink_modebits;
		foreach(@lines) {
		    if ($_ =~ /.*${testfile}.*/) {
			my @data = split(/\s+/, $_);
			$testfile_modebits = @data[2];
		    }
		    if ($_ =~ /.*${testlink}.*/) {
			my @data = split(/\s+/, $_);
			$testlink_modebits = @data[2];
		    }
		}
		if (! $testfile_modebits) {
		    print "ls -sail results: ${result}\n";
		    print "FAIL: The test file ${testfile} was not found in the directory list results.\n";
                    return $FAIL;
		}
		if (! $testlink_modebits) {
		    print "ls -sail results: ${result}\n";
		    print "FAIL: The test file ${testlink} was not found in the directory list results.\n";
                    return $FAIL;
		}

                print "\tLooking for ${testlink} on client side and comparing with ${testfile}.\n";
                # Test to see if file appears
                if (! ($testlink_modebits eq $testfile_modebits)) {
                    print "ls -sail results: ${result}\n";
                    print "FAIL: The symlink ${detectnode}/${testdir}/${testlink} did not have the same mode bits as ${testfile}.\n";
		    print "FAIL: Parsed modebits don't match: testlink:$testlink_modebits, testfile:$testfile_modebits\n";
                    return $FAIL;
                }            
            }
        }
    }
    print "CACHE INVALIDATE UNIT TEST 4 COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# test 5: Create symlink over ssh on server, check file is seen in ganesha and
# actually a symlink
sub test_unittest_5(\@\@$$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir, $usessh) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;

    my $testdir  = "unittest5";
    my $iter = $UNITTEST_ITERS;
    my $result;

    print "CACHE INVALIDATE UNIT TEST 5 COMMENCING ... \n";
    foreach my $detectnode(@mountdirs) {
        foreach my $changenode(@mountdirs) {
	    if ($detectnode eq $changenode) {next;}            
            if (! comm_retry("rm -rf ${detectnode}/${testdir}", $FALSE)) {
                print "WARNING: Could not delete directory ${detectnode}/${testdir}.";
            }
            
            if (! comm_retry("mkdir -p ${detectnode}/${testdir}", $FALSE)) {
                print "FAIL: Could not create directory ${detectnode}/${testdir}.\n";
                return $FAIL;
            }
        #u#sleep(1500000);            
            foreach(1 .. $iter) {
                my $testfile = "unittest5." . rand_str(10);
                my $testlink = "${testfile}.link";
                # Create the file, later we change the mode bits.
                `touch ${detectnode}/${testdir}/${testfile}`;
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                # check if file is already there
                if (! ($result =~ /.*${testfile}.*/)) {
                    print "FAIL: We did not find the ${detectnode}/${testdir}/${testfile} we just created.\n";
                    return $FAIL;
                }
                if ($result =~ /.*${testlink}.*/) {
                    print "FAIL: We found the ${detectnode}/${testdir}/${testlink} before we created it.\n";
                    return $FAIL;                
                }
                
                if ($usessh) {
                    print "\tssh ${nodes[0]} ln -s ${exportdir}/${testdir}/${testfile} ${exportdir}/${testdir}/${testlink}\n";
                    $result = `ssh ${nodes[0]} ln -s ${exportdir}/${testdir}/${testfile} ${exportdir}/${testdir}/${testlink} 2>&1`;
                    
                    # Check if ssh command succeeded.
                    if ($result) {
                        
                    }
                } else {
                    `ln -s ${changenode}/${testdir}/${testfile} ${changenode}/${testdir}/${testlink} 2>&1`;
                }
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                print "\tLooking for ${testfile} on client side.\n";
                
                # Test to see if new link appears, is a link, and has the exact same
                # mode bits as the original file.
                if (! ($result =~ /.*\slrwxrwxrwx\s.*${testlink}.*/)) {
                    print "ls -sail results: ${result}\n";
                    print "FAIL: The symlink ${detectnode}/${testdir}/${testlink} did not have a symlink's mode bits.\n";
                    return $FAIL;
                }
                
            }
        }
    }
    print "CACHE INVALIDATE UNIT TEST 5 COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

# test 6: remove file through ssh on server, check if file still appears on client.
sub test_unittest_6(\@\@$$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir, $usessh) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;

    my $testdir  = "unittest6";
    my $iter = $UNITTEST_ITERS;
    my $result;

    print "CACHE INVALIDATE UNIT TEST 6 COMMENCING ... \n";
    foreach my $detectnode(@mountdirs) {
        foreach my $changenode(@mountdirs) {
	    if ($detectnode eq $changenode) {next;}            
            if (! comm_retry("rm -rf ${detectnode}/${testdir}", $FALSE)) {
                print "WARNING: Could not delete directory ${detectnode}/${testdir}.";
            }
            
            if (! comm_retry("mkdir -p ${detectnode}/${testdir}", $FALSE)) {
                print "FAIL: Could not create directory ${detectnode}/${testdir}.\n";
                return $FAIL;
            }
        #u#sleep(1500000);            
            foreach(1 .. $iter) {
                my $testfile = "unittest6." . rand_str(10);
                my $testlink = "${testfile}.link";
                # Create the file, later we change the mode bits.
                `touch ${detectnode}/${testdir}/${testfile}`;
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                # check if file is already there
                if (!($result =~ /.*${testfile}.*/)) {
                    print "FAIL: We did not find the ${detectnode}/${testdir}/${testfile} we just created.\n";
                    return $FAIL;
                }
                
                if ($usessh) {
                    print "\tssh ${nodes[0]} rm ${exportdir}/${testdir}/${testfile} \n";
                    $result = `ssh ${nodes[0]} rm ${exportdir}/${testdir}/${testfile} 2>&1`;
                    # Check if ssh command succeeded.
                    if ($result) {
                        
                    }
                } else {
                    $result = `rm ${changenode}/${testdir}/${testfile} 2>&1`;
                }
                
                $result = `ls -sail ${detectnode}/${testdir}`;
                print "\tLooking for ${testfile} on client side.\n";
                # Test to see if file appears and is a link (not a symbolic link)
                if ($result =~ /.*${testfile}.*/) {
                    print "ls -sail results: ${result}\n";
                    print "FAIL: The file ${detectnode}/${testdir}/${testfile} is still present after being deleted on server side.\n";
                    return $FAIL;
                }            
            }
        }
    }
    print "CACHE INVALIDATE UNIT TEST 6 COMPLETED SUCCESSFULLY \n\n";
    return $PASS;
}

sub test_fvt_1(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
        my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    foreach(@mountdirs) { print "${_}\n" }
    return $PASS;
}

sub test_fvt_2(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
        my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    foreach(@mountdirs) { print "${_}\n" }
    return $PASS;
}

sub test_fvt_3(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    foreach(@mountdirs) { print "${_}\n" }
    return $PASS;
}

sub test_fvt_4(\@\@$) {
    my ($mountdirs_ref, $nodes_ref, $exportdir) = @_;
    my @mountdirs = @$mountdirs_ref;
    my @nodes = @$nodes_ref;
    foreach(@mountdirs) { print "${_}\n" }
    return $PASS;
}

1;

__END__
