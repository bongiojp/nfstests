#!/usr/bin/perl
#
#The user accounts, uids, gids, should be as follows:
#
#$ id hudson
#uid=2002(hudson) gid=2002(hudson) groups=2002(hudson)
#$ id root
#uid=0(root) gid=0(root) groups=0(root),123(kvm)
#$ id otheruser
#uid=1002(otheruser) gid=1002(otheruser) groups=1002(otheruser)
#
#

my @users = ("root", "hudson", "otheruser");
my @p_list = (0, 1, 2, 3, 4, 5, 6, 7);
my @special_list = (0, 1, 2, 4);

sub check_p;
sub check_result;
sub unmount;
sub mk_all_test_files;

if (@ARGV != 4) {
    print "Usage: $0 server exportdir mountdir [SHORTTEST|LONGTEST|SSHPREPARE|SSHPREPAREBYUNTAR]\n";
    exit(0);
}

my $server = $ARGV[0];
my $exportdir = $ARGV[1];
my $filename = "/permissionstestfile";
my $executablename = "./myecho";
my $mountdir = $ARGV[2];
my $operation = $ARGV[3]; # SSHPREPARE or PREPARE or anything else to commence test
my $change_perm_file = "change_permissions.sh";
my $testdir = "permissions_test";
my $compressed_testfiles = "file_perm_test_dir.tar.bz2";

my %groups;
$groups{$users[0]} = `id -ng ${users[0]}`; chomp($groups{$users[0]});
$groups{$users[1]} = `id -ng ${users[1]}`; chomp($groups{$users[1]});
$groups{$users[2]} = `id -ng ${users[2]}`; chomp($groups{$users[2]});

my %user_ids; 
$user_ids{$users[0]} = `id -u ${users[0]}`; chomp($user_ids{$users[0]});
$user_ids{$users[1]} = `id -u ${users[1]}`; chomp($user_ids{$users[1]});
$user_ids{$users[2]} = `id -u ${users[2]}`; chomp($user_ids{$users[2]});

my %group_ids; 
$group_ids{$users[0]} = `id -g ${users[0]}`; chomp($group_ids{$users[0]});
$group_ids{$users[1]} = `id -g ${users[1]}`; chomp($group_ids{$users[1]});
$group_ids{$users[2]} = `id -g ${users[2]}`; chomp($group_ids{$users[2]});

my $file_contents = "successful read";
my $execution_string = "successful_execution"; #shouldn't have spaces

# check that the user accounts are setup correctly
my $result = `id -G ${users[0]}`;
if ($result =~ /.*\s${groups[1]}\s.*/) {
    print "on local machine: User ${users[0]} belongs to ${user[1]}'s group. Change this before testing.\n";
    exit(1);
}
elsif ($result =~ /.*\s${groups[2]}\s.*/) {
    print "on local machine: User ${users[0]} belongs to ${users[2]}'s group. Change this before testing.\n";
    exit(1);    
}
$result = `id -G ${users[1]}`;
if ($result =~ /.*\s${groups[0]}\s.*/) {
    print "on local machine: User ${users[1]} belongs to ${users[0]}'s group. Change this before testing.\n";
    exit(1);
}
elsif ($result =~ /.*\s${groups[2]}\s.*/) {
    print "on local machine: User ${users[1]} belongs to ${users[2]}'s group. Change this before testing.\n";
    exit(1);    
}
$result = `id -G ${users[2]}`;
if ($result =~ /.*\s{groups[0]}\s.*/) {
    print "on local machine: User ${users[2]} belongs to ${users[0]}'s group. Change this before testing.\n";
    exit(1);
}
elsif ($result =~ /.*\s${groups[1]}\s.*/) {
    print "on local machine: User ${users[2]} belongs to ${users[1]}'s group. Change this before testing.\n";
    exit(1);    
}

# Check that the user accounts exist.
foreach (@users) {
    print "checking for existence of user account: $_ ... ";
    (`id -u ${_} 2>&1` =~ /\d+/) or die "User '${_}' does not exist, please create this user account before running this script.";
    print "EXISTS\n";
}

if ($operation eq "PREPARE") {
    &mk_all_test_files($exportdir, $testdir,  $filename, $executablename,
		       \@p_list, \@special_list, \@users, \%groups, \%user_ids, \%group_ids);
    exit 0;
}


# Check whether user uids and group gids match on remote server and local machine.
foreach(@users) {
    my $result = `ssh root\@${server} id -g ${_}`;
    chomp($result);
    if (! ($result eq $group_ids{$_})) {
	print "User ${_} has a different gid on local machine ($group_ids{$_}) and server ($result). Change this before testing.\n";
	exit(1);    
    }
    $result = `ssh root\@${server} id -u ${_}`;
    chomp($result);
    if (! ($result eq $user_ids{$_})) {
	print "User ${_} has a different uid on local machine ($user_ids{$_}) and server ($result). Change this before testing.\n";
	exit(1);    
    }
}

if ($operation eq "SSHPREPARE") {
    `scp ./${executablename} root\@${server}:~/`;
    `scp ./$0 root\@${server}:~/`;

    # Watch out with the last argument, this could create a nasty ssh loop
    print "ssh root\@${server} ./${0} ${ARGV[0]} ${ARGV[1]} ${ARGV[2]} PREPARE 2>&1\n";
    $result = `ssh root\@${server} ./${0} ${ARGV[0]} ${ARGV[1]} ${ARGV[2]} PREPARE 2>&1`;
    print $result;
    exit 0;
}
elsif ($operation eq "SSHPREPAREBYUNTAR") {
    `scp ${compressed_testfiles} root\@${server}:${exportdir}/`;
    $result = `ssh root\@${server} "cd ${exportdir}/ && tar jxf ./${compressed_testfiles} 2>&1" 2>&1`;
    print $result;
    exit 0;
}

print "Mounting Ganesha share\n";
( -d $mountdir ) or `sudo mkdir -p ${mountdir}`;
`sudo mount -o noac,proto=tcp,vers=3 -t nfs ${server}:${exportdir} ${mountdir} 2>&1`;

# check that the nfs share was mounted successfully
my $mount_successful = `mount -l | grep ${mountdir} 2>&1`;
$mount_successful or die "Could not mount nfs share with the following parameters: -o proto=tcp,vers=3,noac -t nfs ${server}:${exportdir} ${mountdir}\n";

$SIG{__DIE__} = sub { &unmount($mountdir); };
$SIG{'INT'} = sub { &unmount($mountdir); };

`sudo cp ${executablename} ${mountdir}/`;
if ( ! -e "${mountdir}/${filename}" ) {
    `touch ${mountdir}/${filename}`;
}

if ($operation eq "SHORTTEST") {
    @special_list = (0);
    @p_list = (0, 1, 2, 4, 7);
}

foreach( 0 .. 1 ) {
    my $test_user = $users[$_];
    my $test_group = $groups{$test_user};

    print "\n-----------------------------------------------\n";
    print "TESTING user $test_user (" . $user_ids{$test_user}
    . ") with group $test_group (" . $group_ids{$test_group} . ")";
    print "\n-----------------------------------------------\n";
    foreach(@special_list) {
	my $special_p = $_;
	foreach(@p_list) {
	    my $user_p = $_;
	    foreach(@p_list) {
		my $group_p = $_;
		foreach(@p_list) {
		    my $other_p = $_;
		    my $octal = "${special_p}${user_p}${group_p}${other_p}";
		    foreach( @users ) {
			my $file_user = $_;
			foreach( values %groups ) {
			    my $file_group = $_;

			    if ($test_user eq "root") {
				if ($file_user eq $users[2]) { next; }
				if ($file_group eq $groups{$users[2]}) { next; }
			    }
			    if ($operation eq "SHORTTEST") {
				if ($file_user eq $users[0]) { next; }
				if ($file_group eq $groups{$users[0]}) { next; }
			    }

			    my $uid = $user_ids{$file_user};
			    my $gid = $group_ids{$file_group};
			    
			    print "testing file permissions: user:${uid} gid:${gid} octal:${octal} ";
			    &check_permissions($octal, $test_user, $test_group, $file_user, $file_group,
					       $server, $mountdir, $testdir . "/${uid}.${gid}", "$filename.${octal}.${uid}.${gid}",
					       "$executablename.${octal}.${uid}.${gid}");
			}
		    }
		}
	    }
	}
    }
}


sub check_permissions {
    my $octal = shift(@_);
    my $test_user = shift(@_);
    my $test_group = shift(@_);
    my $file_user = shift(@_);
    my $file_group = shift(@_);
    my $server = shift(@_);
    my $mountdir = shift(@_);
    my $testdir = shift(@_);
    my $filename = shift(@_);
    my $executablename = shift(@_);

    #attempt to read
    print " read .. ";
    my $result = `sudo su ${test_user} -c "cat ${mountdir}/${testdir}/${filename} 2>&1" 2>&1`;
    
    $pass = &check_result($octal, $test_user, $test_group, $file_user, $file_group, "read", $result);
    if ($pass == 1) {
	print "\nsudo su ${test_user} -c \"cat ${mountdir}/${testdir}/${filename} 2>&1\" 2>&1\n";
	print "Read succeeded when it shouldn't w/ permissions (octal:${octal},uid:${file_user},gid:${file_group}). \nTEST FAILED\n"; 
	print "-- $result\n";
    }
    if ($pass == 2) {
	print "\nsudo su ${test_user} -c \"cat ${mountdir}/${testdir}/${filename} 2>&1\" 2>&1\n";
	print "Read failed when it shouldn't w/ permissions (octal:${octal},uid:${file_user},gid:${file_group}). \nTEST FAILED\n"; 
	print "-- $result\n";
    }
    
    #attempt to execute
    print " execute .. ";
    $result = `sudo su ${test_user} -c "${mountdir}/${testdir}/${executablename} ${execution_string} 2>&1" 2>&1`;

    &check_result($octal, $test_user, $test_group, $file_user, $file_group, "execute", $result);
    if ($pass == 1) {
	print "\nsudo su ${test_user} -c \"${mountdir}/${testdir}/${executablename} ${execution_string} 2>&1\" 2>&1\n";
	print "Execute succeeded when it shouldn't w/ permissions (octal:${octal},uid:${file_user},gid:${file_group}). \nTEST FAILED\n"; 
	print "-- $result\n";
    }
    if ($pass == 2) {
	print "\nsudo su ${test_user} -c \"${mountdir}/${testdir}/${executablename} ${execution_string} 2>&1\" 2>&1\n";
	print "Execute failed when it shouldn't w/ permissions (octal:${octal},uid:${file_user},gid:${file_group}). \nTEST FAILED\n"; 
	print "-- $result\n";
    }

    #attempt to write
    print " write .. \n";
    $result = `sudo su ${test_user} -c "echo successful write > ${mountdir}/${testdir}/${filename} 2>&1" 2>&1`;

    &check_result($octal, $test_user, $test_group, $file_user, $file_group, "write", $result);
    if ($pass == 1) {
	print "sudo su ${test_user} -c \"echo successful write > ${mountdir}/${testdir}/${filename} 2>&1\" 2>&1\n";
	print "Write succeeded when it shouldn't w/ permissions (octal:${octal},uid:${file_user},gid:${file_group}). \nTEST FAILED\n"; 
	print "-- $result\n";
    }
    if ($pass == 2) {
	print "sudo su ${test_user} -c \"echo successful write > ${mountdir}/${testdir}/${filename} 2>&1\" 2>&1\n";
	print "Write failed when it shouldn't w/ permissions (octal:${octal},uid:${file_user},gid:${file_group}). \nTEST FAILED\n"; 
	print "-- $result\n";
    }

    $result = `sudo echo ${file_contents} > ${mountdir}/${testdir}/${filename} 2>&1`;
    if ($result) {
	print "WARNING: Could not reset contents of file after write operation: ${mountdir}/${testdir}/${filename}\n";
    }
    # how do we test privileged flag or other special flags ?
    ######################## FIX ME!!
}

sub check_result {
    my $octal = shift(@_);
    my $test_user = shift(@_);
    my $test_group = shift(@_);
    my $file_user = shift(@_);
    my $file_group = shift(@_);
    my $op = shift(@_);
    my $result = shift(@_);

    my ($special_p, $user_p, $group_p, $other_p) = split(//, $octal);

    my $read_should_succeed = 0;
    my $write_should_succeed = 0;
    my $execute_should_succeed = 0;

    #read should succeed if:
    if (
	($test_user eq $file_user && $user_p >= 4) ||
	($test_group eq $file_group && $test_user ne $file_user && $group_p >= 4) ||
	($test_user ne $file_user && $test_group ne $file_group && $other_p >= 4) ||
	($test_user eq "root") # At least on some systems root ignores file permissions
	) {
	$read_should_succeed = 1;
    }

    #write should succeed if:
    # uid takes precedence over gid, uid and gid take precedence over other
    if (
	($test_user eq $file_user && ($user_p == 2 || $user_p == 3 || $user_p == 6 || $user_p == 7)) ||
	($test_group eq $file_group && $test_user ne $file_user && ($group_p == 2 || $group_p == 3 || $group_p == 6 || $group_p == 7)) ||
	($test_user ne $file_user && $test_group ne $file_group 
	 && ($other_p == 2 || $other_p == 3 || $other_p == 6 || $other_p == 7)) ||
	($test_user eq "root") # At least on some systems root ignores file permissions
	) {
	$write_should_succeed = 1;
    }

    #execute should succeed if:
    if (
	($test_user eq $file_user && ($user_p % 2)) ||
	($test_group eq $file_group && $test_user ne $file_user && ($group_p % 2)) ||
	($test_user ne $file_user && $test_group ne $file_group && ($other_p % 2)) ||
	($test_user eq "root" && ($other_p % 2)) # At least on some systems root ignores file permissions
	) {
	$execute_should_succeed = 1;
    }

    # now check if the operation behaved as expected

    # results of cat
    if ($op eq "read") {
#	print "------> $result\n";
	if (($result =~ /$file_contents/) && $read_should_succeed)
	{return 0;} #PASS
	elsif (($result =~ /$file_contents/) && ! $read_should_succeed)
	{return 1;} #FAIL
	elsif ($read_should_succeed)
	{return 2;} #FAIL
	else
	{return 0;} #PASS
    }

    # results of piped echo
    # FIX ME: I should match for the permission denied error, otherwise we could pass for the wrong reasons.
    elsif ($op eq "write") {
	if ((! $result) && $write_should_succeed)
	{return 0;} #PASS
	elsif ((! $result) && (! $write_should_succeed))
	{return 1;} #FAIL
	elsif ($write_should_succeed)
	{return 2;} #FAIL
	else
	{return 0;} #PASS
    }

    # results of shell (/bin/sh) execution
    elsif ($op eq "execute") {
	# The result may be "command not found" or it may be "permission denied" depending on the shell used.
	if (($result =~ /$execution_string/) && $execute_should_succeed)
	{return 0;} #PASS
	elsif (($result =~ /$execution_string/) && ! $execute_should_succeed)
	{return 1;} #FAIL
	elsif ($execute_should_succeed)
	{return 2;} #FAIL
	else
	{return 0;} #PASS
    }
}

sub unmount {
    my $mountdir = shift(@_);
    my $uname = `uname -o`;

    if ($uname =~ /linux/i) {
	print "Unmounting NFS share.\n";
	`umount -l ${mountdir}`; # linux
    } else {
	print "Unmounting NFS share.\n";
	`umount -F ${mountdir}`; # solaris
    }
    exit 1;
}

sub mk_all_test_files {
    my $exportdir = shift(@_);
    my $testdir = shift(@_);
    my $filename = shift(@_);
    my $executablename = shift(@_);
    my @p_list = @{shift(@_)}; #array ref
    my @special_list = @{shift(@_)}; #array ref
    my @users = @{shift(@_)}; #array ref
    my @groups = %{shift(@_)}; #hash ref
    my %user_ids = %{shift(@_)}; #hash ref
    my %group_ids = %{shift(@_)}; #hash ref

    if ( ! -d "${exportdir}/${testdir}" ) {
	if ( -e "${exportdir}/${testdir}" ) {
	    `rm -f ${exportdir}/${testdir}`;
	}
	`mkdir ${exportdir}/${testdir}`;
    }

    foreach(@special_list) { # 4
	my $special_p = $_;
	foreach(@p_list) { # 8
	    my $user_p = $_;
	    foreach(@p_list) { # 8
		my $group_p = $_;
		foreach(@p_list) { # 8
		    my $other_p = $_;
		    my $octal = "${special_p}${user_p}${group_p}${other_p}";
		    foreach( @users ) { # 3
			my $file_user = $_;
			foreach( @groups ) { # 3
			    my $file_group = $_;
			    my $uid = $user_ids{$file_user};
			    my $gid = $group_ids{$file_group};

			    if ( ! -d "${exportdir}/${testdir}/${uid}.${gid}" ) {
				if ( -e "${exportdir}/${testdir}/${uid}.${gid}" ) {
				    `rm -f ${exportdir}/${testdir}/${uid}.${gid}`;
				}
				`mkdir ${exportdir}/${testdir}/${uid}.${gid}`;
			    }

			    print "user: ${file_user}:${uid} group: ${file_group}:${gid} mode:${octal}\n";

			    `echo \"${file_contents}\" > ${exportdir}/${testdir}/${uid}.${gid}/${filename}.$octal.$uid.$gid`;
			    `chmod ${octal} ${exportdir}/${testdir}/${uid}.${gid}/${filename}.$octal.$uid.$gid`;
			    `chown ${uid} ${exportdir}/${testdir}/${uid}.${gid}/${filename}.$octal.$uid.$gid`;
			    `chgrp ${gid} ${exportdir}/${testdir}/${uid}.${gid}/${filename}.$octal.$uid.$gid`;

			    if (! -e "${exportdir}/${testdir}/${uid}.${gid}/${executablename}.$octal.$uid.$gid") {
				`cp ${executablename} ${exportdir}/${testdir}/${uid}.${gid}/${executablename}.$octal.$uid.$gid`;
			    }
			    `chmod ${octal} ${exportdir}/${testdir}/${uid}.${gid}/${executablename}.$octal.$uid.$gid`;
			    `chown ${uid} ${exportdir}/${testdir}/${uid}.${gid}/${executablename}.$octal.$uid.$gid`;
			    `chgrp ${gid} ${exportdir}/${testdir}/${uid}.${gid}/${executablename}.$octal.$uid.$gid`;
			}
		    }
		}
	    }
	}
    }
}
