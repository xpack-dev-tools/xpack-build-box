#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------


function build_zlib()
{
  # http://zlib.net
  # http://zlib.net/fossils/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-git

  # 2017-01-15, "1.2.11"

  local XBB_ZLIB_VERSION="$1"

  local XBB_ZLIB_FOLDER="zlib-${XBB_ZLIB_VERSION}"
  local XBB_ZLIB_ARCHIVE="${XBB_ZLIB_FOLDER}.tar.gz"
  local XBB_ZLIB_URL="http://zlib.net/fossils/${XBB_ZLIB_ARCHIVE}"
  # local XBB_ZLIB_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_ZLIB_ARCHIVE}"

  echo
  echo "Building native zlib ${XBB_ZLIB_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_ZLIB_ARCHIVE}" "${XBB_ZLIB_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_ZLIB_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    # -fPIC makes possible to include static libs in shared libs.
    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -fPIC"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    # Some apps (cmake) would be happier with shared libs.
    # Some apps (python) fail without shared libs.

     bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install
  )
}

function build_gmp()
{
  # https://gmplib.org
  # https://gmplib.org/download/gmp/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gmp-hg

  # 16-Dec-2016, "6.1.2"

  local XBB_GMP_VERSION="$1"

  local XBB_GMP_FOLDER="gmp-${XBB_GMP_VERSION}"
  local XBB_GMP_ARCHIVE="${XBB_GMP_FOLDER}.tar.xz"
  local XBB_GMP_URL="https://gmplib.org/download/gmp/${XBB_GMP_ARCHIVE}"
  # local XBB_GMP_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_GMP_ARCHIVE}"

  echo
  echo "Building gmp ${XBB_GMP_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_GMP_ARCHIVE}" "${XBB_GMP_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_GMP_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    # Mandatory, it fails on 32-bits.
    export ABI="${BITS}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

function build_mpfr()
{
  # http://www.mpfr.org
  # http://www.mpfr.org/mpfr-3.1.6
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/mpfr

  # 7 September 2017, "3.1.6"

  local XBB_MPFR_VERSION="$1"

  local XBB_MPFR_FOLDER="mpfr-${XBB_MPFR_VERSION}"
  local XBB_MPFR_ARCHIVE="${XBB_MPFR_FOLDER}.tar.xz"
  local XBB_MPFR_URL="http://www.mpfr.org/${XBB_MPFR_FOLDER}/${XBB_MPFR_ARCHIVE}"
  # local XBB_MPFR_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_MPFR_ARCHIVE}"

  echo
  echo "Building mpfr ${XBB_MPFR_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MPFR_ARCHIVE}" "${XBB_MPFR_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_MPFR_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

function build_mpc()
{
  # http://www.multiprecision.org/
  # ftp://ftp.gnu.org/gnu/mpc
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/libmpc

  # February 2015, "1.0.3"

  local XBB_MPC_VERSION="$1"

  local XBB_MPC_FOLDER="mpc-${XBB_MPC_VERSION}"
  local XBB_MPC_ARCHIVE="${XBB_MPC_FOLDER}.tar.gz"
  local XBB_MPC_URL="ftp://ftp.gnu.org/gnu/mpc/${XBB_MPC_ARCHIVE}"

  echo
  echo "Building mpc ${XBB_MPC_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MPC_ARCHIVE}" "${XBB_MPC_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_MPC_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}


function build_isl()
{
  # http://isl.gforge.inria.fr
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=isl

  # 2016-12-20, "0.18"

  local XBB_ISL_VERSION="$1"

  local XBB_ISL_FOLDER="isl-${XBB_ISL_VERSION}"
  local XBB_ISL_ARCHIVE="${XBB_ISL_FOLDER}.tar.xz"
  local XBB_ISL_URL="http://isl.gforge.inria.fr/${XBB_ISL_ARCHIVE}"
  # local XBB_ISL_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_ISL_ARCHIVE}"

  echo
  echo "Building isl ${XBB_ISL_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_ISL_ARCHIVE}" "${XBB_ISL_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_ISL_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

function build_nettle()
{
  # https://www.lysator.liu.se/~nisse/nettle/
  # https://ftp.gnu.org/gnu/nettle/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=nettle-git

  # 2017-11-19, "3.4"

  local XBB_NETTLE_VERSION="$1"

  local XBB_NETTLE_FOLDER="nettle-${XBB_NETTLE_VERSION}"
  local XBB_NETTLE_ARCHIVE="${XBB_NETTLE_FOLDER}.tar.gz"
  local XBB_NETTLE_URL="https://ftp.gnu.org/gnu/nettle/${XBB_NETTLE_ARCHIVE}"

  echo
  echo "Building nettle ${XBB_NETTLE_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_NETTLE_ARCHIVE}" "${XBB_NETTLE_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_NETTLE_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-implicit-fallthrough -Wno-deprecated-declarations"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --disable-documentation

    make -j ${JOBS}
    # For unknown reasons, on 32-bits make install-info fails
    # (`install-info --info-dir="/opt/xbb/share/info" nettle.info` returns 1)
    # Make the other install targets.
    make install-headers install-static install-pkgconfig install-shared-nettle  install-shared-hogweed

    if [ -f "${XBB_FOLDER}/${LIB_ARCH}/pkgconfig/nettle.pc" ]
    then
      echo
      cat "${XBB_FOLDER}/${LIB_ARCH}/pkgconfig/nettle.pc"
    fi

    if [ -f "${XBB_FOLDER}/${LIB_ARCH}/pkgconfig/hogweed.pc" ]
    then
      echo
      cat "${XBB_FOLDER}/${LIB_ARCH}/pkgconfig/hogweed.pc"
    fi
  )
}

function build_tasn1()
{
  # https://www.gnu.org/software/libtasn1/
  # http://ftp.gnu.org/gnu/libtasn1/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libtasn1-git

  # 2017-11-19, "4.12"

  local XBB_TASN1_VERSION="$1"

  local XBB_TASN1_FOLDER="libtasn1-${XBB_TASN1_VERSION}"
  # .gz only.
  local XBB_TASN1_ARCHIVE="${XBB_TASN1_FOLDER}.tar.gz"
  local XBB_TASN1_URL="https://ftp.gnu.org/gnu/libtasn1/${XBB_TASN1_ARCHIVE}"

  echo
  echo "Building tasn1 ${XBB_TASN1_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_TASN1_ARCHIVE}" "${XBB_TASN1_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_TASN1_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-logical-op -Wno-missing-prototypes -Wno-implicit-fallthrough -Wno-format-truncation"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install

    if [ -f "${XBB_FOLDER}/lib/pkgconfig/libtasn1.pc" ]
    then
      echo
      cat "${XBB_FOLDER}/lib/pkgconfig/libtasn1.pc"
    fi
  )
}

function build_expat()
{
  # https://libexpat.github.io
  # https://github.com/libexpat/libexpat/releases
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=expat-git

  # "2.2.5"

  local XBB_EXPAT_VERSION="$1"

  local XBB_EXPAT_FOLDER="expat-${XBB_EXPAT_VERSION}"
  local XBB_EXPAT_ARCHIVE="${XBB_EXPAT_FOLDER}.tar.bz2"
  local XBB_EXPAT_RELEASE="R_$(echo ${XBB_EXPAT_VERSION} | sed -e 's|[.]|_|g')"
  local XBB_EXPAT_URL="https://github.com/libexpat/libexpat/releases/download/${XBB_EXPAT_RELEASE}/${XBB_EXPAT_ARCHIVE}"

  echo
  echo "Building expat ${XBB_EXPAT_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_EXPAT_ARCHIVE}" "${XBB_EXPAT_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_EXPAT_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

function build_libffi()
{
  # https://sourceware.org/libffi/
  # https://sourceware.org/pub/libffi/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libffi-git

  # 12-Nov-2014, "3.2.1"

  local XBB_LIBFFI_VERSION="$1"

  local XBB_LIBFFI_FOLDER="libffi-${XBB_LIBFFI_VERSION}"
  # .gz only.
  local XBB_LIBFFI_ARCHIVE="${XBB_LIBFFI_FOLDER}.tar.gz"
  local XBB_LIBFFI_URL="https://sourceware.org/pub/libffi/${XBB_LIBFFI_ARCHIVE}"

  echo
  echo "Building libffi ${XBB_LIBFFI_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_LIBFFI_ARCHIVE}" "${XBB_LIBFFI_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_LIBFFI_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --enable-pax_emutramp

    make -j ${JOBS}
    make install

    if [ -f "${XBB_FOLDER}/lib/pkgconfig/libffi.pc" ]
    then
      echo
      cat "${XBB_FOLDER}/lib/pkgconfig/libffi.pc"
    fi
  )
}

function build_libiconv()
{
  # https://www.gnu.org/software/libiconv/
  # https://ftp.gnu.org/pub/gnu/libiconv/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libiconv

  # 2017-02-02, "1.15"

  local XBB_LIBICONV_VERSION="$1"

  local XBB_LIBICONV_FOLDER="libiconv-${XBB_LIBICONV_VERSION}"
  local XBB_LIBICONV_ARCHIVE="${XBB_LIBICONV_FOLDER}.tar.gz"
  local XBB_LIBICONV_URL="https://ftp.gnu.org/pub/gnu/libiconv/${XBB_LIBICONV_ARCHIVE}"

  # Required by wget.
  echo
  echo "Building libiconv ${XBB_LIBICONV_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_LIBICONV_ARCHIVE}" "${XBB_LIBICONV_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_LIBICONV_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip

    # Does not leave a pkgconfig/iconv.pc;
    # Pass -liconv explicitly.
  )
}

function build_gnutls()
{
  # http://www.gnutls.org/
  # https://www.gnupg.org/ftp/gcrypt/gnutls/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gnutls-git

  # 2017-10-21, "3.5.16"
  # XBB_GNUTLS_MAJOR_VERSION="3.5"
  # XBB_GNUTLS_VERSION="${XBB_GNUTLS_MAJOR_VERSION}.16"

  # 2017-10-21, "3.6.1"

  local XBB_GNUTLS_VERSION="$1"
  local XBB_GNUTLS_MAJOR_VERSION="$(echo ${XBB_GNUTLS_VERSION} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1.\2|')"

  local XBB_GNUTLS_FOLDER="gnutls-${XBB_GNUTLS_VERSION}"
  local XBB_GNUTLS_ARCHIVE="${XBB_GNUTLS_FOLDER}.tar.xz"
  local XBB_GNUTLS_URL="https://www.gnupg.org/ftp/gcrypt/gnutls/v${XBB_GNUTLS_MAJOR_VERSION}/${XBB_GNUTLS_ARCHIVE}"

  # Requires libtasn1 & nettle.
  echo
  echo "Building gnutls ${XBB_GNUTLS_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_GNUTLS_ARCHIVE}" "${XBB_GNUTLS_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_GNUTLS_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-parentheses -Wno-bad-function-cast -Wno-unused-macros -Wno-bad-function-cast -Wno-unused-variable -Wno-pointer-sign -Wno-implicit-fallthrough -Wno-format-truncation -Wno-missing-prototypes -Wno-missing-declarations -Wno-shadow -Wno-sign-compare"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --without-p11-kit \
      --enable-guile \
      --with-guile-site-dir=no \
      --with-included-unistring

    make -j ${JOBS}
    make install-strip

    if [ -f "${XBB_FOLDER}/lib/pkgconfig/gnutls.pc" ]
    then
      echo
      cat "${XBB_FOLDER}/lib/pkgconfig/gnutls.pc"
    fi
  )
}

function build_xz()
{
  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=xz-git

  # 2016-12-30, "5.2.3"

  local XBB_XZ_VERSION="$1"

  local XBB_XZ_FOLDER="xz-${XBB_XZ_VERSION}"
  local XBB_XZ_ARCHIVE="${XBB_XZ_FOLDER}.tar.xz"
  local XBB_XZ_URL="https://sourceforge.net/projects/lzmautils/files/${XBB_XZ_ARCHIVE}"
  # local XBB_XZ_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_XZ_ARCHIVE}"

  echo
  echo "Building xz ${XBB_XZ_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_XZ_ARCHIVE}" "${XBB_XZ_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_XZ_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-implicit-fallthrough"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --disable-rpath

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate

    "${XBB_FOLDER}/bin/xz" --version
  )

  hash -r
}

function build_libpng()
{
  # To ensure builds stability, use slightly older releases.
  # https://sourceforge.net/projects/libpng/files/libpng16/
  # https://sourceforge.net/projects/libpng/files/libpng16/older-releases/

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libpng-git
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-libpng

  # LIBPNG_VERSION="1.2.53"
  # LIBPNG_VERSION="1.6.17"
  # LIBPNG_VERSION="1.6.23" # 2016-06-09
  # LIBPNG_VERSION="1.6.36" # 2018-12-01
  # LIBPNG_SFOLDER="libpng12"
  # LIBPNG_SFOLDER="libpng16"

  # 2017-09-16
  # 2018-12-01, "1.6.36"

  local XBB_LIBPNG_VERSION="$1"
  local XBB_LIBPNG_SFOLDER="libpng16"

  local XBB_LIBPNG_FOLDER_NAME="libpng-${XBB_LIBPNG_VERSION}"
  local XBB_LIBPNG_ARCHIVE="${XBB_LIBPNG_FOLDER_NAME}.tar.xz"
  local XBB_LIBPNG_URL="https://sourceforge.net/projects/libpng/files/${XBB_LIBPNG_SFOLDER}/${XBB_LIBPNG_VERSION}/${XBB_LIBPNG_ARCHIVE}"
  # local XBB_LIBPNG_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_LIBPNG_ARCHIVE}"

  echo
  echo "Installing libpng ${XBB_LIBPNG_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_LIBPNG_ARCHIVE}" "${XBB_LIBPNG_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_LIBPNG_FOLDER_NAME}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_LIB}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

# -----------------------------------------------------------------------------
