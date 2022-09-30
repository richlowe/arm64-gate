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

TOP= ../../..
LIBRARY = libpk11wrap.a
VERS = .1
OBJECTS = \
	dev3hack.o \
	pk11akey.o \
	pk11auth.o \
	pk11cert.o \
	pk11cxt.o \
	pk11err.o  \
	pk11hpke.o  \
	pk11kea.o \
	pk11list.o \
	pk11load.o \
	pk11mech.o \
	pk11merge.o \
	pk11nobj.o \
	pk11obj.o \
	pk11pars.o \
	pk11pbe.o \
	pk11pk12.o \
	pk11pqg.o \
	pk11sdr.o \
	pk11skey.o \
	pk11slot.o \
	pk11util.o
include ../../Makefile.nss

NSS_LIBRARY_VERSION = 3
SOFTOKEN_LIBRARY_VERSION = 3
CPPFLAGS += -DSHLIB_SUFFIX=\"$(DLL_SUFFIX)\" -DSHLIB_PREFIX=\"$(DLL_PREFIX)\" \
        -DNSS_SHLIB_VERSION=\"$(NSS_LIBRARY_VERSION)\" \
        -DSOFTOKEN_SHLIB_VERSION=\"$(SOFTOKEN_LIBRARY_VERSION)\"

HDRDIR=		$(NSS_BASE)/lib/pk11wrap
SRCDIR=		$(NSS_BASE)/lib/pk11wrap

LIBS =		$(LIBRARY)

MAPFILE=
CPPFLAGS +=
CFLAGS +=
LDLIBS +=
ROOTLIBS=
ROOTLINKS=

all: $(LIBS)
install: all $(ROOTLIBS) $(ROOTLINKS)

include $(SRC)/lib/Makefile.targ
