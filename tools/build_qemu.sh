#!/bin/ksh93

set -e

DISK=$PWD/qemu-setup/illumos-disk.img
POOL=armpool			# Must match build_image
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=8g
BE_UUID=`/usr/bin/uuidgen`

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

if [ ! -f $PWD/illumos-gate/proto/root_aarch64/boot/loader64.efi ]; then
	print -u2 "loader64.efi not found in proto area"
	exit 2
fi

if [ ! -f $PWD/build/u-boot-qemu/u-boot.bin ]; then
	print -u2 "u-boot-qemu/u-boot.bin not found in build area"
	exit 2
fi

if [[ $(zonename) != global ]]; then
	print -u2 "$0 should be run in the global zone"
	exit 2
fi

mkdir -p $PWD/qemu-setup

mkfile $DISKSIZE $DISK
BLK_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BLK_DEVICE/dsk/rdsk}
FAT_RAW=${RAW_DEVICE/p0/s0}
FAT_BLK=${BLK_DEVICE/p0/s0}

print "Building a GPT-partitioned image"
sudo zpool create -B -t $POOL -m $MNT $POOL ${BLK_DEVICE%p0}

print "Populating root"

sudo zfs create -o canmount=noauto -o mountpoint=legacy $POOL/ROOT

pv < out/illumos.zfs | sudo zfs receive -u $POOL/$ROOTFS
sudo zfs set canmount=noauto $POOL/$ROOTFS
sudo zfs set mountpoint=legacy $POOL/$ROOTFS
sudo zfs set org.opensolaris.libbe:uuid=$BE_UUID $POOL/$ROOTFS
sudo zfs set org.opensolaris.libbe:policy=static $POOL/$ROOTFS

sudo zfs create -sV 1G $POOL/swap
sudo zfs create -V 1G $POOL/dump

sudo zpool set bootfs=$POOL/$ROOTFS $POOL
sudo zpool set cachefile="" $POOL
sudo zfs set canmount=noauto $POOL
sudo zfs set mountpoint=/$POOL $POOL
sudo zpool export $POOL

print "Populating boot"
# Format the FAT partition and copy in the boot files.
yes | sudo mkfs -F pcfs -o fat=32,b=bootfs $FAT_RAW
sudo mount -F pcfs $FAT_BLK $MNT
mkdir -p $MNT/EFI/BOOT
cp $PWD/illumos-gate/proto/root_aarch64/boot/loader64.efi \
    $MNT/EFI/BOOT/bootaa64.efi
sudo umount $MNT

sudo lofiadm -d $DISK
cp build/u-boot-qemu/u-boot.bin qemu-setup
