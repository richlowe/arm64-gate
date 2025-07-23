#!/bin/ksh93

set -e

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

if [[ $(zonename) != global ]]; then
	print -u2 "$0 should be run in the global zone"
	exit 2
fi

DATASET="$(zfs list -Ho name / | cut -d/ -f1)/braich_image"
ROOT=/braich_image
WORKDIR=$PWD
POOL=armpool # We need to know this to configure swap and dump

zfs list $DATASET >/dev/null 2>&1 && sudo zfs destroy -r $DATASET
sudo zfs create -o mountpoint=$ROOT $DATASET
trap 'sudo zfs destroy -r $DATASET' EXIT

# Setting this flag lets `pkg` know that this is an automatic installation and
# that the installed packages should not be marked as 'manually installed'
# in the pkg database.
export PKG_AUTOINSTALL=1

ILLUMOS_REPO=$PWD/illumos-gate/packages/aarch64/nightly/repo.redist

sudo pkg image-create --full						\
     --variant variant.arch=aarch64					\
     --set-property flush-content-cache-on-success=True			\
     --publisher $ILLUMOS_REPO						\
     $ROOT

for publisher in omnios extra.omnios; do
	sudo pkg -R $ROOT set-publisher					\
	     -g file:///$PWD/archives/omnios				\
	     -g https://pkg.omnios.org/bloody/braich			\
	     -m https://us-west.mirror.omnios.org/bloody/braich		\
	     $publisher
done

# We install entire, and also the optional packages listed in entire. These are
# ones that we'd like in the initial image but can be removed by the user if
# desired.
# network/telnet is broken out here because unfortunately the unqualified name
# is ambiguous (it also matches service/network/telnet). We can't just use
# qualified names in general because the pkg://omnios/ packages conflict with
# the newer versions in pkg://on-nightly/.
pkglist=(
	entire
	"pkg://on-nightly/*"
	developer/build-essential
	$(pkg -R $ROOT contents -rH -a type=optional -o fmri entire | \
	    cut -d/ -f4- | egrep -v '(telnet|rsyslog)')
	pkg://on-nightly/network/telnet
)
sudo pkg -R $ROOT install --reject ssh-common --reject system/rsyslog \
     ${pkglist[*]}

sudo pkg -R $ROOT set-publisher				\
    --non-sticky					\
    -G file:///$ILLUMOS_REPO				\
    on-nightly

for publisher in omnios extra.omnios; do
	sudo pkg -R $ROOT set-publisher			\
	    -G file:///$PWD/archives/omnios		\
	    $publisher
done

sudo sed -i '/^last_uuid/d' $ROOT/var/pkg/pkg5.image

sudo sed -i '/PermitRootLogin/s/no/yes/' $ROOT/etc/ssh/sshd_config

# Set up a skeleton /dev
sudo tar -xf tools/dev.tar -C $ROOT
sudo touch $ROOT/reconfigure

# Without mdb(8) or kmdb(8) kmem debugging is much less useful, and much too
# slow in the emulator.  This is KMF_DEADBEEF|KMF_REDZONE
#echo "set kmem_flags = 0x6" | sudo tee -a $ROOT/etc/system > /dev/null

# Don't require passwords
sudo sed -i 's/PASSREQ=YES/PASSREQ=NO/' $ROOT/etc/default/login

# Have a host name etc, in case dhcp
echo "braich" | sudo tee -a $ROOT/etc/nodename > /dev/null
sudo sed -i 's/localhost/braich.dev braich localhost/' $ROOT/etc/inet/hosts

# Have some swap space
echo "/dev/zvol/dsk/$POOL/swap	-	-	swap	-	no	-" | \
	sudo tee -a $ROOT/etc/vfstab >/dev/null

# Have a dump device
cat <<EOF  | sudo tee -a $ROOT/etc/dumpadm.conf >/dev/null
DUMPADM_DEVICE=/dev/zvol/dsk/$POOL/dump
DUMPADM_SAVDIR=/var/crash/braich
DUMPADM_CONTENT=kernel
DUMPADM_ENABLE=yes
DUMPADM_CSAVE=on
EOF

# Put the SMF profiles in place
sudo ln -s ns_files.xml $ROOT/etc/svc/profile/name_service.xml
sudo ln -s generic_limited_net.xml $ROOT/etc/svc/profile/generic.xml
sudo ln -s inetd_generic.xml $ROOT/etc/svc/profile/inetd_services.xml
sudo ln -s platform_none.xml $ROOT/etc/svc/profile/platform.xml

# Set the default timezone to UTC
sudo sed -i '/^TZ/c\
TZ=UTC
' $ROOT/etc/default/init

# Import all the services ahead of time.  This is a shame, because allowing
# EMI to happen has found many bugs, but it also takes _forever_
SVCCFG=illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld/bin/i386/svccfg
SVCCFG_CONFIGD_PATH=illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld/bin/i386/svc.configd
SVCCFG_REPOSITORY=/tmp/arm-gate.$$

cp $ROOT/lib/svc/seed/global.db $SVCCFG_REPOSITORY
chmod u+w $SVCCFG_REPOSITORY
env PKG_INSTALL_ROOT=$ROOT \
    SVCCFG_DTD=$ROOT/usr/share/lib/xml/dtd/service_bundle.dtd.1 \
    SVCCFG_REPOSITORY=$SVCCFG_REPOSITORY \
    SVCCFG_CHECKHASH=1 $SVCCFG import \
		       -p /dev/stdout $ROOT/lib/svc/manifest
sudo cp -a $SVCCFG_REPOSITORY $ROOT/etc/svc/repository.db
sudo chown root:sys $ROOT/etc/svc/repository.db
sudo chmod 0600 $ROOT/etc/svc/repository.db
rm -f $SVCCFG_REPOSITORY

sudo mkdir $ROOT/platform/armv8/aarch64  # won't exist yet
sudo $ROOT/boot/solaris/bin/create_ramdisk -R $ROOT -p aarch64 -f cpio
# Expand the filelist that was used to create our boot archive into a format
# suitable for use as the archive cache and as input to stat cache production.
(
    cd $ROOT
    $ROOT/boot/solaris/bin/extract_boot_filelist \
        -R $ROOT -p aarch64 boot/solaris/filelist.ramdisk \
        etc/boot/solaris/filelist.ramdisk \
        | while read file; do
            [ -e "$file" ] && find "$file" -type f
        done | awk '{printf("/%s=%s\n", $1, $1)}' | \
    sudo tee platform/armv8/aarch64/archive_cache > /dev/null 2>&1
    sudo chmod 644 platform/armv8/aarch64/archive_cache
)
# Now create the stat cache.
sudo $WORKDIR/build/barn -R $ROOT -w $ROOT/platform/armv8/aarch64/archive_cache
sudo touch $ROOT/boot/solaris/timestamp.cache

# drop a boot config override into the loader configs to allow booting from an
# implementation architecture, to prefer the serial console, and to boot
# verbosely
sudo tee $ROOT/boot/conf.d/00-aarch64-defaults.conf > /dev/null <<'EOF'
bootfile="/platform/${IMPLARCH}/kernel/${ISADIR}/unix;/platform/${BASEARCH}/kernel/${ISADIR}/unix"
console="${default-uart-name},text"
boot-args="-vm verbose"
EOF

sudo zfs snapshot $DATASET@image
mkdir -p out
sudo zfs send $DATASET@image | pv > out/illumos.zfs

