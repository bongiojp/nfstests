# gdb -p `pidof /usr/bin/gpfs.ganesha.nfsd` -x dump_threads.gdb
set logging redirect on
set logging overwrite on
set logging file /root/threads_bt2.log
set logging on
thread apply all bt
set logging off
quit
