#!/usr/bin/perl -w

# It is assumed that we are testing when Ganesha has Commits enabled
# and is not using the ganesha write buffer.

use Fcntl;
use strict;

# arguements
my $dir = "./GPFS_CONFIGS";
my $perm_localconfigfile = "${dir}/gpfs.ganesha.exports.conf";

sub create_configfile {
    my $paccess_root = shift(@_);
    my $paccess_r = shift(@_);
    my $paccess_rw = shift(@_);
    my $paccess_mdonly_r = shift(@_);
    my $paccess_mdonly_rw = shift(@_);

    my $new_localconfigfile = "${perm_localconfigfile}.${paccess_root}.${paccess_r}.${paccess_rw}.${paccess_mdonly_r}.${paccess_mdonly_rw}";

    `rm -f ${new_localconfigfile}`;
    open(OLD, "<${perm_localconfigfile}") or die "Could not open configuration file: ${perm_localconfigfile}\n";
    open(NEW, ">${new_localconfigfile}") or die "Could not open new configuration file: ${new_localconfigfile}\n";

    while (my $line = <OLD>) {
	# Comment Access away
	if ($line =~ m/\s*\#.*\sAccess\s.*\=.*/) {
	    print NEW $line;
	    next;
	}
	if ($line =~ m/\s*\sAccess\s.*\=.*/) {
	    print NEW "# " . $line;
	    next;
	}

	# Comment Access_Type away
	if ($line =~ m/\s*\#.*\sAccess_Type\s.*\=.*/) {
	    print NEW $line;
	    next;
	}
	if ($line =~ m/\s*Access_Type\s.*\=.*/) {
	    print NEW "# " . $line;
	    next;
	}

	# (Un)Comment Root_Access
#	if ($line =~ m/\s*\#\sRoot_Access.*\=.*/ && $paccess_root) {
#	    print NEW "  Root_Access = \"*\";\n";
#	    next;
#	}
	if ($line =~ m/\s*Root_Access.*\=.*/ && (! $paccess_root)) {
	    print NEW "# " . $line;
	    next;
	}
	
	# (Un)Comment RW_Access
#	if ($line =~ m/\s*\#\s*RW_Access.*\=.*/ && $paccess_rw) {
#	    print NEW "  RW_Access = \"*\";\n";
#	    next;
#	}
	if ($line =~ m/\s*RW_Access.*\=.*/ && (! $paccess_rw)) {
	    print NEW "# " . $line;
	    next;
	}
	
	# (Un)Comment R_Access
	if ($line =~ m/\s*\#.*R_Access.*\=.*/ && $paccess_r) {
	    print NEW "  R_Access = \"*\";\n";
	    next;
	}
	if ($line =~ m/\s*R_Access.*\=.*/ && (! $paccess_r)) {
	    print NEW "# " . $line;
	    next;
	}
	
	# (Un)Comment MDONLY_RW_Access
	if ($line =~ m/\s*\#.*MDONLY_Access.*\=.*/ && $paccess_mdonly_rw) {
	    print NEW "  MDONLY_Access = \"*\";\n";
	    next;
	}
	if ($line =~ m/\s*MDONLY_Access.*\=.*/ && (! $paccess_mdonly_rw)) {
	    print NEW "# " . $line;
	    next;
	}
	
	# (Un)Comment MDONLY_R_Access
	if ($line =~ m/\s*\#.*MDONLY_RO_Access.*\=.*/ && $paccess_mdonly_r) {
	    print NEW "  MDONLY_RO_Access = \"*\";\n";
	    next;
	}
	if ($line =~ m/\s*MDONLY_RO_Access.*\=.*/ && (! $paccess_mdonly_r)) {
	    print NEW "# " . $line;
	    next;
	}

	# Default to just copying the line
	print NEW $line;
    }
    
    close(OLD);
    close(NEW);
}

`mkdir ${dir}`;

# If there were > 3 arguments 
my @access_root_option = (0,1);
my @access_r_option = (0,1);
my @access_rw_option = (0,1);
my @access_mdonly_r_option = (0,1);
my @access_mdonly_rw_option = (0,1);

foreach my $access_root (@access_root_option) { # root access
    foreach my $access_r (@access_r_option) { # read access
	foreach my $access_rw (@access_rw_option) { # read/write access
	    foreach my $access_mdonly_r (@access_mdonly_r_option) { # mdonly read access
		foreach my $access_mdonly_rw (@access_mdonly_rw_option) { # mdonly read/write access
		    # Create the configuration file
		    &create_configfile($access_root, $access_r,
				       $access_rw, $access_mdonly_r,
				       $access_mdonly_rw);
		}
	    }
	}
    }
}
