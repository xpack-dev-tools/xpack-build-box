# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2020 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

function build_versioned_components()
{
  if [[ "${XBB_VERSION}" =~ 3\.[4] ]]
  then
    # WARNING: experimental, used only to test builds on Apple Silicon.

    # -------------------------------------------------------------------------

    # The main characteristic of XBB Bootstrap is the compiler version.

    # Fortunatelly GCC 11.[12] were updated and work on Apple hardware.
    XBB_GCC_VERSION="11.2.0" # "8.4.0" # "8.3.0" "7.5.0" "7.4.0"
    XBB_BINUTILS_VERSION="2.36.1" # "2.32" # "2.31"

    XBB_LLVM_BRANDING="xPack Build Box Bootstrap ${HOST_BITS}-bit"
    XBB_BINUTILS_BRANDING="xPack Build Box Bootstrap ${HOST_BITS}-bit binutils"
    XBB_GCC_BRANDING="xPack Build Box Bootstrap ${HOST_BITS}-bit GCC"
    XBB_GLIBC_BRANDING="xPack Build Box Bootstrap ${HOST_BITS}-bit GNU libc"

    # -------------------------------------------------------------------------

    if is_linux
    then
      prepare_library_path

      LD_RUN_PATH="${XBB_LIBRARY_PATH}"

      echo "LD_RUN_PATH=${LD_RUN_PATH}"
      export LD_RUN_PATH
    fi

    # All of he following are compiled with the original Ubuntu compiler
    # (GCC 6.x) and should be locked to system shared libraries.

    # -------------------------------------------------------------------------

    if is_darwin
    then
      build_realpath "1.0.0"
    fi

    if is_linux
    then
      # depends ?
      # Warning: buggy!
      build_patchelf "0.13.1" # "0.12" # "0.10"
    fi

    # build_chrpath "0.16"

    # New zlib, it is used in most of the tools.
    # depends=('glibc')
    build_zlib "1.2.11"

    # Library, required by tar.
    # depends=('sh')
    build_xz "5.2.5" # "5.2.3"

    # New tar, with xz support.
    # depends=('glibc')
    build_tar "1.34" # "1.30" # Requires xz.

    # -------------------------------------------------------------------------
    # From this moment on, .xz archives can be processed.

    # depends=('sh' 'perl' 'awk' 'm4' 'texinfo')
    build_autoconf "2.71" # "2.69"

    # depends=('sh' 'perl')
    # Requires autoconf, the order is important on macOS.
    # PATCH! .xz!
    build_automake "1.16.5" # "1.16.3" # "1.16.2"

    # depends=('glibc' 'glib2 (internal)')
    # Required by wget.
    build_pkg_config "0.29.2"

    # Required by libxcrypt
    # depends=('sh' 'tar' 'glibc')
    # Notice: will use the old compiler
    libtool_version="2.4.6"
    build_libtool "${libtool_version}"

    # Libraries, required by gcc & other.
    # depends=('gcc-libs' 'sh')
    build_gmp "6.2.1" # "6.1.2"
    # depends=('gmp>=5.0')
    build_mpfr "4.1.0" # "3.1.6"
    # depends=('mpfr')
    build_mpc "1.2.1" #C"1.1.0" # "1.0.3"
    # depends=('gmp')
    build_isl "0.24" # "0.21"

    # Replacement for the old libcrypt.so.1.
    # ! Requires new autotools.
    build_libxcrypt "4.4.26" # "4.4.15"

    # New openssl, required by curl, cmake, python, etc.
    # depends=('perl')
    build_openssl "1.1.1l" # "1.0.2u" # "1.0.2r"

    # Requires openssl.
    # depends=('glibc' 'gmp')
    # PATCH!
    build_nettle "3.7.3" # "3.5.1" # "3.4.1"

    # New curl, that better understands all protocols.
    # depends=('ca-certificates' 'krb5' 'libssh2' 'openssl' 'zlib' 'libpsl' 'libnghttp2')
    build_curl "7.80.0" # "7.64.1" # "7.57.0"

    # Libraries, required by gnutls.
    # depends=('glibc')
    build_tasn1 "4.18.0" # "4.15.0" # "4.13"

    # After autogen, requires libopts.so.25.
    # depends=('glibc' 'libidn2' 'libtasn1' 'libunistring' 'nettle' 'p11-kit' 'readline' 'zlib')
    # Retuired by wget.
    build_gnutls "3.7.2" # "3.6.11.1" # "3.6.7"

    # -------------------------------------------------------------------------
    # From this moment on, new https sites can be accessed.

    build_coreutils "9.0" # "8.31"

    # depends=('glibc')
    # PATCH!
    build_m4 "1.4.19" # "1.4.18"

    # depends=('glibc' 'mpfr')
    build_gawk "5.1.1" # "4.2.1"

    # depends ?
    build_sed "4.8" # "4.7"

    # depends=('glibc' 'glib2' 'libunistring' 'ncurses')
    build_gettext "0.21" # "0.19.8"

    # depends=('libsigsegv')
    build_diffutils "3.8" # "3.7"

    # depends=('glibc' 'attr')
    build_patch "2.7.6"

    # depends=('glibc')
    build_bison "3.8.2" # "3.4.2" # "3.3.2"

    # depends=('glibc' 'guile')
    # PATCH!
    build_make "4.3" # "4.2.1"

    if is_darwin && is_arm
    then
      # Still problematic, building GCC in XBB fails with missing __Z5yyendv...
      :
    else
      # macOS 10.10 uses 2.5.3, 11.6 uses 2.6.4, an update is not mandatory.
      # macOS 11.6 uses 2.6.4
      # Ubuntu 12 uses 2.5.35, an update is not mandatory.
      # ! Requires autopoint from autotools.
      # depends=('glibc' 'm4' 'sh')
      # PATCH!
      build_flex "2.6.4" # "2.6.3" fails
    fi

    # depends=()
    # Not needed, possibly harmful for GCC 9.
    # build_libiconv "1.16" # "1.15"

    # depends=('libutil-linux' 'gnutls' 'libidn' 'libpsl>=0.7.1-3' 'gpgme')
    # Required by libmpdec tests
    build_wget "1.21.2" # "1.20.3" # "1.20.1"

    # Required by Python3
    build_expat "2.4.1" # "2.2.9"
    build_libmpdec "2.5.1" # "2.4.2"
    build_libffi "3.4.2" # "3.3"

    # macOS 10.1[04] uses 5.18.2, an update is not mandatory.
    # Ubuntu 12 uses 5.14.2.
    # 5.18.2 fails to build automake 1.16 on Linux (fixed by a patch)

    # macOS 10.10
    # HiRes.c:2061:17: error: use of undeclared identifier 'CLOCK_REALTIME'

    # ! Requires patchelf.
    # depends=('gdbm' 'db' 'glibc')
    # On macOS 10.10 newer versions fail with clang, due to a missing clock_gettime()
    # Warning: macOS divergence!
    # old PATCH!

    # 5.18.2 fails on macOS 10.10
    # ./reentr.h:643:22: error: field has incomplete type 'struct drand48_data'

    # 5.32.0 ok on macOS 11.1

    build_perl "5.34.0" # "5.32.0" # "5.18.2" # "5.24.4" # "5.26.3" # "5.28.2"

    # -------------------------------------------------------------------------

    # Recent versions require C++11.
    # depends=('curl' 'libarchive' 'shared-mime-info' 'jsoncpp' 'rhash')
    build_cmake "3.21.4" # "3.19.8" # "3.15.6" # "3.13.4"

    # -------------------------------------------------------------------------

    # macOS 10.13/11.6 use 2.7.16, close enough.
    # On Apple Silicon it fails, it is not worth the effort.
    # On Ubuntu 18 there is 2.7.17; not much difference with 2.7.18.
    # depends=('bzip2' 'gdbm' 'openssl' 'zlib' 'expat' 'sqlite' 'libffi')
    # build_python2 "2.7.18" # "2.7.16" # "2.7.10" # "2.7.12" # "2.7.14" #  # "2.7.14"

    # require xz, openssl
    build_python3 "3.9.8" # "3.9.7" # "3.8.10" # "3.7.6" # "3.8.1" # "3.7.3"
    # The necessary bits to build these optional modules were not found:
    # _bz2                  _curses               _curses_panel
    # _dbm                  _gdbm                 _sqlite3
    # _tkinter              _uuid                 readline

    # depends=('python3')
    build_meson "0.60.1" # "0.58.1" # "0.57.2" # "0.53.1" # "0.50.0"

      # depends=('python3')
      build_scons "4.2.0" # "3.1.2" # "3.1.1" # "3.0.5" # "3.0.1"

    # Requires scons
    # depends=('python2')
    build_ninja "1.10.2" # "1.10.0" # "1.9.0"

    # makedepend is needed by openssl
    build_util_macros "1.19.3" # "1.19.2" # "1.17.1"
    # PATCH!
    build_xorg_xproto "7.0.31" # Needs a patch for aarch64.
    build_makedepend "1.0.6" # "1.0.5"

    # -------------------------------------------------------------------------
    # Native binutils and gcc.

    # By all means DO NOT build binutils on macOS, since this will
    # override Apple specific tools (ar, strip, etc) and break the
    # build in multiple ways.
    if is_linux
    then
      # Requires gmp, mpfr, mpc, isl.
      # PATCH!
      build_native_binutils "${XBB_BINUTILS_VERSION}"
    fi

    # Requires gmp, mpfr, mpc, isl.
    build_native_gcc "${XBB_GCC_VERSION}"

    (
      # depends=('sh' 'tar' 'glibc')
      # Do it again with the new compiler
      prepare_gcc_env "" "-xbs"

      build_libtool "${libtool_version}" "-2"
    )

    # From here on, a reasonable C++11 is available.

    # -------------------------------------------------------------------------

    strip_static_objects

    if is_linux
    then
      patch_elf_rpath
    fi

    run_tests

    # -------------------------------------------------------------------------

  else
    echo
    echo "Version ${XBB_VERSION} not yet supported."
  fi
}

# -----------------------------------------------------------------------------
