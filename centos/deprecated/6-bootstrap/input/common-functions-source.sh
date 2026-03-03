# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

function prepare_xbb_env()
{
  XBB_DOWNLOAD_FOLDER="/tmp/xbb-download"
  XBB_TMP_FOLDER="/tmp/xbb"

  # The next folders are called XBB for consistency reasons,
  # in fact they are used by the the bootstrap.
  XBB_FOLDER="/opt/xbb-bootstrap"
  XBB_BUILD_FOLDER="${XBB_TMP_FOLDER}/bootstrap-build"

  mkdir -p "${XBB_TMP_FOLDER}"
  mkdir -p "${XBB_DOWNLOAD_FOLDER}"

  mkdir -p "${XBB_FOLDER}"
  mkdir -p "${XBB_BUILD_FOLDER}"

  # ---------------------------------------------------------------------------

  # x86_64 or i686 (warning -p deprecated)
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

  XBB_CPPFLAGS=""
  if [ "${BITS}" == "32" ]
  then
    # To avoid "stat: Value too large for defined data type".
    XBB_CPPFLAGS+=" -D_FILE_OFFSET_BITS=64"
  fi

  XBB_CFLAGS="-O2 -ffunction-sections -fdata-sections -m${BITS} -pipe"
  XBB_CXXFLAGS="-O2 -ffunction-sections -fdata-sections -m${BITS} -pipe"

  XBB_LDFLAGS=""
  XBB_LDFLAGS_LIB="${XBB_LDFLAGS}"
  XBB_LDFLAGS_APP="${XBB_LDFLAGS} -Wl,--gc-sections  -static-libstdc++"
  XBB_LDFLAGS_APP_STATIC="${XBB_LDFLAGS_APP} -static -static-libgcc"

  BUILD="${UNAME_ARCH}-linux-gnu"

  # Make all tools choose gcc, not the old cc.
  CC="gcc"
  CXX="g++"

  PKG_CONFIG="${XBB_FOLDER}/bin/pkg-config-verbose"

  # Leave an explicit file with the version.
  echo "${XBB_VERSION}" > "${XBB_FOLDER}/VERSION"

  # ---------------------------------------------------------------------------

  # Default PATH.
  PATH=${PATH:-""}

  # Default LD_LIBRARY_PATH.
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-""}

  # Default empty PKG_CONFIG_PATH.
  PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-":"}

  JOBS=${JOBS:-""}

  # ---------------------------------------------------------------------------

  export XBB_DOWNLOAD_FOLDER
  export XBB_TMP_FOLDER
  export XBB_FOLDER

  export UNAME_ARCH
  export BITS
  export LIB_ARCH

  export XBB_CPPFLAGS
  export XBB_CFLAGS
  export XBB_CXXFLAGS
  export XBB_LDFLAGS
  export XBB_LDFLAGS_LIB
  export XBB_LDFLAGS_APP
  export XBB_LDFLAGS_APP_STATIC

  export BUILD
  export JOBS

  export PATH
  export LD_LIBRARY_PATH
  export PKG_CONFIG_PATH
  export PKG_CONFIG

  export CC
  export CXX
}

# -----------------------------------------------------------------------------

function create_pkg_config_verbose()
{
  # Note: __EOF__ is quoted to prevent substitutions here.
  mkdir -p "${XBB_FOLDER}/bin"
  cat <<'__EOF__' > "${XBB_FOLDER}/bin/pkg-config-verbose"
#! /bin/sh
# pkg-config wrapper for debug

pkg-config $@
RET=$?
OUT=$(pkg-config $@)
echo "($PKG_CONFIG_PATH) | pkg-config $@ -> $RET [$OUT]" 1>&2
exit ${RET}

__EOF__
# The above marker must start in the first column.

  chmod +x "${XBB_FOLDER}/bin/pkg-config-verbose"
}

# -----------------------------------------------------------------------------

# Included when building the final XBB tools.
function create_xbb_source()
{
  # Note: __EOF__ is quoted to prevent substitutions here.
  cat <<'__EOF__' > "${XBB_FOLDER}/xbb-source.sh"
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

export XBB_BOOTSTRAP_FOLDER="/opt/xbb-bootstrap"
__EOF__
# The above marker must start in the first column.

echo "export XBB_VERSION=\"${XBB_VERSION}\"" >> "${XBB_FOLDER}/xbb-source.sh"

# Note: __EOF__ is quoted to prevent substitutions here.
cat <<'__EOF__' >> "${XBB_FOLDER}/xbb-source.sh"

# Adjust PATH & LD_LIBRARY_PATH to prefer the XBB bootstrap binaries.
xbb_activate_bootstrap()
{
  # Add the XBB bootstrap bin to the PATH.
  PATH="${XBB_BOOTSTRAP_FOLDER}/bin:${PATH}"

  # Add the XBB bootstrap lib to the LD_LIBRARY_PATH.
  LD_LIBRARY_PATH="${XBB_BOOTSTRAP_FOLDER}/lib:${LD_LIBRARY_PATH}"

  if [ -d "${XBB_BOOTSTRAP_FOLDER}/lib64" ]
  then
    # On 64-bit systems, add lib64 to the LD_LIBRARY_PATH.
    LD_LIBRARY_PATH="${XBB_BOOTSTRAP_FOLDER}/lib64:${LD_LIBRARY_PATH}"
  fi

  export PATH
  export LD_LIBRARY_PATH
}

# Add TeX to PATH.
function xbb_activate_tex()
{
  if [ -d "/opt/texlive/bin/x86_64-linux" ]
  then
    PATH="/opt/texlive/bin/x86_64-linux:${PATH}"
  elif [ -d "/opt/texlive/bin/i386-linux" ]
  then
    PATH="/opt/texlive/bin/i386-linux:${PATH}"
  fi

  export PATH
}

__EOF__
# The above marker must start in the first column.
}

function xbb_activate()
{
  :
}

# For the XBB bootstrap builds, add the freshly built binaries.
function xbb_activate_installed_bin()
{
  # Add the XBB bin to the PATH.
  PATH="${XBB_FOLDER}/bin:${PATH}"

  # Add the XBB lib to the LD_LIBRARY_PATH.
  LD_LIBRARY_PATH="${XBB_FOLDER}/lib:${LD_LIBRARY_PATH}"

  if [ -d "${XBB_FOLDER}/lib64" ]
  then
    # On 64-bit systems, add lib64 to the LD_LIBRARY_PATH.
    LD_LIBRARY_PATH="${XBB_FOLDER}/lib64:${LD_LIBRARY_PATH}"
  fi

  export PATH
  export LD_LIBRARY_PATH
}

# For the XBB builds, add the freshly built headrs and libraries.
function xbb_activate_installed_dev()
{
  # Add XBB include in front of XBB_CPPFLAGS.
  XBB_CPPFLAGS="-I${XBB_FOLDER}/include ${XBB_CPPFLAGS}"

  # Add XBB lib in front of XBB_LDFLAGS.
  XBB_LDFLAGS="-L${XBB_FOLDER}/lib ${XBB_LDFLAGS}"
  XBB_LDFLAGS_LIB="-L${XBB_FOLDER}/lib ${XBB_LDFLAGS_LIB}"
  XBB_LDFLAGS_APP="-L${XBB_FOLDER}/lib ${XBB_LDFLAGS_APP}"
  XBB_LDFLAGS_APP_STATIC="-L${XBB_FOLDER}/lib ${XBB_LDFLAGS_APP_STATIC}"

  # Add XBB lib in front of PKG_CONFIG_PATH.
  PKG_CONFIG_PATH="${XBB_FOLDER}/lib/pkgconfig:${PKG_CONFIG_PATH}"

  LD_LIBRARY_PATH="${XBB_FOLDER}/lib:${LD_LIBRARY_PATH}"

  if [ -d "${XBB_FOLDER}/lib64" ]
  then
    # For 64-bit systems, add XBB lib64 in front of paths.
    XBB_LDFLAGS_LIB="-L${XBB_FOLDER}/lib64 ${XBB_LDFLAGS_LIB}"
    XBB_LDFLAGS_APP="-L${XBB_FOLDER}/lib64 ${XBB_LDFLAGS_APP}"
    XBB_LDFLAGS_APP_STATIC="-L${XBB_FOLDER}/lib64 ${XBB_LDFLAGS_APP_STATIC}"
    PKG_CONFIG_PATH="${XBB_FOLDER}/lib64/pkgconfig:${PKG_CONFIG_PATH}"
    LD_LIBRARY_PATH="${XBB_FOLDER}/lib64:${LD_LIBRARY_PATH}"
  fi

  export XBB_CPPFLAGS
  export XBB_LDFLAGS
  export XBB_LDFLAGS_LIB
  export XBB_LDFLAGS_APP
  export XBB_LDFLAGS_APP_STATIC
  export LD_LIBRARY_PATH
}

# -----------------------------------------------------------------------------
# Common functions.

function extract()
{
  local ARCHIVE_NAME="$1"

  if [ -x "${XBB_FOLDER}/bin/tar" ]
  then
    (
      PATH="${XBB_FOLDER}/bin:${PATH}"
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

  if [ ! -f "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}" ]
  then
    rm -f "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}.download"
    if [ -x "${XBB_FOLDER}/bin/curl" ]
    then
      (
        PATH="${XBB_FOLDER}/bin:${PATH}"
        curl --fail -L -o "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}.download" "${URL}"
      )
    else
      curl --fail -L -o "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}.download" "${URL}"
    fi
    mv "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}.download" "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}"
  fi

  extract "${XBB_DOWNLOAD_FOLDER}/${ARCHIVE_NAME}"
}

# -----------------------------------------------------------------------------

do_strip_libs()
{
  (
    cd "${XBB_FOLDER}"

    xbb_activate

    set +e
    if [ -f "${XBB_FOLDER}/bin/strip" ]
    then
      # -type f to skip links.
      find lib* -name '*.so' -type f -print -exec "${XBB_FOLDER}/bin/strip" --strip-debug {} \;
      find lib* -name '*.so.*'  -type f -print -exec "${XBB_FOLDER}/bin/strip" --strip-debug {} \;
      find lib* -name '*.a'  -type f  -print -exec "${XBB_FOLDER}/bin/strip" --strip-debug {} \;
    fi
    set -e
  )
}

# -----------------------------------------------------------------------------

do_cleaunup()
{
  # Preserve download, will be used by xbb and removed later.
  # rm -rf "$XBB_DOWNLOAD_FOLDER"

  # All other can go.
  rm -rf "${XBB_BUILD_FOLDER}"
  rm -rf "${XBB_TMP_FOLDER}"
  rm -rf "${XBB_INPUT_FOLDER}"
}

# -----------------------------------------------------------------------------
