# An AArch64 sysroot to the degree we need one
SYSROOT=$(PWD)/sysroot

# The area where our cross tools land
CROSS=$(PWD)/cross

# The directory where build output lands for extra bits
BUILDS=$(PWD)/build

# The directory where we mark things as built, because we're lazy
STAMPS=$(PWD)/stamps

# Where source archives end up
ARCHIVES=$(PWD)/archives

# Max jobs for sub-builds
MAX_JOBS= 12

BLDENV= $(PWD)/illumos-gate/usr/src/tools/scripts/bldenv

# OmniOS puts GMP headers in a weird place, know where to find them.
GMPINCDIR= /usr/include/gmp

# XXXARM: We can't .KEEP_STATE because something confuses everything
# (directory changes in rules?) and it gets bogus dependencies and always
# rebuilds everything (which, to be fair, often happens anyway).

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
SYSROOT_PKGS=		\
	c-runtime	\
	header-idnkit	\
	header-nspr	\
	header-nss	\
	idnkit		\
	libxml2		\
	mozilla-nss	\
	nspr		\
	openssl-3	\
	xorriso		\
	zlib

DOWNLOADS=			\
	binutils-gdb		\
	dtc			\
	gcc			\
	illumos-gate		\
	$(SYSROOT_PUBLISHER)	\
	perl			\
	u-boot

download-perl: $(ARCHIVES)
	wget -O archives/perl-5.36.0.tar.gz https://www.cpan.org/src/5.0/perl-5.36.0.tar.gz
	tar xf archives/perl-5.36.0.tar.gz
	wget -O archives/perl-cross-1.4.tar.gz https://github.com/arsv/perl-cross/releases/download/1.4/perl-cross-1.4.tar.gz
	tar xf archives/perl-cross-1.4.tar.gz
	rsync -a perl-cross-1.4/* perl-5.36.0/
	(cd perl-5.36.0 && patch -p1 < ../patches/perl-nanosleep.patch)

download-gcc: $(ARCHIVES)
	git clone --shallow-since=2019-01-01 -b il-10_3_0-arm64 https://github.com/richlowe/gcc

download-binutils-gdb: $(ARCHIVES)
	git clone --shallow-since=2019-01-01 -b illumos-arm64 https://github.com/richlowe/binutils-gdb

download-illumos-gate: $(ARCHIVES)
	git clone -b arm64-gate https://github.com/richlowe/illumos-gate

download-u-boot: $(ARCHIVES)
	git clone --shallow-since=2019-01-01 -b v2022.10 https://github.com/u-boot/u-boot/

# XXXARM: We specify what we extract, because the release tarball contains a
# GNU tar-ism we don't understand.
download-dtc: $(ARCHIVES)
	wget -O archives/dtc-1.6.1.tar.gz https://git.kernel.org/pub/scm/utils/dtc/dtc.git/snapshot/dtc-1.6.1.tar.gz
	tar xf archives/dtc-1.6.1.tar.gz dtc-1.6.1

$(ARCHIVES)/$(SYSROOT_PUBLISHER): $(ARCHIVES)
	pkgrepo -s $@ create

download-$(SYSROOT_PUBLISHER): $(ARCHIVES)/$(SYSROOT_PUBLISHER)
	pkgrecv -s $(SYSROOT_REPO) -m latest -d $^ '*@latest'

download: $(DOWNLOADS:%=download-%)
setup: $(SETUP_TARGETS)
$(SETUP_TARGETS): $(SETUP_TARGETS:%=$(BUILDS)/%) $(SYSROOT) $(CROSS) $(BUILDS) $(STAMPS)

sysroot: $(SYSROOT)
$(SYSROOT): FRC
	[ -f $@/var/pkg/pkg5.image ] || pkg image-create -f --full \
	    --publisher $(SYSROOT_PUBLISHER)=$(ARCHIVES)/$(SYSROOT_PUBLISHER) \
	    --variant variant.arch=aarch64 \
	    --facet osnet-lock=false \
	    --facet doc.man=false \
	    $@
	-pkg -R $@ install $(SYSROOT_PKGS)


binutils-gdb: $(STAMPS)/binutils-gdb-stamp
$(STAMPS)/binutils-gdb-stamp: sysroot
	(cd $(BUILDS)/binutils-gdb && \
	../../binutils-gdb/configure \
	    --with-sysroot \
	    --target=aarch64-unknown-solaris2.11 \
	    --prefix=$(CROSS) \
	    --enable-initfini-array && \
	gmake -j $(MAX_JOBS) CPPFLAGS+='-I$(GMPINCDIR)' && \
	gmake -j $(MAX_JOBS) install) && \
	touch $@

# Build a tools ld and headers and copy them into the sysroot (in the normal place)
sgs: $(STAMPS)/sgs-stamp
$(STAMPS)/sgs-stamp: sysroot
	(cd illumos-gate && \
	 $(BLDENV) ../env/aarch64 'cd usr/src/; make -j $(MAX_JOBS) bldtools sgs' && \
	 rsync -a usr/src/tools/proto/root_i386-nd/ $(CROSS)/ && \
	 mkdir -p $(SYSROOT)/usr/include && \
	 rsync -a proto/root_aarch64/usr/include/ $(SYSROOT)/usr/include/) && \
	touch $@

# Note lp64 only, the default is multilib
# This is the bootstrap GCC used to build bootstrap bits we can then use when
# building a real GCC
boot-gcc: $(STAMPS)/boot-gcc-stamp
$(STAMPS)/boot-gcc-stamp: sgs binutils-gdb sysroot
	(cd $(BUILDS)/boot-gcc; \
	../../gcc/configure \
	    --with-gmp-include=$(GMPINCDIR) \
	    --target=aarch64-unknown-solaris2.11 \
	    --with-abi=lp64 \
	    --prefix=$(CROSS) \
	    --enable-languages=c,c++ \
	    --with-build-sysroot=$(SYSROOT) \
	    --disable-shared \
	    --enable-c99 \
	    --disable-libstdcxx \
	    --disable-libquadmath \
	    --disable-libmudflag \
	    --disable-libgomp \
	    --disable-decimal-float \
	    --disable-libatomic \
	    --disable-libitm \
	    --disable-libsanitizer \
	    --disable-libvtv \
	    --disable-libcilkcrts \
	    --with-system-zlib \
	    --enable-__cxa-atexit \
	    --enable-initfini-array \
	    --with-headers=$(SYSROOT)/usr/include \
	    --with-gnu-as \
	    --with-as=$(CROSS)/bin/aarch64-unknown-solaris2.11-as \
	    --without-gnu-ld \
	    --with-ld=$(CROSS)/opt/onbld/bin/amd64/ld && \
	gmake -j $(MAX_JOBS) && \
	gmake -j $(MAX_JOBS) install && \
	rm -fr $(CROSS)/lib/gcc/aarch64-unknown-solaris2.11/10.3.0/include-fixed) && \
	touch $@

gcc: $(STAMPS)/gcc-stamp
$(STAMPS)/gcc-stamp: sgs binutils-gdb boot-gcc sysroot
	(cd $(BUILDS)/gcc; \
	env CFLAGS_FOR_TARGET="-g -O2 -mno-outline-atomics -mtls-dialect=trad" \
	    CXXFLAGS_FOR_TARGET="-g -O2 -mno-outline-atomics -mtls-dialect=trad" \
	../../gcc/configure \
	    --with-gmp-include=$(GMPINCDIR) \
	    --target=aarch64-unknown-solaris2.11 \
	    --with-abi=lp64 \
	    --prefix=$(CROSS) \
	    --enable-languages=c,c++ \
	    --with-build-sysroot=$(SYSROOT) \
	    --enable-c99 \
	    --disable-libquadmath \
	    --disable-libmudflag \
	    --disable-libgomp \
	    --disable-decimal-float \
	    --disable-libitm \
	    --disable-libsanitizer \
	    --disable-libvtv \
	    --disable-libcilkcrts \
	    --with-system-zlib \
	    --enable-__cxa-atexit \
	    --enable-initfini-array \
	    --with-headers=$(SYSROOT)/usr/include \
	    --with-gnu-as \
	    --with-as=$(CROSS)/bin/aarch64-unknown-solaris2.11-as \
	    --without-gnu-ld \
	    --with-ld=$(CROSS)/opt/onbld/bin/amd64/ld && \
	gmake -j $(MAX_JOBS) && \
	gmake -j $(MAX_JOBS) install && \
	rm -fr $(CROSS)/lib/gcc/aarch64-unknown-solaris2.11/10.3.0/include-fixed) && \
	touch $@

# XXXARM:
# out of tree build is broken for the cross miniperl
# the cross miniperl build requires gnu tools
# miniperl is racy (i.e. xconfig.h is not re-generated before the build uses it)
perl: $(STAMPS)/perl-stamp
$(STAMPS)/perl-stamp: gcc sysroot
	(cd perl-5.36.0 && \
	env PATH="/usr/gnu/bin:$$PATH" \
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
$(STAMPS)/u-boot-stamp: sysroot
	cd u-boot && \
	gmake V=1 O=$(PWD)/build/u-boot \
	    HOSTCC="gcc -m64" \
	    HOSTCFLAGS+="-I/opt/ooce/include" \
	    HOSTLDLIBS+="-L/opt/ooce/lib/amd64 -lnsl -lsocket" \
	    sandbox_defconfig && \
	gmake V=1 O=$(PWD)/build/u-boot \
	    HOSTCC="gcc -m64" \
	    HOSTCFLAGS+="-I/opt/ooce/include" \
	    HOSTLDLIBS+="-L/opt/ooce/lib/amd64 -lnsl -lsocket" tools && \
	touch $@

dtc: $(STAMPS)/dtc-stamp
$(STAMPS)/dtc-stamp: sysroot
	cd dtc-1.6.1 && \
	gmake NO_YAML=1 \
	    NO_PYTHON=1 \
	    SHAREDLIB_LDFLAGS="-shared -Wl,-soname" && \
	gmake PREFIX=$(CROSS) \
	    NO_YAML=1 \
	    NO_PYTHON=1 \
	    INSTALL=/usr/gnu/bin/install install && \
	touch $@

illumos: $(STAMPS)/illumos-stamp
$(STAMPS)/illumos-stamp: setup
	(cd illumos-gate && \
	 $(BLDENV) ../env/aarch64 'cd usr/src; make -j $(MAX_JOBS) setup' && \
	 $(BLDENV) ../env/aarch64 'cd usr/src; make -j $(MAX_JOBS) install') && \
	touch $@

illumos-pkgs: $(STAMPS)/illumos-pkgs
$(STAMPS)/illumos-pkgs:
	(cd illumos-gate && \
	 $(BLDENV) ../env/aarch64 'cd usr/src/pkg; make -j $(MAX_JOBS) install') && \
	touch $@

disk: illumos-pkgs
	ksh tools/build_disk.sh

$(BUILDS):
	mkdir -p $@
$(STAMPS):
	mkdir -p $@
$(ARCHIVES):
	mkdir -p $@
$(CROSS):
	mkdir -p $@
$(SETUP_TARGETS:%=$(BUILDS)/%):
	mkdir -p $@

clean-dtc:
	cd dtc-1.6.1 && gmake clean

clean-illumos:
	(cd illumos-gate && \
	 rm -fr packages && \
	 rm -fr proto && \
	 $(BLDENV) ../env/aarch64 'cd usr/src; make -j $(MAX_JOBS) clobber')

clean: clean-dtc clean-illumos
	rm -fr $(SYSROOT) $(BUILDS) $(STAMPS) $(CROSS)

clobber: clean
	rm -fr $(ARCHIVES)

FRC:
