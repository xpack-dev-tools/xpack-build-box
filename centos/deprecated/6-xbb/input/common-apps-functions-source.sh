#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

function build_native_binutils()
{
  # https://ftp.gnu.org/gnu/binutils/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=binutils-git
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gdb-git

  # cmake fails with Internal error; use 2.31.
  # 2019-02-02, "2.32"

  local XBB_BINUTILS_VERSION="$1"

  local XBB_BINUTILS_FOLDER_NAME="binutils-${XBB_BINUTILS_VERSION}"
  local XBB_BINUTILS_ARCHIVE="${XBB_BINUTILS_FOLDER_NAME}.tar.xz"
  local XBB_BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/${XBB_BINUTILS_ARCHIVE}"

  # Requires gmp, mpfr, mpc, isl.
  echo
  echo "Building native binutils ${XBB_BINUTILS_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_BINUTILS_ARCHIVE}" "${XBB_BINUTILS_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_BINUTILS_FOLDER_NAME}-native-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_BINUTILS_FOLDER_NAME}-native-build"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-sign-compare"
    export CXXFLAGS="${XBB_CXXFLAGS} -Wno-sign-compare"
    # export LDFLAGS="-static-libstdc++ ${LDFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash "${XBB_BUILD_FOLDER}/${XBB_BINUTILS_FOLDER_NAME}/configure" --help

    bash "${XBB_BUILD_FOLDER}/${XBB_BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${XBB_FOLDER}" \
      --build="${BUILD}" \
      --disable-shared \
      --enable-static \
      --enable-threads \
      --enable-deterministic-archives \
      --disable-gdb

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/size" --version
  )

  hash -r
}

# -----------------------------------------------------------------------------

function build_native_gcc()
{
  # https://gcc.gnu.org
  # https://ftp.gnu.org/gnu/gcc/
  # https://gcc.gnu.org/wiki/InstallingGCC
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gcc-git

  # 2018-12-06, "7.4.0"

  local XBB_GCC_VERSION="$1"

  local XBB_GCC_FOLDER_NAME="gcc-${XBB_GCC_VERSION}"
  local XBB_GCC_ARCHIVE="${XBB_GCC_FOLDER_NAME}.tar.xz"
  local XBB_GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${XBB_GCC_VERSION}/${XBB_GCC_ARCHIVE}"

  # Requires gmp, mpfr, mpc, isl.
  echo
  echo "Building native gcc ${XBB_GCC_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_GCC_ARCHIVE}" "${XBB_GCC_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_GCC_FOLDER_NAME}-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_GCC_FOLDER_NAME}-build"

    xbb_activate
    xbb_activate_installed_bin
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-sign-compare"
    export CXXFLAGS="${XBB_CXXFLAGS} -Wno-sign-compare"
    # export LDFLAGS="-static-libstdc++ ${LDFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash "${XBB_BUILD_FOLDER}/${XBB_GCC_FOLDER_NAME}/configure" --help

    # --disable-shared failed with errors in libstdc++-v3
    # --build used conservatively.
    bash "${XBB_BUILD_FOLDER}/${XBB_GCC_FOLDER_NAME}/configure" \
      --prefix="${XBB_FOLDER}" \
      --build="${BUILD}" \
      --program-suffix="${XBB_GCC_SUFFIX}" \
      --with-pkgversion="${XBB_GCC_BRANDING}" \
      --enable-languages=c,c++ \
      --enable-static \
      --enable-threads=posix \
      --enable-libmpx \
      --enable-__cxa_atexit \
      --disable-libunwind-exceptions \
      --enable-clocale=gnu \
      --disable-libstdcxx-pch \
      --disable-libssp \
      --enable-gnu-unique-object \
      --enable-linker-build-id \
      --enable-lto \
      --enable-plugin \
      --enable-install-libiberty \
      --with-linker-hash-style=gnu \
      --enable-gnu-indirect-function \
      --disable-multilib \
      --disable-werror \
      --enable-checking=release \
      --disable-bootstrap

    # Parallel builds fail while running build/genrecog.
    # make -j ${JOBS}
    make
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/g++${XBB_GCC_SUFFIX}" --version

    mkdir -p "${HOME}/tmp"
    cd "${HOME}/tmp"

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello" << std::endl;
}
__EOF__

    if true
    then

      "${XBB_FOLDER}/bin/g++${XBB_GCC_SUFFIX}" hello.cpp -o hello
      "${XBB_FOLDER}/bin/readelf" -d hello

      if [ "x$(./hello)x" != "xHellox" ]
      then
        exit 1
      fi

    fi

    rm -rf hello.cpp hello
  )

  hash -r
}

# -----------------------------------------------------------------------------
# mingw-w64

function build_mingw_binutils()
{
  # https://ftp.gnu.org/gnu/binutils/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-binutils-weak

  # 2019-02-02, "2.32"

  local XBB_MINGW_BINUTILS_VERSION="$1"

  local XBB_MINGW_BINUTILS_FOLDER_NAME="binutils-${XBB_MINGW_BINUTILS_VERSION}"
  local XBB_MINGW_BINUTILS_ARCHIVE="${XBB_MINGW_BINUTILS_FOLDER_NAME}.tar.xz"
  local XBB_MINGW_BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/${XBB_MINGW_BINUTILS_ARCHIVE}"

  echo
  echo "Building mingw-w64 binutils ${XBB_MINGW_BINUTILS_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MINGW_BINUTILS_ARCHIVE}" "${XBB_MINGW_BINUTILS_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_MINGW_BINUTILS_FOLDER_NAME}-mingw-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_MINGW_BINUTILS_FOLDER_NAME}-mingw-build"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-sign-compare"
    export CXXFLAGS="${XBB_CXXFLAGS} -Wno-sign-compare"
    # export LDFLAGS="-static-libstdc++ ${LDFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # --build used conservatively
    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_BINUTILS_FOLDER_NAME}/configure" --help

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_BINUTILS_FOLDER_NAME}/configure" \
      --prefix="${XBB_FOLDER}" \
      --with-sysroot="${XBB_FOLDER}" \
      --build="${BUILD}" \
      --target=${MINGW_TARGET} \
      --disable-shared \
      --enable-static \
      --disable-multilib \
      --enable-lto \
      --enable-plugins \
      --disable-nls \
      --disable-werror

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-size" --version
  )

  hash -r
}

function build_mingw_all()
{
  # http://mingw-w64.org/doku.php/start
  # https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/

  # 2018-06-03, "5.0.4"

  local XBB_MINGW_VERSION="$1"

  # The original SourceForge location.
  local XBB_MINGW_FOLDER_NAME="mingw-w64-v${XBB_MINGW_VERSION}"
  local XBB_MINGW_ARCHIVE="${XBB_MINGW_FOLDER_NAME}.tar.bz2"
  local XBB_MINGW_URL="https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/${XBB_MINGW_ARCHIVE}"
  # local XBB_MINGW_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_MINGW_ARCHIVE}"

  # If SourceForge is down, there is also a GitHub mirror.
  # https://github.com/mirror/mingw-w64
  # XBB_MINGW_FOLDER_NAME="mingw-w64-${XBB_MINGW_VERSION}"
  # XBB_MINGW_ARCHIVE="v${XBB_MINGW_VERSION}.tar.gz"
  # XBB_MINGW_URL="https://github.com/mirror/mingw-w64/archive/${XBB_MINGW_ARCHIVE}"

  # https://sourceforge.net/p/mingw-w64/wiki2/Cross%20Win32%20and%20Win64%20compiler/
  # https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/configure

  echo
  echo "Building mingw-w64 headers ${XBB_MINGW_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MINGW_ARCHIVE}" "${XBB_MINGW_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}-headers-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}-headers-build"

    xbb_activate
    xbb_activate_installed_dev

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}/mingw-w64-headers/configure" --help

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}/mingw-w64-headers/configure" \
      --prefix="${XBB_FOLDER}/${MINGW_TARGET}" \
      --build="${BUILD}" \
      --host="${MINGW_TARGET}"

    make -j ${JOBS}
    make install-strip

    # GCC requires the `x86_64-w64-mingw32` folder be mirrored as `mingw`
    # in the same root.
    (cd "${XBB_FOLDER}"; ln -s "${MINGW_TARGET}" "mingw")

    # For non-multilib builds, links to "lib32" and "lib64" are no longer
    # needed, "lib" is enough.
  )

  hash -r

  # https://gcc.gnu.org
  # https://gcc.gnu.org/wiki/InstallingGCC
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-gcc

  # https://ftp.gnu.org/gnu/gcc/
  # 2018-12-06, "7.4.0"

  local XBB_MINGW_GCC_VERSION="$2"

  local XBB_MINGW_GCC_FOLDER_NAME="gcc-${XBB_MINGW_GCC_VERSION}"
  local XBB_MINGW_GCC_ARCHIVE="${XBB_MINGW_GCC_FOLDER_NAME}.tar.xz"
  local XBB_MINGW_GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${XBB_MINGW_GCC_VERSION}/${XBB_MINGW_GCC_ARCHIVE}"
  local XBB_MINGW_GCC_BRANDING="xPack Build Box Mingw-w64 GCC\x2C ${BITS}-bit"

  echo
  echo "Building mingw-w64 gcc ${XBB_MINGW_GCC_VERSION}, step 1..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MINGW_GCC_ARCHIVE}" "${XBB_MINGW_GCC_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_MINGW_GCC_FOLDER_NAME}-mingw-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_MINGW_GCC_FOLDER_NAME}-mingw-build"

    xbb_activate
    xbb_activate_installed_bin
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-sign-compare -Wno-implicit-function-declaration -Wno-missing-prototypes"
    export CXXFLAGS="${XBB_CXXFLAGS} -Wno-sign-compare -Wno-type-limits"
    # export LDFLAGS="-static-libstdc++ ${LDFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # For the native build, --disable-shared failed with errors in libstdc++-v3
    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_GCC_FOLDER_NAME}/configure" --help

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_GCC_FOLDER_NAME}/configure" \
      --prefix="${XBB_FOLDER}" \
      --with-sysroot="${XBB_FOLDER}" \
      --build="${BUILD}" \
      --target=${MINGW_TARGET} \
      --with-pkgversion="${XBB_MINGW_GCC_BRANDING}" \
      --enable-languages=c,c++ \
      --enable-shared \
      --enable-static \
      --enable-threads=posix \
      --enable-fully-dynamic-string \
      --enable-libstdcxx-time=yes \
      --with-system-zlib \
      --enable-cloog-backend=isl \
      --enable-lto \
      --disable-dw2-exceptions \
      --enable-libgomp \
      --disable-multilib \
      --enable-checking=release

    # Parallel builds fail.
    # make all-gcc -j ${JOBS}
    make all-gcc
    make install-gcc
  )

  hash -r

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-crt-git

  echo
  echo "Building mingw-w64 crt ${XBB_MINGW_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MINGW_ARCHIVE}" "${XBB_MINGW_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}-crt-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}-crt-build"

    xbb_activate
    xbb_activate_installed_bin
    xbb_activate_installed_dev

    # Overwrite the flags, -ffunction-sections -fdata-sections result in
    # {standard input}: Assembler messages:
    # {standard input}:693: Error: CFI instruction used without previous .cfi_startproc
    # {standard input}:695: Error: .cfi_endproc without corresponding .cfi_startproc
    # {standard input}:697: Error: .seh_endproc used in segment '.text' instead of expected '.text$WinMainCRTStartup'
    # {standard input}: Error: open CFI at the end of file; missing .cfi_endproc directive
    # {standard input}:7150: Error: can't resolve `.text' {.text section} - `.LFB5156' {.text$WinMainCRTStartup section}
    # {standard input}:8937: Error: can't resolve `.text' {.text section} - `.LFB5156' {.text$WinMainCRTStartup section}

    export CFLAGS="-O2 -pipe -Wno-unused-variable -Wno-implicit-fallthrough -Wno-implicit-function-declaration -Wno-cpp"
    export CXXFLAGS="-O2 -pipe"
    export LDFLAGS=""

    # Without it, apparently a bug in autoconf/c.m4, function AC_PROG_CC, results in:
    # checking for _mingw_mac.h... no
    # configure: error: Please check if the mingw-w64 header set and the build/host option are set properly.
    # (https://github.com/henry0312/build_gcc/issues/1)
    export CC=""

    "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}/mingw-w64-crt/configure" --help
    if [ "${BITS}" == "64" ]
    then
      _crt_configure_lib32="--disable-lib32"
      _crt_configure_lib64="--enable-lib64"
    elif [ "${BITS}" == "32" ]
    then
      _crt_configure_lib32="--enable-lib32"
      _crt_configure_lib64="--disable-lib64"
    else
      exit 1
    fi

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}/mingw-w64-crt/configure" \
      --prefix="${XBB_FOLDER}/${MINGW_TARGET}" \
      --with-sysroot="${XBB_FOLDER}" \
      --build="${BUILD}" \
      --host="${MINGW_TARGET}" \
      --enable-wildcard \
      ${_crt_configure_lib32} \
      ${_crt_configure_lib64}

    # Parallel builds fail.
    # make -j ${JOBS}
    make
    make install-strip

    ls -l "${XBB_FOLDER}" "${XBB_FOLDER}/${MINGW_TARGET}"
  )

  hash -r

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-winpthreads-git

  echo
  echo "Building mingw-w64 winpthreads ${XBB_MINGW_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MINGW_ARCHIVE}" "${XBB_MINGW_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}-winphreads-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}-winphreads-build"

    xbb_activate
    xbb_activate_installed_bin
    xbb_activate_installed_dev

    export CPPFLAGS=""
    export CFLAGS="-O2 -pipe"
    export CXXFLAGS="-O2 -pipe"
    export LDFLAGS=""

    export CC=""

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}/mingw-w64-crt/configure" --help
    if [ "${BITS}" == "64" ]
    then
      _crt_configure_lib32="--disable-lib32"
      _crt_configure_lib64="--enable-lib64"
    elif [ "${BITS}" == "32" ]
    then
      _crt_configure_lib32="--enable-lib32"
      _crt_configure_lib64="--disable-lib64"
    else
      exit 1
    fi

    bash "${XBB_BUILD_FOLDER}/${XBB_MINGW_FOLDER_NAME}/mingw-w64-libraries/winpthreads/configure" \
      --prefix="${XBB_FOLDER}/${MINGW_TARGET}" \
      --build="${BUILD}" \
      --host="${MINGW_TARGET}" \
      --enable-static \
      --enable-shared

    make -j ${JOBS}
    make install-strip

    ls -l "${XBB_FOLDER}" "${XBB_FOLDER}/${MINGW_TARGET}"
  )

  hash -r

  echo
  echo "Building mingw-w64 gcc ${XBB_MINGW_GCC_VERSION}, step 2..."

  cd "${XBB_BUILD_FOLDER}"

  # download_and_extract "${XBB_MINGW_GCC_ARCHIVE}" "${XBB_MINGW_GCC_URL}"

  (
    mkdir -p "${XBB_BUILD_FOLDER}/${XBB_MINGW_GCC_FOLDER_NAME}-mingw-build"
    cd "${XBB_BUILD_FOLDER}/${XBB_MINGW_GCC_FOLDER_NAME}-mingw-build"

    xbb_activate
    xbb_activate_installed_bin
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-sign-compare -Wno-implicit-function-declaration -Wno-missing-prototypes"
    export CXXFLAGS="${XBB_CXXFLAGS} -Wno-sign-compare -Wno-type-limits"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # Parallel builds fail.
    # make -j ${JOBS}
    make
    make install-strip
  )

  (
    cd "${XBB_FOLDER}"

    xbb_activate_installed_bin

    if true
    then

      set +e
      find ${MINGW_TARGET} \
        -name '*.so' -type f \
        -print \
        -exec "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-strip" --strip-debug {} \;
      find ${MINGW_TARGET} \
        -name '*.so.*'  \
        -type f \
        -print \
        -exec "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-strip" --strip-debug {} \;
      # Note: without ranlib, windows builds failed.
      find ${MINGW_TARGET} lib/gcc/${MINGW_TARGET} \
        -name '*.a'  \
        -type f  \
        -print \
        -exec "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-strip" --strip-debug {} \; \
        -exec "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-ranlib" {} \;
      set -e

    fi
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-g++" --version

    mkdir -p "${HOME}/tmp"
    cd "${HOME}/tmp"

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello" << std::endl;
}
__EOF__

    "${XBB_FOLDER}/bin/${UNAME_ARCH}-w64-mingw32-g++" hello.cpp -o hello

    rm -rf hello.cpp hello
  )

  hash -r
}

# =============================================================================

function build_openssl()
{
  # https://www.openssl.org
  # https://www.openssl.org/source/
  # https://www.openssl.org/source/openssl-1.0.2r.tar.gz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=openssl-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=openssl-git

  # 2017-Nov-02
  # XBB_OPENSSL_VERSION="1.1.0g"
  # The new version deprecated CRYPTO_set_locking_callback, and yum fails with
  # /usr/lib64/python2.6/site-packages/pycurl.so: undefined symbol: CRYPTO_set_locking_callback

  # 2017-Dec-07, "1.0.2n"
  # 2019-Feb-26, "1.0.2r"

  local XBB_OPENSSL_VERSION="$1"

  local XBB_OPENSSL_FOLDER="openssl-${XBB_OPENSSL_VERSION}"
  # Only .gz available.
  local XBB_OPENSSL_ARCHIVE="${XBB_OPENSSL_FOLDER}.tar.gz"
  local XBB_OPENSSL_URL="https://www.openssl.org/source/${XBB_OPENSSL_ARCHIVE}"
  # local XBB_OPENSSL_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_OPENSSL_ARCHIVE}"

  echo
  echo "Building openssl ${XBB_OPENSSL_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_OPENSSL_ARCHIVE}" "${XBB_OPENSSL_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_OPENSSL_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # This config does not use the standard GNU environment definitions.
    ./config --help

    if [ "${UNAME_ARCH}" == 'x86_64' ]; then
		  optflags='enable-ec_nistp_64_gcc_128'
	  elif [ "${UNAME_ARCH}" == 'i686' ]; then
		  optflags=''
	  fi

    # shared needed by libcurl
    ./config \
      --prefix="${XBB_FOLDER}" \
      --openssldir="${XBB_FOLDER}/openssl" \
      shared \
      no-ssl3-method \
      ${optflags} \
      "-Wa,--noexecstack ${CPPFLAGS} ${CFLAGS} ${LDFLAGS}"

    make depend -j ${JOBS}
    make -j ${JOBS}
    make install_sw

    strip --strip-all "${XBB_FOLDER}/bin/openssl"

    if [ ! -f "${XBB_FOLDER}/openssl/cert.pem" ]
    then
      mkdir -p "${XBB_FOLDER}/openssl"
      ln -s /etc/pki/tls/certs/ca-bundle.crt "${XBB_FOLDER}/openssl/cert.pem"
    fi
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/openssl" version
  )

  hash -r
}

function build_tar()
{
  # https://www.gnu.org/software/tar/
  # https://ftp.gnu.org/gnu/tar/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=tar-git

  # 2016-05-16, "1.29"
  # 2017-12-17, "1.30"
  # "1.32"

  local XBB_TAR_VERSION="$1"

  local XBB_TAR_FOLDER="tar-${XBB_TAR_VERSION}"
  local XBB_TAR_ARCHIVE="${XBB_TAR_FOLDER}.tar.xz"
  local XBB_TAR_URL="https://ftp.gnu.org/gnu/tar/${XBB_TAR_ARCHIVE}"

  # Requires xz
  echo
  echo "Building tar ${XBB_TAR_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_TAR_ARCHIVE}" "${XBB_TAR_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_TAR_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # Avoid 'configure: error: you should not run configure as root'.
    export FORCE_UNSAFE_CONFIGURE=1

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/tar" --version
  )

  hash -r
}

function build_curl()
{
  # https://curl.haxx.se
  # https://curl.haxx.se/download/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=curl-git

  # 2017-10-23, "7.56.1"
  # XBB_CURL_VERSION="7.56.1"
  # 2017-11-29, "7.57.0"

  local XBB_CURL_VERSION="$1"

  local XBB_CURL_FOLDER="curl-${XBB_CURL_VERSION}"
  local XBB_CURL_ARCHIVE="${XBB_CURL_FOLDER}.tar.xz"
  local XBB_CURL_URL="https://curl.haxx.se/download/${XBB_CURL_ARCHIVE}"
  # local XBB_CURL_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_CURL_ARCHIVE}"

  echo
  echo "Building curl ${XBB_CURL_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_CURL_ARCHIVE}" "${XBB_CURL_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_CURL_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --disable-debug \
      --with-ssl \
      --enable-optimize \
      --disable-manual \
      --disable-ldap \
      --disable-ldaps \
      --enable-versioned-symbols \
      --enable-threaded-resolver \
      --with-gssapi \
      --with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt

    make -j ${JOBS}
    make install

    strip --strip-all "${XBB_FOLDER}/bin/curl"
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/curl" --version
  )

  hash -r
}

function build_pkg_config()
{
  # https://www.freedesktop.org/wiki/Software/pkg-config/
  # https://pkgconfig.freedesktop.org/releases/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=pkg-config-git

  # 2017-03-20, "0.29.2"

  local XBB_PKG_CONFIG_VERSION="$1"

  local XBB_PKG_CONFIG_FOLDER="pkg-config-${XBB_PKG_CONFIG_VERSION}"
  local XBB_PKG_CONFIG_ARCHIVE="${XBB_PKG_CONFIG_FOLDER}.tar.gz"
  local XBB_PKG_CONFIG_URL="https://pkgconfig.freedesktop.org/releases/${XBB_PKG_CONFIG_ARCHIVE}"
  # local XBB_PKG_CONFIG_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_PKG_CONFIG_ARCHIVE}"

  echo
  echo "Building pkg-config ${XBB_PKG_CONFIG_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_PKG_CONFIG_ARCHIVE}" "${XBB_PKG_CONFIG_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_PKG_CONFIG_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-unused-value"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help
    bash glib/configure --help

    # Use internal glib
    bash configure \
      --prefix="${XBB_FOLDER}" \
      --with-internal-glib \
      --with-libiconv

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/pkg-config" --version
  )

  hash -r
}


function build_coreutils()
{
  # https://ftp.gnu.org/gnu/coreutils/

  # "8.31"

  local XBB_COREUTILS_VERSION="$1"

  local XBB_COREUTILS_FOLDER_NAME="coreutils-${XBB_COREUTILS_VERSION}"
  local XBB_COREUTILS_ARCHIVE="${XBB_COREUTILS_FOLDER_NAME}.tar.xz"
  local XBB_COREUTILS_URL="https://ftp.gnu.org/gnu/coreutils/${XBB_COREUTILS_ARCHIVE}"

  echo
  echo "Building coreutils ${XBB_COREUTILS_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_COREUTILS_ARCHIVE}" "${XBB_COREUTILS_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_COREUTILS_FOLDER_NAME}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # error: you should not run configure as root (set FORCE_UNSAFE_CONFIGURE=1
    # in environment to bypass this check
    export FORCE_UNSAFE_CONFIGURE=1

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/realpath" --version
  )

  hash -r
}

function build_m4()
{
  # https://www.gnu.org/software/m4/
  # https://ftp.gnu.org/gnu/m4/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=m4-git

  # 2016-12-31, "1.4.18"

  local XBB_M4_VERSION="$1"

  local XBB_M4_FOLDER="m4-${XBB_M4_VERSION}"
  local XBB_M4_ARCHIVE="${XBB_M4_FOLDER}.tar.xz"
  local XBB_M4_URL="https://ftp.gnu.org/gnu/m4/${XBB_M4_ARCHIVE}"

  echo
  echo "Building m4 ${XBB_M4_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_M4_ARCHIVE}" "${XBB_M4_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_M4_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/m4" --version
  )

  hash -r
}

function build_gawk()
{
  # https://www.gnu.org/software/gawk/
  # https://ftp.gnu.org/gnu/gawk/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gawk-git

  # 2017-10-19, "4.2.0"

  local XBB_GAWK_VERSION="$1"

  local XBB_GAWK_FOLDER="gawk-${XBB_GAWK_VERSION}"
  local XBB_GAWK_ARCHIVE="${XBB_GAWK_FOLDER}.tar.xz"
  local XBB_GAWK_URL="https://ftp.gnu.org/gnu/gawk/${XBB_GAWK_ARCHIVE}"

  echo
  echo "Building gawk ${XBB_GAWK_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_GAWK_ARCHIVE}" "${XBB_GAWK_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_GAWK_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --without-libsigsegv

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/awk" --version
  )

  hash -r
}

function build_sed()
{
  # https://www.gnu.org/software/sed/
  # https://ftp.gnu.org/gnu/sed/

  # 2018-12-21, "4.7"

  local XBB_SED_VERSION="$1"

  local XBB_SED_FOLDER="sed-${XBB_SED_VERSION}"
  local XBB_SED_ARCHIVE="${XBB_SED_FOLDER}.tar.xz"
  local XBB_SED_URL="https://ftp.gnu.org/gnu/sed/${XBB_SED_ARCHIVE}"

  echo
  echo "Building sed ${XBB_SED_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_SED_ARCHIVE}" "${XBB_SED_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_SED_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
    --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/sed" --version
  )

  hash -r
}

function build_autoconf()
{
  # https://www.gnu.org/software/autoconf/
  # https://ftp.gnu.org/gnu/autoconf/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=autoconf-git

  # 2012-04-24, "2.69"

  local XBB_AUTOCONF_VERSION="$1"

  local XBB_AUTOCONF_FOLDER="autoconf-${XBB_AUTOCONF_VERSION}"
  local XBB_AUTOCONF_ARCHIVE="${XBB_AUTOCONF_FOLDER}.tar.xz"
  local XBB_AUTOCONF_URL="https://ftp.gnu.org/gnu/autoconf/${XBB_AUTOCONF_ARCHIVE}"

  echo
  echo "Building autoconf ${XBB_AUTOCONF_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_AUTOCONF_ARCHIVE}" "${XBB_AUTOCONF_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_AUTOCONF_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/autoconf" --version
  )

  hash -r
}

function build_automake()
{
  # https://www.gnu.org/software/automake/
  # https://ftp.gnu.org/gnu/automake/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=automake-git

  # 2015-01-05, "1.15"

  local XBB_AUTOMAKE_VERSION="$1"

  local XBB_AUTOMAKE_FOLDER="automake-${XBB_AUTOMAKE_VERSION}"
  local XBB_AUTOMAKE_ARCHIVE="${XBB_AUTOMAKE_FOLDER}.tar.xz"
  local XBB_AUTOMAKE_URL="https://ftp.gnu.org/gnu/automake/${XBB_AUTOMAKE_ARCHIVE}"

  echo
  echo "Building automake ${XBB_AUTOMAKE_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_AUTOMAKE_ARCHIVE}" "${XBB_AUTOMAKE_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_AUTOMAKE_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/automake" --version
  )

  hash -r
}

function build_libtool()
{
  # https://www.gnu.org/software/libtool/
  # http://gnu.mirrors.linux.ro/libtool/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libtool-git

  # 15-Feb-2015, "2.4.6"

  local XBB_LIBTOOL_VERSION="$1"

  local XBB_LIBTOOL_FOLDER="libtool-${XBB_LIBTOOL_VERSION}"
  local XBB_LIBTOOL_ARCHIVE="${XBB_LIBTOOL_FOLDER}.tar.xz"
  local XBB_LIBTOOL_URL="http://ftpmirror.gnu.org/libtool/${XBB_LIBTOOL_ARCHIVE}"
  # local XBB_LIBTOOL_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_LIBTOOL_ARCHIVE}"

  echo
  echo "Building libtool ${XBB_LIBTOOL_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_LIBTOOL_ARCHIVE}" "${XBB_LIBTOOL_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_LIBTOOL_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/libtool" --version
  )

  hash -r
}

function build_gettext()
{
  # https://www.gnu.org/software/gettext/
  # https://ftp.gnu.org/gnu/gettext/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gettext-git

  # 2016-06-09, "0.19.8"

  local XBB_GETTEXT_VERSION="$1"

  local XBB_GETTEXT_FOLDER="gettext-${XBB_GETTEXT_VERSION}"
  local XBB_GETTEXT_ARCHIVE="${XBB_GETTEXT_FOLDER}.tar.xz"
  local XBB_GETTEXT_URL="https://ftp.gnu.org/gnu/gettext/${XBB_GETTEXT_ARCHIVE}"

  echo
  echo "Building gettext ${XBB_GETTEXT_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_GETTEXT_ARCHIVE}" "${XBB_GETTEXT_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_GETTEXT_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-discarded-qualifiers"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/gettext" --version
  )

  hash -r
}

function build_diffutils()
{
  # https://www.gnu.org/software/diffutils/
  # https://ftp.gnu.org/gnu/diffutils/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=diffutils-git

  # 2017-05-21, "3.6"

  local XBB_DIFFUTILS_VERSION="$1"

  local XBB_DIFFUTILS_FOLDER="diffutils-${XBB_DIFFUTILS_VERSION}"
  local XBB_DIFFUTILS_ARCHIVE="${XBB_DIFFUTILS_FOLDER}.tar.xz"
  local XBB_DIFFUTILS_URL="https://ftp.gnu.org/gnu/diffutils/${XBB_DIFFUTILS_ARCHIVE}"

  echo
  echo "Building diffutils ${XBB_DIFFUTILS_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_DIFFUTILS_ARCHIVE}" "${XBB_DIFFUTILS_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_DIFFUTILS_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/diff" --version
  )

  hash -r
}

function build_patch()
{
  # https://www.gnu.org/software/patch/
  # https://ftp.gnu.org/gnu/patch/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=patch-git

  # 2015-03-06, "2.7.5"

  local XBB_PATCH_VERSION="$1"

  local XBB_PATCH_FOLDER="patch-${XBB_PATCH_VERSION}"
  local XBB_PATCH_ARCHIVE="${XBB_PATCH_FOLDER}.tar.xz"
  local XBB_PATCH_URL="https://ftp.gnu.org/gnu/patch/${XBB_PATCH_ARCHIVE}"

  echo
  echo "Building patch ${XBB_PATCH_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_PATCH_ARCHIVE}" "${XBB_PATCH_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_PATCH_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/patch" --version
  )

  hash -r
}

function build_bison()
{
  # https://www.gnu.org/software/bison/
  # https://ftp.gnu.org/gnu/bison/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=bison-git

  # 2015-01-23, "3.0.4"

  local XBB_BISON_VERSION="$1"

  local XBB_BISON_FOLDER="bison-${XBB_BISON_VERSION}"
  local XBB_BISON_ARCHIVE="${XBB_BISON_FOLDER}.tar.xz"
  local XBB_BISON_URL="https://ftp.gnu.org/gnu/bison/${XBB_BISON_ARCHIVE}"

  echo
  echo "Building bison ${XBB_BISON_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_BISON_ARCHIVE}" "${XBB_BISON_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_BISON_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/bison" --version
  )

  hash -r
}

function build_make()
{
  # https://www.gnu.org/software/make/
  # https://ftp.gnu.org/gnu/make/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=make-git

  # 2016-06-10, "4.2.1"

  local XBB_MAKE_VERSION="$1"

  local XBB_MAKE_FOLDER="make-${XBB_MAKE_VERSION}"
  # Only .bz2 available.
  local XBB_MAKE_ARCHIVE="${XBB_MAKE_FOLDER}.tar.bz2"
  local XBB_MAKE_URL="https://ftp.gnu.org/gnu/make/${XBB_MAKE_ARCHIVE}"

  echo
  echo "Building make ${XBB_MAKE_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_MAKE_ARCHIVE}" "${XBB_MAKE_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_MAKE_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --with-guile

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/make" --version
  )

  hash -r
}

function build_wget()
{
  # https://www.gnu.org/software/wget/
  # https://ftp.gnu.org/gnu/wget/
  # https://ftp.gnu.org/gnu/wget/wget-1.20.1.tar.gz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=wget-git

  # 2016-06-10, "1.19"

  local XBB_WGET_VERSION="$1"

  local XBB_WGET_FOLDER="wget-${XBB_WGET_VERSION}"
  local XBB_WGET_ARCHIVE="${XBB_WGET_FOLDER}.tar.gz"
  local XBB_WGET_URL="https://ftp.gnu.org/gnu/wget/${XBB_WGET_ARCHIVE}"

  # http://git.savannah.gnu.org/cgit/wget.git/tree/configure.ac

  # Requires gnutls.
  # On CentOS 32-bits, the runtime test of the included libiconv fails;
  # the solution was to build the latest libiconv.
  echo
  echo "Building wget ${XBB_WGET_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_WGET_ARCHIVE}" "${XBB_WGET_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_WGET_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS} -Wno-implicit-function-declaration"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"
    export LIBS="-liconv"

    bash configure --help

    # libpsl is not available anyway.
    bash configure \
      --prefix="${XBB_FOLDER}" \
      --without-libpsl \
      --without-included-regex \
      --enable-nls \
      --enable-dependency-tracking \
      --with-ssl=gnutls \
      --with-metalink

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/wget" --version
  )

  hash -r
}

function build_texinfo()
{
  # https://www.gnu.org/software/texinfo/
  # https://ftp.gnu.org/gnu/texinfo/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=texinfo-svn

  # 2017-09-12, "6.5"

  local XBB_TEXINFO_VERSION="$1"

  local XBB_TEXINFO_FOLDER="texinfo-${XBB_TEXINFO_VERSION}"
  local XBB_TEXINFO_ARCHIVE="${XBB_TEXINFO_FOLDER}.tar.gz"
  local XBB_TEXINFO_URL="https://ftp.gnu.org/gnu/texinfo/${XBB_TEXINFO_ARCHIVE}"

  # GCC: Texinfo version 4.8 or later is required by make pdf.

  # http://git.savannah.gnu.org/cgit/texinfo.git/tree/INSTALL.generic
  echo
  echo "Installing texinfo ${XBB_TEXINFO_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_TEXINFO_ARCHIVE}" "${XBB_TEXINFO_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_TEXINFO_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/texi2pdf" --version
  )

  hash -r
}

function build_patchelf()
{
  # https://nixos.org/patchelf.html
  # https://nixos.org/releases/patchelf/

  # 2016-02-29, "0.9"

  local XBB_PATCHELF_VERSION="$1"

  local XBB_PATCHELF_FOLDER="patchelf-${XBB_PATCHELF_VERSION}"
  local XBB_PATCHELF_ARCHIVE="${XBB_PATCHELF_FOLDER}.tar.bz2"
  local XBB_PATCHELF_URL="https://nixos.org/releases/patchelf/patchelf-${XBB_PATCHELF_VERSION}/${XBB_PATCHELF_ARCHIVE}"

  echo
  echo "Building patchelf ${XBB_PATCHELF_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_PATCHELF_ARCHIVE}" "${XBB_PATCHELF_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_PATCHELF_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    # Wihtout -static-libstdc++, the bootstrap lib folder is needed to
    # find libstdc++.
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/patchelf" --version
  )

  hash -r
}

function build_dos2unix()
{
  # http://dos2unix.sourceforge.net
  # https://sourceforge.net/projects/dos2unix/files/dos2unix/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=dos2unix-git

  # 30-Oct-2017, "7.4.0"

  local XBB_DOS2UNIX_VERSION="$1"

  local XBB_DOS2UNIX_FOLDER="dos2unix-${XBB_DOS2UNIX_VERSION}"
  local XBB_DOS2UNIX_ARCHIVE="${XBB_DOS2UNIX_FOLDER}.tar.gz"
  local XBB_DOS2UNIX_URL="https://sourceforge.net/projects/dos2unix/files/dos2unix/${XBB_DOS2UNIX_VERSION}/${XBB_DOS2UNIX_ARCHIVE}"

  echo
  echo "Installing dos2unix ${XBB_DOS2UNIX_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_DOS2UNIX_ARCHIVE}" "${XBB_DOS2UNIX_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_DOS2UNIX_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    make prefix="${XBB_FOLDER}" -j ${JOBS} clean all
    make prefix="${XBB_FOLDER}" strip install
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/unix2dos" --version
  )

  hash -r
}

function build_flex()
{
  # https://github.com/westes/flex
  # https://github.com/westes/flex/releases
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=flex-git

  # May 6, 2017, "2.6.4"

  local XBB_FLEX_VERSION="$1"

  local XBB_FLEX_FOLDER="flex-${XBB_FLEX_VERSION}"
  local XBB_FLEX_ARCHIVE="${XBB_FLEX_FOLDER}.tar.gz"
  local XBB_FLEX_URL="https://github.com/westes/flex/releases/download/v${XBB_FLEX_VERSION}/${XBB_FLEX_ARCHIVE}"

  # Requires gettext
  echo
  echo "Building flex ${XBB_FLEX_VERSION}..."
  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_FLEX_ARCHIVE}" "${XBB_FLEX_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_FLEX_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    ./autogen.sh
    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}"

    make -j ${JOBS}
    make install-strip
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/flex" --version
  )

  hash -r
}

function build_perl()
{
  # https://www.cpan.org
  # http://www.cpan.org/src/
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/perl

  # 2017-09-22, "5.26.1"

  local XBB_PERL_VERSION="$1"
  local XBB_PERL_MAJOR_VERSION="5.0"

  local XBB_PERL_FOLDER="perl-${XBB_PERL_VERSION}"
  local XBB_PERL_ARCHIVE="${XBB_PERL_FOLDER}.tar.gz"
  local XBB_PERL_URL="http://www.cpan.org/src/${XBB_PERL_MAJOR_VERSION}/${XBB_PERL_ARCHIVE}"

  echo
  echo "Building perl ${XBB_PERL_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_PERL_ARCHIVE}" "${XBB_PERL_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_PERL_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    set +e
    # Exits with error.
    ./Configure --help
    set -e

    # GCC 7.2.0 does not provide a 'cc'.
    # -Dcc is necessary to avoid picking up the original program.
    export CFLAGS="${CFLAGS} -Wno-implicit-fallthrough -Wno-clobbered -Wno-int-in-bool-context -Wno-nonnull -Wno-format -Wno-sign-compare"

    ./Configure -d -e -s \
      -Dprefix="${XBB_FOLDER}" \
      -Dcc=gcc-7bs \
      -Dccflags="${CFLAGS}"

    make -j ${JOBS}
    make install-strip

    curl -L http://cpanmin.us | perl - App::cpanminus
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/perl" --version
  )

  hash -r
}

function build_cmake()
{
  # https://cmake.org
  # https://cmake.org/download/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=cmake-git

  # November 10, 2017
  # XBB_CMAKE_MAJOR_VERSION="3.9"
  # XBB_CMAKE_VERSION="${XBB_CMAKE_MAJOR_VERSION}.6"

  # November 2017, "3.10.1"
  # XBB_CMAKE_MAJOR_VERSION="3.10"
  # XBB_CMAKE_VERSION="${XBB_CMAKE_MAJOR_VERSION}.1"

  local XBB_CMAKE_VERSION="$1"

  local XBB_CMAKE_MAJOR_VERSION="$(echo ${XBB_CMAKE_VERSION} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1.\2|')"

  local XBB_CMAKE_FOLDER="cmake-${XBB_CMAKE_VERSION}"
  local XBB_CMAKE_ARCHIVE="${XBB_CMAKE_FOLDER}.tar.gz"
  local XBB_CMAKE_URL="https://cmake.org/files/v${XBB_CMAKE_MAJOR_VERSION}/${XBB_CMAKE_ARCHIVE}"

  echo
  echo "Installing cmake ${XBB_CMAKE_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_CMAKE_ARCHIVE}" "${XBB_CMAKE_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_CMAKE_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # Normally it would be much happier with dynamic zlib and curl.

    # If more verbosity is needed:
    #  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON

    # Use the existing cmake to configure this one.
    cmake \
      -DCMAKE_INSTALL_PREFIX="${XBB_FOLDER}" \
      .

    # Parallel builds fail at about 72%.
    # g++-7bs: internal compiler error: Killed (program cc1plus)
    # make -j ${JOBS}
    make
    make install

    strip --strip-all ${XBB_FOLDER}/bin/cmake
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/cmake" --version
  )

  hash -r
}

# -----------------------------------------------------------------------------

function do_python()
{
  # https://www.python.org
  # https://www.python.org/downloads/source/
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python2

  # 2017-09-16, "2.7.14"

  local XBB_PYTHON_VERSION="$1"

  local XBB_PYTHON_FOLDER="Python-${XBB_PYTHON_VERSION}"
  local XBB_PYTHON_ARCHIVE="${XBB_PYTHON_FOLDER}.tar.xz"
  local XBB_PYTHON_URL="https://www.python.org/ftp/python/${XBB_PYTHON_VERSION}/${XBB_PYTHON_ARCHIVE}"

  echo
  echo "Installing python ${XBB_PYTHON_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_PYTHON_ARCHIVE}" "${XBB_PYTHON_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_PYTHON_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    # Python is happier with dynamic zlib and curl.
    # Without --enabled-shared the build fails with
    # ImportError: No module named '_struct'
    # --enable-universalsdk is required by -arch.

    # --with-lto fails.
    # --with-system-expat fails.
    # https://github.com/python/cpython/tree/2.7

    export CFLAGS="${CFLAGS} -Wno-int-in-bool-context -Wno-maybe-uninitialized -Wno-nonnull -Wno-stringop-overflow"

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --enable-shared \
      --with-universal-archs=${BITS}-bits \
      --enable-universalsdk \
      --enable-optimizations \
      --with-threads \
      --enable-unicode=ucs4 \
      --with-system-expat \
      --with-system-ffi \
      --with-dbmliborder=gdbm:ndbm \
      --without-ensurepip

    make -j ${JOBS}
    make install

    strip --strip-all "${XBB_FOLDER}/bin/python"
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/python" --version

    hash -r

    cd "${XBB_BUILD_FOLDER}/${XBB_PYTHON_FOLDER}"

    # Install setuptools and pip. Be sure the new version is used.
    # https://packaging.python.org/tutorials/installing-packages/
    echo
    echo "Installing setuptools and pip..."
    set +e
    "${XBB_FOLDER}/bin/pip" --version
    # pip: command not found
    set -e
    "${XBB_FOLDER}/bin/python" -m ensurepip --default-pip
    "${XBB_FOLDER}/bin/python" -m pip install --upgrade pip setuptools wheel
    "${XBB_FOLDER}/bin/pip" --version
  )

  hash -r
}

function build_python3()
{
  # https://www.python.org
  # https://www.python.org/downloads/source/

  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python-pip

  # 2018-12-24, "3.7.2"

  local XBB_PYTHON_VERSION="$1"

  local XBB_PYTHON_FOLDER_NAME="Python-${XBB_PYTHON_VERSION}"
  local XBB_PYTHON_ARCHIVE="${XBB_PYTHON_FOLDER_NAME}.tar.xz"
  local XBB_PYTHON_URL="https://www.python.org/ftp/python/${XBB_PYTHON_VERSION}/${XBB_PYTHON_ARCHIVE}"

  echo
  echo "Installing python ${XBB_PYTHON_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_PYTHON_ARCHIVE}" "${XBB_PYTHON_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_PYTHON_FOLDER_NAME}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    bash configure --help

    # Python is happier with dynamic zlib and curl.
    # Without --enabled-shared the build fails with
    # ImportError: No module named '_struct'
    # --enable-universalsdk is required by -arch.

    # --with-lto fails.
    # --with-system-expat fails.
    # https://github.com/python/cpython/tree/2.7

    export CFLAGS="${CFLAGS} -Wno-int-in-bool-context -Wno-maybe-uninitialized -Wno-nonnull -Wno-stringop-overflow"

    bash configure \
      --prefix="${XBB_FOLDER}" \
      --enable-shared \
      --with-universal-archs=${BITS}-bits \
      --enable-universalsdk \
      --with-computed-gotos \
      --enable-optimizations \
      --with-lto \
      --with-system-expat \
      --with-dbmliborder=gdbm:ndbm \
      --with-system-ffi \
      --with-system-libmpdec \
      --enable-loadable-sqlite-extensions \
      --without-ensurepip

    make -j ${JOBS} build_all
    make install

    strip --strip-all "${XBB_FOLDER}/bin/python3"
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/python3" --version

    hash -r

    cd "${XBB_BUILD_FOLDER}/${XBB_PYTHON_FOLDER_NAME}"

    # Install setuptools and pip. Be sure the new version is used.
    # https://packaging.python.org/tutorials/installing-packages/
    echo
    echo "Installing setuptools and pip..."
    set +e
    "${XBB_FOLDER}/bin/pip3" --version
    # pip3: command not found
    set -e
    "${XBB_FOLDER}/bin/python3" -m ensurepip --default-pip
    "${XBB_FOLDER}/bin/python3" -m pip install --upgrade pip setuptools wheel
    "${XBB_FOLDER}/bin/pip3" --version
  )

  hash -r
}

function build_meson
{
  # http://mesonbuild.com/
  # https://pypi.org/project/meson/0.50.0/#description
  (
    xbb_activate_installed_bin

    pip3 install meson==$1

    "${XBB_FOLDER}/bin/meson" --version
  )

  hash -r
}

function build_scons()
{
  # http://scons.org
  # https://sourceforge.net/projects/scons/files/scons/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=python2-scons

  # 2017-09-16, "3.0.1"

  local XBB_SCONS_VERSION="$1"

  local XBB_SCONS_FOLDER="scons-${XBB_SCONS_VERSION}"
  local XBB_SCONS_ARCHIVE="${XBB_SCONS_FOLDER}.tar.gz"
  local XBB_SCONS_URL="https://sourceforge.net/projects/scons/files/scons/${XBB_SCONS_VERSION}/${XBB_SCONS_ARCHIVE}"
  # local XBB_SCONS_URL="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${XBB_SCONS_ARCHIVE}"

  echo
  echo "Installing scons ${XBB_SCONS_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_SCONS_ARCHIVE}" "${XBB_SCONS_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_SCONS_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    "${XBB_FOLDER}/bin/python" setup.py install \
      --prefix="${XBB_FOLDER}" \
      --optimize=1
  )

  hash -r
}

function build_wine()
{
  # https://www.winehq.org
  # https://dl.winehq.org/wine/source/
  # https://dl.winehq.org/wine/source/4.x/wine-4.3.tar.xz

  # 2017-09-16, "4.3"

  local XBB_WINE_VERSION="$1"

  local XBB_WINE_VERSION_MAJOR="$(echo ${XBB_WINE_VERSION} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1|')"
  local XBB_WINE_VERSION_MINOR="$(echo ${XBB_WINE_VERSION} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\2|')"

  local XBB_WINE_FOLDER_NAME="wine-${XBB_WINE_VERSION}"
  local XBB_WINE_ARCHIVE="${XBB_WINE_FOLDER_NAME}.tar.xz"
  local XBB_WINE_URL="https://dl.winehq.org/wine/source/${XBB_WINE_VERSION_MAJOR}.x/${XBB_WINE_ARCHIVE}"

  echo
  echo "Installing wine ${XBB_WINE_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_WINE_ARCHIVE}" "${XBB_WINE_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_WINE_FOLDER_NAME}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    if [ "${BITS}" == "64" ]
    then
      ENABLE_64="--enable-win64"
    else
      ENABLE_64=""
    fi

    bash configure --help

    bash configure \
      --prefix="${XBB_FOLDER}" \
      \
      ${ENABLE_64} \
      --disable-win16 \
      --disable-tests \
      \
      --without-freetype \
      --without-x \
      --with-png

    # Parallel builds fail with
    # gcc-7bs: internal compiler error: Killed (program cc1)
    # make -j ${JOBS} STRIP=true
    make STRIP=true
    make install

    if [ "${BITS}" == "64" ]
    then
      (cd "${XBB_FOLDER}/bin"; ln -s wine64 wine)
    fi
  )

  (
    xbb_activate_installed_bin

    # First check if the program is able to tell its version.
    "${XBB_FOLDER}/bin/wine" --version

    # This test should check if the program is able to start
    # a simple executable.
    # As a side effect, the "${HOME}/.wine" folder is created
    # and populated with lots of files., so subsequent runs
    # will no longer have to do it.
    "${XBB_FOLDER}/bin/wine" "${XBB_FOLDER}"/lib*/wine/fakedlls/netstat.exe
  )

  hash -r
}

function build_ninja()
{
  # https://ninja-build.org
  # https://github.com/ninja-build/ninja/archive/v1.9.0.zip
  # https://github.com/ninja-build/ninja/archive/v1.9.0.tar.gz

  # "1.9.0"

  local XBB_NINJA_VERSION="$1"

  local XBB_NINJA_FOLDER_NAME="ninja-${XBB_NINJA_VERSION}"
  local XBB_NINJA_ARCHIVE="v${XBB_NINJA_VERSION}.tar.gz"
  local XBB_NINJA_URL="https://github.com/ninja-build/ninja/archive/${XBB_NINJA_ARCHIVE}"

  echo
  echo "Installing ninja ${XBB_NINJA_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_NINJA_ARCHIVE}" "${XBB_NINJA_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_NINJA_FOLDER_NAME}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    ./configure.py --help

    ./configure.py \
      --bootstrap \
      --verbose \
      --with-python=python2 \
      --platform=linux \

    install -m755 -t "${XBB_FOLDER}/bin" ninja
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/ninja" --version
  )

  hash -r
}

function build_git()
{
  # https://git-scm.com/
  # https://www.kernel.org/pub/software/scm/git/
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/git

  # 30-Oct-2017
  # XBB_GIT_VERSION="2.15.0"

  # 29-Nov-2017, "2.15.1"

  local XBB_GIT_VERSION="$1"

  local XBB_GIT_FOLDER="git-${XBB_GIT_VERSION}"
  local XBB_GIT_ARCHIVE="${XBB_GIT_FOLDER}.tar.xz"
  local XBB_GIT_URL="https://www.kernel.org/pub/software/scm/git/${XBB_GIT_ARCHIVE}"

  echo
  echo "Installing git ${XBB_GIT_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_GIT_ARCHIVE}" "${XBB_GIT_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_GIT_FOLDER}"

    xbb_activate
    xbb_activate_installed_dev

    # export LDFLAGS="-ldl -L${XBB_FOLDER}/lib ${LDFLAGS}"
    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"
    export LIBS="-ldl"

    make configure
    bash configure --help

	  bash configure \
      --prefix="${XBB_FOLDER}"

    # Parallel builds fail with
    # gcc-7bs: internal compiler error: Killed (program cc1)
    # make all -j ${JOBS} CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
    make all CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
    make install

    strip --strip-all "${XBB_FOLDER}/bin/git"
    strip --strip-all "${XBB_FOLDER}/bin"/git-[rsu]*
  )

  (
    xbb_activate_installed_bin

    "${XBB_FOLDER}/bin/git" --version
  )

  hash -r
}

function build_p7zip()
{
  # https://sourceforge.net/projects/p7zip/
  # https://sourceforge.net/projects/p7zip/files/p7zip/16.02/p7zip_16.02_src_all.tar.bz2/download

  # "16.02"

  local XBB_P7ZIP_VERSION="$1"

  local XBB_P7ZIP_FOLDER_NAME="p7zip_${XBB_P7ZIP_VERSION}"
  local XBB_P7ZIP_ARCHIVE="${XBB_P7ZIP_FOLDER_NAME}_src_all.tar.bz2"
  local XBB_P7ZIP_URL="https://sourceforge.net/projects/p7zip/files/p7zip/${XBB_P7ZIP_VERSION}/${XBB_P7ZIP_ARCHIVE}"

  echo
  echo "Building p7zip ${XBB_P7ZIP_VERSION}..."

  cd "${XBB_BUILD_FOLDER}"

  download_and_extract "${XBB_P7ZIP_ARCHIVE}" "${XBB_P7ZIP_URL}"

  (
    cd "${XBB_BUILD_FOLDER}/${XBB_P7ZIP_FOLDER_NAME}"

    xbb_activate
    xbb_activate_installed_dev

    export CPPFLAGS="${XBB_CPPFLAGS}"
    export CFLAGS="${XBB_CFLAGS}"
    export CXXFLAGS="${XBB_CXXFLAGS}"
    export LDFLAGS="${XBB_LDFLAGS_APP}"

    # Override the hard-coded gcc & g++.
    sed -i -e "s|CXX=g++.*|CXX=${CXX}|" makefile.machine
    sed -i -e "s|CC=gcc.*|CC=${CC}|" makefile.machine

    # make test test_7z
    make all_test

    ls -lL bin

    # Override the hard-coded '/usr/local'.
    sed -i -e "s|DEST_HOME=/usr/local|DEST_HOME=${XBB_FOLDER}|" install.sh

    bash install.sh
  )

  (
    xbb_activate_installed_bin

    echo
    "${XBB_FOLDER}/bin/7za" --help
    echo
    "${XBB_FOLDER}/bin/7z" --help
  )

  hash -r
}

# -----------------------------------------------------------------------------
