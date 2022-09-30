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

LIBRARY = libnssutil3.a
VERS = .1
OBJECTS = \
	quickder.o \
	secdig.o \
	derdec.o \
	derenc.o \
	dersubr.o \
	dertime.o \
	errstrs.o \
	nssb64d.o \
	nssb64e.o \
	nssrwlk.o \
	nssilock.o \
	oidstring.o \
	pkcs1sig.o \
	portreg.o \
	secalgid.o \
	secasn1d.o \
	secasn1e.o \
	secasn1u.o \
	secitem.o \
	secload.o \
	secoid.o \
	sectime.o \
	secport.o \
	templates.o \
	utf8.o \
	utilmod.o \
	utilpars.o \
	pkcs11uri.o

include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/util
SRCDIR=		$(NSS_BASE)/lib/util

LIBS =		$(DYNLIB)

MAPFILE=$(SRCDIR)/nssutil.def
MAPFILES=mapfile-vers
CPPFLAGS +=
CFLAGS +=
LDLIBS += $(NSSLIBS)

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ

$(LIBS): $(MAPFILES)
$(MAPFILES): $(MAPFILE)
	grep -v ';-' $(MAPFILE) | sed -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' > $@

CLEANFILES+=$(MAPFILES)
