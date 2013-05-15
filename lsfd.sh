LOGFILE=/ftdc/ls.out5

while true;
do date | tee -a $LOGFILE;
X=`ls -l /proc/\`pidof /usr/bin/gpfs.ganesha.nfsd\`/fd |wc -l 2>&1`
echo "file descriptors: ${X}" | tee -a $LOGFILE;
X=`ps -p \`pidof /usr/bin/gpfs.ganesha.nfsd\` -o %mem | tail -n 1`
echo "memory usage: ${X}" | tee -a $LOGFILE;

#cache_nb_entries
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.1.2.1`
echo "cache_nb_entries: ${X}" | tee -a $LOGFILE;
#cache_min_rbt_num_node
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.2.2.1`
echo "cache_min_rbt_num_node: ${X}" | tee -a $LOGFILE;
#cache_max_rbt_num_node
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.3.2.1`
echo "cache_max_rbt_num_node: ${X}" | tee -a $LOGFILE;
#workers_nb_udp_req
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.6.2.1`
echo "workers_nb_udp_req: ${X}" | tee -a $LOGFILE;
#workers_nb_tcp_req
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.7.2.1`
echo "workers_nb_tcp_req: ${X}" | tee -a $LOGFILE;
#workers_nb_mnt1_req
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.8.2.1`
echo "workers_nb_mnt1_req: ${X}" | tee -a $LOGFILE;
#workers_nb_mnt3_req
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.9.2.1`
echo "workers_nb_mnt3_req: ${X}" | tee -a $LOGFILE;
#total_pending_requests
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.15.2.1`
echo "total_pending_requests: ${X}" | tee -a $LOGFILE;
#dupreq_nb_entries
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.17.2.1`
echo "dupreq_nb_entries: ${X}" | tee -a $LOGFILE;
#dupreq_min_rbt_num_node
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.18.2.1`
echo "dupreq_min_rbt_num_node: ${X}" | tee -a $LOGFILE;
#dupreq_max_rbt_num_node
X=`snmpwalk -Os -c ganesha -v 1 localhost -Oq -Ov enterprises.12384.999.2.0.19.2.1`
echo "dupreq_max_rbt_num_node: ${X}" | tee -a $LOGFILE;

X=`mmdf fs2`
echo "RESULT of mmdf fs2:"
echo "${X}" | tee -a $LOGFILE
X=`mmdf fs1`
echo "RESULT of mmdf fs1:"
echo "${X}" | tee -a $LOGFILE

sleep 10;
done 

