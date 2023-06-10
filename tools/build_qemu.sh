#!/bin/ksh93

set -e

DISK=$PWD/qemu-setup/illumos-disk.img
POOL=armpool
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=8g

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

if [[ $(zonename) != global ]]; then
	print -u2 "$0 should be run in the global zone"
	exit 2
fi

mkdir -p $PWD/qemu-setup

mkfile $DISKSIZE $DISK

BASE_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BASE_DEVICE/dsk/rdsk}
SLICE=${BASE_DEVICE/p0/s0}

# Taken from OmniOS kayak, note that this leaves s2 and s0 overlapping (which,
# well...) and so requires zpool create -f, which I don't like.
sudo fdisk -B $RAW_DEVICE
# Create slice 0 covering all of the non-reserved space
OIFS="$IFS"; IFS=" ="
set -- $(sudo prtvtoc -f $RAW_DEVICE)
IFS="$OIFS"
# FREE_START=2048 FREE_SIZE=196608 FREE_COUNT=1 FREE_PART=...
start=$2; size=$4
sudo fmthard -d 0:2:01:$start:$size $RAW_DEVICE

sudo zpool create -f -t $POOL -m $MNT $POOL $SLICE
sudo zfs create -o canmount=noauto -o mountpoint=legacy $POOL/ROOT

pv < out/illumos.zfs | sudo zfs receive -u $POOL/$ROOTFS
sudo zfs set canmount=noauto $POOL/$ROOTFS
sudo zfs set mountpoint=legacy $POOL/$ROOTFS

sudo zfs create -V 1G $POOL/swap
sudo zfs create -V 1G $POOL/dump

sudo zpool set bootfs=$POOL/$ROOTFS $POOL
sudo zpool set cachefile="" $POOL
sudo zfs set mountpoint=none $POOL
sudo zpool export $POOL
sudo lofiadm -d $DISK

cp illumos-gate/proto/root_aarch64/platform/QEMU,virt-4.1/inetboot.bin \
    qemu-setup

