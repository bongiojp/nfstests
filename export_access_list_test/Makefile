all: exportaccesslist_test

exportaccesslist_test:
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
	echo "Backing up exports configuration file on server."
	-scp root\@${SERVER}:/etc/ganesha/gpfs.ganesha.exports.conf gpfs.ganesha.exports.conf.bak 2>&1

	echo "Commencing test ..."
	-sudo ./test_export_access_list.pl ${SERVER} ${EXPORTDIR} /exportaccesslistfile > ${TMPDIR}/exportliststest.results 2>&1
	-sudo ./parse_export_access_list.rb ${XMLDEST} ${TMPDIR} 2>&1

	echo "Restoring exports configuration file on server with backup copy."
	-scp ./gpfs.ganesha.exports.conf.bak root\@${SERVER}:/etc/ganesha/gpfs.ganesha.exports.conf 2>&1
