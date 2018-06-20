#!/bin/sh

export SVN_REVISION=335462
export FBSD_BRANCH=head
export TARGET=arm64
export TARGET_ARCH=aarch64

export WORKSPACE=/home/lwhsu/workspace

export SSL_CA_CERT_FILE=/usr/local/share/certs/ca-root-nss.crt

export DIST_PACKAGES="base kernel tests"
export ARTIFACTS_DIR=${WORKSPACE}/artifact

export IMG_NAME=RPi3.img
export IMGBASE=${WORKSPACE}/${IMG_NAME}

export SD_DEV=/dev/da0
export USB_DEV=0.6

if [ -z "${SVN_REVISION}" ]; then
	echo "No subversion revision specified"
	exit 1
fi

sh -ex fetch-artifact.sh
sudo -E sh -ex create-image.sh

sh -ex swtich-sd.sh 1
sudo usbconfig -d ${USB_DEV} power_off
sudo usbconfig -d ${USB_DEV} power_on
sudo sh -c "pv ${IMGBASE} > /dev/da0"

./power.sh 1 off
sh -ex swtich-sd.sh 2
./power.sh 1 on

sudo cu -s 115200 -l /dev/cuaU0
