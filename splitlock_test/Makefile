all: test_nfsv3 test_nfsv4

test_nfsv3:
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
	gcc lock_test_sequence.c -o lock_seq -lpthread
	gcc lock.c -o lock
	-ssh -tt root@$(SERVER) service nfs-ganesha-gpfs restart
	-mkdir ./splitlocktest.mnt

	sudo mount -t nfs -o noac,vers=3,proto=tcp ${SERVER}:${EXPORTDIR} ./splitlocktest.mnt
	-sudo ./lock_seq ./splitlocktest.mnt/splitlocktest.file EXCLUSIVE NOBLOCK > ${TMPDIR}/splitlocktest_v3.results 2>&1
	-sleep 1
	-killall lock_seq
	-sudo umount -l -f ./splitlocktest.mnt

	-sudo rmdir ./splitlocktest.mnt
	-sudo mkdir ${XMLDEST}
	-sudo ruby ./parse_splitlock_test.rb ${XMLDEST} ${TMPDIR} 3

test_nfsv4:
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
	gcc lock_test_sequence.c -o lock_seq -lpthread
	gcc lock.c -o lock
	-ssh -tt root@$(SERVER) service nfs-ganesha-gpfs restart
	-mkdir ./splitlocktest.mnt

	sudo mount -t nfs -o noac,vers=4,proto=tcp ${SERVER}:${EXPORTDIR} ./splitlocktest.mnt
	-sudo ./lock_seq ./splitlocktest.mnt/splitlocktest.file EXCLUSIVE NOBLOCK > ${TMPDIR}/splitlocktest_v4.results 2>&1
	-sleep 1
	-killall lock_seq
	-sudo umount -l -f ./splitlocktest.mnt

	-sudo rmdir ./splitlocktest.mnt
	-sudo mkdir ${XMLDEST}
	-sudo ruby ./parse_splitlock_test.rb ${XMLDEST} ${TMPDIR} 4