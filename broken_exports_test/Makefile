all: readdirplus_test

readdirplus_test: dbench
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
	-sudo ./broken_exports.pl ${SERVER} ${EXPORTDIR} ../dbench/ > ${TMPDIR}/broken_exports.results 2>&1
	-sudo ruby ./parse_broken_exports.rb ${XMLDEST} ${TMPDIR}

dbench::
	cd .. && make dbench
