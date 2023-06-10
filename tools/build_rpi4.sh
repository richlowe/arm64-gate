#!/bin/ksh93

DISK=$PWD/rpi4-setup/illumos-disk.img
POOL=armpool
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=4g

set -e

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
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

cp illumos-gate/proto/root_aarch64/platform/RaspberryPi,4/inetboot $boot/

cp build/arm-trusted-firmware/build/rpi4/debug/bl31.bin $boot/

cp build/u-boot/u-boot.bin $boot/

for f in \
	COPYING.linux \
	LICENCE.broadcom \
	bootcode.bin \
	fixup4cd.dat \
	start4cd.elf \
	bcm2711-rpi-4-b.dtb
do
	cp src/firmware-1.*/boot/$f $boot/
done

mkdir -p $boot/overlays
cp src/firmware-1.*/boot/overlays/* $boot/overlays

#
#       -A id:act:bhead:bsect:bcyl:ehead:esect:ecyl:rsect:numsect

mkfile $DISKSIZE $DISK

BASE_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BASE_DEVICE/dsk/rdsk}
SLICE=${BASE_DEVICE/p0/s0}

# Here's the partition table for one of the official raspberry Pi images.
#
# * Id    Act  Bhead  Bsect  Bcyl    Ehead  Esect  Ecyl    Rsect      Numsect
#  12    0    0      1      64      3      32     1023    8192       524288
#  131   0    3      32     1023    3      32     1023    532480     3309568
#  0     0    0      0      0       0      0      0       0          0
#  0     0    0      0      0       0      0      0       0          0

FAT_SECTORS=524288
RESV_SECTORS=8192

# Create the required partition structure.
sudo fdisk -B $RAW_DEVICE

# Id Act Bhead Bsect Bcyl Ehead Esect Ecyl Rsect Numsect
set -- $(sudo fdisk -W - $RAW_DEVICE | awk '$1 == 191 { print }')
TOTAL_SECTORS=${10}

((ZPOOL_SECTORS = TOTAL_SECTORS - FAT_SECTORS - RESV_SECTORS))

#	id act bhead bsect bcyl ehead esect ecyl rsect numsect
tf=`mktemp`
# XXX come back and review this
cat <<-EOM > $tf
	12 0 0 1 64 3 32 1023 $RESV_SECTORS $FAT_SECTORS
	191 128 3 32 1023 3 32 1023 532480 $ZPOOL_SECTORS
EOM
sudo fdisk -F $tf $RAW_DEVICE
rm -f $tf

# Format the FAT partition
yes | sudo mkfs -F pcfs -o fat=32,b=bootfs $RAW_DEVICE:c
sudo mount -F pcfs $BASE_DEVICE:c $MNT
{ cd $boot; find . | sudo cpio -pmud $MNT 2>/dev/null || true; cd -; }
sudo umount $MNT

# Set up a VTOC in the second partition
# Taken from OmniOS kayak, note that this leaves s2 and s0 overlapping (which,
# well...) and so requires zpool create -f, which I don't like.
# Create slice 0 covering all of the non-reserved space
OIFS="$IFS"; IFS=" ="
set -- $(sudo prtvtoc -f $RAW_DEVICE)
IFS="$OIFS"
# FREE_START=2048 FREE_SIZE=196608 FREE_COUNT=1 FREE_PART=...
start=$2; size=$4
sudo fmthard -d 0:2:01:$start:$size $RAW_DEVICE

sudo zpool create -f -t $POOL -m $MNT -o autoexpand=on $POOL $SLICE
sudo zfs create -o canmount=noauto -o mountpoint=legacy $POOL/ROOT

pv < out/illumos.zfs | sudo zfs receive -u $POOL/$ROOTFS
sudo zfs set canmount=noauto $POOL/$ROOTFS
sudo zfs set mountpoint=legacy $POOL/$ROOTFS

sudo zfs create -sV 1G $POOL/swap
sudo zfs create -V 1G $POOL/dump

sudo zpool set bootfs=$POOL/$ROOTFS $POOL
sudo zpool set cachefile="" $POOL
sudo zfs set mountpoint=none $POOL
sudo zpool export $POOL
sudo lofiadm -d $DISK

