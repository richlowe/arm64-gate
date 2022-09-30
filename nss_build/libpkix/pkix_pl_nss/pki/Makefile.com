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

LIBRARY = libpkixpki.a
VERS = .1
OBJECTS = \
	  pkix_pl_basicconstraints.o \
	  pkix_pl_cert.o \
	  pkix_pl_certpolicyinfo.o \
	  pkix_pl_certpolicymap.o \
	  pkix_pl_certpolicyqualifier.o \
	  pkix_pl_crl.o \
	  pkix_pl_crldp.o \
	  pkix_pl_crlentry.o \
	  pkix_pl_date.o \
	  pkix_pl_generalname.o \
	  pkix_pl_infoaccess.o \
	  pkix_pl_nameconstraints.o \
	  pkix_pl_ocsprequest.o \
	  pkix_pl_ocspresponse.o \
	  pkix_pl_publickey.o \
	  pkix_pl_x500name.o \
	  pkix_pl_ocspcertid.o
include ../../../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/libpkix/pkix_pl_nss/pki
SRCDIR=		$(NSS_BASE)/lib/libpkix/pkix_pl_nss/pki

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
