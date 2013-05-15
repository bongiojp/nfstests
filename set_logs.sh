#!/usr/bin/perl 

if ($ARGV[0] eq "on") {
print `/ftdc/snmp_log.pl set_log_level COMPONENT_DISPATCH NIV_FULL_DEBUG`;
# print `/ftdc/snmp_log.pl set_log_level COMPONENT_NFSPROTO NIV_FULL_DEBUG`;
print `/ftdc/snmp_log.pl set_log_level COMPONENT_RPC NIV_FULL_DEBUG`;
# print `/ftdc/snmp_log.pl set_log_level COMPONENT_CACHE_INODE NIV_FULL_DEBUG`;
# print `/ftdc/snmp_log.pl set_log_level COMPONENT_FSAL NIV_FULL_DEBUG`;
}

if ($ARGV[0] eq "off") {
print `/ftdc/snmp_log.pl set_log_level COMPONENT_DISPATCH NIV_EVENT`;
print `/ftdc/snmp_log.pl set_log_level COMPONENT_NFSPROTO NIV_EVENT`;
print `/ftdc/snmp_log.pl set_log_level COMPONENT_RPC NIV_EVENT`;
print `/ftdc/snmp_log.pl set_log_level COMPONENT_CACHE_INODE NIV_EVENT`;
print `/ftdc/snmp_log.pl set_log_level COMPONENT_FSAL NIV_EVENT`;
}
