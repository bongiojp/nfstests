all: multinode_test

multinode_test:
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
	echo "./multinode_test.pl ${EXPORTDIR} /mnt/multinode ${SERVER} ${SERVER}"
	-sudo ./multinode_test.pl ${EXPORTDIR} /mnt/multinode ${SERVER} ${SERVER} > ${TMPDIR}/multinode_test.results 2>&1
	-sudo ruby ./parse_multinode_test.rb ${XMLDEST} ${TMPDIR}
