#!/bin/ksh93

set -e

DISK=$PWD/qemu-setup/illumos-disk.img
POOL=armpool
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=8g

USAGE="[+NAME?build_qemu --- create a disk image for booting under qemu]"
USAGE+="[e:efi?Generate an EFI disk image]"
USAGE+="[m:mbr?Generate an MBR disk image]"

typeset -i EFI=0
typeset -i MBR=0

while getopts "$USAGE" opt; do
	case $opt in
	    e)	EFI=1 ;;
	    m)	MBR=1 ;;
	esac
done

if ((EFI + MBR != 1)); then
	print -u2 "$0: Exactly one of --mbr or --efi must be provided"
	exit 2
fi

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
BLK_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BLK_DEVICE/dsk/rdsk}

if ((EFI)); then
	print "Building an EFI (GPT-partitioned) image"
	sudo zpool create -t $POOL -m $MNT $POOL ${BLK_DEVICE%p0}
else
	print "Building an MBR-partitioned image"
	# Taken from OmniOS kayak, note that this leaves s2 and s0 overlapping
	# (which, well...) and so requires zpool create -f, which I don't like.
	sudo fdisk -B $RAW_DEVICE
	# Create slice 0 covering all of the non-reserved space
	OIFS="$IFS"; IFS=" ="
	set -- $(sudo prtvtoc -f $RAW_DEVICE)
	IFS="$OIFS"
	# FREE_START=2048 FREE_SIZE=196608 FREE_COUNT=1 FREE_PART=...
	start=$2; size=$4
	sudo fmthard -d 0:2:01:$start:$size $RAW_DEVICE

	sudo zpool create -f -t $POOL -m $MNT $POOL ${BLK_DEVICE/p0/s0}
fi

print "Populating root"

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
cp illumos-gate/proto/root_aarch64/platform/QEMU,virt-4.1/inetboot.bin \
    qemu-setup

