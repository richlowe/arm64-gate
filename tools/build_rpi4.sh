#!/bin/ksh93

DISK=$PWD/rpi4-setup/illumos-disk.img
POOL=armpool			# Must match build_image
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=4g

USAGE="[+NAME?build_rpi4 --- create a disk image for a Raspberry Pi 4]"
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

mkfile $DISKSIZE $DISK
BLK_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BLK_DEVICE/dsk/rdsk}

if ((EFI)); then
	print "Building an EFI (GPT-partitioned) image"

	# This is the easier option, we can just use the -B option to zpool
	# to get it to create an initial FAT partition for us.
	sudo zpool create \
	    -B -o bootsize=256M \
	    -t $POOL -m $MNT $POOL ${BLK_DEVICE%p0}

	FAT_RAW=${RAW_DEVICE/p0/s0}
	FAT_BLK=${BLK_DEVICE/p0/s0}
else
	print "Building an MBR-partitioned image"

	# Here's the partition table for one of the official Raspberry Pi
	# Linux images.
	#
	#  Id  Act Bhead  Bsect Bcyl Ehead Esect Ecyl Rsect  Numsect
	#  12  0   0      1     64   3     32    1023 8192   524288
	#  131 0   3      32    1023 3     32    1023 532480 3309568
	#  0   0   0      0     0    0     0     0    0      0
	#  0   0   0      0     0    0     0     0    0      0

	# XXX - work out what to use here.
	# These values do produce bootable images.
	FAT_SECTORS=524288	# Ends up being ~256MiB
	RESV_FAT_SECTORS=8192
	RESV_SOL_SECTORS=532480

	# Create the required partition structure.
	# Calculate the total number of available sectors by creating a single
	# sol2 partition that spans the entire disk and reading the Numsect
	# value back out.
	#
	sudo fdisk -B $RAW_DEVICE
	# Id Act Bhead Bsect Bcyl Ehead Esect Ecyl Rsect Numsect
	set -- $(sudo fdisk -W - $RAW_DEVICE | awk '$1 == 191 { print }')
	TOTAL_SECTORS=${10}

	# Now create the real partition table, small FAT32 partition followed
	# by a solaris one filling the remaining space.

	((ZPOOL_SECTORS = TOTAL_SECTORS - FAT_SECTORS - RESV_FAT_SECTORS))

	#	id act bhead bsect bcyl ehead esect ecyl rsect numsect
	tf=`mktemp`
	cat <<-EOM > $tf
		12 0 0 1 64 3 32 1023 $RESV_FAT_SECTORS $FAT_SECTORS
		191 128 3 32 1023 3 32 1023 $RESV_SOL_SECTORS $ZPOOL_SECTORS
	EOM
	sudo fdisk -F $tf $RAW_DEVICE
	rm -f $tf

	# Set up a VTOC in the second partition Taken from OmniOS kayak, note
	# that this leaves s2 and s0 overlapping (which, well...) and so
	# requires zpool create -f, which I don't like.
	# Create slice 0 covering all of the non-reserved space
	OIFS="$IFS"; IFS=" ="
	set -- $(sudo prtvtoc -f $RAW_DEVICE)
	IFS="$OIFS"
	# FREE_START=2048 FREE_SIZE=196608 FREE_COUNT=1 FREE_PART=...
	start=$2; size=$4
	sudo fmthard -d 0:2:01:$start:$size $RAW_DEVICE

	sudo zpool create -f -t $POOL -m $MNT $POOL $SLICE ${BLK_DEVICE/p0/s0}

	FAT_RAW=$RAW_DEVICE:c
	FAT_BLK=$BLK_DEVICE:c
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

print "Populating boot"

# Format the FAT partition and copy in the boot files.
yes | sudo mkfs -F pcfs -o fat=32,b=bootfs $FAT_RAW
sudo mount -F pcfs $FAT_BLK $MNT
{ cd $boot; find . | sudo cpio -pmud $MNT 2>/dev/null || true; cd -; }
sudo umount $MNT

sudo lofiadm -d $DISK

