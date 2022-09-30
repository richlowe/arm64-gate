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

LIBRARY = libsoftokn3.a
VERS = .1
OBJECTS = \
	fipsaudt.o \
	fipstest.o \
	fipstokn.o \
	kbkdf.o   \
	lowkey.o   \
	lowpbe.o   \
	padbuf.o   \
	pkcs11.o   \
	pkcs11c.o  \
	pkcs11u.o  \
	sdb.o  \
	sftkdb.o  \
	sftkdhverify.o  \
	sftkhmac.o  \
	sftkike.o  \
	sftkmessage.o  \
	sftkpars.o  \
	sftkpwd.o  \
	softkver.o  \
	tlsprf.o   \
	jpakesftk.o \
	lgglue.o

include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/softoken
SRCDIR=		$(NSS_BASE)/lib/softoken
MAPFILES=
LIBS =		$(DYNLIB)

CFLAGS +=
LDLIBS +=  -lnssutil3 -lsqlite3 $(NSSLIBS) -lfreebl3

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ

CLEANFILES+=$(MAPFILES)
