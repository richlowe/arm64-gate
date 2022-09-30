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

LIBRARY = libsqlite3.a
VERS = .1
OBJECTS = sqlite3.o
include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/sqlite
SRCDIR=		$(NSS_BASE)/lib/sqlite

LIBS =		$(DYNLIB)

MAPFILE=$(SRCDIR)/sqlite.def
MAPFILES=mapfile-vers
CPPFLAGS += -DSQLITE_THREADSAFE=1 -DHAVE_STDINT_H=1 -DHAVE_INTTYPES_H=1
LDLIBS += -lc -lgcc

pics/sqlite3.o := CERRWARN += -_gcc10=-Wno-return-local-addr
pics/sqlite3.o := CERRWARN += -_gcc11=-Wno-return-local-addr
pics/sqlite3.o := CERRWARN += -_gcc11=-Wno-misleading-indentation

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ

$(LIBS): $(MAPFILES)
$(MAPFILES): $(MAPFILE)
	grep -v ';-' $(MAPFILE) | sed -e 's,;+,,' -e 's; DATA ;;' -e 's,;;,,' -e 's,;.*,;,' > $@

CLEANFILES+= $(MAPFILES)
