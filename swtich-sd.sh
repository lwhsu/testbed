#!/bin/sh

CONTROLLER_IP=192.168.11.98
ID=freebsd
KEY=/home/lwhsu/key/id_ed25519
GPIO_PIN=23

DEV=$1

usage()
{
	echo 1>&2 "Usage: switch-sd.sh [1|2]"
	exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

if [ ${DEV} -lt 1 -o ${DEV} -gt 2 ]; then
	echo 1>&2 "Available dev number: 1-2"
	exit 1
fi

OUTPUT=$(($DEV - 1))
ssh -l ${ID} -i ${KEY} ${CONTROLLER_IP} \
	"sudo gpioctl -c ${GPIO_PIN} OUT; sudo gpioctl ${GPIO_PIN} ${OUTPUT}"
sleep 2
