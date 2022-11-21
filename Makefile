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
	crt		\
	dtc		\
	gcc		\
	idnkit		\
	libc		\
	libc-filters	\
	libkstat	\
	libm		\
	libmd		\
	libnsl		\
	libsocket	\
	libstdc++	\
	libxml2		\
	nspr		\
	nss		\
	openssl		\
	sgs		\
	ssp_ns		\
	u-boot		\
	xorriso		\
	zlib

DOWNLOADS=		\
	binutils-gdb	\
	dtc		\
	gcc		\
	idnkit		\
	illumos-gate	\
	libxml2		\
	nspr		\
	nss		\
	openssl		\
	u-boot		\
	xorriso		\
	zlib

download-zlib: $(ARCHIVES)
	wget -O archives/zlib-1.2.12.tar.gz https://zlib.net/fossils/zlib-1.2.12.tar.gz
	tar xf archives/zlib-1.2.12.tar.gz

download-libxml2: $(ARCHIVES)
	wget -O archives/libxml2-2.9.9.tar.gz http://xmlsoft.org/download/libxml2-2.9.9.tar.gz
	tar xf archives/libxml2-2.9.9.tar.gz

download-idnkit: $(ARCHIVES)
	wget -O archives/idnkit-2.3.tar.bz2 http://jprs.co.jp/idn/idnkit-2.3.tar.bz2
	tar xf archives/idnkit-2.3.tar.bz2

download-openssl: $(ARCHIVES)
	wget -O archives/openssl-3.0.7.tar.gz https://www.openssl.org/source/openssl-3.0.7.tar.gz
	gtar xf archives/openssl-3.0.7.tar.gz
	cp files/openssl-15-illumos-aarch.conf \
	    openssl-3.0.7/Configurations/15-illumos-aarch.conf

download-gcc: $(ARCHIVES)
	git clone --shallow-since=2019-01-01 -b il-10_3_0-arm64 https://github.com/richlowe/gcc

download-binutils-gdb: $(ARCHIVES)
	git clone --shallow-since=2019-01-01 -b illumos-arm64 https://github.com/richlowe/binutils-gdb

download-nss: $(ARCHIVES)
	git clone -b illumos-arm64 https://github.com/richlowe/nss

download-nspr: $(ARCHIVES)
	git clone -b illumos-arm64 https://github.com/richlowe/nspr

download-illumos-gate: $(ARCHIVES)
	git clone -b arm64-gate https://github.com/richlowe/illumos-gate

download-u-boot: $(ARCHIVES)
	git clone --shallow-since=2019-01-01 -b v2022.10 https://github.com/u-boot/u-boot/

# XXXARM: We specify what we extract, because the release tarball contains a
# GNU tar-ism we don't understand.
download-dtc: $(ARCHIVES)
	wget -O archives/dtc-1.6.1.tar.gz https://git.kernel.org/pub/scm/utils/dtc/dtc.git/snapshot/dtc-1.6.1.tar.gz
	tar xf archives/dtc-1.6.1.tar.gz dtc-1.6.1

download-xorriso: $(ARCHIVES)
	wget -O archives/xorriso-1.5.4.pl02.tar.gz https://www.gnu.org/software/xorriso/xorriso-1.5.4.pl02.tar.gz
	tar xf archives/xorriso-1.5.4.pl02.tar.gz
	(cd xorriso-1.5.4 && patch -p1 < ../patches/xorriso-no-libvol.patch)

download: $(DOWNLOADS:%=download-%)
setup: $(SETUP_TARGETS)
$(SETUP_TARGETS): $(SETUP_TARGETS:%=$(BUILDS)/%) $(SYSROOT) $(CROSS) $(BUILDS) $(STAMPS)

binutils-gdb: $(STAMPS)/binutils-gdb-stamp
$(STAMPS)/binutils-gdb-stamp:
	(cd $(BUILDS)/binutils-gdb && \
	../../binutils-gdb/configure \
	    --with-sysroot \
	    --target=aarch64-solaris2.11 \
	    --prefix=$(CROSS) \
	    --enable-initfini-array && \
	gmake -j $(MAX_JOBS) CPPFLAGS+='-I$(GMPINCDIR)' && \
	gmake -j $(MAX_JOBS) install) && \
	touch $@

# Build a tools ld and headers and copy them into the sysroot (in the normal place)
sgs: $(STAMPS)/sgs-stamp
$(STAMPS)/sgs-stamp:
	(cd illumos-gate && \
	 $(BLDENV) ../env/aarch64 'cd usr/src/; make -j $(MAX_JOBS) bldtools sgs' && \
	 rsync -a usr/src/tools/proto/root_i386-nd/ $(CROSS)/ && \
	 mkdir -p $(SYSROOT)/usr/include && \
	 rsync -a proto/root_aarch64/usr/include/ $(SYSROOT)/usr/include/) && \
	touch $@

# Note lp64 only, the default is multilib
gcc: $(STAMPS)/gcc-stamp
$(STAMPS)/gcc-stamp: sgs binutils-gdb
	(cd $(BUILDS)/gcc; \
	../../gcc/configure \
	    --with-gmp-include=$(GMPINCDIR) \
	    --target=aarch64-solaris2.11 \
	    --with-abi=lp64 \
	    --prefix=$(CROSS) \
	    --enable-languages=c,c++ \
	    --with-build-sysroot=$(SYSROOT) \
	    --disable-shared \
	    --enable-c99 \
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
	    --with-as=$(CROSS)/bin/aarch64-solaris2.11-as \
	    --without-gnu-ld \
	    --with-ld=$(CROSS)/opt/onbld/bin/amd64/ld && \
	gmake -j $(MAX_JOBS) && \
	gmake -j $(MAX_JOBS) install && \
	rm -fr $(SYSROOT)/lib/gcc/aarch64-solaris2.11/10.3.0/include-fixed) && \
	touch $@

crt: $(STAMPS)/crt-stamp
$(STAMPS)/crt-stamp: sgs gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/crt; make install' && \
	mkdir -p $(SYSROOT)/usr/lib/aarch64 && \
	cp proto/root_aarch64/usr/lib/*.o $(SYSROOT)/usr/lib/) && \
	touch $@

libc: $(STAMPS)/libc-stamp
$(STAMPS)/libc-stamp: ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libc; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libc.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libc.* $(SYSROOT)/lib/) && \
	touch $@

libm: $(STAMPS)/libm-stamp
$(STAMPS)/libm-stamp: ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libm_aarch64; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libm.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libm.* $(SYSROOT)/lib/) && \
	touch $@

libsocket: $(STAMPS)/libsocket-stamp
$(STAMPS)/libsocket-stamp: libnsl ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libsocket; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libsocket.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libsocket.* $(SYSROOT)/lib/) && \
	touch $@

libkstat: $(STAMPS)/libkstat-stamp
$(STAMPS)/libkstat-stamp: libc ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libkstat; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libkstat.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libkstat.* $(SYSROOT)/lib/) && \
	touch $@

libnsl: $(STAMPS)/libnsl-stamp
$(STAMPS)/libnsl-stamp: libmp libmd libc ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libnsl; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libnsl.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libnsl.* $(SYSROOT)/lib/) && \
	touch $@

libmd: $(STAMPS)/libmd-stamp
$(STAMPS)/libmd-stamp: libc ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libmd; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libmd.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libmd.* $(SYSROOT)/lib/) && \
	touch $@

libmp: $(STAMPS)/libmp-stamp
$(STAMPS)/libmp-stamp: libc ssp_ns gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libmp; make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libmp.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/libmp.* $(SYSROOT)/lib/) && \
	touch $@

zlib: $(STAMPS)/zlib-stamp
$(STAMPS)/zlib-stamp: libc ssp_ns gcc
	(cd build/zlib && \
	  env PATH="$(CROSS)/bin:$$PATH" \
	      CC=$(CROSS)/bin/aarch64-solaris2.11-gcc \
	      AR=$(CROSS)/bin/aarch64-solaris2.11-ar \
	      RANLIB=$(CROSS)/bin/aarch64-solaris2.11-ar \
	      LDSHARED="$(CROSS)/bin/aarch64-solaris2.11-gcc -shared" \
	      CFLAGS="--sysroot=$(SYSROOT) -fpic" \
	  ../../zlib-1.2.12/configure --shared --prefix=$(SYSROOT)/usr && \
	  env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) && \
	  env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

libxml2: $(STAMPS)/libxml2-stamp
$(STAMPS)/libxml2-stamp: libc libm libmp libmd zlib ssp_ns gcc
	(cd build/libxml2 && \
	env PATH="$(CROSS)/bin:$$PATH" \
	    CC=$(CROSS)/bin/aarch64-solaris2.11-gcc \
	    CFLAGS="--sysroot=$(SYSROOT)" \
	 ../../libxml2-2.9.9/configure \
	    --host=aarch64-solaris2.11 \
	    --with-sysroot=$(SYSROOT) \
	    --prefix=$(SYSROOT)/usr \
	    --without-zlib \
	    --without-lzma \
	    --without-python && \
	 env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) LDFLAGS+="-lsocket -lnsl -lmd" && \
	 env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

idnkit: $(STAMPS)/idnkit-stamp
$(STAMPS)/idnkit-stamp: libc ssp_ns gcc
	(cd build/idnkit && \
	 env PATH="$(CROSS)/bin:$$PATH" \
	 CC=$(CROSS)/bin/aarch64-solaris2.11-gcc \
	    CFLAGS="--sysroot=$(SYSROOT)" \
	 ../../idnkit-2.3/configure \
	    --host=aarch64-solaris2.11 \
	    --with-sysroot=$(SYSROOT) \
	    --prefix=$(SYSROOT)/usr && \
	 env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) && \
	 env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

ssp_ns: $(STAMPS)/ssp_ns-stamp
$(STAMPS)/ssp_ns-stamp: gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/ssp_ns && make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/libssp* $(SYSROOT)/usr/lib/) && \
	touch $@

libc-filters: $(STAMPS)/libc-filters-stamp
$(STAMPS)/libc-filters-stamp: libc gcc
	(cd illumos-gate && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/librt && make install' && \
	$(BLDENV) ../env/aarch64 'cd usr/src/cmd/sgs/libdl && make install' && \
	$(BLDENV) ../env/aarch64 'cd usr/src/lib/libpthread && make install' && \
	mkdir -p $(SYSROOT)/usr/lib && \
	rsync -a proto/root_aarch64/usr/lib/librt.* $(SYSROOT)/usr/lib/ && \
	rsync -a proto/root_aarch64/usr/lib/libdl.* $(SYSROOT)/usr/lib/ && \
	rsync -a proto/root_aarch64/usr/lib/libposix4.* $(SYSROOT)/usr/lib/ && \
	rsync -a proto/root_aarch64/usr/lib/libpthread.* $(SYSROOT)/usr/lib/ && \
	mkdir -p $(SYSROOT)/lib && \
	rsync -a proto/root_aarch64/lib/librt.* $(SYSROOT)/lib/ && \
	rsync -a proto/root_aarch64/lib/libdl.* $(SYSROOT)/lib/ && \
	rsync -a proto/root_aarch64/lib/libposix4.* $(SYSROOT)/lib/ && \
	rsync -a proto/root_aarch64/lib/libpthread.* $(SYSROOT)/lib/) && \
	touch $@

libstdc++: $(STAMPS)/libstdc++-stamp
$(STAMPS)/libstdc++-stamp: libc libc-filters ssp_ns gcc
	(cd build/libstdc++ && \
	 env PATH="$(CROSS)/bin:$$PATH" \
	    CC=$(CROSS)/bin/aarch64-solaris2.11-gcc \
	    CXX=$(CROSS)/bin/aarch64-solaris2.11-g++ \
	    CFLAGS="--sysroot=$(SYSROOT) -mno-outline-atomics" \
	    CXXFLAGS="--sysroot=$(SYSROOT) -mno-outline-atomics" \
	    LDFLAGS="--sysroot=$(SYSROOT)" \
	    CPPFLAGS="-I$(SYSROOT)/usr/include" \
	../../gcc/libstdc++-v3/configure \
	    --host=aarch64-solaris2.11 \
	    --prefix=$(SYSROOT)/usr && \
	env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) && \
	env PATH="$(CROSS)/bin:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

nspr: $(STAMPS)/nspr-stamp
$(STAMPS)/nspr-stamp: libc libc-filters ssp_ns gcc
	(cd build/nspr && \
	 env PATH="$(CROSS)/bin/:$$PATH" \
         CC="$(CROSS)/bin/aarch64-solaris2.11-gcc --sysroot=$(SYSROOT)" \
	 ../../nspr/configure \
	    --build=i386-pc-solaris2.11 \
	    --target=aarch64-solaris2.11 \
	    --prefix=$(SYSROOT) \
	    --libdir=$(SYSROOT)/usr/lib/mps \
	    --bindir=$(SYSROOT)/usr/bin \
	    --includedir=$(SYSROOT)/usr/include/mps && \
	env PATH="$(CROSS)/bin/:$$PATH" gmake -j $(MAX_JOBS) && \
	env PATH="$(CROSS)/bin/:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

# XXXARM: This is horrid, I'm sorry
nss: $(STAMPS)/nss-stamp
$(STAMPS)/nss-stamp: libc libc-filters libkstat ssp_ns gcc
	(cd nss_build && \
	    export NATIVE_MACH=i386 \
	    MACH=aarch64 \
	    SRC=$(PWD)/illumos-gate/usr/src/ \
	    NSS_BASE=$(PWD)/nss \
	    NSS_BUILD=$(PWD) \
	    ONBLD_TOOLS=$(PWD)/illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld \
	    ROOT=$(SYSROOT) \
	    aarch64_PRIMARY_CC=gcc10,$(CROSS)/bin/aarch64-solaris2.11-gcc,gnu \
	    aarch64_SYSROOT=$(SYSROOT); \
	    make -j $(MAX_JOBS) -e install_h && \
	    make -j $(MAX_JOBS) -e install) && \
	touch $@

openssl: $(STAMPS)/openssl-stamp
$(STAMPS)/openssl-stamp: libc libc-filters libsocket libnsl zlib ssp_ns gcc
	(cd build/openssl && \
	 env PATH="$(CROSS)/bin/:$$PATH" \
	 CC="gcc --sysroot=$(SYSROOT)" \
	 CFLAGS="-I$(SYSROOT)/usr/include" \
	 LDFLAGS="-shared -Wl,-z,text,-z,aslr,-z,ignore" \
	 MAKE=gmake \
	 ../../openssl-3.0.7/Configure \
	    --prefix=$(SYSROOT)/usr \
	    --cross-compile-prefix=aarch64-solaris2.11- \
	    --api=1.1.1 \
	    shared threads zlib enable-ec_nistp_64_gcc_128 no-asm \
	    solaris-aarch64-gcc \
	    && \
	env PATH="$(CROSS)/bin/:$$PATH" gmake -j $(MAX_JOBS) && \
	env PATH="$(CROSS)/bin/:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

xorriso: $(STAMPS)/xorriso-stamp
$(STAMPS)/xorriso-stamp: libc libc-filters ssp_ns gcc
	(cd build/xorriso && \
	 env PATH="$(CROSS)/bin/:$$PATH" \
         CC="$(CROSS)/bin/aarch64-solaris2.11-gcc --sysroot=$(SYSROOT)" \
	 MAKE=gmake \
	 ../../xorriso-1.5.4/configure \
	    --build=i386-pc-solaris2.11 \
	    --host=aarch64-solaris2.11 \
	    --prefix=$(SYSROOT)/usr && \
	env PATH="$(CROSS)/bin/:$$PATH" gmake -j $(MAX_JOBS) && \
	env PATH="$(CROSS)/bin/:$$PATH" gmake -j $(MAX_JOBS) install) && \
	touch $@

u-boot: $(STAMPS)/u-boot-stamp
$(STAMPS)/u-boot-stamp:
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
$(STAMPS)/dtc-stamp:
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

$(SYSROOT):
	mkdir -p $@
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
	 $(BLDENV) ../env/aarch64 'cd usr/src; make -j $(MAX_JOBS) clobber') && \

# XXXARM: I am, once again, sorry about this.
clean-nss:
	(cd nss_build && \
	    export NATIVE_MACH=i386 \
	    MACH=aarch64 \
	    SRC=$(PWD)/illumos-gate/usr/src/ \
	    NSS_BASE=$(PWD)/nss \
	    NSS_BUILD=$(PWD) \
	    ONBLD_TOOLS=$(PWD)/illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld \
	    ROOT=$(SYSROOT) \
	    aarch64_PRIMARY_CC=gcc10,$(CROSS)/bin/aarch64-solaris2.11-gcc,gnu \
	    aarch64_SYSROOT=$(SYSROOT); \
	    make -j $(MAX_JOBS) -e clobber)

clean: clean-dtc clean-illumos clean-nss
	rm -fr $(SYSROOT) $(BUILDS) $(STAMPS) $(CROSS)

clobber: clean
	rm -fr $(ARCHIVES)

FRC:
