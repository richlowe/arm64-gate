# The directory where downloaded source is extracted
SRCS=$(PWD)/src

# The directory where build output lands for extra bits
BUILDS=$(PWD)/build
#
# The area where our cross tools land
CROSS=$(BUILDS)/cross

# An AArch64 sysroot to the degree we need one
SYSROOT=$(BUILDS)/sysroot

# The directory where we mark things as built, because we're lazy
STAMPS=$(PWD)/stamps

# Where source archives end up
ARCHIVES=$(PWD)/archives

# Max jobs for sub-builds
MAX_JOBS= 12

BLDENV= $(PWD)/illumos-gate/usr/src/tools/scripts/bldenv
NIGHTLY= $(PWD)/illumos-gate/usr/src/tools/scripts/nightly

# OmniOS puts GMP headers in a weird place, know where to find them.
GMPINCDIR= /usr/include/gmp

# XXXARM: We can't .KEEP_STATE because something confuses everything
# (directory changes in rules?) and it gets bogus dependencies and always
# rebuilds everything.

all:
	@echo "Targets:"
	@echo
	@echo "    download - fetch required sources"
	@echo "       setup - build all pre-requisites"
	@echo "     illumos - build illumos"
	@echo "       image - build illumos ZFS image"
	@echo "   qemu-disk - build QEMU disk image"
	@echo "   rpi4-disk - build Raspberry Pi 4 disk image"
	@echo "        disk - build all disk images"
	@echo
	@echo "These are usually run one at a time, in the order shown above."
	@echo "See README.md for more information."

SETUP_TARGETS =			\
	arm-trusted-firmware	\
	binutils-gdb		\
	boot-gcc		\
	dtc			\
	gcc			\
	perl			\
	sgs			\
	sysroot			\
	u-boot			\
	u-boot-rpi4

SYSROOT_PUBLISHER=	omnios
SYSROOT_REPO=		https://pkg.omnios.org/bloody/braich
SYSROOT_PKGS=						\
	pkg:/library/glib2				\
	pkg:/library/idnkit				\
	pkg:/library/idnkit/header-idnkit		\
	pkg:/library/libxml2				\
	pkg:/library/nspr				\
	pkg:/library/nspr/header-nspr			\
	pkg:/library/security/openssl-3			\
	pkg:/library/zlib				\
	pkg:/media/xorriso				\
	pkg:/shell/bash					\
	pkg:/system/library/c-runtime			\
	pkg:/system/library/dbus			\
	pkg:/system/library/libdbus-glib		\
	pkg:/system/library/mozilla-nss			\
	pkg:/system/library/mozilla-nss/header-nss	\
	pkg:/system/management/snmp/net-snmp

DOWNLOADS=			\
	arm-trusted-firmware	\
	binutils-gdb		\
	dtc			\
	gcc			\
	illumos-gate		\
	$(SYSROOT_PUBLISHER)	\
	perl			\
	rpi-firmware		\
	u-boot

PERLVER=5.36.0
PERLCROSSVER=1.4
download-perl: $(ARCHIVES) $(SRCS)
	wget -O $(ARCHIVES)/perl-$(PERLVER).tar.gz \
	    https://www.cpan.org/src/5.0/perl-$(PERLVER).tar.gz
	/bin/tar -xf archives/perl-$(PERLVER).tar.gz -C $(SRCS)
	wget -O $(ARCHIVES)/perl-cross-$(PERLCROSSVER).tar.gz \
	    https://github.com/arsv/perl-cross/releases/download/$(PERLCROSSVER)/perl-cross-$(PERLCROSSVER).tar.gz
	/bin/tar -xf $(ARCHIVES)/perl-cross-$(PERLCROSSVER).tar.gz -C $(SRCS)
	rsync -a $(SRCS)/perl-cross-$(PERLCROSSVER)/* $(SRCS)/perl-$(PERLVER)/
	cd $(SRCS)/perl-$(PERLVER) && \
	    patch -p1 < $(PWD)/patches/perl-nanosleep.patch

download-gcc: $(SRCS)
	git clone --shallow-since=2019-01-01 -b il-10_4_0-arm64 \
	    https://github.com/richlowe/gcc $(SRCS)/gcc

download-binutils-gdb: $(SRCS)
	git clone --shallow-since=2019-01-01 -b illumos-arm64 \
	    https://github.com/richlowe/binutils-gdb $(SRCS)/binutils-gdb

download-illumos-gate: FRC
	git clone -b arm64-gate https://github.com/richlowe/illumos-gate

download-u-boot: $(SRCS)
	git clone --shallow-since=2019-01-01 -b v2022.10 \
	    https://github.com/u-boot/u-boot $(SRCS)/u-boot
	cd $(SRCS)/u-boot && patch -p1 < $(PWD)/patches/u-boot.patch

download-arm-trusted-firmware: $(SRCS)
	  git clone --depth=1 --branch v2.9.0 \
	      https://github.com/ARM-software/arm-trusted-firmware \
	      $(SRCS)/arm-trusted-firmware

RPIFWVER=1.20230405
download-rpi-firmware: $(ARCHIVES) $(SRCS)
	wget -O $(ARCHIVES)/firmware-$(RPIFWVER).tar.gz \
	    https://github.com/raspberrypi/firmware/archive/refs/tags/$(RPIFWVER).tar.gz
	/bin/tar -xf $(ARCHIVES)/firmware-$(RPIFWVER).tar.gz -C $(SRCS) \
	    firmware-$(RPIFWVER)/boot

# XXXARM: We specify what we extract, because the release tarball contains a
# GNU tar-ism we don't understand.
DTCVER=1.6.1
download-dtc: $(ARCHIVES)
	wget -O $(ARCHIVES)/dtc-$(DTCVER).tar.gz \
	    https://git.kernel.org/pub/scm/utils/dtc/dtc.git/snapshot/dtc-$(DTCVER).tar.gz
	/bin/tar -xf $(ARCHIVES)/dtc-$(DTCVER).tar.gz -C $(SRCS) dtc-$(DTCVER)

$(ARCHIVES)/$(SYSROOT_PUBLISHER): $(ARCHIVES)
	pkgrepo -s $@ create

download-$(SYSROOT_PUBLISHER): $(ARCHIVES)/$(SYSROOT_PUBLISHER)
	pkgrecv -s $(SYSROOT_REPO) -m latest -d $^ '*@latest'

download: $(DOWNLOADS:%=download-%)


setup: $(SETUP_TARGETS:%=$(STAMPS)/%-stamp)
$(SETUP_TARGETS:%=$(STAMPS)/%-stamp): $(BUILDS) $(STAMPS)

sysroot: $(STAMPS)/sysroot-stamp
$(STAMPS)/sysroot-stamp:
	pkg image-create -f --zone \
	    --publisher $(SYSROOT_PUBLISHER)=$(ARCHIVES)/$(SYSROOT_PUBLISHER) \
	    --variant variant.arch=aarch64 \
	    --facet osnet-lock=false \
	    --facet doc.man=false \
	    $(SYSROOT) && \
	pkg -R $(SYSROOT) install $(SYSROOT_PKGS) && \
	touch $@

binutils-gdb: $(STAMPS)/binutils-gdb-stamp
$(STAMPS)/binutils-gdb-stamp: $(STAMPS)/sysroot-stamp
	mkdir -p $(BUILDS)/binutils-gdb && \
	(cd $(BUILDS)/binutils-gdb && \
	$(SRCS)/binutils-gdb/configure \
	    --with-sysroot \
	    --target=aarch64-unknown-solaris2.11 \
	    --prefix=$(CROSS) \
	    --enable-initfini-array && \
	gmake -j $(MAX_JOBS) CPPFLAGS+='-I$(GMPINCDIR)' && \
	gmake -j $(MAX_JOBS) install) && \
	touch $@

# Build a tools ld and headers and copy them into the sysroot (in the normal
# place)
sgs: $(STAMPS)/sgs-stamp
$(STAMPS)/sgs-stamp: $(STAMPS)/sysroot-stamp
	(cd illumos-gate && \
	 $(BLDENV) -T aarch64 ../env/aarch64 'cd usr/src/; make -j $(MAX_JOBS) bldtools sgs' && \
	 rsync -a usr/src/tools/proto/root_i386-nd/ $(CROSS)/ && \
	 mkdir -p $(SYSROOT)/usr/include && \
	 rsync -a proto/root_aarch64/usr/include/ $(SYSROOT)/usr/include/) && \
	touch $@

# Note lp64 only, the default is multilib
COMMON_GCC_OPTS=						\
	--with-gmp-include=$(GMPINCDIR)				\
	--target=aarch64-unknown-solaris2.11			\
	--with-abi=lp64						\
	--prefix=$(CROSS)					\
	--enable-languages=c,c++				\
	--with-build-sysroot=$(SYSROOT)				\
	--enable-c99						\
	--disable-libquadmath					\
	--disable-libmudflag					\
	--disable-libgomp					\
	--disable-decimal-float					\
	--disable-libitm					\
	--disable-libsanitizer					\
	--disable-libvtv					\
	--disable-libcilkcrts					\
	--with-system-zlib					\
	--enable-__cxa-atexit					\
	--enable-initfini-array					\
	--with-headers=$(SYSROOT)/usr/include			\
	--with-gnu-as						\
	--with-as=$(CROSS)/bin/aarch64-unknown-solaris2.11-as	\
	--without-gnu-ld					\
	--with-ld=$(CROSS)/opt/onbld/bin/amd64/ld

# This is the bootstrap GCC used to build bootstrap bits we can then use when
# building a real GCC
boot-gcc: $(STAMPS)/boot-gcc-stamp
$(STAMPS)/boot-gcc-stamp: $(STAMPS)/sgs-stamp $(STAMPS)/binutils-gdb-stamp
	mkdir -p $(BUILDS)/boot-gcc && \
	(cd $(BUILDS)/boot-gcc; \
	$(SRCS)/gcc/configure $(COMMON_GCC_OPTS) \
	    --disable-shared \
	    --disable-libstdcxx \
	    --disable-libatomic \
	    --enable-warn-rwx-segments=no && \
	gmake -j $(MAX_JOBS) && \
	gmake -j $(MAX_JOBS) install && \
	rm -fr $(CROSS)/lib/gcc/aarch64-unknown-solaris2.11/10.4.0/include-fixed) && \
	touch $@

gcc: $(STAMPS)/gcc-stamp
$(STAMPS)/gcc-stamp: $(STAMPS)/boot-gcc-stamp
	mkdir -p $(BUILDS)/gcc && \
	(cd $(BUILDS)/gcc; \
	env CFLAGS_FOR_TARGET="-g -O2 -mno-outline-atomics -mtls-dialect=trad" \
	    CXXFLAGS_FOR_TARGET="-g -O2 -mno-outline-atomics -mtls-dialect=trad" \
	$(SRCS)/gcc/configure $(COMMON_GCC_OPTS) && \
	gmake -j $(MAX_JOBS) && \
	gmake -j $(MAX_JOBS) install && \
	rm -fr $(CROSS)/lib/gcc/aarch64-unknown-solaris2.11/10.4.0/include-fixed) && \
	touch $@

# XXXARM:
# out of tree build is broken for the cross miniperl
# the cross miniperl build requires gnu tools
# miniperl is racy (i.e. xconfig.h is not re-generated before the build uses it)
# configure breaks with certain locale settings
perl: $(STAMPS)/perl-stamp
$(STAMPS)/perl-stamp: $(STAMPS)/gcc-stamp
	(cd $(SRCS)/perl-$(PERLVER) && \
	env PATH="/usr/gnu/bin:$$PATH" LC_ALL=C.UTF-8 \
	./configure \
	    --target=aarch64-unknown-solaris2.11 \
	    --host-libs="m" \
	    --host-set-osname=solaris \
	    --sysroot=$(SYSROOT) \
	    -Dccdlflags= \
	    -Dusethreads \
	    -Duseshrplib \
	    -Dusemultiplicity \
	    -Duselargefiles \
	    -Duse64bitall \
	    -Dmyhostname=localhost \
	    -Umydomain \
	    -Dmyuname=sunos \
	    -Dosname=solaris \
	    -Dcc=$(CROSS)/bin/aarch64-unknown-solaris2.11-gcc \
	    -Dcpp=$(CROSS)/bin/aarch64-unknown-solaris2.11-cpp \
	    -Dar=$(CROSS)/bin/aarch64-unknown-solaris2.11-ar \
	    -Dnm=$(CROSS)/bin/aarch64-unknown-solaris2.11-nm \
	    -Dranlib=$(CROSS)/bin/aarch64-unknown-solaris2.11-ranlib \
	    -Dreadelf=$(CROSS)/bin/aarch64-unknown-solaris2.11-readelf \
	    -Dobjdump=$(CROSS)/bin/aarch64-unknown-solaris2.11-objdump \
	    -Doptimize="-O3" \
	    -Dprefix=$(CROSS)/usr/perl5/5.36 \
	    -Ulocincpth= \
	    -Uloclibpth= && \
	sed -i "s/^d_unsetenv=.*/d_unsetenv='undef'/g" xconfig.sh && \
	gmake miniperl && \
	gmake -j $(MAX_JOBS) modules && \
	mkdir -p $(CROSS)/usr/perl5/5.36/bin && \
	mkdir -p $(CROSS)/usr/perl5/5.36/lib/aarch64-solaris-64/CORE && \
	cp -f miniperl $(CROSS)/usr/perl5/5.36/bin/perl && \
	rsync -a lib/* $(CROSS)/usr/perl5/5.36/lib/aarch64-solaris-64/ && \
	ln -sf ./aarch64-solaris-64/ExtUtils $(CROSS)/usr/perl5/5.36/lib/ExtUtils && \
	cp -f *.h $(CROSS)/usr/perl5/5.36/lib/aarch64-solaris-64/CORE/) && \
	touch $@

U_BOOT_ARGS =							\
	HOSTCC="gcc -m64"					\
	HOSTCFLAGS="-I/opt/ooce/include"			\
	HOSTLDLIBS="-L/opt/ooce/lib/amd64 -lnsl -lsocket"

u-boot: $(STAMPS)/u-boot-stamp
$(STAMPS)/u-boot-stamp: $(STAMPS)/sysroot-stamp
	mkdir -p $(BUILDS)/u-boot && \
	gmake -C $(SRCS)/u-boot V=1 O=$(BUILDS)/u-boot \
	    $(U_BOOT_ARGS) sandbox_defconfig && \
	gmake -C $(SRCS)/u-boot V=1 O=$(BUILDS)/u-boot \
	    $(U_BOOT_ARGS) tools && \
	touch $@

u-boot-rpi4: $(STAMPS)/u-boot-rpi4-stamp
$(STAMPS)/u-boot-rpi4-stamp: $(STAMPS)/u-boot-stamp $(STAMPS)/gcc-stamp
	gmake -C $(SRCS)/u-boot V=1 O=$(BUILDS)/u-boot \
	    $(U_BOOT_ARGS) \
	    CROSS_COMPILE=$(CROSS)/bin/aarch64-unknown-solaris2.11- \
	    ARCH=arm rpi_4_defconfig u-boot u-boot.bin && \
	touch $@

arm-trusted-firmware: $(STAMPS)/arm-trusted-firmware-stamp
$(STAMPS)/arm-trusted-firmware-stamp: $(STAMPS)/gcc-stamp $(STAMPS)/dtc-stamp
	rsync -a $(SRCS)/arm-trusted-firmware/ \
	    $(BUILDS)/arm-trusted-firmware/ && \
	rm -rf $(BUILDS)/arm-trusted-firmware/.git && \
	CROSS_COMPILE=$(CROSS)/bin/aarch64-unknown-solaris2.11- \
	DTC=$(CROSS)/bin/dtc \
	gmake -C $(BUILDS)/arm-trusted-firmware -j $(MAX_JOBS) \
	    PLAT=rpi4 DEBUG=1 bl31 && \
	touch $@

dtc: $(STAMPS)/dtc-stamp
$(STAMPS)/dtc-stamp: $(STAMPS)/sysroot-stamp
	rsync -a $(SRCS)/dtc-$(DTCVER)/ $(BUILDS)/dtc-$(DTCVER)/ && \
	rm -rf $(BUILDS)/dtc-$(DTCVER)/.git && \
	gmake -C $(BUILDS)/dtc-$(DTCVER) \
	    NO_PYTHON=1 \
	    SHAREDLIB_LDFLAGS="-shared -Wl,-soname" && \
	gmake -C $(BUILDS)/dtc-$(DTCVER) PREFIX=$(CROSS) \
	    NO_YAML=1 \
	    NO_PYTHON=1 \
	    INSTALL=/usr/gnu/bin/install install && \
	touch $@

illumos: $(STAMPS)/illumos-stamp
$(STAMPS)/illumos-stamp: $(SETUP_TARGETS:%=$(STAMPS)/%-stamp)
	(cd illumos-gate && \
	 $(NIGHTLY) -T aarch64 ../env/aarch64) && \
	touch $@

image: $(PWD)/out/illumos.zfs
$(PWD)/out/illumos.zfs: $(STAMPS)/illumos-stamp
	ksh tools/build_image.sh

qemu-disk: $(PWD)/out/illumos.zfs
	ksh tools/build_qemu.sh --efi

rpi4-disk: $(PWD)/out/illumos.zfs
	ksh tools/build_rpi4.sh --efi

disk: qemu-disk rpi4-disk

$(BUILDS):
	mkdir -p $@
$(STAMPS):
	mkdir -p $@
$(ARCHIVES):
	mkdir -p $@
$(SRCS):
	mkdir -p $@
$(CROSS):
	mkdir -p $@

clean-illumos:
	(cd illumos-gate && \
	 rm -fr packages && \
	 rm -fr proto && \
	 $(BLDENV) -T aarch64 ../env/aarch64 \
	     'cd usr/src; make -j $(MAX_JOBS) clobber') && \
	 rm -f $(STAMPS)/illumos-stamp

clean: clean-illumos
	rm -fr $(BUILDS) $(STAMPS)

clobber:
	rm -fr $(BUILDS) $(STAMPS) $(ARCHIVES) $(SRCS) illumos-gate

FRC:
