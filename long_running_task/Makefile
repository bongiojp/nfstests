all: long_running_task

long_running_task: dbench
ifndef SERVER
	@echo "SERVER environment variable not defined"
	exit 1
endif

ifndef EXPORTDIR
	@echo "EXPORTDIR environment variable not defined"
	exit 1
endif

ifndef XMLDEST
	@echo "XMLDEST environment variable not defined"
	exit 1
endif
ifndef TMPDIR
	@echo "TMPDIR environment variable not defined"
	exit 1
endif
	-killall long_running_task.pl
	-ssh -tt root@$(SERVER) service nfs-ganesha-gpfs restart
	-sleep 10
	-sudo ./long_running_task.pl ${SERVER} ../dbench 2>&1 | tee ${TMPDIR}/longtask.results
	-sleep 1

	-sudo ruby ./parse_long_running_task.rb ${XMLDEST} ${TMPDIR}

dbench::
	cd .. && make dbench
