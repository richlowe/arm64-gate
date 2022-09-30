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

LIBRARY = libpkixchecker.a
VERS = .1
OBJECTS = \
	pkix_basicconstraintschecker.o \
	pkix_certchainchecker.o \
	pkix_crlchecker.o \
	pkix_ekuchecker.o \
	pkix_expirationchecker.o \
	pkix_namechainingchecker.o \
	pkix_nameconstraintschecker.o \
	pkix_ocspchecker.o \
	pkix_revocationmethod.o \
	pkix_revocationchecker.o \
	pkix_policychecker.o \
	pkix_signaturechecker.o \
	pkix_targetcertchecker.o
include ../../../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/libpkix/pkix/checker
SRCDIR=		$(NSS_BASE)/lib/libpkix/pkix/checker

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
