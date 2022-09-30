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

LIBRARY = libcrmf.a
VERS = .1
OBJECTS = \
 	crmfenc.o	\
	crmftmpl.o	\
	crmfreq.o	\
	crmfpop.o	\
	crmfdec.o	\
	crmfget.o	\
	crmfcont.o	\
	cmmfasn1.o	\
	cmmfresp.o	\
	cmmfrec.o	\
	cmmfchal.o	\
	servget.o	\
	encutil.o	\
	respcli.o	\
	respcmn.o	\
	challcli.o	\
	asn1cmn.o
include ../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/crmf
SRCDIR=		$(NSS_BASE)/lib/crmf

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
