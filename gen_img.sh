if [ ! -b "$1" ]; then
  echo "请指定磁盘设备"
  exit 2
fi
set -e
SQUASHFS_START_SECTOR=$(fdisk -l $1 | grep Linux | awk '{print $2}')
#make boot partition
dd if=$1 of=base.img bs=1k count=$(($SQUASHFS_START_SECTOR/2))
mkdir -p /tmp/fat32
#mount and modify boot partition
BOOT_START_SECTOR=$(fdisk -l base.img | grep FAT32 | awk '{print $2}')
mount -o loop,offset=$(($BOOT_START_SECTOR*512)) base.img /tmp/fat32
INITRD_PATH=$(find /tmp/fat32 -name "initrd*")
INITRD=${INITRD_PATH##*/}
if [ ! -f "$INITRD_PATH" ]; then
  echo "没有找到引导镜像，请先生成"
  umount /tmp/fat32
  rm base.img
  exit 2
fi
sed -i /tmp/fat32/config.txt -e "/initramfs.*/d" 
echo initramfs "$INITRD" >> /tmp/fat32/config.txt
if ! grep -q "boot=overlay" /tmp/fat32/cmdline.txt ; then
    sed -i /tmp/fat32/cmdline.txt -e "s/^/boot=overlay /"
fi
sed -i /tmp/fat32/cmdline.txt -e 's/=PARTUUID=f1dd6903-02/=\/dev\/mmcblk0p2/g' 
sed -i /tmp/fat32/cmdline.txt -e 's/rootfstype=ext4/rootfstype=squashfs/g' 
sync
umount /tmp/fat32
mkdir -p /tmp/ext4
rm -rf /tmp/ext4/*
echo $(($SQUASHFS_START_SECTOR*512))
mount -o loop,offset=$(($SQUASHFS_START_SECTOR*512)) $1 /tmp/ext4
rm -r /tmp/fat32
cp src/expand_mmcblk0p3.sh /tmp/ext4/usr/local/bin/expandfs.sh
chmod 755 /tmp/ext4/usr/local/yiku/systool/expandfs.sh
mksquashfs  /tmp/ext4/*  rootfs.img -noI -noF -noX -processors $(($(nproc) + 1))
rm /tmp/ext4/usr/local/bin/expandfs.sh
SQUASHFS_SIZE=$(ls -l rootfs.img | awk '{print $5}')
PADDING_SIZE=$((4*1024*1024*1024-$SQUASHFS_SIZE))
PADDING_BLOCK=$(($PADDING_SIZE/512))
dd if=rootfs.img of=base.img bs=1k seek=$(($SQUASHFS_START_SECTOR/2)) status=progress
dd if=/dev/zero count=$PADDING_BLOCK bs=512 status=progress >> base.img
umount /tmp/ext4
fdisk base.img <<EOF

d
2
n
p
2
$SQUASHFS_START_SECTOR


w
EOF

SQUASHFS_END_SECTOR=$(fdisk -l base.img | grep Linux | awk '{print $3}')
OVERLAYFS_START_SECTOR=$(($SQUASHFS_END_SECTOR+1))
echo $(($SQUASHFS_END_SECTOR+1))
dd if=/dev/zero count=512 bs=1M status=progress >> base.img
fdisk base.img <<EOF

n
p
3
$OVERLAYFS_START_SECTOR

w
EOF
losetup -o $((512*$OVERLAYFS_START_SECTOR)) /dev/loop0 base.img
mkfs.ext4 /dev/loop0
losetup -d /dev/loop0
rm -r /tmp/ext4
rm rootfs.img
mv base.img rpi.img
