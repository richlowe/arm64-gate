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

include $(SRC)/Makefile.master

libpkix crmf : pk11wrap
nss : dbm util freebl sqlite softoken \
	  base dev pki libpkix certdb \
	  certhigh pk11wrap cryptohi
ckfw: nss
ssl: nss
freebl: util
smime: pkcs7 pkcs12 nss
softoken: util sqlite

SUBDIRS = dbm util freebl sqlite softoken \
	  base dev pki libpkix certdb \
	  certhigh pk11wrap cryptohi nss ssl pkcs12 pkcs7 smime \
	  crmf jar ckfw

all :=		TARGET= all
clean :=	TARGET= clean
clobber :=	TARGET= clobber
install :=	TARGET= install
install_h := 	TARGET= install_h

all clean clobber install install_h: $(SUBDIRS)

$(SUBDIRS): FRC
	cd $@; pwd; $(MAKE) $(TARGET)

FRC:
