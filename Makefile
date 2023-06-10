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
	@echo "        disk - build QEMU disk image"
	@echo
	@echo "These are usually run one at a time, in the order shown above."
	@echo "See README.md for more information."

SETUP_TARGETS =		\
	binutils-gdb 	\
	boot-gcc	\
	dtc		\
	gcc		\
	perl		\
	sgs		\
	sysroot		\
	u-boot

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
	binutils-gdb		\
	dtc			\
	gcc			\
	illumos-gate		\
	$(SYSROOT_PUBLISHER)	\
	perl			\
	u-boot

PERLVER=5.36.0
PERLCROSSVER=1.4
download-perl: $(ARCHIVES) $(SRCS)
	wget -O $(ARCHIVES)/perl-$(PERLVER).tar.gz \
	    https://www.cpan.org/src/5.0/perl-$(PERLVER).tar.gz
	tar -C $(SRCS) -xf archives/perl-$(PERLVER).tar.gz
	wget -O $(ARCHIVES)/perl-cross-$(PERLCROSSVER).tar.gz \
	    https://github.com/arsv/perl-cross/releases/download/$(PERLCROSSVER)/perl-cross-$(PERLCROSSVER).tar.gz
	tar -C $(SRCS) -xf $(ARCHIVES)/perl-cross-$(PERLCROSSVER).tar.gz
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

# XXXARM: We specify what we extract, because the release tarball contains a
# GNU tar-ism we don't understand.
DTCVER=1.6.1
download-dtc: $(ARCHIVES)
	wget -O $(ARCHIVES)/dtc-$(DTCVER).tar.gz \
	    https://git.kernel.org/pub/scm/utils/dtc/dtc.git/snapshot/dtc-$(DTCVER).tar.gz
	tar -C $(SRCS) -xf $(ARCHIVES)/dtc-$(DTCVER).tar.gz dtc-$(DTCVER)

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
COMMON_GCC_OPTS= 						\
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
	    --disable-libatomic && \
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

u-boot: $(STAMPS)/u-boot-stamp
$(STAMPS)/u-boot-stamp: $(STAMPS)/sysroot-stamp
	mkdir -p $(BUILDS)/u-boot && \
	gmake -C $(SRCS)/u-boot V=1 O=$(BUILDS)/u-boot \
	    HOSTCC="gcc -m64" \
	    HOSTCFLAGS+="-I/opt/ooce/include" \
	    HOSTLDLIBS+="-L/opt/ooce/lib/amd64 -lnsl -lsocket" \
	    sandbox_defconfig && \
	gmake -C $(SRCS)/u-boot V=1 O=$(BUILDS)/u-boot \
	    HOSTCC="gcc -m64" \
	    HOSTCFLAGS+="-I/opt/ooce/include" \
	    HOSTLDLIBS+="-L/opt/ooce/lib/amd64 -lnsl -lsocket" tools && \
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

disk: $(STAMPS)/illumos-stamp
	ksh tools/build_disk.sh

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
