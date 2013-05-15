#!/usr/bin/perl

if ($ARGV[0] eq "help") {
    print "${0} [mountdir:mountdir:...](/mnt/temp) [total processes](20) [per process directories](1000) [per directory files](1000)\n\n";
    exit;
}

my $mount_dir_str = $ARGV[0];
my $numprocs = $ARGV[1];
my $numdir = $ARGV[2];
my $numfile = $ARGV[3];

# Defaults
$numdir or $numdir = 1000;
$numfile or $numfile = 1000;
$numprocs or $numprocs = 20;

my @mount_dirs = split(/:/, $mount_dir_str);

sub stress{
    my $mount_dir = shift(@_);
    my $pid = $$;
    foreach(1 .. $numdir) {
	$dir = "${mount_dir}/fdstress\[${pid}\].${_}";
	print "Creating directory ${dir}\n";
	
	`mkdir -p ${dir}`;
	foreach(1 .. $numfile) {
	    $file = "${dir}/file.${_}";
	    `echo ${file} > ${file}`;
	}
	`rm -rf ${dir}`;
    }
    
    print "Finished!!\n\n";
}

print "Starting fd stress with ${numdir} directories, ${numfile} files, ${numprocs} procs.\n";

my @children;
foreach(@mount_dirs) {
    my $dir = $_;
    foreach(1 .. $numprocs) {
	my $pid = fork();
	
	if ($pid) { # PARENT
	    push(@children, $pid);
	} elsif ($pid == 0) { # CHILD
	    print "Starting process ${_}\n";
	    stress($dir);
	} else {
	    die "Could not create thread ${_}\n";
	}
    }
}

foreach (@children) {
    my $tmp = waitpid($_, 0);
    print "Child ${tmp}\n";
}

