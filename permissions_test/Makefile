all: cprog permissions_test

permissions_test: cprog
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
	-sudo ./test_permissions.pl ${SERVER} ${EXPORTDIR} /mnt/permissions_test SHORTTEST > ${TMPDIR}/permissionstest.results 2>&1 
	-sudo ./parse_permissions_test.rb ${XMLDEST} ${TMPDIR} 2>&1

cprog:
	gcc myecho.c -o myecho
