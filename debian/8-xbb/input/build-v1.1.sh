#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPacks distribution.
#   (https://xpack.github.io)
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

script_path="$0"
if [[ "${script_path}" != /* ]]
then
  # Make relative path absolute.
  script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# Script to build a Docker image with the xPack Build Box (xbb).
#
# Some of the newest tools can no longer be built on CentOS 6 directly; an
# intermediate solution (a bootstrap) is used, which includes the most
# recent versions that can be build with GCC 4.4. This intermediate version
# is used to build the final tools.

# To activate the new build environment, use:
#
#   $ source /opt/xbb/xbb.sh
#   $ xbb_activate
#
# This will adjust the PATH and LD_LIBRARY_PATH to include the
# /opt/xbb folders.

# If it is necessary to build some other development tools, use:
#
#   $ xbb_activate_dev
#
# This will add some environment variable that include the
# headers and libraries.

# For completeness, the header and library files have been installed in:
#    /opt/xbb/include
#    /opt/xbb/lib64
#    /opt/xbb/lib

# -static-libstdc++
# This is a tricky issue, and sometimes a cause for warnings.
# Without it, testing the binaries before building GCC will fail, since
# the libstdc++.so.6 is not yet available and the system version is too old.
# LD_LIBRARY_PATH=/opt/xbb/lib64:/opt/xbb/lib:
# /opt/xbb/bin/patchelf --version
# /opt/xbb/bin/patchelf: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.21' not found (required by /opt/xbb/bin/patchelf)

# Credits: Initially inspired by the Holy Build Box build script,
# but later diverged quite a lot.
# Many of the configuration options were inspired by ARCH Linux.

# -----------------------------------------------------------------------------

XBB_INPUT="/xbb-input"
XBB_DOWNLOAD="/tmp/xbb-download"
XBB_TMP="/tmp/xbb"

XBB="/opt/xbb"
XBB_BUILD="${XBB_TMP}"/xbb-build

MAKE_CONCURRENCY=4

# -----------------------------------------------------------------------------

mkdir -p "${XBB_TMP}"
mkdir -p "${XBB_DOWNLOAD}"

mkdir -p "${XBB}"
mkdir -p "${XBB_BUILD}"

# -----------------------------------------------------------------------------

# x86_64 or i686 (do not use -p, it is not set in recent versions).
UNAME_ARCH=$(uname -m)
if [ "${UNAME_ARCH}" == "x86_64" ]
then
  BITS="64"
  LIB_ARCH="lib64"
elif [ "${UNAME_ARCH}" == "i686" ]
then
  BITS="32"
  LIB_ARCH="lib"
fi

build=${UNAME_ARCH}-linux-gnu
# x86_64-w64-mingw32 or i686-w64-mingw32
MINGW_TARGET=${UNAME_ARCH}-w64-mingw32

# -----------------------------------------------------------------------------

# Make all tools choose gcc, not the old cc.
export CC=gcc
export CXX=g++

# -----------------------------------------------------------------------------


# =============================================================================

function do_texlive()
{
  local year=$1

  echo
  echo "Installing texlive..."

  # ---

  # required to find curl.
  apt-get update

  # Reqired by apt-get
  apt-get install --yes apt-utils

  apt-get install --yes wget

  # Reqired to make Pod::Usage
  apt-get install --yes make

  # Required to find CPAN modules.
  apt-get install --yes perl-modules

  # Used in install-tl line 100
  perl -MCPAN -e install Pod::Usage

  # ---

  # https://www.tug.org/texlive/acquire-netinstall.html

  # The master is
  # ftp://tug.org/historic, and it is mirrored at
  # ftp://ftp.math.utah.edu/pub/tex/historic and
  # http://www.math.utah.edu/pub/tex/historic.

  # XBB_TEXLIVE_HISTORIC_URL="ftp://tug.org/historic"
  XBB_TEXLIVE_HISTORIC_URL="http://ftp.math.utah.edu/pub/tex/historic"
  XBB_TEXLIVE_FOLDER="install-tl"
  XBB_TEXLIVE_ARCHIVE="install-tl-unx.tar.gz"
  XBB_TEXLIVE_EDITION="${year}"
  XBB_TEXLIVE_URL="${XBB_TEXLIVE_HISTORIC_URL}/systems/texlive/${XBB_TEXLIVE_EDITION}/${XBB_TEXLIVE_ARCHIVE}"
  XBB_TEXLIVE_REPO_URL="${XBB_TEXLIVE_HISTORIC_URL}/systems/texlive/${XBB_TEXLIVE_EDITION}/tlnet-final"
  XBB_TEXLIVE_PREFIX="/opt/texlive"

  wget -O "${XBB_DOWNLOAD}/${XBB_TEXLIVE_ARCHIVE}" "${XBB_TEXLIVE_URL}"

# Create the texlive.profile used to automate the install.
# These definitions are specific to TeX Live 2016.
tmp_profile=$(mktemp)

# Note: __EOF__ is not quoted to allow local substitutions.
cat <<__EOF__ > "${tmp_profile}"
# texlive.profile
TEXDIR ${XBB_TEXLIVE_PREFIX}
TEXMFCONFIG ~/.texlive/texmf-config
TEXMFHOME ~/texmf
TEXMFLOCAL ${XBB_TEXLIVE_PREFIX}/texmf-local
TEXMFSYSCONFIG ${XBB_TEXLIVE_PREFIX}/texmf-config
TEXMFSYSVAR ${XBB_TEXLIVE_PREFIX}/texmf-var
TEXMFVAR ~/.texlive/texmf-var

option_doc 0
option_src 0
__EOF__

  (
    mkdir -p "${XBB_TEXLIVE_FOLDER}"
    cd "${XBB_TEXLIVE_FOLDER}"

    tar x -v --strip-components 1 -f "${XBB_DOWNLOAD}/${XBB_TEXLIVE_ARCHIVE}"

    ls -lL

    mkdir -p "${XBB_TEXLIVE_PREFIX}"

    export PATH="${XBB_TEXLIVE_PREFIX}"/bin/"${UNAME_ARCH}"-linux:${PATH}

    set +e

    # -scheme small, medium, full
    "./install-tl" \
      -repository "${XBB_TEXLIVE_REPO_URL}" \
      -no-gui \
      -lang en \
      -profile "${tmp_profile}" \
      -scheme medium

    # Keep no backups (not required, simply makes cache bigger)
    tlmgr option -- autobackup 0

    set -e

    # The following errors may be encountered when installing the full distribution:
    # fmtutil [INFO]: /opt/texlive/texmf-var/web2c/pdftex/cslatex.fmt installed.
    # fmtutil [ERROR]: running `xetex -ini   -jobname=xetex -progname=xetex -etex xetex.ini </dev/null' return status 127
    # fmtutil [ERROR]: return error due to options --strict
    # fmtutil [ERROR]: running `xetex -ini   -jobname=cont-en -progname=context -8bit *cont-en.mkii </dev/null' return status 127
    # fmtutil [ERROR]: return error due to options --strict
    # fmtutil [ERROR]: running `xetex -ini   -jobname=xelatex -progname=xelatex -etex xelatex.ini </dev/null' return status 127
    # fmtutil [ERROR]: return error due to options --strict
    # fmtutil [ERROR]: running `xetex -ini   -jobname=pdfcsplain -progname=pdfcsplain -etex csplain.ini </dev/null' return status 127
    # fmtutil [ERROR]: return error due to options --strict
    # fmtutil [INFO]: Disabled formats: 6
    # fmtutil [INFO]: Successfully rebuilt formats: 40
    # fmtutil [INFO]: Failed to build: 4 (xetex/xetex xetex/cont-en xetex/xelatex xetex/pdfcsplain)
    # fmtutil [INFO]: Total formats: 50
    # fmtutil [INFO]: exiting with status 4

    if [ -f "${XBB_TEXLIVE_PREFIX}"/install-tl.log ]
    then
      cat "${XBB_TEXLIVE_PREFIX}"/install-tl.log 1>&2
    fi
  )

  hash -r
}

# -----------------------------------------------------------------------------

function do_cleanup()
{
  rm -rf "${XBB_DOWNLOAD}"
  rm -rf "${XBB_INPUT}"
}
# =============================================================================

# 2019 fails.
do_texlive "2018"

do_cleanup

# -----------------------------------------------------------------------------
