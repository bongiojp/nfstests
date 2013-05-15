all: fdleak_test

fdleak_test:
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
	-mkdir ./temp 2>&1
	-sudo mount -t nfs -o proto=tcp,vers=3 ${SERVER}:${EXPORTDIR} ./temp 2>&1
	-sudo ./test_fdleak.pl ${SERVER} ${EXPORTDIR} ./temp > ${TMPDIR}/fdleaktest.results 2>&1
	-sudo umount -f -l ./temp 2>&1
	-sudo ./parse_fdleak_test.rb ${XMLDEST} ${TMPDIR} 2>&1