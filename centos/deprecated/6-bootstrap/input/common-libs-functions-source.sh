# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Support functions to be used in all versions of the containers.
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
  echo "Building zlib ${XBB_ZLIB_VERSION}..."

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

    ./configure --help

    # Some apps (cmake) would be happier with shared libs.
    # Some apps (python) fail without shared libs.

    ./configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install
  )
}

# -----------------------------------------------------------------------------

function build_xz()
{
  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=xz-git

  # 2016-12-30, "5.2.3"

  local XBB_XZ_VERSION="$1"

  local XBB_XZ_FOLDER="xz-${XBB_XZ_VERSION}"
  # Conservatively use .gz, the native tar may be very old.
  local XBB_XZ_ARCHIVE="${XBB_XZ_FOLDER}.tar.gz"
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
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS}"

    ./configure --help

    ./configure \
      --prefix="${XBB_FOLDER}" \
      --disable-rpath

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/xz" --version
  )

  hash -r
}

# -----------------------------------------------------------------------------

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

    # Mandatory, otherwise it fails on 32-bit.
    export ABI="${BITS}"

    ./configure --help

    ./configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

function build_mpfr()
{
  # http://www.mpfr.org
  # http://www.mpfr.org/mpfr-3.1.6
  # https://www.archlinux.org/packages/core/x86_64/mpfr/

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

    ./configure --help

    ./configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

function build_mpc()
{
  # http://www.multiprecision.org/
  # ftp://ftp.gnu.org/gnu/mpc/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-libmpc

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

    ./configure --help

    ./configure \
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

    ./configure --help

    ./configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )
}

# -----------------------------------------------------------------------------
