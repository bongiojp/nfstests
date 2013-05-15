#!/bin/bash -x

if [ $# -ne 3 ]; then
    echo "Usage: $0 xmldestination hostname nodename"
    exit
fi

XMLDEST=$1 # destination where junit xml files should go
SERVER=$2 # Ganesha server to tell tests about
EXPORTDIR=$3
TMPDIR="/tmp"

#####################################################################
# Run bad exports test
echo "RUNNING BAD EXPORTS TEST ...\n";
echo "--------------------------------------------------\n";
ssh -tt root@${SERVER} service nfs-ganesha-gpfs restart

cd ./broken_exports_test
sudo ./broken_exports.pl ${SERVER} ${EXPORTDIR} > ${TMPDIR}/broken_exports.results 2>&1

#parse the output
sudo ruby ./parse_broken_exports.rb ${XMLDEST} ${TMPDIR}
cd ..

#####################################################################
# Run duplicate request test
echo "RUNNING DUPLICATE REQUEST TEST ...\n";
echo "--------------------------------------------------\n";
sudo killall dupreq_check
ssh -tt root@${SERVER} service nfs-ganesha-gpfs restart

cd ./dupreq_test
if [[ ! -e ./dupreq_check ]]; then
    make
    if [ "$?" -ne 0 ]; then
	echo "FAIL: Could not compile dupreq_check program."
	exit 1
    fi
fi

sudo ./dupreq_check -h ${SERVER} -d ${EXPORTDIR} -C &> ${TMPDIR}/dupreq_check-C

#parse the output
sudo ./c-toxml.rb ${XMLDEST} ${TMPDIR}
cd ..

#####################################################################
# Run xid collision test
echo "RUNNING XID COLLISION TEST ...\n";
echo "--------------------------------------------------\n";
sudo killall dupreq_check
ssh -tt root@${SERVER} service nfs-ganesha-gpfs restart

cd ./dupreq_test
if [[ ! -e ./dupreq_check ]]; then
    make
    if [ "$?" -ne 0 ]; then
	echo "FAIL: Could not compile dupreq_check program."
	exit 1
    fi
fi

sudo ./dupreq_check -h ${SERVER} -d ${EXPORTDIR} -D &> ${TMPDIR}/dupreq_check-D

#parse the output
sudo ./d-toxml.rb ${XMLDEST} ${TMPDIR}
cd ..

#####################################################################
# Run delete while locked test w/ shared lock
echo "RUNNING DELETE WHILE SHARE LOCKED TEST ...\n"
echo "--------------------------------------------------\n";
ssh -tt root@${SERVER} service nfs-ganesha-gpfs restart

if [[ ! -e ./dbench/comm_create ]]; then
   cd ./dbench;
   ./autogen.sh && ./configure && make
   if [ "$?" -ne 0 ]; then
       echo "FAIL: Could not compile dbench and accompanying command programs."
       exit 1
   fi
   cd ..
fi

cd ./delete_while_locked_test/
if [[ ! -d ./sharedlocktest.mnt ]]; then
    mkdir ./exclusivelocktest.mnt
fi

sudo ./delete_while_locked.pl ${SERVER} ${EXPORTDIR} /exclusivelocktest.file ./exclusivelocktest.mnt EXCLUSIVE ../dbench &> ${TMPDIR}/exclusivelocktest.results
if [ $? -ne 0 ]; then
    echo "FAIL: delete while locked test returned failure."
fi

if [[ -e ./sharedlocktest.mnt/exclusivelocktest.file ]]; then
    rm -f ./sharedlocktest.mnt/exclusivelocktest.file
fi

if [[ -d ./sharedlocktest.mnt ]]; then
    sleep 1
    sudo umount ./exclusivelocktest.mnt
    sudo rmdir ./exclusivelocktest.mnt
fi

#parse the output
sudo ./parse_delete_while_locked.rb ${XMLDEST} ${TMPDIR} EXCLUSIVE
cd ..

#####################################################################
# Run delete while locked test w/ exclusive lock
echo "RUNNING DELETE WHILE EXCLUSIVE LOCKED TEST ...\n"
echo "--------------------------------------------------\n"
ssh -tt root@${SERVER} service nfs-ganesha-gpfs restart

if [[ ! -e ./dbench/comm_create ]]; then
   cd ./dbench;
   ./autogen.sh && ./configure && make
   if [ "$?" -ne 0 ]; then
       echo "FAIL: Could not compile dbench and accompanying command programs."
       exit 1
   fi
   cd ..
fi

cd ./delete_while_locked_test/
if [[ ! -d ./sharedlocktest.mnt ]]; then
    mkdir ./exclusivelocktest.mnt
fi

sudo ./delete_while_locked.pl ${SERVER} ${EXPORTDIR} /sharedlocktest.file ./sharedlocktest.mnt SHARED ../dbench &> ${TMPDIR}/sharedlocktest.results
if [ $? -ne 0 ]; then
    echo "FAIL: delete while locked test returned failure."
fi

if [[ -e ./sharedlocktest.mnt/sharedlocktest.file ]]; then
    rm -f ./sharedlocktest.mnt/sharedlocktest.file
fi

if [[ -d ./sharedlocktest.mnt ]]; then
    sleep 1
    sudo umount ./sharedlocktest.mnt
    sudo rmdir ./sharedlocktest.mnt
fi

#parse the output
sudo ./parse_delete_while_locked.rb ${XMLDEST} ${TMPDIR} SHARED
cd ..

#####################################################################