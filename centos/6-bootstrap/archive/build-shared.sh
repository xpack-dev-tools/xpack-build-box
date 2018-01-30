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

# Script to build a Docker image with a bootstrap system, used to later build  
# the final xPack Build Box (xbb).
#
# To finally get access to the very latest tools versions it is required to   
# do it in two steps, since the orginal CentOS 6 is too old to compile some 
# of the modern sources. So, in the first step are compiled the most recent
# versions allowed by CentOS 6; being based on GCC 7.2, they shold be enough
# for a few years to come. With them, in the second step are compiled the
# latest versions.

# Credits: Inspired by Holy Build Box build script.

XBB_INPUT="/xbb-input"
XBB_DOWNLOAD="/tmp/xbb-download"
XBB_TMP="/tmp/xbb"

XBB="/opt/xbb-bootstrap"
XBB_BUILD="${XBB_TMP}"/bootstrap-build

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
elif [ "${UNAME_ARCH}" == "i686" ]
then
  BITS="32"
fi

BUILD=${UNAME_ARCH}-linux-gnu

# -----------------------------------------------------------------------------

# Make all tools choose gcc, not the old cc.
export CC=gcc
export CXX=g++

# -----------------------------------------------------------------------------

# Note: __EOF__ is quoted to prevent substitutions here.
cat <<'__EOF__' >> "${XBB}"/xbb.sh

export XBB_FOLDER="/opt/xbb-bootstrap"

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

  export PATH="${PREFIX_}/bin:${PATH}"
  export C_INCLUDE_PATH="${PREFIX_}/include"
  export CPLUS_INCLUDE_PATH="${PREFIX_}/include"
  export LIBRARY_PATH="${PREFIX_}/lib"
  export PKG_CONFIG_PATH="${PREFIX_}/lib/pkgconfig:/usr/lib/pkgconfig"
  export LD_LIBRARY_PATH="${PREFIX_}/lib"

  export CPPFLAGS="-I${PREFIX_}/include"
  export LDPATHFLAGS="-L${PREFIX_}/lib ${EXTRA_LDPATHFLAGS_}"

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

xbb_activate_bootstrap()
{
  PREFIX_="${XBB}" 
  EXTRA_LDFLAGS_="-Wl,-rpath -Wl,\"${XBB}/lib\"" 
  EXTRA_SHLIB_CFLAGS_="-fPIC"

  xbb_activate_param
}

xbb_activate_bootstrap_static()
{
  PREFIX_="${XBB}"
  EXTRA_CFLAGS_="-ffunction-sections -fdata-sections "
  EXTRA_CXXFLAGS_="-ffunction-sections -fdata-sections "
  EXTRA_LDFLAGS_="-static-libstdc++ -Wl,--gc-sections -Wl,-rpath -Wl,\"${XBB}/lib\""
  EXTRA_STATICLIB_CFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_STATICLIB_CXXFLAGS_="-ffunction-sections -fdata-sections"
  EXTRA_SHLIB_CFLAGS_="-fvisibility=hidden -fPIC"
  EXTRA_SHLIB_LDFLAGS_="-static-libstdc++"

  xbb_activate_param
}

__EOF__
# The above marker must start in the first column.

source "${XBB}"/xbb.sh

# -----------------------------------------------------------------------------

# Note: __EOF__ is quoted to prevent substitutions here.
mkdir -p "${XBB}"/bin
cat <<'__EOF__' >> "${XBB}"/bin/pkg-config-verbose
#! /bin/sh
# pkg-config wrapper for debug

pkg-config $@
RET=$?
OUT=$(pkg-config $@)
echo "($PKG_CONFIG_PATH) | pkg-config $@ -> $RET [$OUT]" >&2
exit ${RET}

__EOF__
# The above marker must start in the first column.

chmod +x "${XBB}"/bin/pkg-config-verbose

export PKG_CONFIG="${XBB}/bin/pkg-config-verbose"

# -----------------------------------------------------------------------------
# Common functions.

function extract()
{
  local ARCHIVE_NAME="$1"

  if [ -x "${XBB}"/bin/tar ]
  then
    (
      PATH="${XBB}"/bin:${PATH}
      tar xf "${ARCHIVE_NAME}"
    )
  else
    if [[ "${ARCHIVE_NAME}" =~ '\.bz2$' ]]; then
      tar xjf "${ARCHIVE_NAME}"
    else
      tar xzf "${ARCHIVE_NAME}"
    fi
  fi
}

function download_and_extract()
{
  local ARCHIVE_NAME="$1"
  local URL="$2"

  if [ ! -f "${XBB_DOWNLOAD}/${ARCHIVE_NAME}" ]
  then
    rm -f "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download"
    if [ -x "${XBB}"/bin/curl ]
    then
      (
        PATH="${XBB}/bin":${PATH}
        curl --fail -L -o "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download" "${URL}"
      )
    else
      curl --fail -L -o "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download" "${URL}"
    fi
    mv "${XBB_DOWNLOAD}/${ARCHIVE_NAME}.download" "${XBB_DOWNLOAD}/${ARCHIVE_NAME}"
  fi

  extract "${XBB_DOWNLOAD}/${ARCHIVE_NAME}"
}

function eval_bool()
{
  local VAL="$1"
  [[ "${VAL}" = 1 || "${VAL}" = true || "${VAL}" = yes || "${VAL}" = y ]]
}

# -----------------------------------------------------------------------------

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
    cd "$XBB_ZLIB_FOLDER"

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

# -----------------------------------------------------------------------------

function do_xz() {

  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # 2016-12-30
  XBB_XZ_VERSION="5.2.3"
  XBB_XZ_FOLDER="xz-${XBB_XZ_VERSION}"
  # Conservatively use .gz, the native tar may be very old.
  XBB_XZ_ARCHIVE="${XBB_XZ_FOLDER}.tar.gz"
  XBB_XZ_URL="https://sourceforge.net/projects/lzmautils/files/${XBB_XZ_ARCHIVE}"

  echo
  echo "Building xz ${XBB_XZ_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_XZ_ARCHIVE}" "${XBB_XZ_URL}"

  (
    cd "${XBB_XZ_FOLDER}"
    
    xbb_activate_bootstrap

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
  # Conservatively use .gz, the native tar may be very old.
  XBB_TAR_ARCHIVE="${XBB_TAR_FOLDER}.tar.gz"
  XBB_TAR_URL="https://ftp.gnu.org/gnu/tar/${XBB_TAR_ARCHIVE}"

  # Requires xz.

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

function do_openssl() {

  # https://www.openssl.org
  # https://www.openssl.org/source/
  # 2017-Nov-02 
  XBB_OPENSSL_VERSION="1.1.0g"
  XBB_OPENSSL_FOLDER="openssl-${XBB_OPENSSL_VERSION}"
  # Only .gz available.
  XBB_OPENSSL_ARCHIVE="${XBB_OPENSSL_FOLDER}.tar.gz"
  XBB_OPENSSL_URL="https://www.openssl.org/source/${XBB_OPENSSL_ARCHIVE}"

  # https://github.com/openssl/openssl/blob/master/INSTALL

  echo
  echo "Building openssl ${XBB_OPENSSL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_OPENSSL_ARCHIVE}" "${XBB_OPENSSL_URL}"

  (
    cd "${XBB_OPENSSL_FOLDER}"

    xbb_activate_bootstrap

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
      no-comp \
      no-shared
    
    make
    make install_sw

    strip --strip-all "${XBB}"/bin/openssl

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

  openssl version

  hash -r
}

# -----------------------------------------------------------------------------

function do_curl() {

  # https://curl.haxx.se
  # https://curl.haxx.se/download/
  # 2017-10-23 
  XBB_CURL_VERSION="7.56.1"
  XBB_CURL_FOLDER="curl-${XBB_CURL_VERSION}"
  XBB_CURL_ARCHIVE="${XBB_CURL_FOLDER}.tar.xz"
  XBB_CURL_URL="https://curl.haxx.se/download/${XBB_CURL_ARCHIVE}"

  # Requires openssl & zlib.

  echo
  echo "Building curl ${XBB_CURL_VERSION}..."

  cd "${XBB_BUILD}"

  download_and_extract "${XBB_CURL_ARCHIVE}" "${XBB_CURL_URL}"

  (
    cd "${XBB_CURL_FOLDER}"

    xbb_activate_bootstrap

    # Without the --disable-static some further builds (cmake) fail.
    ./buildconf

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --enable-static \
      --disable-shared \
      --disable-debug \
      --with-ssl \
      --enable-optimize \
      --disable-manual \
      --with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt
    
    make -j${MAKE_CONCURRENCY}
    make install

    strip --strip-all "${XBB}"/bin/curl

    if [ -f "${XBB}/lib/libcurl.a" ]
    then
      strip --strip-debug "${XBB}/lib/libcurl.a"
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

function do_m4() {

  # https://www.gnu.org/software/m4/
  # https://ftp.gnu.org/gnu/m4/
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

    ./configure \
      --prefix="${XBB}"
    
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

# -----------------------------------------------------------------------------

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

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --enable-static \
      --disable-shared \
      --with-internal-glib
    
    rm -f "${XBB}"/bin/*pkg-config
    make -j${MAKE_CONCURRENCY} 
    make install-strip
  )

  "${XBB}"/bin/pkg-config --version

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

  # Requires gettext.
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
  XBB_PERL_VERSION="5.24.1"
  # Fails with undefined reference to `Perl_fp_class_denorm'
  # XBB_PERL_VERSION="5.26.1"
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

    ./Configure -d -e -s \
      -Dprefix="${XBB}" \
      -Dcc=gcc
 
    make -j${MAKE_CONCURRENCY}
    make install-strip

    # Install modules.
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

    strip --strip-all "${XBB}"/bin/cmake
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

    ./configure --help

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

    # Install setuptools and pip. Be sure the new version is used.
    # https://packaging.python.org/tutorials/installing-packages/
    echo
    echo "Installing setuptools and pip..."
    set +e
    pip --version
    # pip: command not found
    set -e
    python -m ensurepip --default-pip
    python -m pip install --upgrade pip setuptools wheel
    pip --version
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

    python setup.py install --prefix="${XBB}"
  )

  hash -r
}

# -----------------------------------------------------------------------------

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

    # Mandatory, otherwise it fails on 32-bits. 
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
  # ftp://ftp.gnu.org/gnu/mpc/
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
    cd "$XBB_ISL_FOLDER"

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
# Texinfo version 4.8 or later is required for make pdf.
# TeX (any working version)

# XBB_ZLIB_VERSION=1.2.11

# -----------------------------------------------------------------------------

function do_native_binutils() {

  # https://www.gnu.org/software/binutils/
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
    cd "${XBB_BINUTILS_FOLDER}"

    xbb_activate_bootstrap

    ./configure --help

    ./configure \
      --prefix="${XBB}" \
      --disable-shared \
      --enable-static
    
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

  # The documentation recommands a separate build folder.
  (
    mkdir -p "${XBB_GCC_FOLDER}-build"
    cd "${XBB_GCC_FOLDER}-build"

    xbb_activate_bootstrap

    "${XBB_BUILD}/${XBB_GCC_FOLDER}/configure" --help

    # --disable-shared failed with errors in libstdc++-v3
    "${XBB_BUILD}/${XBB_GCC_FOLDER}/configure" \
      --prefix="${XBB}" \
      --enable-languages=c,c++ \
      --disable-multilib
    
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

    "${XBB}"/bin/g++ hello.cpp -o hello
    readelf -d hello

    if [ "x$(./hello)x" != "xHellox" ]
    then
      exit 1
    fi

    rm -rf hello.cpp hello
  )

  hash -r
}

# =============================================================================

# WARNING: the order is important, since some of the builds depend
# on previous ones.

# For extra safety, the ${XBB} is not permanently added to PATH,
# it is added explicitly with xbb_activate_bootstrap in sub-shells.

# Generally build only the static versions of the libraries.
# (the exception are libcrypto.so libcurl.so libssl.so)

# -----------------------------------------------------------------------------

# The first step is to build a new zlib, it is used in most of the tools.
do_zlib

# The second step is to build a new tar, that understand xz.
# It requires the xz libraries, so we do it first.
do_xz
do_tar

# From this moment on, .xz archives can be processed.

# Build a new openssl, required by curl, cmake, python, etc.
do_openssl

# Build a new curl, that better understands all protocols.
do_curl

# Build GNU tools. From now, xz is available.
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

# Build third party tools.
do_pkg_config

# Requires gettext.
do_flex

do_perl
do_cmake
do_python
do_scons

# Libraries.
do_gmp
do_mpfr
do_mpc
do_isl

# And finally build the binutils and gcc.

# Require gmp, mpfr, mpc, isl.
do_native_binutils
do_native_gcc

# -----------------------------------------------------------------------------

# Preserve download, will be used by xbb and removed later.
# rm -rf "$XBB_DOWNLOAD"

# All other can go.
rm -rf "${XBB_BUILD}"
rm -rf "${XBB_TMP}"
rm -rf "${XBB_INPUT}"

# -----------------------------------------------------------------------------
