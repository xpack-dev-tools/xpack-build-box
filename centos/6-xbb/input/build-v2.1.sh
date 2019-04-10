#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software 
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Identify the script location, to reach, for example, the helper scripts.

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# Script to build a subsequent version of a Docker image with the 
# xPack Build Box (XBB).

# -----------------------------------------------------------------------------

XBB_VERSION="2.1"
echo
echo "centOS XBB v${XBB_VERSION} script started..."

# -----------------------------------------------------------------------------

XBB_INPUT_FOLDER="/xbb-input"
source "${XBB_INPUT_FOLDER}/common-functions-source.sh"
source "${XBB_INPUT_FOLDER}/common-libs-functions-source.sh"
source "${XBB_INPUT_FOLDER}/common-apps-functions-source.sh"

prepare_xbb_env

source "${XBB_BOOTSTRAP_FOLDER}/xbb-source.sh"

# Create the xbb-source.sh file. Will be used by applications.
create_xbb_source

# Copy pkg-config-verbose from bootstrap to here.
mkdir -p "${XBB_FOLDER}/bin"
/usr/bin/install -m755 -c "${XBB_BOOTSTRAP_FOLDER}/bin/pkg-config-verbose" "${XBB_FOLDER}/bin/pkg-config-verbose"

# -----------------------------------------------------------------------------

# xbb_activate - activate the bootstrap binaries
# xbb_activate_installed_bin - activate the new xbb binaries
# xbb_activate_installed_dev - activate the new xbb headers & libraries 

(
  xbb_activate
  
  echo 
  echo "xbb_activate"
  echo ${PATH}
  echo ${LD_LIBRARY_PATH}

  echo
  g++ --version
  g++-7bs --version
)

# -----------------------------------------------------------------------------

XBB_GCC_BRANDING="xPack Build Box GCC\x2C ${BITS}-bit"
XBB_GCC_SUFFIX="-7"

if true
then

  # New zlib, used in most of the tools.
  # depends=('glibc')
  do_zlib "1.2.11"

  # Libraries, required by gcc.
  # depends=('gcc-libs' 'sh')
  do_gmp "6.1.2"
  # depends=('gmp>=5.0')
  do_mpfr "3.1.6"
  # depends=('mpfr')
  do_mpc "1.0.3"
  # depends=('gmp')
  do_isl "0.21"

  # Libraries, required by gnutls.
  # depends=('glibc' 'gmp')
  do_nettle "3.4.1"
  # depends=('glibc')
  do_tasn1 "4.13"
  # Library, required by Python.
  # depends=('glibc')
  do_expat "2.2.6"
  # depends=('glibc')
  do_libffi "3.2.1"

  # Libary, required by tar. 
  # depends=('sh')
  do_xz "5.2.4"

  # depends=('perl')
  do_openssl "1.0.2r" # "1.1.1b"

  # Needed by wine.
  do_libpng "1.6.36"

fi

if true
then

  # Library, required by wget.
  # depends=()
  do_libiconv "1.15"

  # depends=('glibc' 'glib2 (internal)')
  do_pkg_config "0.29.2"

  # depends=('ca-certificates' 'krb5' 'libssh2' 'openssl' 'zlib' 'libpsl' 'libnghttp2')
  do_curl "7.64.1"

  # tar with xz support.
  # depends=('glibc')
  do_tar "1.32"

fi

if true
then

  # depends=('glibc' 'libidn2' 'libtasn1' 'libunistring' 'nettle' 'p11-kit' 'readline' 'zlib')
  do_gnutls "3.6.7"

  do_coreutils "8.31"

  # GNU tools.
  # depends=('glibc')
  do_m4 "1.4.18"

  # depends=('glibc' 'mpfr')
  do_gawk "4.2.1"

  do_sed "4.7"

  # depends=('sh' 'perl' 'awk' 'm4' 'texinfo')
  do_autoconf "2.69"
  # depends=('sh' 'perl')
  do_automake "1.16"

  # depends=('sh' 'tar' 'glibc')
  do_libtool "2.4.6"

  # depends=('glibc' 'glib2' 'libunistring' 'ncurses')
  do_gettext "0.19.8"

  # depends=('glibc' 'attr')
  do_patch "2.7.6"

  # depends=('libsigsegv')
  do_diffutils "3.7"

  # depends=('glibc')
  do_bison "3.3.2"

  # depends=('glibc' 'guile')
  do_make "4.2.1"

  # Third party tools.

  # depends=('libutil-linux' 'gnutls' 'libidn' 'libpsl>=0.7.1-3' 'gpgme')
  do_wget "1.20.1"

  # Required to build PDF manuals.
  # depends=('coreutils')
  do_texinfo "6.6"
  # depends ?
  do_patchelf "0.10"
  # depends=('glibc')
  do_dos2unix "7.4.0"

  # depends=('glibc' 'm4' 'sh')
  do_flex "2.6.4"

  # depends=('gdbm' 'db' 'glibc')
  do_perl "5.28.1"

fi

if true
then

  # depends=('curl' 'libarchive' 'shared-mime-info' 'jsoncpp' 'rhash')
  do_cmake "3.13.4"

  # depends=('bzip2' 'gdbm' 'openssl' 'zlib' 'expat' 'sqlite' 'libffi')
  do_python "2.7.16"

  # require xz, openssl
  do_python3 "3.7.3"

  # depends=('python2')
  do_scons "3.0.5"

  # depends=('python2')
  do_ninja "1.9.0"

  # depends=('python3')
  do_meson "0.50.0"

  # depends=('curl' 'expat>=2.0' 'perl-error' 'perl>=5.14.0' 'openssl' 'pcre2' 'grep' 'shadow')
  do_git "2.21.0"

fi

if true
then
  do_p7zip "16.02"

  do_wine "4.3"
fi

if true
then
  # Native binutils and gcc.
  do_native_binutils "2.31"
  # makedepends=('binutils>=2.26' 'libmpc' 'gcc-ada' 'doxygen' 'git')
  do_native_gcc "7.4.0"
fi

if true
then
  # mingw-w64 binutils and gcc.
  # depends=('zlib')
  do_mingw_binutils "2.31"
  # depends=('zlib' 'libmpc' 'mingw-w64-crt' 'mingw-w64-binutils' 'mingw-w64-winpthreads' 'mingw-w64-headers')
  do_mingw_all "5.0.4" "7.4.0"
fi

# -----------------------------------------------------------------------------

if true
then
  do_strip_libs

  do_cleaunup
fi

echo
echo "Done"

# -----------------------------------------------------------------------------
