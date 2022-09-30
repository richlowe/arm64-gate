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
include $(SRC)/lib/Makefile.lib

ROOTHDRDIR=$(ROOT)/usr/include/mps
ROOTLIBDIR=$(ROOT)/usr/lib/mps

DLL_PREFIX=lib
DLL_SUFFIX=so
SOFTOKEN_LIBRARY_VERSION=3
SOFTOKEN_LIB_NAME=libsoftokn3.so

CPPFLAGS += -I$(SRCDIR) -I$(HDRDIR) -I$(ROOT)/usr/include/mps
CPPFLAGS += -UDEBUG -DNDEBUG -DSOLARIS2_11 -DSVR4 -DSYSV -D__svr4 -D__svr4__ -DSOLARIS -D_REENTRANT
CPPFLAGS += -DNSS_ENABLE_ECC -DUSE_UTIL_DIRECTLY -DNSS_USE_64
CPPFLAGS += -DNSS_STATIC_SOFTOKEN
CPPFLAGS += -DSHLIB_SUFFIX=\"$(DLL_SUFFIX)\" -DSHLIB_PREFIX=\"$(DLL_PREFIX)\"
CPPFLAGS += -DSHLIB_VERSION=\"$(LIBRARY_VERSION)\"
CPPFLAGS += -DSOFTOKEN_LIB_NAME=\"$(SOFTOKEN_LIB_NAME)\"
CPPFLAGS += -DSOFTOKEN_SHLIB_VERSION=\"$(SOFTOKEN_LIBRARY_VERSION)\"

CPPFLAGS += -I$(NSS_BASE)/lib/dev
CPPFLAGS += -I$(NSS_BASE)/lib/base
CPPFLAGS += -I$(NSS_BASE)/lib/util
CPPFLAGS += -I$(NSS_BASE)/lib/ssl
CPPFLAGS += -I$(NSS_BASE)/lib/ckfw
CPPFLAGS += -I$(NSS_BASE)/lib/certdb
CPPFLAGS += -I$(NSS_BASE)/lib/certhigh
CPPFLAGS += -I$(NSS_BASE)/lib/cryptohi
CPPFLAGS += -I$(NSS_BASE)/lib/pk11wrap
CPPFLAGS += -I$(NSS_BASE)/lib/pkcs7
CPPFLAGS += -I$(NSS_BASE)/lib/pkcs12
CPPFLAGS += -I$(NSS_BASE)/lib/nss
CPPFLAGS += -I$(NSS_BASE)/lib/freebl
CPPFLAGS += -I$(NSS_BASE)/lib/freebl/ecl
CPPFLAGS += -I$(NSS_BASE)/lib/freebl/mpi
CPPFLAGS += -I$(NSS_BASE)/lib/dbm/include
CPPFLAGS += -I$(NSS_BASE)/lib/smime
CPPFLAGS += -I$(NSS_BASE)/lib/softoken
CPPFLAGS += -I$(NSS_BASE)/lib/pki
CPPFLAGS += -I$(NSS_BASE)/lib/sqlite
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/include
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix_pl_nss/pki
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix_pl_nss/system
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix_pl_nss/module
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/util
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/checker
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/results
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/crlsel
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/params
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/store
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/certsel
CPPFLAGS += -I$(NSS_BASE)/lib/libpkix/pkix/top
CPPFLAGS += -I$(NSS_BASE)/lib/ckfw/ckfw
CPPFLAGS += -I$(ROOT)/usr/include/mps

CERRWARN += -_gcc=-Wno-old-style-declaration
CERRWARN += -_gcc=-Wno-unused-variable
CERRWARN += -_gcc=-Wno-unused-function
CERRWARN += -_gcc=-Wno-empty-body
CERRWARN += -_gcc=-Wno-cast-function-type
CERRWARN += -_gcc=-Wno-implicit-fallthrough

LDLIBS += -L$(ROOT)/usr/lib/mps -Wl,-rpath -Wl,/usr/lib/mps
NSSLIBS = -lplc4 -lplds4 -lnspr4 -lnsl -lsocket -ldl -lkstat -lc
CSTD= $(CSTD_GNU99)

# XXXARM: mapfiles are auto-generated and bad, guidance of course doesn't like
# that.
ZGUIDANCE=
