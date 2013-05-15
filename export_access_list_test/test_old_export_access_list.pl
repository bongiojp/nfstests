#!/usr/bin/perl -w

# It is assumed that we are testing when Ganesha has Commits enabled
# and is not using the ganesha write buffer.

use Fcntl;
use strict;

if (@ARGV < 3) {
    print "Usage: $0 server exportdir /filename\n";
    exit(0);
}

my $USERNAME = "hudson";

# arguements
my $server = $ARGV[0];
my $exportdir = $ARGV[1];
my $filename = $ARGV[2];
my $mountdir = "/mnt/exportaccess_mnt";
my $testfile_name = "export_access_testfile";
my $testfile = "${mountdir}/${testfile_name}";
my $perm_localconfigfile = "./gpfs.ganesha.exports.conf";
my $new_localconfigfile = "./gpfs.ganesha.exports.conf.new";

# commands
my $scpconfigfile = "scp ${new_localconfigfile} root\@${server}:/etc/ganesha/gpfs.ganesha.exports.conf 2>&1";
my $unmount = "sudo umount -l ${mountdir} 2>&1";
my $mount = "sudo mount -t nfs -o proto=tcp,noac,vers=3 ${server}:${exportdir} ${mountdir} 2>&1";
my $reset_remote_file = "ssh root\@${server} \"echo abc > ${exportdir}/${testfile_name}\" 2>&1";
my $reset_remote_file_pt2 = "ssh root\@${server} chown ${USERNAME} ${exportdir}/${testfile_name} && chmod 0755 ${exportdir}/${testfile_name} 2>&1";
my $restart_ganesha = "ssh -tt root\@${server} service nfs-ganesha-gpfs restart 2>&1";
my $get_ganesha_status = "ssh -tt root\@${server} service nfs-ganesha-gpfs status 2>&1";

my $root_read_data = "sudo su  -c \"cat ${testfile}\" 2>&1";
my $root_write_data = "sudo su -c \"echo abc > ${testfile}\" 2>&1";
my $root_read_metadata = "sudo su -c \"stat ${testfile}\" 2>&1";
my $root_write_metadata = "sudo su -c \"chmod a+wrx ${testfile}\" 2>&1";

my $read_data = "sudo su ${USERNAME} -c \"cat ${testfile}\" 2>&1";
my $write_data = "sudo su ${USERNAME} -c \"echo abc > ${testfile}\" 2>&1";
#my $write_data = "sudo su ${USERNAME} -c \"touch ${testfile}\" 2>&1";
my $read_metadata = "sudo su ${USERNAME} -c \"stat ${testfile}\" 2>&1";
my $write_metadata = "sudo su ${USERNAME} -c \"chmod a+wrx ${testfile}\" 2>&1";

sub create_configfile {
    my $pconfigfile = shift(@_);
    my $paccess_root = shift(@_);
    my $paccess = shift(@_);
    my $paccess_type = shift(@_);

    `rm -f ${new_localconfigfile}`;
    open(OLD, "<${perm_localconfigfile}") or die "Could not open configuration file: ${perm_localconfigfile}\n";
    open(NEW, ">${new_localconfigfile}") or die "Could not open new configuration file: ${new_localconfigfile}\n";

    while (my $line = <OLD>) {
	# Comment Root_Access
	if ($line =~ m/.*Root_Access.*/) {
	    print NEW "# " . $line;
	    next;
	}
	
	# Comment RW_Access
	if ($line =~ m/.*RW_Access.*\=.*/) {
	    print NEW "# " . $line;
	    next;
	}
	
	# Comment R_Access
	if ($line =~ m/.*R_Access.*\=.*/) {
	    print NEW "# " . $line;
	    next;
	}
	
	# Comment MDONLY_RW_Access
	if ($line =~ m/.*MDONLY_Access.*\=.*/) {
	    print NEW "# " . $line;
	    next;
	}
	
	# Comment MDONLY_R_Access
	if ($line =~ m/.*MDONLY_RO_Access.*/) {
	    print NEW "# " . $line;
	    next;
	}

	if ($line =~ m/.*}.*/) {
	    # Add Access
	    if ($paccess) { print NEW "  Access = \"*\";\n"; }
	    
	    # Add Access_Type
	    print NEW "  Access_Type = \"${paccess_type}\";\n";
	    
	    # Add Root_Access
	    if ($paccess_root) { print NEW "  Root_Access = \"*\";\n"; }
	}

	# Default to just copying the line
	print NEW $line;
    }

    close(OLD);
    close(NEW);
}

`mkdir ${mountdir}`;

# If there were > 3 arguments 
my @access_root_option = (1,0);
my @access_option = (1,0);
my @access_type_option = ("RW", "RO", "MDONLY", "MDONLY_RO");

if (exists $ARGV[3]) {
    if (($ARGV[3] == 1) || ($ARGV[3] == 0)) { @access_root_option = ($ARGV[3]); }
}
if (exists $ARGV[4]) {
    if (($ARGV[4] == 1) || ($ARGV[4] == 0)) { @access_option = ($ARGV[4]); }
}
if (exists $ARGV[5]) {
    if (($ARGV[5] == 1) || ($ARGV[5] == 0)) { @access_type_option = ($ARGV[5]); }
}

print "root user accesstype\n\n";
foreach my $access_root (@access_root_option) { # root access
    foreach my $access (@access_option) { # user access
	foreach my $access_type (@access_type_option) { # access permissions
	    print "\n---------------------------------------------\n";
	    print "access: $access_root $access $access_type\n";
	    
	    print "Resetting remote file for next test ... \n";
	    my $result = `${reset_remote_file}`;
	    $result = `${reset_remote_file_pt2}`;
	    
	    # Now create the configuration file
	    &create_configfile($filename, $access_root, $access, $access_type);
	    
	    # Move config file to Ganesha and restart server
	    print "Moving new config to Ganesha server ...\n";
	    $result = `${scpconfigfile}`;
	    
	    print "Restarting Ganesha server ...\n";
	    $result = `${restart_ganesha}`;
#		    print $result . "\n";
	    if ($result =~ m/.*Starting\sgpfs.ganesha.nfsd.*FAILED.*/) {
		print "Could not start Ganesha server with this config!!\n";
		next;
	    }
	    
	    $result = `${get_ganesha_status}`;
	    if ($result =~ m/.*GPFS.Ganesha.is.not.running.*/) {
		print "Ganesha server crashed shortly after startup!!\n";
		next;
	    }
	    
	    # Unmount export if already mounted
	    $result = `${unmount}`;
#		    print $result . "\n";
	    #######################################		    
	    # Test mounting
	    $result = `${mount}`;
#		    print "--- mount returned this: " . $result . "\n\n\n\n\n\n";
	    my $failed;
	    if ($result =~ m/.+/) { # A successful mount shouldn't return anything
		$failed = 1;
	    } else {
		$failed = 0;
	    }
	    
	    if (($access_root == 0 && $access == 0) || (! $access_type)) {
		# should be denied mount access
		if ($failed == 0) {
		    print "FAIL: Mount should not have been allowed\n";
		} else {
		    print "Mount was correctly refused\n";
		    next;
		}
	    } else {
		# should be granted mount access
		if ($failed == 0) {
		    print "Mount was correctly allowed\n";
		} else {
		    print "FAIL: Mount should have been allowed\n";
		    next;
		}
	    }
	    #######################################
	    # Test reading data
	    $result = `${read_data}`;
#		    print "--- read returned this: " . $result . "\n";
	    if ($result =~ m/abc/) { # A successful read should return the contents of the file
		$failed = 0;
	    } else {
		$failed = 1;
	    }
	    
	    if ($access == 0 || ($access_type ne "RW" && $access_type ne "RO")) {
		# should be denied mount access
		if ($failed == 0) {
		    print "FAIL: Read was incorrectly allowed.\n";
		} else {
		    print "Read was correctly refused.\n";
		    
		}
	    } else {
		# should be granted mount access
		if ($failed == 0) {
		    print "Read was correctly allowed.\n";
		} else {
		    print "FAIL: Read was incorrectly refused.\n";
		}
	    }
	    
	    #######################################
	    # Test writing data
	    $result = `${write_data}`;
#		    print "--- write returned this: " . $result . "\n";
	    if ($result =~ m/.+/) { # A successful write should return nothing
		$failed = 1;
	    } else {
		$failed = 0;
	    }
	    
	    if ($access == 0 || $access_type ne "RW") {
		# should be denied mount access
		if ($failed == 0) {
		    print "FAIL: Write was incorrectly allowed.\n";
		} else {
		    print "Write was correctly refused.\n";
		}
	    } else {
		# should be granted mount access
		if ($failed == 0) {
		    print "Write was correctly allowed.\n";
		} else {
		    print "FAIL: Write was incorrectly refused.\n";
		}
	    }		    
	    
	    #######################################
	    # Test reading metadata
	    $result = `${read_metadata}`;
#		    print "--- read metadata returned this: " . $result . "\n";
	    if ($result =~ m/.*File.*export_access_testfile.*/) { # A successful metadata read should return 
		$failed = 0;
	    } else {
		$failed = 1;
	    }
	    
	    if ($access == 0 || ($access_type ne "RW" && $access_type ne "RO"
				 && $access_type ne "MDONLY_RO" && $access_type ne "MDONLY")) {
		# should be denied mount access
		if ($failed == 0) {
		    print "FAIL: Metadata read was incorrectly allowed.\n";
		} else {
		    print "Metadata read was correctly refused.\n";
		}
	    } else {
		# should be granted mount access
		if ($failed == 0) {
		    print "Metadata read was correctly allowed.\n";
		} else {
		    print "FAIL: Metadata read was incorrectly refused.\n";
		}
	    }
	    
	    #######################################
	    # Test writing metadata
	    $result = `${write_metadata}`;
#		    print "--- write metadata returned this: " . $result . "\n";
	    if ($result =~ m/.+/) { # A successful metadata write should return nothing
		$failed = 1;
	    } else {
		$failed = 0;
	    }
	    
	    if ($access == 0 || ($access_type ne "RW" && $access_type ne "MDONLY")) {
		# should be denied mount access
		if ($failed == 0) {
		    print "FAIL: Metadata write was incorrectly allowed.\n";
		} else {
		    print "Metadata write was correctly refused.\n";
		}
	    } else {
		# should be granted mount access
		if ($failed == 0) {
		    print "Metadata write was correctly allowed.\n";
		} else {
		    print "FAIL: Metadata write was incorrectly refused.\n";
		}
	    }
	    
	    # end of main loop
	}
    }
}
