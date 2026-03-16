#!/bin/ksh93

set -e
set -x

MNT=$PWD/nfs
ROOT=$MNT
NFSIP=192.168.1.6

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

mkdir -p $MNT
(cd $MNT && sudo rm -rf * )
# for reasons I can't fathom, synthetic packages don't get published right now
pkgsend publish -s illumos-gate/packages/aarch64/nightly/repo.redist \
    illumos-gate/usr/src/pkg/packages.aarch64/osnet-incorporation.mog
pkgsend publish -s illumos-gate/packages/aarch64/nightly/repo.redist \
    illumos-gate/usr/src/pkg/packages.aarch64/osnet-redist.mog

pkg image-create --full						\
     --variant variant.arch=aarch64					\
     --set-property flush-content-cache-on-success=True			\
     --publisher $PWD/illumos-gate/packages/aarch64/nightly/repo.redist	\
     $ROOT

for publisher in omnios extra.omnios; do
	 pkg -R $ROOT set-publisher		\
	     -g file:///$PWD/archives/omnios	\
	     -g https://pkg.omnios.org/bloody/braich $publisher
done

# Install everything, to the degree that it is possible, for convenience since
# there's no pkg(8) in the image
sudo pkg -R $ROOT install --no-refresh			\
     --reject=osnet					\
     --reject=ssh-common				\
     '*@latest'

sudo sed -i '/^last_uuid/d' $ROOT/var/pkg/pkg5.image

sudo sed -i '/PermitRootLogin/s/no/yes/' $ROOT/etc/ssh/sshd_config

# Set up a skeleton /dev
sudo tar -xf tools/dev.tar -C $ROOT
sudo touch $ROOT/reconfigure

# Without mdb(8) or kmdb(8) kmem debugging is much less useful, and much too
# slow in the emulator.  This is KMF_DEADBEEF|KMF_REDZONE
echo "set kmem_flags = 0x6" | sudo tee -a $ROOT/etc/system > /dev/null

# Don't require passwords
sudo sed -i 's/PASSREQ=YES/PASSREQ=NO/' $ROOT/etc/default/login

# Have a host name etc, in case dhcp
echo "rpi4" |  sudo tee -a $ROOT/etc/nodename > /dev/null
sudo sed -i 's/localhost/localhost rpi4/' $ROOT/etc/inet/hosts

# Put the SMF profiles in place
sudo ln -s ns_files.xml $ROOT/etc/svc/profile/name_service.xml
sudo ln -s generic_limited_net.xml $ROOT/etc/svc/profile/generic.xml
sudo ln -s inetd_generic.xml $ROOT/etc/svc/profile/inetd_services.xml
sudo ln -s platform_none.xml $ROOT/etc/svc/profile/platform.xml

# Import all the services ahead of time.  This is a shame, because allowing
# EMI to happen has found many bugs, but it also takes _forever_
SVCCFG=illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld/bin/i386/svccfg
if [[ ! -x $SVCCFG ]]; then
	SVCCFG=illumos-gate/usr/src/cmd/svc/svccfg/svccfg-native
fi
SVCCFG_REPOSITORY=/tmp/arm-gate.$$

cp $ROOT/lib/svc/seed/global.db $SVCCFG_REPOSITORY
chmod u+w $SVCCFG_REPOSITORY
env PKG_INSTALL_ROOT=$ROOT \
    SVCCFG_DTD=$ROOT/usr/share/lib/xml/dtd/service_bundle.dtd.1 \
    SVCCFG_REPOSITORY=$SVCCFG_REPOSITORY \
    SVCCFG_CHECKHASH=1 $SVCCFG import \
		       -p - $ROOT/lib/svc/manifest
#  -p /dev/stdout $ROOT/lib/svc/manifest
sudo cp -a $SVCCFG_REPOSITORY $ROOT/etc/svc/repository.db
sudo chown root:sys $ROOT/etc/svc/repository.db
sudo chmod 0600 $ROOT/etc/svc/repository.db
rm -f $SVCCFG_REPOSITORY


#RPi4 device add
sudo rem_drv  -b $ROOT  pl011
sudo rem_drv  -b $ROOT  ns16550a
sudo add_drv  -b $ROOT -i "arm,pl011" ns16550a
sudo add_drv  -b $ROOT -i "brcm,bcm2711-emmc2" bcm2711-emmc2

#Fix rootfs for NFS
echo "$NFSIP:$ROOT	-	/	nfs	-	no	-" | sudo tee -a  $ROOT/etc/vfstab
	
#Fix missing RTC for Rpi contacting the NFS server for rdate during the boot
#note - services svc:/network/time:dgram, svc:/network/time:stream must be enabled on NFS server
echo "/usr/bin/rdate $NFSIP" | sudo tee $ROOT/etc/init.d/rdate
sudo chown root:sys $ROOT/etc/init.d/rdate
sudo chmod 744 $ROOT/etc/init.d/rdate
sudo ln $ROOT/etc/init.d/rdate $ROOT/etc/rc2.d/S10rdate

# Create a boot_archive manually, because tooling
(cd $ROOT;
  sudo mkisofs -quiet -graft-points -dlrDJN -relaxed-filenames -o ./platform/armv8/boot_archive \
      $(boot/solaris/bin/extract_boot_filelist -R $ROOT -p aarch64 boot/solaris/filelist.ramdisk | \
		(while read file; do [[ -e $file ]] && echo $file; done) | \
		awk '{printf("/%s=./%s\n", $1, $1);}'))

#cp illumos-gate/proto/root_aarch64/platform/QEMU,virt-4.1/inetboot.bin qemu-setup

# Prepare installation scripts for ZFS 
sudo mkdir $ROOT/var/install
sudo cp tools/dev.tar $ROOT/var/install
