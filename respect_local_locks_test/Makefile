all: readdirplus_test

readdirplus_test: lock
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

	-mkdir ./mount.locktests
	-sudo ./respect_local_locks_test.pl  ${SERVER} ${EXPORTDIR} /filename.locktests ./mount.locktests > ${TMPDIR}/respect_local_locks.results 2>&1
	-sudo ruby ./parse_respect_local_locks_test.rb ${XMLDEST} ${TMPDIR}

lock:
	gcc -o lock lock.c