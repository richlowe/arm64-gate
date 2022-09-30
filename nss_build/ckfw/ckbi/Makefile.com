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

LIBRARY = libnssckbi.a
VERS = .1
OBJECTS = \
	anchor.o	\
	constants.o	\
	bfind.o		\
	binst.o 	\
	bobject.o	\
	bsession.o	\
	bslot.o		\
	btoken.o	\
	certdata.o	\
	ckbiver.o

include ../../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/ckfw/builtins
SRCDIR=		$(NSS_BASE)/lib/ckfw/builtins

LIBS =		$(DYNLIB)

MAPFILE=$(SRCDIR)/nssckbi.def
MAPFILES=mapfile-vers
CFLAGS +=
LDLIBS += -Wl,--whole-archive
LDLIBS += ../../../base/$(MACH)/libnssb.a
LDLIBS += ../../ckfw/$(MACH)/libnssckfw.a
LDLIBS += -Wl,--no-whole-archive
LDLIBS += -lnss3 -lnssutil3 $(NSSLIBS)

NSS_CERTDATA_TXT = $(SRCDIR)/certdata.txt

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)
include $(SRC)/lib/Makefile.targ

$(LIBS): $(MAPFILES)
$(MAPFILES): $(MAPFILE)
	grep -v ';-' $(MAPFILE) | sed -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' > $@

CLEANFILES+=$(MAPFILES) pics/certdata.c

pics/certdata.c: $(NSS_CERTDATA_TXT) $(SRCDIR)/certdata.perl
	$(PERL) $(SRCDIR)/certdata.perl $(NSS_CERTDATA_TXT) > $@

pics/certdata.o: pics/certdata.c
	$(COMPILE.c) -o $@ $<
	$(POST_PROCESS_O)
