#!/bin/sh

RPC_IP=192.168.11.99
PORT_NUM=8

PORT=$1
CMD=$2

usage()
{
	echo 1>&2 "Usage: power.sh PORT [on|off|status]"
	exit 1
}

if [ $# -ne 2 ]; then
	usage
fi

if [ ${PORT} -lt 1 -o ${PORT} -gt ${PORT_NUM} ]; then
	echo 1>&2 "Available port number: 1-${PORT_NUM}"
	exit 1
fi

case $CMD in
[Oo][Nn]|[Oo][Ff][Ff])
	( printf "1\r${CMD} ${PORT}\r"; sleep 3; printf "logout\r" ) | nc ${RPC_IP} 23 | grep "Outlet ${PORT}"
	;;
[Ss][Tt][Aa][Tt][Uu][Ss])
	( printf "1\rlogout\r" ) | nc ${RPC_IP} 23 | grep "Outlet ${PORT}"
	;;
*)
	usage
	;;
esac
