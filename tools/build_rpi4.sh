#!/bin/ksh93

DISK=$PWD/rpi4-setup/illumos-disk.img
POOL=armpool			# Must match build_image
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=4g
BE_UUID=`/usr/bin/uuidgen`

USAGE="[+NAME?build_rpi4 --- create a disk image for a Raspberry Pi 4]"

typeset -i MBR=0

while getopts "$USAGE" opt; do
	case $opt in
	    e)	;;
	    m)	MBR=1 ;;
	esac
done

if ((MBR != 0)); then
	print -u2 "$0: The --mbr argument is no longer supported"
	exit 2
fi

set -e

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

if [ ! -f $PWD/illumos-gate/proto/root_aarch64/boot/loader64.efi ]; then
	print -u2 "loader64.efi not found in proto area"
	exit 2
fi

if [ ! -f $PWD/build/u-boot-rpi4/u-boot.bin ]; then
	print -u2 "u-boot-rpi4/u-boot.bin not found in build area"
	exit 2
fi

if [[ $(zonename) != global ]]; then
	print -u2 "$0 should be run in the global zone"
	exit 2
fi

# Populate the boot directory, which contains the files that should be copied
# to the first (FAT) partition on the SD card.

boot=$PWD/rpi4-setup/boot
rm -rf $boot
mkdir -p $boot

cat <<EOM > $boot/config.txt
arm_boost=1
gpu_mem=16
start_file=start4cd.elf
fixup_file=fixup4cd.dat
arm_64bit=1
enable_gic=1
armstub=bl31.bin
kernel=u-boot.bin
dtoverlay=mmc
dtoverlay=disable-wifi
# The following two lines disable the mini UART and set the first PL011 UART as
# the primary UART - that which is presented on GPIO14/GPIO15. The mini UART
# is less capable and its baud rate is linked to the VCPU clock speed.
enable_uart=1
dtoverlay=disable-bt
EOM

cp build/arm-trusted-firmware/build/rpi4/debug/bl31.bin $boot/

cp build/u-boot-rpi4/u-boot.bin $boot/

for f in \
	COPYING.linux \
	LICENCE.broadcom \
	bootcode.bin \
	fixup4cd.dat \
	start4cd.elf \
	bcm2711-rpi-4-b.dtb
do
	cp src/firmware-1.20*/boot/$f $boot/
done

mkdir -p $boot/overlays
cp src/firmware-1.20*/boot/overlays/* $boot/overlays

mkdir -p $boot/EFI/BOOT
cp $PWD/illumos-gate/proto/root_aarch64/boot/loader64.efi \
    $boot/EFI/BOOT/bootaa64.efi

mkfile $DISKSIZE $DISK
BLK_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BLK_DEVICE/dsk/rdsk}

print "Building a GPT-partitioned image"

# This is the easier option, we can just use the -B option to zpool
# to get it to create an initial FAT partition for us.
sudo zpool create \
    -B -o bootsize=256M \
    -t $POOL -m $MNT $POOL ${BLK_DEVICE%p0}

FAT_RAW=${RAW_DEVICE/p0/s0}
FAT_BLK=${BLK_DEVICE/p0/s0}

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
{ cd $boot; find . | sudo cpio -pmud $MNT 2>/dev/null || true; cd -; }
sudo umount $MNT

sudo lofiadm -d $DISK

