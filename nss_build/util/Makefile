#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
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
# Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

include ../Makefile.nss

SUBDIRS=	$(MACH)

all :=		TARGET = all
clean :=		TARGET = clean
clobber :=	TARGET = clobber
install :=	TARGET = install

#
# Definitions for header files
#

HDRS = \
	base64.h \
	ciferfam.h \
	eccutil.h \
	hasht.h \
	nssb64.h \
	nssb64t.h \
	nsslocks.h \
	nssilock.h \
	nssilckt.h \
	nssrwlk.h \
	nssrwlkt.h \
	nssutil.h \
	pkcs11.h \
	pkcs11f.h \
	pkcs11p.h \
	pkcs11t.h \
	pkcs11n.h \
	pkcs11u.h \
	pkcs1sig.h \
	portreg.h \
	secasn1.h \
	secasn1t.h \
	seccomon.h \
	secder.h \
	secdert.h \
	secdig.h \
	secdigt.h \
	secitem.h \
	secoid.h \
	secoidt.h \
	secport.h \
	secerr.h \
	utilmodt.h \
	utilrename.h \
	utilpars.h \
	utilparst.h \
	pkcs11uri.h

HDRDIR=		$(NSS_BASE)/lib/util
SRCDIR=		$(NSS_BASE)/lib/util
ROOTHDRS=	$(HDRS:%=$(ROOTHDRDIR)/%)

all clean clobber install: $(SUBDIRS)
install_h: $(ROOTHDRS)


$(ROOTHDRS) := FILEMODE= 644

$(ROOTHDRDIR):
	$(INS.dir)

$(ROOTHDRDIR)/%: $(HDRDIR)/% $(ROOTHDRDIR)
	$(INS.file)

$(SUBDIRS):	FRC
	@cd $@; pwd; $(MAKE) $(TARGET)

FRC:
