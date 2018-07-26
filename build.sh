#!/bin/sh

export SSL_CA_CERT_FILE=/usr/local/share/certs/ca-root-nss.crt

if [ -z "${SVN_REVISION}" ]; then
	echo "No subversion revision specified"
	exit 1
fi

if [ -z "${WORKSPACE}" ]; then
	echo "No WORKSPACE defined"
	exit 1
fi

export FBSD_BRANCH=head
export TARGET=arm64
export TARGET_ARCH=aarch64

export DIST_PACKAGES="base kernel tests"
export ARTIFACTS_DIR=${WORKSPACE}/artifact

export IMG_NAME=RPi3.img
export IMGBASE=${WORKSPACE}/${IMG_NAME}

export SD_DEV=/dev/da0
export USB_DEV=0.3

script_base=$(dirname $(realpath $0))

sh -ex ${script_base}/fetch-artifact.sh
sudo -E sh -ex ${script_base}/create-image.sh

sh -ex ${script_base}/swtich-sd.sh 1
sudo usbconfig -d ${USB_DEV} power_off
sudo usbconfig -d ${USB_DEV} power_on
sleep 2
sudo sh -c "pv ${IMGBASE} > /dev/da0"

${script_base}/power.sh 1 off
sh -ex ${script_base}/swtich-sd.sh 2
${script_base}/power.sh 1 on

set +e
expect -c "\
set timeout 300; \
spawn sudo cu -s 115200 -l /dev/cuaU0; \
expect \"login:\" { send \"\r~.\r\" }
expect timeout { return 1 }
"
set -e
rc=$?

${script_base}/power.sh 1 off
exit $rc
