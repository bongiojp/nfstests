#!/usr/bin/perl

use strict;

my $numthreads = $ARGV[0];
my $filesize = $ARGV[1]; #gigabytes
my $dir = $ARGV[2];
my @children;

@ARGV == 3 or die "Not enough args @{ARGV} instead of 3.  numthreads filesize dir";

sub on_die{
    print "Exit forced ...\n";
    foreach(@children) {
	print "Killing dd process ${_}\n";
	`killall -s KILL dd`;
	`kill -s KILL $_`;
	`killall -s KILL dd`;
	`kill -s KILL $_`;
	`killall -s KILL dd`;
	`kill -s KILL $_`;
	`killall -s KILL dd`;
	`kill -s KILL $_`;
	`killall -s KILL dd`;
	`kill -s KILL $_`;
	`killall -s KILL dd`;
    }
}

#trap 'on_die' TERM;
#trap 'on_die' INT;
#trap 'on_die' QUIT;

$SIG{TERM} = \&on_die;
$SIG{INT} = \&on_die;
$SIG{QUIT} = \&on_die;

sub dd{
    my $filesize = shift(@_);
    my $mount_dir = shift(@_);
    my $pid = $$;
    my $output = `dd if=/dev/zero of=${mount_dir}/${pid} bs=1024M count=${filesize}`;
    print "dd process ${pid} finished!!\n";
    print "${output}\n\n";
}

print "Running ${numthreads} dd processes generating ${filesize}GB in ${dir}/<pid>\n";
my $pid;
foreach(1 .. $numthreads) {
    $pid = fork();
    if ($pid) { # PARENT
	push(@children, $pid);
    } elsif ($pid == 0) { # CHILD                                                                                 
	print "Starting dd process ${_}\n";
	dd($filesize, $dir);
	exit;
    } else {
	die "Could not create thread ${_}\n";
    }
}

#children exited by now
foreach (@children) {
    my $tmp = waitpid($_, 0);
#    print "Child ${tmp}\n";
}
