#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2017 Hayashi Naoyuki
#

LIBRARY = libfreebl3.a
VERS = .1
OBJECTS = \
	freeblver.o \
	ldvector.o \
	sysrand.o \
	sha_fast.o \
	md2.o \
	md5.o \
	sha512.o \
	cmac.o \
	alghmac.o \
	rawhash.o \
	alg2268.o \
	arcfour.o \
	arcfive.o \
	crypto_primitives.o \
	blake2b.o \
	desblapi.o \
	des.o \
	drbg.o \
	chacha20poly1305.o \
	cts.o \
	ctr.o \
	blinit.o \
	fipsfreebl.o \
	gcm.o \
	hmacct.o \
	rijndael.o \
	aeskeywrap.o \
	camellia.o \
	dh.o \
	ec.o \
	ecdecode.o \
	pqg.o \
	dsa.o \
	rsa.o \
	rsapkcs.o \
	shvfy.o \
	tlsprfalg.o \
	jpake.o \
	seed.o \
	mpprime.o mpmontg.o mplogic.o mpi.o mp_gf2m.o \
	mpcpucache.o \
	ecl.o ecl_mult.o ecl_gf.o \
	ecp_aff.o ecp_jac.o ecp_mont.o \
	ec_naf.o ecp_jm.o ecp_256.o ecp_384.o ecp_521.o \
	ecp_256_32.o ecp_25519.o ecp_secp384r1.o ecp_secp521r1.o \
	secmpi.o \
	curve25519_64.o \
	Hacl_Chacha20.o \
	Hacl_Chacha20Poly1305_32.o \
	Hacl_Poly1305_32.o \
	Hacl_Curve25519_51.o

include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/freebl
SRCDIR=		$(NSS_BASE)/lib/freebl

LIBS =		$(DYNLIB)

MAPFILES=
CPPFLAGS += -DRIJNDAEL_INCLUDE_TABLES -DMP_API_COMPATIBLE
CPPFLAGS += -I$(NSS_BASE)/lib/freebl/verified/kremlin/include
CPPFLAGS += -I$(NSS_BASE)/lib/freebl/verified/kremlin/kremlib/dist/minimal/
CFLAGS +=
LDLIBS += -lnssutil3
LDLIBS += $(NSSLIBS)

pics/chacha20poly1305.o := CERRWARN += -_gcc=-Wno-type-limits
pics/gcm.o := CERRWARN += -_gcc=-Wno-type-limits

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ

CLEANFILES+=$(MAPFILES)

pics/%.o: $(SRCDIR)/mpi/%.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)

pics/%.o: $(SRCDIR)/ecl/%.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)

pics/%.o: $(SRCDIR)/verified/%.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)

pics/%.o: $(SRCDIR)/deprecated/%.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)
