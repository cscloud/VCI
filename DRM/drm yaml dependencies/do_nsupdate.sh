#!/bin/bash

#set -x 
function print_usage() {
echo 'do_nsupdate.sh version 1.02           June 16 2014'
echo '=================================================='
echo
echo 'do_nsupdate.sh -N <hostname_or_alias> -A -D -R <record_type> -I <Ip_adress>'
echo '               -E <eth_device> -L <logger_tag> -hH?'
echo ' '
echo '-N  <hostname_or_alias> : Required parameter.'
echo '-A  flag indicates to add the record to the nameserver'
echo '-D  flag indicates to delete the record from the nameserver'
echo '    Must use either -A or -D'
echo '-R  <Record_type>. Either "A" or "CNAME" record'
echo '    "A" is for the master record in the DNS server.'
echo '    "A" would be used for either the guest, or for a LB-VIP'
echo '    "CNAME" is for additional aliases added to an existing host'
echo '    "CNAME" would be used for providing a shorter host name to a guest'
echo '-I  <IP> Only used when requesting an "A" record'
echo '    If IP is empty, and "A" record is requested, then use local guest IP'
echo '-E  <eth_device> Only used when requesting an "A" record and not providing'
echo '    IP address (-I <ip_address> ). eth_device can be eth0 to ethX'
echo '    If IP is empty, and "A" record is requested, then use local guest IP'
echo '    eth0 by default will be queried for IP'
echo '-L  <Logger_tag> Optional param for sending messages to /var/log/messages'
echo '    If -P used and -R not set, default retries will be 3'
echo '-h  print usage'
echo '-H  print usage'
echo '-?  print usage'
}

if [ $# -lt 2 ]
then
    print_usage
    exit
fi

HOSTALIAS=EMPTY
METHOD=EMPTY
IP=EMPTY
RECORD=EMPTY
LOGGER=EMPTY
ETH=eth0

while getopts  "N:ADI:R:L:E:hH?" flag
do
    case $flag in

    N)  HOSTALIAS=$OPTARG;;   	# Either hostname, or hostalias
    A)  METHOD="add";;		# ADD the host to the nameserver
    D)  METHOD="delete" ;;	# Delete the host from the nameserver
    I)  IP=$OPTARG ;;		# Use this IP instead of localIP
                                #     IP is an optional argument
    R)  RECORD=$OPTARG ;;	# DNS record type, either 'A' or CNAME   
    L)  LOGGER=$OPTARG ;;	# Enable logger messages using LOGGER tag
    E)  ETH=$OPTARG ;;		# ETH device to use for ifconfig query
    h|H|?)
        print_usage
	exit 0;;
    esac
done

if [ x"${METHOD}" != xadd -a x"${METHOD}" != xdelete ]
then
    print_usage
    echo 'MUST use either -A or -D flag'
    exit
fi

if [ x"${HOSTALIAS}" = x -o  x"${HOSTALIAS}" = xEMPTY ]
then
    print_usage
    echo "MUST use -N <hostalias>"
    exit
fi

if [ x"${RECORD}" = x -o  x"${RECORD}" = xEMPTY ]
then
    print_usage
    echo "MUST use -R <record_type>"
    exit
fi

if [ x"${RECORD}" != xA -a x"${RECORD}" != xCNAME ]
then
    print_usage
    echo "Record_type must be either 'A' or 'CNAME'"
    exit
fi

if [ x"${IP}" = xEMPTY -a x"${RECORD}" = xA ]
then
    IP=`ifconfig ${ETH} | sed "/^[      ]*inet addr/ !d" | cut -f2 -d':' | awk '{print $1}'`
fi

DOMAIN_NAME=`grep -m 1 search /etc/resolv.conf | awk '{print $2}'`

NAMESERVER=`grep -m 1 nameserver /etc/resolv.conf | awk '{print $2}'`

if [ -f /opt/nds/custom_tools/etc/project.cfg ]
then
    HOSTNAME=`hostname | cut -f1 -d'.'`'.'`cat /opt/nds/custom_tools/etc/project.cfg`'.'"${DOMAIN_NAME}"
else
    HOSTNAME=`hostname | cut -f1 -d'.'`".${DOMAIN_NAME}"
fi

if [ x"${NAMESERVER}" != x ]
then
    if [ x"$IP" = xEMPTY ]
    then
nsupdate 1>/dev/null 2>&1 <<EOF
server ${NAMESERVER}
update ${METHOD} ${HOSTALIAS}.${DOMAIN_NAME} 300 ${RECORD} ${HOSTNAME} 
show
send
EOF
        if [ x"${LOGGER}" != xEMPTY ]
        then
	    logger -t "${LOGGER}" "Update nameserver ${NAMESERVER} : update ${METHOD} ${HOSTALIAS}.${DOMAIN_NAME} 300 ${RECORD} ${HOSTNAME}"
	fi
    else
	case ${METHOD} in
	add) 
nsupdate 1>/dev/null 2>&1 <<EOF
server ${NAMESERVER}
update ${METHOD} ${HOSTALIAS}.${DOMAIN_NAME} 300 ${RECORD} ${IP} 
show
send
EOF
        if [ x"${LOGGER}" != xEMPTY ]
        then
	    logger -t "${LOGGER}" "Update nameserver ${NAMESERVER} : update ${METHOD} ${HOSTALIAS}.${DOMAIN_NAME} 300 ${RECORD} ${IP}"
	fi;;
	delete)
nsupdate 1>/dev/null 2>&1 <<EOF
server ${NAMESERVER}
update ${METHOD} ${HOSTALIAS}.${DOMAIN_NAME} ${RECORD} 
show
send
EOF
        if [ x"${LOGGER}" != xEMPTY ]
        then
	    logger -t "${LOGGER}" "Update nameserver ${NAMESERVER} : update ${METHOD} ${HOSTALIAS}.${DOMAIN_NAME} ${RECORD}"
	fi;;
        esac
    fi
fi
