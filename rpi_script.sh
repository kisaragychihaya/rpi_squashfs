#!/bin/bash
if [ ! -f "/proc/device-tree/model" ]; then
  echo "Pls Run this script on RPi"
  exit 2
fi
if [[ "$(cat /proc/device-tree/model | grep \"Raspberry\")" == "" ]]；then
  echo "Pls Run this script on RPi"
  exit 2
fi
if [ -z "$(cat /proc/filesystems | grep squashfs)" ];then
  echo "Kernel DOES NOT  SUPPORT squashfs"
  echo "Compile And Install First"
  echo "https://www.raspberrypi.com/documentation/computers/linux_kernel.html"
  exit 2
fi
KERN=$(uname -r)
INITRD=initrd.img-"$KERN"-overlay

cat > /etc/initramfs-tools/scripts/overlay << EOF
# Local filesystem mounting			-*- shell-script -*-

#
# This script overrides local_mount_root() in /scripts/local
# and mounts root as a read-only filesystem with a temporary (rw)
# overlay filesystem.
#

. /scripts/local

local_mount_root()
{
	local_top
	local_device_setup "${ROOT}" "root file system"
	ROOT="${DEV}"

	# Get the root filesystem type if not set
	if [ -z "${ROOTFSTYPE}" ]; then
		FSTYPE=$(get_fstype "${ROOT}")
	else
		FSTYPE=${ROOTFSTYPE}
	fi

	local_premount

	# CHANGES TO THE ORIGINAL FUNCTION BEGIN HERE
	# N.B. this code still lacks error checking

	modprobe ${FSTYPE}
	checkfs ${ROOT} root "${FSTYPE}"

	# Create directories for root and the overlay
	mkdir /lower /upper /boot

	# Mount read-only root to /lower
	if [ "${FSTYPE}" != "unknown" ]; then
		mount -r -t ${FSTYPE} ${ROOTFLAGS} ${ROOT} /lower
	else
		mount -r ${ROOTFLAGS} ${ROOT} /lower
	fi
    log_begin_msg "checking /boot"
    echo "checking /boot"
    mount /dev/mmcblk0p1 /boot
    log_end_msg
    if [ -f "/boot/FIRST_BOOT" ]
    then
        mount -t tmpfs tmpfs /upper
        rm /boot/FIRST_BOOT
    else
        if [ -f "/boot/wipedata" ]
        then
            rm /boot/wipedata
            mount /dev/mmcblk0p3 /upper
            log_begin_msg "wiping data"
            echo "wiping data"
            mv /upper/data /upper/data.old
            mv /upper/work /upper/work.old
            rm -rf data.old
            rm -rf work.old
            mkdir -p /upper/data /upper/work
            log_end_msg
        else
            mount /dev/mmcblk0p3 /upper
        fi
    fi
    umount /dev/mmcblk0p1

	modprobe overlay || insmod "/lower/lib/modules/$(uname -r)/kernel/fs/overlayfs/overlay.ko"

	# Mount a tmpfs for the overlay in /upper
	mkdir -p /upper/data /upper/work
	# Mount the final overlay-root in $rootmnt
	mount -t overlay \
	    -olowerdir=/lower,upperdir=/upper/data,workdir=/upper/work \
	    overlay ${rootmnt}
}
EOF
if ! grep overlay /etc/initramfs-tools/modules > /dev/null; then
    echo overlay >> /etc/initramfs-tools/modules
fi
update-initramfs -c -k "$KERN"
