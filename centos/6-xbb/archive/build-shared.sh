#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is -x.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

# Script to build a Docker image with the xPack Build Box (xbb).
#
# Building the newest tools on CentOS 6 directly seems now possible, but
# with some limitations; it is debatable if they are relevant or not.
# However it is not guaranteed that the old GCC 4.4 will continue to 
# build future versions.
# So an intermediate solution is used, which includes the most recent 
# versions that can be build with GCC 4.4. This intermediate version is 
# used to build the final tools.

# Header files have been installed in:
#    /opt/xbb/include

# Libraries have been installed in:
#    /opt/xbb/lib

# To activate the new build environment, use:
#
#   $ source /opt/xbb/xbb.sh
#   $ xbb_activate

# If you ever happen to want to link against installed libraries
# in a given directory, LIBDIR, you must either use libtool, and
# specify the full pathname of the library, or use the '-LLIBDIR'
# flag during linking and do at least one of the following:
#    - add LIBDIR to the 'LD_LIBRARY_PATH' environment variable
#      during execution
#    - add LIBDIR to the 'LD_RUN_PATH' environment variable
#      during linking
#    - use the '-Wl,-rpath -Wl,LIBDIR' linker flag
#    - have your system administrator add LIBDIR to '/etc/ld.so.conf'

# Credits: Inspired by Holy Build Box build script.

XBB_INPUT="/xbb-input"
XBB_DOWNLOAD="/tmp/xbb-download"
XBB_TMP="/tmp/xbb"

XBB="/opt/xbb"
XBB_BUILD="${XBB_TMP}"/xbb-build

XBB_BOOTSTRAP="/opt/xbb-bootstrap"

MAKE_CONCURRENCY=2

# -----------------------------------------------------------------------------

mkdir -p "${XBB_TMP}"
mkdir -p "${XBB_DOWNLOAD}"

mkdir -p "${XBB}"
mkdir -p "${XBB_BUILD}"

# -----------------------------------------------------------------------------

# x86_64 or i686
UNAME_ARCH=$(uname -p)
if [ "${UNAME_ARCH}" == "x86_64" ]
then
  BITS="64"
  LIB_ARCH="lib64"
elif [ "${UNAME_ARCH}" == "i686" ]
then
  BITS="32"
  LIB_ARCH="lib"
fi

BUILD=${UNAME_ARCH}-linux-gnu

# x86_64-w64-mingw32 or i686-w64-mingw32
MINGW_TARGET=${UNAME_ARCH}-w64-mingw32

# -----------------------------------------------------------------------------

# Make all tools choose gcc, not the old cc.
export CC=gcc
export CXX=g++

# -----------------------------------------------------------------------------

# Note: __EOF__ is quoted to prevent substitutions here.
cat <<'__EOF__' >> "${XBB}"/xbb.sh

export XBB_FOLDER="/opt/xbb"

function xbb_activate_param()
{
  PREFIX_=${PREFIX_:-${XBB_FOLDER}}

  # Do not include -I... here, use CPPFLAGS.
  EXTRA_CFLAGS_=${EXTRA_CFLAGS_:-""}
  EXTRA_CXXFLAGS_=${EXTRA_CXXFLAGS_:-${EXTRA_CFLAGS_}}

  EXTRA_LDFLAGS_=${EXTRA_LDFLAGS_:-""}

  # Do not include -I... here, use CPPFLAGS.
  EXTRA_STATICLIB_CFLAGS_=${EXTRA_STATICLIB_CFLAGS_:-""}
  EXTRA_STATICLIB_CXXFLAGS_=${EXTRA_STATICLIB_CXXFLAGS_:-${EXTRA_STATICLIB_CFLAGS_}}

  # Do not include -I... here, use CPPFLAGS.
  EXTRA_SHLIB_CFLAGS_=${EXTRA_SHLIB_CFLAGS_:-""}
  EXTRA_SHLIB_CXXFLAGS_=${EXTRA_SHLIB_CXXFLAGS_:-${EXTRA_SHLIB_CFLAGS_}}
  
  EXTRA_SHLIB_LDFLAGS_=${EXTRA_SHLIB_LDFLAGS_:-""}

  EXTRA_LDPATHFLAGS_=${EXTRA_LDPATHFLAGS_:-""}

  export PATH="${PREFIX_}"/bin:${PATH}
  export C_INCLUDE_PATH="${PREFIX_}"/include
  export CPLUS_INCLUDE_PATH="${PREFIX_}"/include
  export LIBRARY_PATH="${PREFIX_}"/lib
  export PKG_CONFIG_PATH="${PREFIX_}"/lib64/pkgconfig:"${PREFIX_}"/lib/pkgconfig:/usr/lib/pkgconfig
  export LD_LIBRARY_PATH="${PREFIX_}"/lib64:"${PREFIX_}"/lib

  export CPPFLAGS="-I${PREFIX_}"/include
  export LDPATHFLAGS="-L${PREFIX_}/lib64 -L${PREFIX_}/lib ${EXTRA_LDPATHFLAGS_}"

  # Do not include -I... here, use CPPFLAGS.
  local COMMON_CFLAGS_=${COMMON_CFLAGS_:-"-g -O2"}
  local COMMON_CXXFLAGS_=${COMMON_CXXFLAGS_:-${COMMON_CFLAGS_}}

  export CFLAGS="${COMMON_CFLAGS_} ${EXTRA_CFLAGS_}"
	export CXXFLAGS="${COMMON_CXXFLAGS_} ${EXTRA_CXXFLAGS_}"
  export LDFLAGS="${LDPATHFLAGS} ${EXTRA_LDFLAGS_}"

	export STATICLIB_CFLAGS="${COMMON_CFLAGS_} ${EXTRA_STATICLIB_CFLAGS_}"
	export STATICLIB_CXXFLAGS="${COMMON_CXXFLAGS_} ${EXTRA_STATICLIB_CXXFLAGS_}"

	export SHLIB_CFLAGS="${COMMON_CFLAGS_} ${EXTRA_SHLIB_CFLAGS_}"
	export SHLIB_CXXFLAGS="${COMMON_CXXFLAGS_} ${EXTRA_SHLIB_CXXFLAGS_}"
  export SHLIB_LDFLAGS="${LDPATHFLAGS} ${EXTRA_SHLIB_LDFLAGS_}"

  echo "xPack Build Box activated! $(lsb_release -is) $(lsb_release -rs), $(gcc --version | grep gcc), $(ldd --version | grep ldd)"
  echo
  echo PATH=${PATH}
  echo
  echo CFLAGS=${CFLAGS}
  echo CXXFLAGS=${CXXFLAGS}
  echo CPPFLAGS=${CPPFLAGS}
  echo LDFLAGS=${LDFLAGS}
  echo
  echo STATICLIB_CFLAGS=${STATICLIB_CFLAGS}
  echo STATICLIB_CXXFLAGS=${STATICLIB_CXXFLAGS}
  echo
  echo SHLIB_CFLAGS=${SHLIB_CFLAGS}
  echo SHLIB_CXXFLAGS=${SHLIB_CXXFLAGS}
  echo SHLIB_LDFLAGS=${SHLIB_LDFLAGS}
  echo
  echo LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
  echo PKG_CONFIG_PATH=${PKG_CONFIG_PATH}
}

xbb_activate()
{
  PREFIX_="${XBB_FOLDER}"
  EXTRA_CFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_LDFLAGS_="-Wl,--gc-sections"
  EXTRA_STATICLIB_CFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_SHLIB_CFLAGS_="-fPIC"

  xbb_activate_param 
}

xbb_activate_static()
{
  PREFIX_="${XBB_FOLDER}"
  EXTRA_CFLAGS_="-ffunction-sections -fdata-sections -fvisibility=hidden"
  EXTRA_LDFLAGS_="-static-libstdc++ -Wl,--gc-sections"
  EXTRA_STATICLIB_CFLAGS_="-ffunction-sections -fdata-sections -fvisibility=hidden"
  EXTRA_SHLIB_CFLAGS_="-fvisibility=hidden -fPIC"
  EXTRA_SHLIB_LDFLAGS_="-static-libstdc++"

  xbb_activate_param 
}

xbb_activate_shared()
{
  PREFIX_="${XBB_FOLDER}"
  EXTRA_CFLAGS_="-fvisibility=hidden"
  EXTRA_LDFLAGS_="-static-libstdc++"
  EXTRA_STATICLIB_CFLAGS_="-fvisibility=hidden"
  EXTRA_SHLIB_CFLAGS_="-fvisibility=hidden -fPIC"
  EXTRA_SHLIB_LDFLAGS_="-static-libstdc++"

  xbb_activate_param 
}

__EOF__
# The above marker must start in the first column.

# -----------------------------------------------------------------------------

# Note: __EOF__ is quoted to prevent substitutions here.
mkdir -p "${XBB}"/bin
cat <<'__EOF__' >> "${XBB}"/bin/pkg-config-verbose
#! /bin/sh
# pkg-config wrapper for debug

pkg-config $@
RET=$?
OUT=$(pkg-config $@)
echo "($PKG_CONFIG_PATH) | pkg-config $@ -> $RET [$OUT]" 1>&2
exit ${RET}

__EOF__
# The above marker must start in the first column.

chmod +x "${XBB}"/bin/pkg-config-verbose

export PKG_CONFIG="${XBB}/bin/pkg-config-verbose"

# -----------------------------------------------------------------------------

# Make the bootstrap tools available in the entire script.
source "${XBB_BOOTSTRAP}"/xbb.sh

xbb_activate_bootstrap()
{
  PREFIX_="${XBB_BOOTSTRAP}"

  EXTRA_CFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_CXXFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_LDFLAGS_="-static-libstdc++ -Wl,--gc-sections -Wl,-rpath -Wl,\"${XBB}/lib\""
  EXTRA_STATICLIB_CFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_STATICLIB_CXXFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_SHLIB_LDFLAGS_="-static-libstdc++"

  xbb_activate_param
}

# -----------------------------------------------------------------------------

function extract()
{
  local ARCHIVE_NAME="$1"
  (
    xbb_activate_bootstrap

    tar xf "${ARCHIVE_NAME}"
  )
}

function download()
{
  local ARCHIVE_NAME="$1"
  local URL="$2"

  if [ ! -f "${XBB_DOWNLOAD}/${ARCHIVE_NAME}" ]
  then
    (
      xbb_activate_bootstrap

      rm -f "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download"
      curl --fail -L -o "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download" "${URL}"
      mv "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download" "${XBB_DOWNLOAD}/${ARCHIVE_NAME}"
    )
  fi
}

function download_and_extract()
{
  local ARCHIVE_NAME="$1"
  local URL="$2"

  download "${ARCHIVE_NAME}" "${URL}"
  extract "${XBB_DOWNLOAD}/${ARCHIVE_NAME}"
}

function eval_bool()
{
  local VAL="$1"
  [[ "${VAL}" = 1 || "${VAL}" = true || "${VAL}" = yes || "${VAL}" = y ]]
}

# =============================================================================

function do_zlib() {

  # http://zlib.net
  # http://zlib.net/fossils/
  # 2017-01-15
  XBB_ZLIB_VERSION="1.2.11"
  XBB_ZLIB_FOLDER="zlib-${XBB_ZLIB_VERSION}"
  XBB_ZLIB_ARCHIVE="${XBB_ZLIB_FOLDER}.tar.gz"
  XBB_ZLIB_URL="http://zlib.net/fossils/${XBB_ZLIB_ARCHIVE}"

  echo
  echo "Building zlib ${XBB_ZLIB_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_ZLIB_ARCHIVE}" "${XBB_ZLIB_URL}"

  (
    cd "${XBB_ZLIB_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    # Some apps (cmake) would be happier with shared libs.
    # Some apps (python) fail without shared libs.
    ./configure \
      --prefix="${XBB}"

    make -j${MAKE_CONCURRENCY}
    make install

    if [ -f "${XBB}"/lib/libz.a ]
    then
      strip --strip-debug "${XBB}"/lib/libz.a 
    fi

    # 415 Bus error
    # if [ -f "${XBB}"/lib/libz.so ]
    # then
    #   strip --strip-debug "${XBB}"/lib/libz.so
    # fi
  )
}

function do_openssl() {

  # https://www.openssl.org
  # https://www.openssl.org/source/
  # 2017-Nov-02 
  XBB_OPENSSL_VERSION="1.1.0g"
  XBB_OPENSSL_FOLDER="openssl-${XBB_OPENSSL_VERSION}"
  # Only .gz available.
  XBB_OPENSSL_ARCHIVE="${XBB_OPENSSL_FOLDER}.tar.gz"
  XBB_OPENSSL_URL="https://www.openssl.org/source/${XBB_OPENSSL_ARCHIVE}"

  echo
  echo "Building openssl ${XBB_OPENSSL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_OPENSSL_ARCHIVE}" "${XBB_OPENSSL_URL}"

  (
    cd "${XBB_OPENSSL_FOLDER}"
    xbb_activate_bootstrap

    # OpenSSL already passes optimization flags regardless of CFLAGS.
		export CFLAGS=`echo "${STATICLIB_CFLAGS}" | sed 's/-O2//'`

    ./config --help

    # Without the 'shared' option cmake builds normally fail, but there 
    # are workarounds:
    # - disable compression (`no-comp`), which should fix the need for 
    #  zlib, which breaks cmake.
    # - disable threads (`no-threads`), which breaks cmake.
    ./config \
      --prefix="${XBB}" \
      --openssldir="${XBB}"/openssl \
      no-threads \
      no-shared \
      no-comp \
      no-sse2

    make
    make install_sw

    strip --strip-all "${XBB}/bin/openssl"

    if [ -f "${XBB}"/lib/libcrypto.a ]
    then
      strip --strip-debug "${XBB}"/lib/libcrypto.a
    fi

    if [ -f "${XBB}"/lib/libssl.a ]
    then
      strip --strip-debug "${XBB}"/lib/libssl.a 
    fi

    if [ -f "${XBB}"/lib/libcrypto.so ]
    then
      strip --strip-debug "${XBB}"/lib/libcrypto.so*
    fi

    if [ -f "${XBB}"/lib/libssl.so ]
    then
      strip --strip-debug "${XBB}"/lib/libssl.so*
    fi

    # Patch the .pc files to add refs to libs.
    if [ -f "${XBB}"/lib/pkgconfig/openssl.pc ]
    then
      cat "${XBB}"/lib/pkgconfig/openssl.pc
      sed -i 's/^Libs:.*/Libs: -L${libdir} -lssl -lcrypto -ldl/' "${XBB}"/lib/pkgconfig/openssl.pc
      sed -i 's/^Libs.private:.*/Libs.private: -L${libdir} -lssl -lcrypto -ldl -lz/' "${XBB}"/lib/pkgconfig/openssl.pc
      cat "${XBB}"/lib/pkgconfig/openssl.pc
    fi

    if [ -f "${XBB}"/lib/pkgconfig/libssl.pc ]
    then
      cat "${XBB}"/lib/pkgconfig/libssl.pc
      sed -i 's/^Libs:.*/Libs: -L${libdir} -lssl -lcrypto -ldl/' "${XBB}"/lib/pkgconfig/libssl.pc
      sed -i 's/^Libs.private:.*/Libs.private: -L${libdir} -lssl -lcrypto -ldl -lz/' "${XBB}"/lib/pkgconfig/libssl.pc
      cat "${XBB}"/lib/pkgconfig/libssl.pc
    fi

    if [ ! -f "${XBB}"/openssl/cert.pem ]
    then
      mkdir -p "${XBB}"/openssl
      ln -s /etc/pki/tls/certs/ca-bundle.crt "${XBB}"/openssl/cert.pem
    fi
  )

  "${XBB}"/bin/openssl version

  hash -r
}

function do_curl() {

  # https://curl.haxx.se
  # https://curl.haxx.se/download/
  # 2017-10-23 
  XBB_CURL_VERSION="7.56.1"
  XBB_CURL_FOLDER="curl-${XBB_CURL_VERSION}"
  XBB_CURL_ARCHIVE="${XBB_CURL_FOLDER}.tar.xz"
  XBB_CURL_URL="https://curl.haxx.se/download/${XBB_CURL_ARCHIVE}"

  echo
  echo "Building curl ${XBB_CURL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_CURL_ARCHIVE}" "${XBB_CURL_URL}"

  (
    cd "${XBB_CURL_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS}"

    ./configure --help

    # --disable-ftp --disable-ftps 
    # ./buildconf
    ./configure \
      --prefix="${XBB}" \
      --enable-static \
      --disable-shared \
      --disable-debug \
      --enable-optimize \
      --disable-werror \
			--disable-curldebug \
      --enable-symbol-hiding \
      --disable-ares \
      --disable-manual \
      --disable-ldap \
      --disable-ldaps \
			--disable-rtsp \
      --disable-dict \
      --disable-gopher \
      --disable-imap \
			--disable-imaps \
      --disable-pop3 \
      --disable-pop3s \
      --without-librtmp \
      --disable-smtp \
      --disable-smtps \
			--disable-telnet \
      --disable-tftp \
      --disable-smb \
      --disable-versioned-symbols \
			--without-libmetalink \
      --without-libidn \
      --without-libssh2 \
      --without-libmetalink \
      --without-nghttp2 \
			--with-ssl

    make -j${MAKE_CONCURRENCY}
    make install

    strip --strip-all "${XBB}"/bin/curl

    if [ -f "${XBB}"/lib/libcurl.a ]
    then
      strip --strip-debug "${XBB}"/lib/libcurl.a
    fi

    if [ -f "${XBB}"/lib/libcurl.so ]
    then
      strip --strip-debug "${XBB}"/lib/libcurl.so
    fi
  )

  "${XBB}"/bin/curl --version

  hash -r
}

# -----------------------------------------------------------------------------

function do_xz() {

  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # 2016-12-30
  XBB_XZ_VERSION="5.2.3"
  XBB_XZ_FOLDER="xz-${XBB_XZ_VERSION}"
  XBB_XZ_ARCHIVE="${XBB_XZ_FOLDER}.tar.xz"
  XBB_XZ_URL="https://sourceforge.net/projects/lzmautils/files/${XBB_XZ_ARCHIVE}"

  echo
  echo "Building xz ${XBB_XZ_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_XZ_ARCHIVE}" "${XBB_XZ_URL}"

  (
    cd "${XBB_XZ_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS} -Wno-implicit-fallthrough"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/xz --version

  hash -r
}

function do_tar() {

  # https://www.gnu.org/software/tar/
  # https://ftp.gnu.org/gnu/tar/
  # 2016-05-16
  XBB_TAR_VERSION="1.29"
  XBB_TAR_FOLDER="tar-${XBB_TAR_VERSION}"
  XBB_TAR_ARCHIVE="${XBB_TAR_FOLDER}.tar.xz"
  XBB_TAR_URL="https://ftp.gnu.org/gnu/tar/${XBB_TAR_ARCHIVE}"

  # Requires xz
  echo
  echo "Building tar ${XBB_TAR_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_TAR_ARCHIVE}" "${XBB_TAR_URL}"

  (
    cd "${XBB_TAR_FOLDER}"
    xbb_activate_bootstrap

    # Avoid 'configure: error: you should not run configure as root'.
    export FORCE_UNSAFE_CONFIGURE=1

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/tar --version

  hash -r
}

# -----------------------------------------------------------------------------
# Libraries.

function do_gmp() {

  # https://gmplib.org
  # https://gmplib.org/download/gmp/
  # 16-Dec-2016
  XBB_GMP_VERSION="6.1.2"
  XBB_GMP_FOLDER="gmp-${XBB_GMP_VERSION}"
  XBB_GMP_ARCHIVE="${XBB_GMP_FOLDER}.tar.xz"
  XBB_GMP_URL="https://gmplib.org/download/gmp/${XBB_GMP_ARCHIVE}"

  echo
  echo "Building gmp ${XBB_GMP_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GMP_ARCHIVE}" "${XBB_GMP_URL}"

  (
    cd "${XBB_GMP_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS}"

    # Mandatory, it fails on 32-bits. 
    export ABI="${BITS}"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )
}

function do_mpfr() {

  # http://www.mpfr.org
  # http://www.mpfr.org/mpfr-3.1.6
  # 7 September 2017
  XBB_MPFR_VERSION="3.1.6"
  XBB_MPFR_FOLDER="mpfr-${XBB_MPFR_VERSION}"
  XBB_MPFR_ARCHIVE="${XBB_MPFR_FOLDER}.tar.xz"
  XBB_MPFR_URL="http://www.mpfr.org/${XBB_MPFR_FOLDER}/${XBB_MPFR_ARCHIVE}"

  echo
  echo "Building mpfr ${XBB_MPFR_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_MPFR_ARCHIVE}" "${XBB_MPFR_URL}"

  (
    cd "${XBB_MPFR_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS}"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )
}

function do_mpc() {

  # http://www.multiprecision.org/
  # ftp://ftp.gnu.org/gnu/mpc
  # February 2015
  XBB_MPC_VERSION="1.0.3"
  XBB_MPC_FOLDER="mpc-${XBB_MPC_VERSION}"
  XBB_MPC_ARCHIVE="${XBB_MPC_FOLDER}.tar.gz"
  XBB_MPC_URL="ftp://ftp.gnu.org/gnu/mpc/${XBB_MPC_ARCHIVE}"

  echo
  echo "Building mpc ${XBB_MPC_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_MPC_ARCHIVE}" "${XBB_MPC_URL}"

  (
    cd "${XBB_MPC_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS}"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )
}

function do_isl() {

  # http://isl.gforge.inria.fr
  # 2016-12-20
  XBB_ISL_VERSION="0.18"
  XBB_ISL_FOLDER="isl-${XBB_ISL_VERSION}"
  XBB_ISL_ARCHIVE="${XBB_ISL_FOLDER}.tar.xz"
  XBB_ISL_URL="http://isl.gforge.inria.fr/${XBB_ISL_ARCHIVE}"

  echo
  echo "Building isl ${XBB_ISL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_ISL_ARCHIVE}" "${XBB_ISL_URL}"

  (
    cd "${XBB_ISL_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS}"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )
}

function do_nettle() {

  # https://www.lysator.liu.se/~nisse/nettle/
  # https://ftp.gnu.org/gnu/nettle/
  # 2017-11-19
  XBB_NETTLE_VERSION="3.4"
  XBB_NETTLE_FOLDER="nettle-${XBB_NETTLE_VERSION}"
  XBB_NETTLE_ARCHIVE="${XBB_NETTLE_FOLDER}.tar.gz"
  XBB_NETTLE_URL="https://ftp.gnu.org/gnu/nettle/${XBB_NETTLE_ARCHIVE}"

  echo
  echo "Building nettle ${XBB_NETTLE_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_NETTLE_ARCHIVE}" "${XBB_NETTLE_URL}"

  (
    cd "${XBB_NETTLE_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS} -Wno-implicit-fallthrough"
    # export CFLAGS="${SHLIB_CFLAGS}"
    # export LDFLAGS="${SHLIB_LDFLAGS}"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static

    make -j${MAKE_CONCURRENCY}
    make install

    if [ -f "${XBB}/${LIB_ARCH}"/pkgconfig/nettle.pc ]
    then
      echo
      cat "${XBB}/${LIB_ARCH}"/pkgconfig/nettle.pc
    fi

    if [ -f "${XBB}/${LIB_ARCH}"/pkgconfig/hogweed.pc ]
    then
      echo
      cat "${XBB}/${LIB_ARCH}"/pkgconfig/hogweed.pc
    fi
  )
}

function do_tasn1() {

  # https://www.gnu.org/software/libtasn1/
  # http://ftp.gnu.org/gnu/libtasn1/
  # 2017-11-19
  XBB_TASN1_VERSION="4.12"
  XBB_TASN1_FOLDER="libtasn1-${XBB_TASN1_VERSION}"
  # .gz only.
  XBB_TASN1_ARCHIVE="${XBB_TASN1_FOLDER}.tar.gz"
  XBB_TASN1_URL="https://ftp.gnu.org/gnu/libtasn1/${XBB_TASN1_ARCHIVE}"

  echo
  echo "Building tasn1 ${XBB_TASN1_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_TASN1_ARCHIVE}" "${XBB_TASN1_URL}"

  (
    cd "${XBB_TASN1_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS} -Wno-logical-op -Wno-missing-prototypes -Wno-implicit-fallthrough -Wno-format-truncation"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install

    if [ -f "${XBB}"/lib/pkgconfig/libtasn1.pc ]
    then
      echo
      cat "${XBB}"/lib/pkgconfig/libtasn1.pc
    fi
  )
}

function do_gnutls() {

  # http://www.gnutls.org/
  # https://www.gnupg.org/ftp/gcrypt/gnutls/v3.5/
  # 2017-10-21
  XBB_GNUTLS_MAJOR_VERSION="3.5"
  XBB_GNUTLS_VERSION="${XBB_GNUTLS_MAJOR_VERSION}.16"
  XBB_GNUTLS_FOLDER="gnutls-${XBB_GNUTLS_VERSION}"
  XBB_GNUTLS_ARCHIVE="${XBB_GNUTLS_FOLDER}.tar.xz"
  XBB_GNUTLS_URL="https://www.gnupg.org/ftp/gcrypt/gnutls/v${XBB_GNUTLS_MAJOR_VERSION}/${XBB_GNUTLS_ARCHIVE}"

  # Requires libtasn1 & nettle.
  echo
  echo "Building gnutls ${XBB_GNUTLS_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GNUTLS_ARCHIVE}" "${XBB_GNUTLS_URL}"

  (
    cd "${XBB_GNUTLS_FOLDER}"
    xbb_activate_bootstrap

    export PATH="${XBB}"/bin:${PATH}
    export CFLAGS="${STATICLIB_CFLAGS} -Wno-parentheses -Wno-bad-function-cast -Wno-unused-macros -Wno-bad-function-cast -Wno-unused-variable -Wno-pointer-sign -Wno-implicit-fallthrough -Wno-format-truncation -Wno-missing-prototypes -Wno-missing-declarations -Wno-shadow -Wno-sign-compare"
    export CXXFLAGS="${STATICLIB_CXXFLAGS}"
    # Without it 'error: libtasn1.h: No such file or directory'
    export CPPFLAGS="-I${XBB}/include ${CPPFLAGS}"
    export LDFLAGS="-L\"${XBB}\"/lib -L\"${XBB}/${LIB_ARCH}\" ${LDFLAGS}"
    export PKG_CONFIG_PATH="${XBB}/lib/pkgconfig:${XBB}/${LIB_ARCH}/pkgconfig:${PKG_CONFIG_PATH}"
  
    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static \
      --with-included-unistring \
      --without-p11-kit

    make -j${MAKE_CONCURRENCY}
    make install-strip

    echo
    cat "${XBB}"/lib/pkgconfig/gnutls.pc

    # Patch the gnutls.pc to add dependednt libs, to make wget build.
    if [ "${BITS}" == "64" ]
    then
      sed -i 's/^Libs:.*/Libs: -L${libdir} -L${exec_prefix}\/lib64 -lgnutls -ltasn1 -lnettle -lhogweed -lgmp/' "${XBB}/lib/pkgconfig/gnutls.pc"
    elif [ "${BITS}" == "32" ]
    then
      sed -i 's/^Libs:.*/Libs: -L${libdir} -L${exec_prefix}\/lib -lgnutls -ltasn1 -lnettle -lhogweed -lgmp/' "${XBB}/lib/pkgconfig/gnutls.pc"
    else
      exit 1
    fi
    
    if [ -f "${XBB}"/lib/pkgconfig/gnutls.pc ]
    then
      echo
      cat "${XBB}"/lib/pkgconfig/gnutls.pc
    fi
  )
}

# -----------------------------------------------------------------------------
# Build the GNU tools.

function do_m4() {

  # https://www.gnu.org/software/m4/
  # https://ftp.gnu.org/gnu/m4/
  # XBB_M4_VERSION=1.4.17
  # 2016-12-31
  XBB_M4_VERSION="1.4.18"
  XBB_M4_FOLDER="m4-${XBB_M4_VERSION}"
  XBB_M4_ARCHIVE="${XBB_M4_FOLDER}.tar.xz"
  XBB_M4_URL="https://ftp.gnu.org/gnu/m4/${XBB_M4_ARCHIVE}"

  echo
  echo "Building m4 ${XBB_M4_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_M4_ARCHIVE}" "${XBB_M4_URL}"

  (
    cd "${XBB_M4_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/m4 --version

  hash -r
}

function do_gawk() {

  # https://www.gnu.org/software/gawk/
  # https://ftp.gnu.org/gnu/gawk/
  # 2017-10-19
  XBB_GAWK_VERSION="4.2.0"
  XBB_GAWK_FOLDER="gawk-${XBB_GAWK_VERSION}"
  XBB_GAWK_ARCHIVE="${XBB_GAWK_FOLDER}.tar.xz"
  XBB_GAWK_URL="https://ftp.gnu.org/gnu/gawk/${XBB_GAWK_ARCHIVE}"

  echo
  echo "Building gawk ${XBB_GAWK_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GAWK_ARCHIVE}" "${XBB_GAWK_URL}"

  (
    cd "${XBB_GAWK_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    # Without --disable-shared it fails to link with static mpfr & gmp
    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/awk --version

  hash -r
}

function do_autoconf() {

  # https://www.gnu.org/software/autoconf/
  # https://ftp.gnu.org/gnu/autoconf/
  # 2012-04-24
  XBB_AUTOCONF_VERSION="2.69"
  XBB_AUTOCONF_FOLDER="autoconf-${XBB_AUTOCONF_VERSION}"
  XBB_AUTOCONF_ARCHIVE="${XBB_AUTOCONF_FOLDER}.tar.xz"
  XBB_AUTOCONF_URL="https://ftp.gnu.org/gnu/autoconf/${XBB_AUTOCONF_ARCHIVE}"

  echo
  echo "Building autoconf ${XBB_AUTOCONF_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_AUTOCONF_ARCHIVE}" "${XBB_AUTOCONF_URL}"

  (
    cd "${XBB_AUTOCONF_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
      
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/autoconf --version

  hash -r
}

function do_automake() {

  # https://www.gnu.org/software/automake/
  # https://ftp.gnu.org/gnu/automake/
  # 2015-01-05
  XBB_AUTOMAKE_VERSION="1.15"
  XBB_AUTOMAKE_FOLDER="automake-${XBB_AUTOMAKE_VERSION}"
  XBB_AUTOMAKE_ARCHIVE="${XBB_AUTOMAKE_FOLDER}.tar.xz"
  XBB_AUTOMAKE_URL="https://ftp.gnu.org/gnu/automake/${XBB_AUTOMAKE_ARCHIVE}"

  echo
  echo "Building automake ${XBB_AUTOMAKE_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_AUTOMAKE_ARCHIVE}" "${XBB_AUTOMAKE_URL}"

  (
    cd "${XBB_AUTOMAKE_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
          
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/automake --version

  hash -r
}

function do_libtool() {

  # https://www.gnu.org/software/libtool/
  # http://gnu.mirrors.linux.ro/libtool/
  # 15-Feb-2015
  XBB_LIBTOOL_VERSION="2.4.6"
  XBB_LIBTOOL_FOLDER="libtool-${XBB_LIBTOOL_VERSION}"
  XBB_LIBTOOL_ARCHIVE="${XBB_LIBTOOL_FOLDER}.tar.xz"
  XBB_LIBTOOL_URL="http://ftpmirror.gnu.org/libtool/${XBB_LIBTOOL_ARCHIVE}"

  echo
  echo "Building libtool ${XBB_LIBTOOL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_LIBTOOL_ARCHIVE}" "${XBB_LIBTOOL_URL}"

  (
    cd "${XBB_LIBTOOL_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/libtool --version

  hash -r
}

function do_gettext() {

  # https://www.gnu.org/software/gettext/
  # https://ftp.gnu.org/gnu/gettext/
  # 2016-06-09
  XBB_GETTEXT_VERSION="0.19.8"
  XBB_GETTEXT_FOLDER="gettext-${XBB_GETTEXT_VERSION}"
  XBB_GETTEXT_ARCHIVE="${XBB_GETTEXT_FOLDER}.tar.xz"
  XBB_GETTEXT_URL="https://ftp.gnu.org/gnu/gettext/${XBB_GETTEXT_ARCHIVE}"

  echo
  echo "Building gettext ${XBB_GETTEXT_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GETTEXT_ARCHIVE}" "${XBB_GETTEXT_URL}"

  (
    cd "${XBB_GETTEXT_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${CFLAGS} -Wno-discarded-qualifiers"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/gettext --version

  hash -r
}

function do_patch() {

  # https://www.gnu.org/software/patch/
  # https://ftp.gnu.org/gnu/patch/
  # 2015-03-06
  XBB_PATCH_VERSION="2.7.5"
  XBB_PATCH_FOLDER="patch-${XBB_PATCH_VERSION}"
  XBB_PATCH_ARCHIVE="${XBB_PATCH_FOLDER}.tar.xz"
  XBB_PATCH_URL="https://ftp.gnu.org/gnu/patch/${XBB_PATCH_ARCHIVE}"

  echo
  echo "Building patch ${XBB_PATCH_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_PATCH_ARCHIVE}" "${XBB_PATCH_URL}"

  (
    cd "${XBB_PATCH_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/patch --version

  hash -r
}

function do_diffutils() {

  # https://www.gnu.org/software/diffutils/
  # https://ftp.gnu.org/gnu/diffutils/
  # 2017-05-21
  XBB_DIFFUTILS_VERSION="3.6"
  XBB_DIFFUTILS_FOLDER="diffutils-${XBB_DIFFUTILS_VERSION}"
  XBB_DIFFUTILS_ARCHIVE="${XBB_DIFFUTILS_FOLDER}.tar.xz"
  XBB_DIFFUTILS_URL="https://ftp.gnu.org/gnu/diffutils/${XBB_DIFFUTILS_ARCHIVE}"

  echo
  echo "Building diffutils ${XBB_DIFFUTILS_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_DIFFUTILS_ARCHIVE}" "${XBB_DIFFUTILS_URL}"

  (
    cd "${XBB_DIFFUTILS_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
      
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/diff --version

  hash -r
}

function do_bison() {

  # https://www.gnu.org/software/bison/
  # https://ftp.gnu.org/gnu/bison/
  # 2015-01-23
  XBB_BISON_VERSION="3.0.4"
  XBB_BISON_FOLDER="bison-${XBB_BISON_VERSION}"
  XBB_BISON_ARCHIVE="${XBB_BISON_FOLDER}.tar.xz"
  XBB_BISON_URL="https://ftp.gnu.org/gnu/bison/${XBB_BISON_ARCHIVE}"

  echo
  echo "Building bison ${XBB_BISON_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_BISON_ARCHIVE}" "${XBB_BISON_URL}"

  (
    cd "${XBB_BISON_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
      
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/bison --version

  hash -r
}

function do_make() {

  # https://www.gnu.org/software/make/
  # https://ftp.gnu.org/gnu/make/
  # 2016-06-10
  XBB_MAKE_VERSION="4.2.1"
  XBB_MAKE_FOLDER="make-${XBB_MAKE_VERSION}"
  # Only .bz2 available.
  XBB_MAKE_ARCHIVE="${XBB_MAKE_FOLDER}.tar.bz2"
  XBB_MAKE_URL="https://ftp.gnu.org/gnu/make/${XBB_MAKE_ARCHIVE}"

  echo
  echo "Building make ${XBB_MAKE_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_MAKE_ARCHIVE}" "${XBB_MAKE_URL}"

  (
    cd "${XBB_MAKE_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
      
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/make --version

  hash -r
}

function do_libiconv() {

  # https://www.gnu.org/software/libiconv/
  # https://ftp.gnu.org/pub/gnu/libiconv/
  # 2017-02-02
  XBB_LIBICONV_VERSION="1.15"
  XBB_LIBICONV_FOLDER="libiconv-${XBB_LIBICONV_VERSION}"
  XBB_LIBICONV_ARCHIVE="${XBB_LIBICONV_FOLDER}.tar.gz"
  XBB_LIBICONV_URL="https://ftp.gnu.org/pub/gnu/libiconv/${XBB_LIBICONV_ARCHIVE}"

  # Required by wget.
  echo
  echo "Building libiconv ${XBB_LIBICONV_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_LIBICONV_ARCHIVE}" "${XBB_LIBICONV_URL}"

  (
    cd "${XBB_LIBICONV_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${STATICLIB_CFLAGS}"
    export CXXFLAGS="${STATICLIB_CXXFLAGS}"
    # No need for CPPFLAGS, PKG_CONFIG_PATH

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY} V=1
    make install-strip

    # Does not leave a pkgconfig/iconv.pc;
    # Pass -liconv explicitly.
  )
}


function do_wget() {
  
  # https://www.gnu.org/software/wget/
  # https://ftp.gnu.org/gnu/wget/
  # 2016-06-10
  XBB_WGET_VERSION="1.19"
  XBB_WGET_FOLDER="wget-${XBB_WGET_VERSION}"
  XBB_WGET_ARCHIVE="${XBB_WGET_FOLDER}.tar.xz"
  XBB_WGET_URL="https://ftp.gnu.org/gnu/wget/${XBB_WGET_ARCHIVE}"

  # http://git.savannah.gnu.org/cgit/wget.git/tree/configure.ac

  # Requires gnutls.
  # On CentOS 32-bits, the runtime test of the included libiconv fails;
  # the solution was to build the latest libiconv.
  echo
  echo "Building wget ${XBB_WGET_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_WGET_ARCHIVE}" "${XBB_WGET_URL}"

  (
    cd "${XBB_WGET_FOLDER}"
    xbb_activate_bootstrap

    export PATH="${XBB}/bin":${PATH}
    export CFLAGS="${STATICLIB_CFLAGS} -Wno-implicit-function-declaration"
    export CXXFLAGS="${STATICLIB_CXXFLAGS}"
    export LDFLAGS="-L${XBB}/lib ${LDFLAGS}"
    export LIBS="-liconv"
    export PKG_CONFIG_PATH="${XBB}/lib/pkgconfig:${XBB}/${LIB_ARCH}/pkgconfig:${PKG_CONFIG_PATH}"

    ./configure --help

    # libpsl is not available anyway.
    set +e
    ./configure \
      --prefix="${XBB}" \
      --without-libpsl
    cat config.log
    set -e

    make -j${MAKE_CONCURRENCY} V=1
    make install-strip
  )

  "${XBB}"/bin/wget --version

  hash -r
}

function do_texinfo() {

  # https://www.gnu.org/software/texinfo/
  # https://ftp.gnu.org/gnu/texinfo/
  XBB_TEXINFO_VERSION="6.5"
  XBB_TEXINFO_FOLDER="texinfo-${XBB_TEXINFO_VERSION}"
  XBB_TEXINFO_ARCHIVE="${XBB_TEXINFO_FOLDER}.tar.gz"
  XBB_TEXINFO_URL="https://ftp.gnu.org/gnu/texinfo/${XBB_TEXINFO_ARCHIVE}"

  # GCC: Texinfo version 4.8 or later is required by make pdf.

  # http://git.savannah.gnu.org/cgit/texinfo.git/tree/INSTALL.generic
  echo
  echo "Installing texinfo ${XBB_TEXINFO_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_TEXINFO_ARCHIVE}" "${XBB_TEXINFO_URL}"

  (
    cd "${XBB_TEXINFO_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}"

    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/texi2pdf --version

  hash -r
}


# -----------------------------------------------------------------------------
# Build third party tools.

function do_pkg_config() {

  # https://www.freedesktop.org/wiki/Software/pkg-config/
  # https://pkgconfig.freedesktop.org/releases/
  # 2017-03-20
  XBB_PKG_CONFIG_VERSION="0.29.2"
  XBB_PKG_CONFIG_FOLDER="pkg-config-${XBB_PKG_CONFIG_VERSION}"
  XBB_PKG_CONFIG_ARCHIVE="${XBB_PKG_CONFIG_FOLDER}.tar.gz"
  XBB_PKG_CONFIG_URL="https://pkgconfig.freedesktop.org/releases/${XBB_PKG_CONFIG_ARCHIVE}"

  echo
  echo "Building pkg-config ${XBB_PKG_CONFIG_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_PKG_CONFIG_ARCHIVE}" "${XBB_PKG_CONFIG_URL}"

  (
    cd "${XBB_PKG_CONFIG_FOLDER}"
    xbb_activate_bootstrap

    export CFLAGS="${CFLAGS} -Wno-unused-value"

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --enable-static \
      --disable-shared \
      --with-internal-glib
    
    rm -f "${XBB}/bin"/*pkg-config
    make -j${MAKE_CONCURRENCY} 
    make install-strip
  )

  "${XBB}"/bin/pkg-config --version

  hash -r
}

function do_patchelf() {

  # https://nixos.org/patchelf.html
  # https://nixos.org/releases/patchelf/
  # https://nixos.org/releases/patchelf/patchelf-0.9/
  # 2016-02-29
  XBB_PATCHELF_VERSION="0.9"
  XBB_PATCHELF_FOLDER="patchelf-${XBB_PATCHELF_VERSION}"
  XBB_PATCHELF_ARCHIVE="${XBB_PATCHELF_FOLDER}.tar.bz2"
  XBB_PATCHELF_URL="https://nixos.org/releases/patchelf/patchelf-${XBB_PATCHELF_VERSION}/${XBB_PATCHELF_ARCHIVE}"

  echo
  echo "Building patchelf ${XBB_PATCHELF_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_PATCHELF_ARCHIVE}" "${XBB_PATCHELF_URL}"

  (
    cd "${XBB_PATCHELF_FOLDER}"
    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" 
    
    make -j${MAKE_CONCURRENCY} 
    make install-strip
  )

  "${XBB}"/bin/patchelf --version

  hash -r
}

function do_flex() {

  # https://github.com/westes/flex
  # https://github.com/westes/flex/releases
  # May 6, 2017
  XBB_FLEX_VERSION="2.6.4"
  XBB_FLEX_FOLDER="flex-${XBB_FLEX_VERSION}"
  XBB_FLEX_ARCHIVE="${XBB_FLEX_FOLDER}.tar.gz"
  XBB_FLEX_URL="https://github.com/westes/flex/releases/download/v${XBB_FLEX_VERSION}/${XBB_FLEX_ARCHIVE}"

  # Requires gettext
  echo
  echo "Building flex ${XBB_FLEX_VERSION}..."
  cd "${XBB_BUILD}"

  download_and_extract "${XBB_FLEX_ARCHIVE}" "${XBB_FLEX_URL}"

  (
    cd "${XBB_FLEX_FOLDER}"
    xbb_activate_bootstrap

    ./autogen.sh
    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/flex --version

  hash -r
}

function do_perl() {

  # https://www.cpan.org
  # http://www.cpan.org/src/
  # 2017-09-22
  XBB_PERL_MAJOR_VERSION="5.0"
  XBB_PERL_VERSION="5.26.1"
  XBB_PERL_FOLDER="perl-${XBB_PERL_VERSION}"
  XBB_PERL_ARCHIVE="${XBB_PERL_FOLDER}.tar.gz"
  XBB_PERL_URL="http://www.cpan.org/src/${XBB_PERL_MAJOR_VERSION}/${XBB_PERL_ARCHIVE}"

  echo
  echo "Building perl ${XBB_PERL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_PERL_ARCHIVE}" "${XBB_PERL_URL}"

  (
    cd "${XBB_PERL_FOLDER}"
    xbb_activate_bootstrap

    set +e
    # Exits with error.
    ./Configure --help
    set -e

    # GCC 7.2.0 does not provide a 'cc'.
    # -Dcc is necessary to avoid picking up the original program.
    export CFLAGS="${CFLAGS} -Wno-implicit-fallthrough -Wno-clobbered -Wno-int-in-bool-context -Wno-nonnull -Wno-format -Wno-sign-compare"
    
    ./Configure -d -e -s \
      -Dprefix="${XBB}" \
      -Dcc=gcc \
      -Dccflags="${CFLAGS}"
    
    make -j${MAKE_CONCURRENCY}
    make install-strip

    curl -L http://cpanmin.us | perl - App::cpanminus
  )

  "${XBB}"/bin/perl --version

  hash -r
}

# -----------------------------------------------------------------------------

function do_cmake() {

  # https://cmake.org
  # https://cmake.org/download/
  # November 10, 2017
  XBB_CMAKE_MAJOR_VERSION="3.9"
  XBB_CMAKE_VERSION="${XBB_CMAKE_MAJOR_VERSION}.6"
  XBB_CMAKE_FOLDER="cmake-${XBB_CMAKE_VERSION}"
  XBB_CMAKE_ARCHIVE="${XBB_CMAKE_FOLDER}.tar.gz"
  XBB_CMAKE_URL="https://cmake.org/files/v${XBB_CMAKE_MAJOR_VERSION}/${XBB_CMAKE_ARCHIVE}"

  echo
  echo "Installing cmake ${XBB_CMAKE_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_CMAKE_ARCHIVE}" "${XBB_CMAKE_URL}"

  (
    cd "${XBB_CMAKE_FOLDER}"
    xbb_activate_bootstrap

    # Normally it would be much happier with dynamic zlib and curl.

    # If more verbosity is needed:
    #  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON 

    # Use the existing cmake to configure this one.
    cmake \
      -DCMAKE_INSTALL_PREFIX="${XBB}" \
      .
    
    make -j${MAKE_CONCURRENCY}
    make install

    strip --strip-all ${XBB}/bin/cmake
  )

  "${XBB}"/bin/cmake --version

  hash -r
}

function do_python() {

  # https://www.python.org
  # https://www.python.org/downloads/source/
  # 2017-09-16
  XBB_PYTHON_VERSION="2.7.14"
  XBB_PYTHON_FOLDER="Python-${XBB_PYTHON_VERSION}"
  XBB_PYTHON_ARCHIVE="${XBB_PYTHON_FOLDER}.tar.xz"
  XBB_PYTHON_URL="https://www.python.org/ftp/python/${XBB_PYTHON_VERSION}/${XBB_PYTHON_ARCHIVE}"

  echo
  echo "Installing python ${XBB_PYTHON_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_PYTHON_ARCHIVE}" "${XBB_PYTHON_URL}"

  (
    cd "${XBB_PYTHON_FOLDER}"
    xbb_activate_bootstrap

    # If you want a release build with all optimizations active (LTO, PGO, etc),
    # please run ./configure --enable-optimizations

    ./configure --help

    export CFLAGS="${CFLAGS} -Wno-int-in-bool-context -Wno-maybe-uninitialized -Wno-nonnull"

    # It would be happier with dynamic zlib and curl.
    # https://github.com/python/cpython/tree/2.7
    ./configure \
      --prefix="${XBB}" 
    
    make -j${MAKE_CONCURRENCY} 
    make install

    strip --strip-all "${XBB}"/bin/python
    strip --strip-debug "${XBB}"/lib/python*/lib-dynload/*.so
  )

  "${XBB}"/bin/python --version

  hash -r
 
  (
    cd "${XBB_PYTHON_FOLDER}"
    xbb_activate_bootstrap

    export PATH="${XBB}"/bin:${PATH}

    # Install setuptools and pip. Be sure the new version is used.
    # https://packaging.python.org/tutorials/installing-packages/
    echo
    echo "Installing setuptools and pip..."
    set +e
    "${XBB}"/bin/pip --version
    # pip: command not found
    set -e
    "${XBB}"/bin/python -m ensurepip --default-pip
    "${XBB}"/bin/python -m pip install --upgrade pip setuptools wheel
    "${XBB}"/bin/pip --version
  )

  hash -r
}

function do_scons() {

  # http://scons.org
  # https://sourceforge.net/projects/scons/files/scons/3.0.1/
  # 2017-09-16
  XBB_SCONS_VERSION="3.0.1"
  XBB_SCONS_FOLDER="scons-${XBB_SCONS_VERSION}"
  XBB_SCONS_ARCHIVE="${XBB_SCONS_FOLDER}.tar.gz"
  XBB_SCONS_URL="https://sourceforge.net/projects/scons/files/scons/${XBB_SCONS_VERSION}/${XBB_SCONS_ARCHIVE}"

  echo
  echo "Installing scons ${XBB_SCONS_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_SCONS_ARCHIVE}" "${XBB_SCONS_URL}"

  (
    cd "${XBB_SCONS_FOLDER}"
    xbb_activate_bootstrap

    "${XBB}"/bin/python setup.py install --prefix="${XBB}"
  )

  hash -r
}

function do_git() {

  # https://git-scm.com/
  # https://www.kernel.org/pub/software/scm/git/
  # 30-Oct-2017
  XBB_GIT_VERSION="2.15.0"
  XBB_GIT_FOLDER="git-${XBB_GIT_VERSION}"
  XBB_GIT_ARCHIVE="${XBB_GIT_FOLDER}.tar.xz"
  XBB_GIT_URL="https://www.kernel.org/pub/software/scm/git/${XBB_GIT_ARCHIVE}"

  echo
  echo "Installing git ${XBB_GIT_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GIT_ARCHIVE}" "${XBB_GIT_URL}"

  (
    cd "${XBB_GIT_FOLDER}"
    xbb_activate_bootstrap

    export PATH="${XBB}/bin":${PATH}
    export CFLAGS="${STATICLIB_CFLAGS}"
    export CXXFLAGS="${STATICLIB_CXXFLAGS}"
    # No need for CPPFLAGS, PKG_CONFIG_PATH
    export LDFLAGS="-ldl -L${XBB}/lib ${LDFLAGS}"

    make configure 
    ./configure --help

	  ./configure \
      --prefix="${XBB}"
	  
    make all -j${MAKE_CONCURRENCY}
    make install

    strip --strip-all "${XBB}/bin"/git "${XBB}/bin"/git-[rsu]*
  )

  "${XBB}"/bin/git --version

  hash -r
}

function do_dos2unix() {

  # http://dos2unix.sourceforge.net
  # https://www.kernel.org/pub/software/scm/git/
  # 30-Oct-2017
  XBB_DOS2UNIX_VERSION="7.4.0"
  XBB_DOS2UNIX_FOLDER="dos2unix-${XBB_DOS2UNIX_VERSION}"
  XBB_DOS2UNIX_ARCHIVE="${XBB_DOS2UNIX_FOLDER}.tar.gz"
  XBB_DOS2UNIX_URL="https://sourceforge.net/projects/dos2unix/files/dos2unix/${XBB_DOS2UNIX_VERSION}/${XBB_DOS2UNIX_ARCHIVE}"

  echo
  echo "Installing dos2unix ${XBB_DOS2UNIX_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_DOS2UNIX_ARCHIVE}" "${XBB_DOS2UNIX_URL}"

  (
    cd "${XBB_DOS2UNIX_FOLDER}"
    xbb_activate_bootstrap

    make prefix="${XBB}" -j${MAKE_CONCURRENCY} clean all
    make prefix="${XBB}" strip install
  )

  "${XBB}"/bin/unix2dos --version

  hash -r
}

# -----------------------------------------------------------------------------

function do_native_binutils() {

  # https://ftp.gnu.org/gnu/binutils/
  # 2017-07-24
  XBB_BINUTILS_VERSION="2.29"
  XBB_BINUTILS_FOLDER="binutils-${XBB_BINUTILS_VERSION}"
  XBB_BINUTILS_ARCHIVE="${XBB_BINUTILS_FOLDER}.tar.xz"
  XBB_BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/${XBB_BINUTILS_ARCHIVE}"

  # Requires gmp, mpfr, mpc, isl.
  echo
  echo "Building native binutils ${XBB_BINUTILS_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_BINUTILS_ARCHIVE}" "${XBB_BINUTILS_URL}"

  (
    mkdir -p "${XBB_BINUTILS_FOLDER}"-native-build
    cd "${XBB_BINUTILS_FOLDER}"-native-build

    xbb_activate_bootstrap

    export CFLAGS="${CFLAGS} -Wno-sign-compare"

    "${XBB_BUILD}/${XBB_BINUTILS_FOLDER}"/configure --help

    "${XBB_BUILD}/${XBB_BINUTILS_FOLDER}"/configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static \
      --without-python \
      --disable-lto

    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/size --version

  hash -r
}

# -----------------------------------------------------------------------------

function do_native_gcc() {

  # https://gcc.gnu.org
  # https://gcc.gnu.org/wiki/InstallingGCC

  # https://ftp.gnu.org/gnu/gcc/
  # 2017-08-14
  XBB_GCC_VERSION="7.2.0"
  XBB_GCC_FOLDER="gcc-${XBB_GCC_VERSION}"
  XBB_GCC_ARCHIVE="${XBB_GCC_FOLDER}.tar.xz"
  XBB_GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${XBB_GCC_VERSION}/${XBB_GCC_ARCHIVE}"

  # Requires gmp, mpfr, mpc, isl.
  echo
  echo "Building native gcc ${XBB_GCC_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GCC_ARCHIVE}" "${XBB_GCC_URL}"

  (
    mkdir -p "${XBB_GCC_FOLDER}"-build
    cd "${XBB_GCC_FOLDER}"-build

    xbb_activate_bootstrap

    export CFLAGS="${CFLAGS} -Wno-sign-compare"
    export CXXFLAGS="${CXXFLAGS} -Wno-sign-compare"

    "${XBB_BUILD}/${XBB_GCC_FOLDER}"/configure --help

    # --disable-shared failed with errors in libstdc++-v3
    # --build used conservatively.
    "${XBB_BUILD}/${XBB_GCC_FOLDER}"/configure \
      --prefix="${XBB}" \
      --build="${BUILD}" \
      --enable-languages=c,c++ \
      --disable-multilib \
      --without-python \
      --disable-lto
    
    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/g++ --version

  (
    mkdir -p "${HOME}"/tmp
    cd "${HOME}"/tmp

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello" << std::endl;
}
__EOF__

    if false
    then

    "${XBB}"/bin/g++ hello.cpp -o hello
    "${XBB}"/bin/readelf -d hello

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

function do_mingw_binutils() {

  echo
  echo "Building mingw-w64 binutils ${XBB_BINUTILS_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_BINUTILS_ARCHIVE}" "${XBB_BINUTILS_URL}"

  (
    mkdir -p "${XBB_BINUTILS_FOLDER}"-mingw-build
    cd "${XBB_BINUTILS_FOLDER}"-mingw-build
    xbb_activate_bootstrap

    export CFLAGS="${CFLAGS} -Wno-sign-compare"

    # --build used conservatively
    "${XBB_BUILD}/${XBB_BINUTILS_FOLDER}"/configure --help

    "${XBB_BUILD}/${XBB_BINUTILS_FOLDER}"/configure \
      --prefix="${XBB}" \
      --with-sysroot="${XBB}" \
      --disable-shared \
      --enable-static \
      --build="${BUILD}" \
      --target=${MINGW_TARGET} \
      --disable-multilib

    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/${UNAME_ARCH}-w64-mingw32-size --version

  hash -r
}

function do_mingw_gcc() {

  # http://mingw-w64.org/doku.php/start
  # https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/
  # 2017-11-04
  XBB_MINGW_VERSION="5.0.3"
  XBB_MINGW_FOLDER="mingw-w64-v${XBB_MINGW_VERSION}"
  XBB_MINGW_ARCHIVE="${XBB_MINGW_FOLDER}.tar.bz2"
  XBB_MINGW_URL="https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/${XBB_MINGW_ARCHIVE}"

  # https://sourceforge.net/p/mingw-w64/wiki2/Cross%20Win32%20and%20Win64%20compiler/
  # https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/configure

  echo
  echo "Building mingw-w64 headers ${XBB_MINGW_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_MINGW_ARCHIVE}" "${XBB_MINGW_URL}"

  (
    mkdir -p "${XBB_MINGW_FOLDER}"-headers-build
    cd "${XBB_MINGW_FOLDER}"-headers-build
    xbb_activate_bootstrap

    export PATH="${XBB}/bin":${PATH}

    "${XBB_BUILD}/${XBB_MINGW_FOLDER}"/mingw-w64-headers/configure --help
    
    "${XBB_BUILD}/${XBB_MINGW_FOLDER}"/mingw-w64-headers/configure \
      --prefix="${XBB}/${MINGW_TARGET}" \
      --build="${BUILD}" \
      --host="${MINGW_TARGET}"

    make -j${MAKE_CONCURRENCY}
    make install-strip

    # GCC requires the `x86_64-w64-mingw32` folder be mirrored as `mingw` 
    # in the same root. 
    (cd "${XBB}"; ln -s "${MINGW_TARGET}" "mingw")

    # For non-multilib builds, links to "lib32" and "lib64" are no longer 
    # needed, "lib" is enough.
  )

  hash -r

  echo
  echo "Building mingw-w64 gcc ${XBB_GCC_VERSION}, step 1..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_GCC_ARCHIVE}" "${XBB_GCC_URL}"

  (
    mkdir -p "${XBB_GCC_FOLDER}"-mingw-build
    cd "${XBB_GCC_FOLDER}"-mingw-build
    xbb_activate_bootstrap

    export PATH="${XBB}/bin":${PATH}
    export CFLAGS="${CFLAGS} -Wno-sign-compare -Wno-implicit-function-declaration -Wno-missing-prototypes"
    export CXXFLAGS="${CXXFLAGS} -Wno-sign-compare"

    # For the native build, --disable-shared failed with errors in libstdc++-v3
    "${XBB_BUILD}/${XBB_GCC_FOLDER}"/configure --help

    "${XBB_BUILD}/${XBB_GCC_FOLDER}"/configure \
      --prefix="${XBB}" \
      --with-sysroot="${XBB}" \
      --build="${BUILD}" \
      --target=${MINGW_TARGET} \
      --enable-languages=c,c++ \
      --enable-static \
      --disable-multilib

    make all-gcc -j${MAKE_CONCURRENCY}
    make install-gcc
  )

  hash -r

  echo
  echo "Building mingw-w64 crt ${XBB_MINGW_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_MINGW_ARCHIVE}" "${XBB_MINGW_URL}"

  (
    mkdir -p "${XBB_MINGW_FOLDER}"-crt-build
    cd "${XBB_MINGW_FOLDER}"-crt-build
    xbb_activate_bootstrap

    # Mandatory for PATH to include the newly built binaries.
    export PATH="${XBB}"/bin:${PATH}
    export CFLAGS="-g -O2 -Wno-unused-variable -Wno-implicit-fallthrough -Wno-implicit-function-declaration -Wno-cpp"
    export CXXFLAGS="-g -O2"
    export LDFLAGS=""
    
    # Without it, apparently a bug in autoconf/c.m4, function AC_PROG_CC, results in:
    # checking for _mingw_mac.h... no
    # configure: error: Please check if the mingw-w64 header set and the build/host option are set properly.
    # (https://github.com/henry0312/build_gcc/issues/1)
    export CC=""

    "${XBB_BUILD}/${XBB_MINGW_FOLDER}"/mingw-w64-crt/configure --help
    if [ "${BITS}" == "64" ]
    then
      "${XBB_BUILD}/${XBB_MINGW_FOLDER}"/mingw-w64-crt/configure \
        --prefix="${XBB}/${MINGW_TARGET}" \
        --with-sysroot="${XBB}" \
        --build="${BUILD}" \
        --host="${MINGW_TARGET}" \
        --disable-lib32 \
        --enable-lib64
    elif [ "${BITS}" == "32" ]
    then
      # Without --build it searched for some mac headers.
      "${XBB_BUILD}/${XBB_MINGW_FOLDER}"/mingw-w64-crt/configure \
        --prefix="${XBB}/${MINGW_TARGET}" \
        --with-sysroot="${XBB}" \
        --build="${BUILD}" \
        --host="${MINGW_TARGET}" \
        --disable-lib64 \
        --enable-lib32
    else
      exit 1
    fi

    make -j${MAKE_CONCURRENCY}
    make install-strip

    ls -l "${XBB}" "${XBB}/${MINGW_TARGET}"
  )

  hash -r

  echo
  echo "Building mingw-w64 gcc ${XBB_GCC_VERSION}, step 2..."

  cd "${XBB_BUILD}"

  # download_and_extract "${XBB_GCC_ARCHIVE}" "${XBB_GCC_URL}"

  (
    mkdir -p "${XBB_GCC_FOLDER}"-mingw-build
    cd "${XBB_GCC_FOLDER}"-mingw-build
    xbb_activate_bootstrap

    export PATH="${XBB}"/bin:${PATH}
    export CFLAGS="${CFLAGS} -Wno-sign-compare -Wno-implicit-function-declaration -Wno-missing-prototypes"
    export CXXFLAGS="${CXXFLAGS} -Wno-sign-compare"

    make -j${MAKE_CONCURRENCY}
    make install-strip
  )

  "${XBB}"/bin/${UNAME_ARCH}-w64-mingw32-g++ --version

  (
    mkdir -p "${HOME}"/tmp
    cd "${HOME}"/tmp

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello" << std::endl;
}
__EOF__

    "${XBB}"/bin/${UNAME_ARCH}-w64-mingw32-g++ hello.cpp -o hello

    rm -rf hello.cpp hello
  )

  hash -r
}

# =============================================================================

# WARNING: the order is important, since some of the builds depend
# on previous ones.

# For extra safety, the ${XBB} is not permanently added to PATH;
# ${XBB_BOOTSTRAP} is added only with xbb_activate_bootstrap 
# in sub-shells.

# Generally build only the static versions of the libraries;
# the exceptions are libz.o and maybe a few more.

# -----------------------------------------------------------------------------
# Other GCC dependencies (from https://gcc.gnu.org/install/prerequisites.html):

# gperf version 2.7.2 (or later)
#   Necessary when modifying gperf input files, e.g. gcc/cp/cfns.gperf to regenerate its associated header file, e.g. gcc/cp/cfns.h.
#
# DejaGnu 1.4.4
# Expect
# Tcl
#   Necessary to run the GCC testsuite
#
# autogen version 5.5.4 (or later) and
# guile version 1.4.1 (or later)
#   Necessary to regenerate fixinc/fixincl.x from fixinc/inclhack.def and fixinc/*.tpl.
#
# TeX (any working version)

# -----------------------------------------------------------------------------

if false
then

# New zlib, used in most of the tools.
do_zlib

# New openssl, required by curl, cmake, python, etc.
do_openssl

# New curl, that better understands all protocols.
do_curl

# Library, required by tar. 
do_xz

# New tar with xz support.
do_tar # Requires xz.

# Libraries, required by gcc.
do_gmp
do_mpfr
do_mpc
do_isl

# Libraries, required by gnutls
do_nettle
do_tasn1

do_gnutls # Requires tasn1 & nettle.

# GNU tools.
do_m4
do_gawk
do_autoconf
do_automake
do_libtool
do_gettext
do_patch
do_diffutils
do_bison
do_make

# Library, required by wget.
do_libiconv

fi
if false
then

do_wget # Requires gnutls, libiconv.

# Required to build PDF manuals.
do_texinfo

# Some third party tools.
do_pkg_config
do_patchelf

do_flex # Requires gettext.

do_perl
do_cmake

do_python
do_scons

do_git
do_dos2unix

fi

if true
then

# Native binutils and gcc.
do_native_binutils # Require gmp, mpfr, mpc, isl.
do_native_gcc # Require gmp, mpfr, mpc, isl.

fi

if false
then

# mingw-w64 binutils and gcc.
do_mingw_binutils # Require gmp, mpfr, mpc, isl.
do_mingw_gcc # Require gmp, mpfr, mpc, isl.

fi

# -----------------------------------------------------------------------------

# rm -rf "${XBB_DOWNLOAD}"

# rm -rf "${XBB_BOOTSTARP}"
rm -rf "${XBB_BUILD}"
rm -rf "${XBB_TMP}"
rm -rf "${XBB_INPUT}"

# -----------------------------------------------------------------------------
