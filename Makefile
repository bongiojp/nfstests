DIRS =	delete_while_locked_test \
	dupreq_test \
	delete_behavior_test \
	readdirplus_test \
	respect_local_locks_test \
	fdleak_test
#	broken_exports_test \
#	export_access_list_test \

#	permissions_test \



INJECT_DIRS =	long_running_task

#SERVER should be defined
#EXPORTDIR should be defined
#XMLDEST should be defined
#TMPDIR should be defined

all: $(DIRS)

inject: $(INJECT_DIRS)

$(INJECT_DIRS)::
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
	TMPDIR=/tmp make -C $@ all

$(DIRS)::
#	-sudo yum install autoconf libtool automake zlib-devel -y
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
	TMPDIR=/tmp make -C $@ all
dbench::
	cd ./dbench && ./autogen.sh && ./configure
	make -C ./dbench
