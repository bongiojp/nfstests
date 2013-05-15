all: dbench gpfsstableflag_test

gpfsstableflag_test: dbench
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
	-sudo ./test_stableflag_on_gpfs.pl ${SERVER} ${EXPORTDIR} /gpfsstableflagtestfile ../dbench/ > ${TMPDIR}/gpfsstableflagtest.results 2>&1
	-sudo ./parse_gpfsstableflag_test.rb ${XMLDEST} ${TMPDIR} 2>&1

dbench::
	cd .. && make dbench
