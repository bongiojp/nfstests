all: delete_then_access_test
delete_then_access_test: dbench
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
	-killall delete_while_locked.pl
	-ssh -tt root@$(SERVER) service nfs-ganesha-gpfs restart
	-sudo ./delete_then_access.pl ${SERVER} ${EXPORTDIR} /deletethenaccesstest.file ./deletethenaccesstest.mnt ../dbench > ${TMPDIR}/deletebehaviortest.results 2>&1

	-sleep 1
	-sudo umount ./deletethenaccesstest.mnt
	-sudo rmdir ./deletethenaccesstest.mnt

	-sudo ruby parse_delete_then_access.pl ${XMLDEST} ${TMPDIR}

dbench::
	cd .. && make dbench
