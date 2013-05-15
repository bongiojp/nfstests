#!/bin/bash -x
#
# Copyright IBM  (2012)
# Author(s): Jeremy Bongio   jbongio@us.ibm.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
# ---------------------------------------

source $HOME/scripts/CONFIG

SERVER=$1
HOSTFS=$2

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel60/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel60/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel60/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel55/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel55/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel55/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel55_32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel55_32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/rhel55_32/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/ubuntu32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/ubuntu32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/root/ubuntu32/nfsv4tcp

ssh -tt root@$HOST chown root $HOSTFS/hudson64/root -R
ssh -tt root@$HOST chgrp root $HOSTFS/hudson64/root -R

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel60/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel60/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel60/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel55/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel55/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel55/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel55_32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel55_32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/rhel55_32/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/ubuntu32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/ubuntu32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson64/jenkins/ubuntu32/nfsv4tcp

ssh -tt root@$HOST chown jenkins $HOSTFS/hudson64/jenkins -R
ssh -tt root@$HOST chgrp jenkins $HOSTFS/hudson64/jenkins -R




ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel60/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel60/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel60/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel55/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel55/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel55/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel55_32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel55_32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/rhel55_32/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/ubuntu32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/ubuntu32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/root/ubuntu32/nfsv4tcp

ssh -tt root@$HOST chown root $HOSTFS/hudson/root -R
ssh -tt root@$HOST chgrp root $HOSTFS/hudson/root -R

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel60/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel60/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel60/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel55/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel55/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel55/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel55_32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel55_32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/rhel55_32/nfsv4tcp

ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/ubuntu32/nfsv3tcp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/ubuntu32/nfsv3udp
ssh -tt root@$HOST mkdir -p $HOSTFS/hudson/jenkins/ubuntu32/nfsv4tcp

ssh -tt root@$HOST chown jenkins $HOSTFS/hudson/jenkins -R
ssh -tt root@$HOST chgrp jenkins $HOSTFS/hudson/jenkins -R
