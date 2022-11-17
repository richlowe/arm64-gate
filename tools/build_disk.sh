#!/bin/ksh93

set -e

DISK=$PWD/qemu-setup/illumos-disk.img
POOL=armpool
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS

if [[ ! -f Makefile && ! -f illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

mkdir -p $PWD/qemu-setup

mkfile 2g $DISK

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

sudo zpool create -f -t $POOL -dm $MNT $POOL $SLICE
sudo zfs create -o canmount=noauto $POOL/ROOT
sudo zfs create $POOL/$ROOTFS
sudo pkg image-create -F --variant variant.arch=aarch64 $MNT/$ROOTFS

sudo pkg -R $ROOT set-publisher -p $PWD/illumos-gate/packages/aarch64/nightly/repo.redist

# for reasons I can't fathom, synthetic packages don't get published right now
pkgsend publish -s illumos-gate/packages/aarch64/nightly/repo.redist \
    illumos-gate/usr/src/pkg/packages.aarch64/osnet-incorporation.mog
pkgsend publish -s illumos-gate/packages/aarch64/nightly/repo.redist \
    illumos-gate/usr/src/pkg/packages.aarch64/osnet-redist.mog

# We don't have (most) dependencies because we don't have a full pkgdepend
# (or full packages), so we have to spell stuff out.
sudo pkg -R $ROOT install				\
     osnet-incorporation@latest				\
     SUNWcsd@latest					\
     SUNWcs@latest					\
     system/kernel@latest				\
     system/kernel/platform@latest			\
     system/kernel/platform/meson-gxbb@latest		\
     system/kernel/platform/raspberry-pi-4@latest	\
     system/kernel/platform/qemu-virtual@latest		\
     system/file-system/zfs@latest			\
     driver/storage/blkdev@latest			\
     system/library@latest				\
     system/boot/real-mode@latest			\
     system/library/math@latest				\
     system/extended-system-utilities@latest		\
     service/fault-management@latest			\
     system/ficl@latest					\
     system/network@latest				\
     system/library/iconv/unicode@latest		\
     system/library/iconv/extra@latest			\
     system/library/iconv/utf-8@latest			\
     system/library/iconv/xsh4/latin@latest		\
     install/beadm@latest

# Set up a skeleton /dev
sudo tar -C $ROOT -xf tools/dev.tar
sudo touch $ROOT/reconfigure

# Drop in extras, we're sloppy about libraries being in /usr/lib or /lib
sudo cp sysroot/usr/lib/libz* $ROOT/lib/
sudo cp sysroot/usr/lib/libz* $ROOT/usr/lib/
sudo cp sysroot/usr/lib/libxml* $ROOT/lib
sudo cp sysroot/usr/lib/libxml* $ROOT/usr/lib
sudo cp sysroot/usr/lib/libidn* $ROOT/lib
sudo cp sysroot/usr/lib/libidn* $ROOT/usr/lib
sudo cp sysroot/usr/lib/libssl* $ROOT/lib
sudo cp sysroot/usr/lib/libssl* $ROOT/usr/lib
sudo cp sysroot/usr/lib/libcrypto* $ROOT/lib
sudo cp sysroot/usr/lib/libcrypto* $ROOT/usr/lib
sudo cp sysroot/usr/lib/libstdc* $ROOT/lib
sudo cp sysroot/usr/lib/libstdc* $ROOT/usr/lib
sudo rsync -a sysroot/usr/lib/mps/ $ROOT/usr/lib/mps/

# Drop in xorrisofs both as itself, and as mkisofs, so we can have HSFS
# boot-archives (which work), rather than UFS (which don't)
sudo cp sysroot/usr/bin/xorrisofs $ROOT/usr/bin
sudo cp sysroot/usr/bin/xorrisofs $ROOT/usr/bin/mkisofs

# Without mdb(8) or kmdb(8) kmem debugging is much less useful, and much too
# slow in the emulator.
echo "set kmem_flags = 0x0" | sudo tee -a $ROOT/etc/system > /dev/null

# Don't require passwords
sudo sed -i'' -e 's/PASSREQ=YES/PASSREQ=NO/' $ROOT/etc/default/login

# Have a host name etc, in case dhcp
echo "braich" | sudo tee -a $ROOT/etc/nodename > /dev/null

# Create a boot_archive manually, because tooling
(cd $ROOT;
 sudo mkisofs -quiet -graft-points -dlrDJN -relaxed-filenames -o ./platform/armv8/boot_archive \
      $(boot/solaris/bin/extract_boot_filelist -R $ROOT -p aarch64 boot/solaris/filelist.ramdisk | \
		(while read file; do [[ -e $file ]] && echo $file; done) | \
		awk '{printf("/%s=./%s\n", $1, $1);}'))

# If this worked it would be lovely, but it doesn't yet
# because it can only create ufs/cpio archives, and we can only boot from hsfs
#sudo illumos-gate/usr/src/cmd/boot/scripts/create_ramdisk -R $ROOT -p aarch64 -f ufs-nocompress

sudo zpool set bootfs=$POOL/$ROOTFS $POOL
sudo zpool set cachefile="" $POOL
sudo zfs set mountpoint=none $POOL
sudo zfs set mountpoint=legacy $POOL/ROOT
sudo zfs set canmount=noauto $POOL/$ROOTFS
sudo zfs set mountpoint=/ $POOL/$ROOTFS
sudo zpool export $POOL
sudo lofiadm -d $DISK

cp illumos-gate/proto/root_aarch64/platform/QEMU,virt-4.1/inetboot.bin qemu-setup
