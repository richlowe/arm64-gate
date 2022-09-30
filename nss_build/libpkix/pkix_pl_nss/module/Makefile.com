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

LIBRARY = libpkixmodule.a
VERS = .1
OBJECTS = \
	pkix_pl_aiamgr.o \
	pkix_pl_colcertstore.o \
	pkix_pl_httpcertstore.o \
	pkix_pl_httpdefaultclient.o \
	pkix_pl_ldaptemplates.o \
	pkix_pl_ldapcertstore.o \
	pkix_pl_ldapresponse.o \
	pkix_pl_ldaprequest.o \
	pkix_pl_ldapdefaultclient.o \
	pkix_pl_nsscontext.o \
	pkix_pl_pk11certstore.o \
	pkix_pl_socket.o
include ../../../../Makefile.nss

HDRDIR=		$(NSS_BASE)/lib/libpkix/pkix_pl_nss/module
SRCDIR=		$(NSS_BASE)/lib/libpkix/pkix_pl_nss/module

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
