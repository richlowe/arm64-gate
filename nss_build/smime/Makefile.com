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

LIBRARY = libsmime3.a
VERS = .1
OBJECTS = \
	cmsarray.o \
	cmsasn1.o \
	cmsattr.o \
	cmscinfo.o \
	cmscipher.o \
	cmsdecode.o \
	cmsdigdata.o \
	cmsdigest.o \
	cmsencdata.o \
	cmsencode.o \
	cmsenvdata.o \
	cmsmessage.o \
	cmspubkey.o \
	cmsrecinfo.o \
	cmsreclist.o \
	cmssigdata.o \
	cmssiginfo.o \
	cmsudf.o \
	cmsutil.o \
	smimemessage.o \
	smimeutil.o \
	smimever.o
include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/smime
SRCDIR=		$(NSS_BASE)/lib/smime

LIBS =		$(DYNLIB)

MAPFILE=$(SRCDIR)/smime.def
MAPFILES=mapfile-vers
CPPFLAGS +=
CFLAGS +=
LDLIBS +=

LDLIBS += -Wl,--whole-archive
LDLIBS += ../../pkcs12/$(MACH)/libpkcs12.a
LDLIBS += ../../pkcs7/$(MACH)/libpkcs7.a
LDLIBS += -Wl,--no-whole-archive
LDLIBS += -lnss3 -lnssutil3 $(NSSLIBS)

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ

$(LIBS): $(MAPFILES)
$(MAPFILES): $(MAPFILE)
	grep -v ';-' $(MAPFILE) | sed -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' > $@

CLEANFILES+=$(MAPFILES)
