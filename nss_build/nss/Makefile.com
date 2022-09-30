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

LIBRARY = libnss3.a
VERS = .1
OBJECTS = \
	nssinit.o nssoptions.o nssver.o utilwrap.o
include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/nss
SRCDIR=		$(NSS_BASE)/lib/nss

LIBS =		$(DYNLIB)

MAPFILE=$(SRCDIR)/nss.def
MAPFILES=mapfile-vers
CPPFLAGS +=
CFLAGS +=
LDLIBS += -Wl,--whole-archive
LDLIBS += ../../certhigh/$(MACH)/libcerthi.a
LDLIBS += ../../cryptohi/$(MACH)/libcryptohi.a
LDLIBS += ../../pk11wrap/$(MACH)/libpk11wrap.a
LDLIBS += ../../certdb/$(MACH)/libcertdb.a
LDLIBS += ../../pki/$(MACH)/libnsspki.a
LDLIBS += ../../dev/$(MACH)/libnssdev.a
LDLIBS += ../../base/$(MACH)/libnssb.a
LDLIBS += ../../libpkix/pkix/certsel/$(MACH)/libpkixcertsel.a
LDLIBS += ../../libpkix/pkix/checker/$(MACH)/libpkixchecker.a
LDLIBS += ../../libpkix/pkix/params/$(MACH)/libpkixparams.a
LDLIBS += ../../libpkix/pkix/results/$(MACH)/libpkixresults.a
LDLIBS += ../../libpkix/pkix/top/$(MACH)/libpkixtop.a
LDLIBS += ../../libpkix/pkix/util/$(MACH)/libpkixutil.a
LDLIBS += ../../libpkix/pkix/crlsel/$(MACH)/libpkixcrlsel.a
LDLIBS += ../../libpkix/pkix/store/$(MACH)/libpkixstore.a
LDLIBS += ../../libpkix/pkix_pl_nss/pki/$(MACH)/libpkixpki.a
LDLIBS += ../../libpkix/pkix_pl_nss/system/$(MACH)/libpkixsystem.a
LDLIBS += ../../libpkix/pkix_pl_nss/module/$(MACH)/libpkixmodule.a
LDLIBS += -Wl,--no-whole-archive

LDLIBS += -lnssutil3 $(NSSLIBS) -lsoftokn3

#XXXARM: This trips a limit in CTF
CTFCONVERT=/bin/true
CTFMERGE=/bin/true
CTFCVTFLAGS+= -s

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ

$(LIBS): $(MAPFILES)
$(MAPFILES): $(MAPFILE)
	grep -v ';-' $(MAPFILE) | sed -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' > $@

CLEANFILES+=$(MAPFILES)
