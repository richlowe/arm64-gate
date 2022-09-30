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

LIBRARY = libssl3.a
VERS = .1
OBJECTS = \
        dtlscon.o \
        dtls13con.o \
        prelib.o \
        ssl3con.o \
        ssl3gthr.o \
        sslauth.o \
        sslbloom.o \
        sslcon.o \
        ssldef.o \
        sslencode.o \
        sslenum.o \
        sslerr.o \
        sslerrstrs.o \
        sslinit.o \
        ssl3ext.o \
        ssl3exthandle.o \
        sslmutex.o \
        sslnonce.o \
        sslreveal.o \
        sslsecur.o \
        sslsnce.o \
        sslsock.o \
        sslspec.o \
        ssltrace.o \
        sslver.o \
        authcert.o \
        cmpcert.o \
        selfencrypt.o \
        sslinfo.o \
        ssl3ecc.o \
        tls13con.o \
        tls13exthandle.o \
        tls13hashstate.o \
        tls13hkdf.o \
        tls13psk.o \
        tls13replay.o \
        sslcert.o \
        sslgrp.o \
        sslprimitive.o \
        tls13ech.o \
        tls13echv.o \
        tls13subcerts.o \
        unix_err.o

include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/ssl
SRCDIR=		$(NSS_BASE)/lib/ssl

LIBS =		$(DYNLIB)

MAPFILE=$(SRCDIR)/ssl.def
MAPFILES=mapfile-vers
LDLIBS += -lnss3 -lnssutil3 $(NSSLIBS) -lz

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)
include $(SRC)/lib/Makefile.targ

$(LIBS): $(MAPFILES)
$(MAPFILES): $(MAPFILE)
	grep -v ';-' $(MAPFILE) | sed -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' > $@

CLEANFILES+=$(MAPFILES)
