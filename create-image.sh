#!/bin/sh

WORKDIR=${WORKSPACE}

DESTDIR=${WORKSPACE}/dest

DTB_DIR="/usr/local/share/rpi-firmware"
DTB="bcm2710-rpi-3-b.dtb"
EMBEDDED_TARGET_ARCH="aarch64"
EMBEDDED_TARGET="arm64"
EMBEDDEDBUILD=1
EMBEDDEDPORTS="sysutils/u-boot-rpi3 sysutils/rpi-firmware"
FAT_SIZE="50m -b 1m"
FAT_TYPE="16"
IMAGE_SIZE="2560M"
KERNEL="GENERIC"
MD_ARGS="-x 63 -y 255"
NODOC=1
OL_DIR="${DTB_DIR}/overlays"
OVERLAYS="mmc.dtbo pwm.dtbo pi3-disable-bt.dtbo"
PART_SCHEME="MBR"
export BOARDNAME="RPI3"

umount_loop() {
	DIR=$1
	i=0
	sync
	while ! umount ${DIR}; do
		i=$(( $i + 1 ))
		if [ $i -ge 10 ]; then
			# This should never happen.  But, it has happened.
			echo "Cannot umount(8) ${DIR}"
			echo "Something has gone horribly wrong."
			return 1
		fi
		sleep 1
	done

	return 0
}

arm_install_uboot() {
	UBOOT_DIR="/usr/local/share/u-boot/u-boot-rpi3"
	UBOOT_FILES="README u-boot.bin"
	DTB_FILES="armstub8.bin bootcode.bin fixup_cd.dat \
		fixup_db.dat fixup_x.dat fixup.dat LICENCE.broadcom \
		start_cd.elf start_db.elf start_x.elf start.elf ${DTB}"
	FATMOUNT="${DESTDIR%${KERNEL}}fat"
	UFSMOUNT="${DESTDIR%${KERNEL}}ufs"
	mkdir -p "${FATMOUNT}" "${UFSMOUNT}"
	mount_msdosfs /dev/${mddev}s1 ${FATMOUNT}
	mount /dev/${mddev}s2a ${UFSMOUNT}
	for _UF in ${UBOOT_FILES}; do
		cp ${UBOOT_DIR}/${_UF} \
			${FATMOUNT}/${_UF}
	done
	for _DF in ${DTB_FILES}; do
		cp ${DTB_DIR}/${_DF} \
			${FATMOUNT}/${_DF}
	done
	cp ${DTB_DIR}/config_rpi3.txt \
			${FATMOUNT}/config.txt
	mkdir -p ${FATMOUNT}/overlays
	for _OL in ${OVERLAYS}; do
		cp ${OL_DIR}/${_OL} \
			${FATMOUNT}/overlays/${_OL}
	done

	BOOTFILES="$(realpath ${BOOTFILES})"

	mkdir -p ${FATMOUNT}/EFI/BOOT
	#cp -p ${BOOTFILES}/efi/loader/loader.efi \
	#	${FATMOUNT}/EFI/BOOT/bootaa64.efi
	cp ${UFSMOUNT}/boot/loader.efi \
		${FATMOUNT}/EFI/BOOT/bootaa64.efi
	touch ${UFSMOUNT}/firstboot
	sync
	umount_loop ${FATMOUNT}
	umount_loop ${UFSMOUNT}
	#rmdir ${FATMOUNT}
	#rmdir ${UFSMOUNT}
	
	return 0
}

arm_create_disk() {
	# Create the target raw file and temporary work directory.
	gpart create -s ${PART_SCHEME} ${mddev}
	#gpart add -t fat32lba -a 512k -s ${FAT_SIZE} ${mddev}
	gpart add -t '!12' -a 512k -s ${FAT_SIZE} ${mddev}
	gpart set -a active -i 1 ${mddev}
	newfs_msdos -L msdosboot -F ${FAT_TYPE} /dev/${mddev}s1
	gpart add -t freebsd ${mddev}
	gpart create -s bsd ${mddev}s2
	gpart add -t freebsd-ufs -a 64k /dev/${mddev}s2
	newfs -U -L rootfs /dev/${mddev}s2a

	return 0
}

arm_create_user() {
	# Create a default user account 'freebsd' with the password 'freebsd',
	# and set the default password for the 'root' user to 'root'.
	/usr/sbin/pw -R ${DESTDIR} \
		groupadd freebsd -g 1001
	mkdir -p ${DESTDIR}/home/freebsd
	/usr/sbin/pw -R ${DESTDIR} \
		useradd freebsd \
		-m -M 0755 -w yes -n freebsd -u 1001 -g 1001 -G 0 \
		-c 'FreeBSD User' -d '/home/freebsd' -s '/bin/csh'
	/usr/sbin/pw -R ${DESTDIR} \
		usermod root -w yes

	return 0
}

arm_install_base() {
	mount /dev/${mddev}s2a ${DESTDIR}

	for f in ${DIST_PACKAGES}
	do
		tar Jxf ${ARTIFACTS_DIR}/${f}.txz -C ${DESTDIR}
	done

	mkdir -p ${DESTDIR}/boot/msdos

	arm_create_user

	echo 'boot_multicons="YES"' >> ${DESTDIR}/boot/loader.conf
	echo 'boot_serial="YES"' >> ${DESTDIR}/boot/loader.conf

	cat > ${DESTDIR}/etc/fstab << EOF
# Custom /etc/fstab for FreeBSD embedded images
/dev/ufs/rootfs   /       ufs     rw      1       1
/dev/msdosfs/MSDOSBOOT /boot/msdos msdosfs rw,noatime 0 0
tmpfs /tmp tmpfs rw,mode=1777,size=50m 0 0
EOF

	local hostname
	hostname="$(echo ${KERNEL} | tr '[:upper:]' '[:lower:]')"
	echo "hostname=\"${hostname}\"" > ${DESTDIR}/etc/rc.conf
	echo 'ifconfig_DEFAULT="DHCP"' >> ${DESTDIR}/etc/rc.conf
	echo 'sshd_enable="YES"' >> ${DESTDIR}/etc/rc.conf
	echo 'sendmail_enable="NONE"' >> ${DESTDIR}/etc/rc.conf
	echo 'sendmail_submit_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	echo 'sendmail_outbound_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	echo 'sendmail_msp_queue_enable="NO"' >> ${DESTDIR}/etc/rc.conf
	echo 'growfs_enable="YES"' >> ${DESTDIR}/etc/rc.conf

	sync
	umount_loop ${DESTDIR}

	return 0
}

mkdir -p ${DESTDIR}
rm -f ${IMGBASE}
truncate -s ${IMAGE_SIZE} ${IMGBASE}
mddev=$(mdconfig -f ${IMGBASE} ${MD_ARGS})

arm_create_disk
arm_install_base
arm_install_uboot

mdconfig -d -u ${mddev}
