all: dwl_test ldwl_test

dwl_test:
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
	gcc -o delete_while_locked delete_while_locked.c
	-ssh -tt root@$(SERVER) service nfs-ganesha-gpfs restart
	-mkdir ./deletewhilelockedtest.mnt
	sudo mount -t nfs -o noac,vers=3 ${SERVER}:${EXPORTDIR} ./deletewhilelockedtest.mnt
	-cd ./deletewhilelockedtest.mnt
	sudo ./delete_while_locked ./locktest.file > ${TMPDIR}/deletewhilelockedtest.results 2>&1
	-cd ..
	-sleep 1
	-sudo umount -f ./deletewhilelockedtest.mnt
	-sudo rmdir ./deletewhilelockedtest.mnt
	-sudo mkdir ${XMLDEST}
	-sudo ruby ./parse_delete_while_locked.rb ${XMLDEST} ${TMPDIR}

ldwl_test:
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
	 gcc -o local_delete_while_locked local_delete_while_locked.c
	-ssh -tt root@$(SERVER) service nfs-ganesha-gpfs restart
	-mkdir ./deletewhilelockedtest.mnt
	sudo mount -t nfs -o noac,vers=3 ${SERVER}:${EXPORTDIR} ./deletewhilelockedtest.mnt
	-cd ./deletewhilelockedtest.mnt
	sudo ./local_delete_while_locked ./locallocktest.file ${SERVER} ${EXPORTDIR} > ${TMPDIR}/localdeletewhilelockedtest.results 2>&1
	-cd ..
	-sleep 1
	-sudo umount -f ./deletewhilelockedtest.mnt
	-sudo rmdir ./deletewhilelockedtest.mnt
	-sudo mkdir ${XMLDEST}
	-sudo ruby ./parse_local_delete_while_locked.rb ${XMLDEST} ${TMPDIR}
