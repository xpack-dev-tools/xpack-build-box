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

# To split version into components:
# local XBB_CMAKE_MAJOR_VERSION="$(echo ${XBB_CMAKE_MAJOR_VERSION} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1.\2|')"

function prepare_xbb_env()
{
  XBB_DOWNLOAD_FOLDER="/tmp/xbb-download"
  XBB_TMP_FOLDER="/tmp/xbb"

  XBB_FOLDER="/opt/xbb"
  XBB_BOOTSTRAP_FOLDER="/opt/xbb-bootstrap"
  XBB_BUILD_FOLDER="${XBB_TMP_FOLDER}/xbb-build"

  mkdir -p "${XBB_TMP_FOLDER}"
  mkdir -p "${XBB_DOWNLOAD_FOLDER}"

  mkdir -p "${XBB_FOLDER}"
  mkdir -p "${XBB_BUILD_FOLDER}"

  # ---------------------------------------------------------------------------

  # x86_64 or i686 (do not use -p)
  UNAME_ARCH="$(uname -m)"
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
  # Wihtout -static-libstdc++, the bootstrap lib folder is needed to
  # find libstdc++.
  XBB_LDFLAGS_APP="${XBB_LDFLAGS} -Wl,--gc-sections -static-libstdc++"
  XBB_LDFLAGS_APP_STATIC="${XBB_LDFLAGS_APP} -static -static-libgcc"

  BUILD="${UNAME_ARCH}-linux-gnu"

  # x86_64-w64-mingw32 or i686-w64-mingw32
  MINGW_TARGET="${UNAME_ARCH}-w64-mingw32"

  # Make all tools choose gcc, not the old cc.
  CC="gcc-7bs"
  CXX="g++-7bs"

  PKG_CONFIG="${XBB_BOOTSTRAP_FOLDER}/bin/pkg-config-verbose"

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
  export XBB_BOOTSTRAP_FOLDER
  export XBB_BUILD_FOLDER

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
  export MINGW_TARGET
  export JOBS

  export PATH
  export LD_LIBRARY_PATH
  export PKG_CONFIG_PATH
  export PKG_CONFIG

  export CC
  export CXX

  export SHELL="/bin/bash"
  export CONFIG_SHELL="/bin/bash"
}

function create_xbb_source()
{
  # Create the main source file to be source included by the applications.
  cat <<'__EOF__' > "${XBB_FOLDER}/xbb-source.sh"
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

export XBB_FOLDER="/opt/xbb"
__EOF__
# The above marker must start in the first column.

echo "export XBB_VERSION=\"${XBB_VERSION}\"" >> "${XBB_FOLDER}/xbb-source.sh"

# Note: __EOF__ is quoted to prevent substitutions here.
cat <<'__EOF__' >> "${XBB_FOLDER}/xbb-source.sh"

# Adjust PATH & LD_LIBRARY_PATH to prefer the XBB binaries.
# This is enough to run the XBB binaries in the application script.
# This **does not** provide access to the XBB libraries and headers,
# which normally are internal to XBB and should not be used.
function xbb_activate()
{
  # Add the XBB bin to the bottom of the PATH.
  PATH="${XBB_FOLDER}/bin:${PATH}"

  # Add XBB lib to LD_LIBRARY_PATH.
  LD_LIBRARY_PATH="${XBB_FOLDER}/lib:${LD_LIBRARY_PATH}"

  if [ -d "${XBB_FOLDER}/lib64" ]
  then
    # On 64-bit systems, add lib64 in front of LD_LIBRARY_PATH.
    LD_LIBRARY_PATH="${XBB_FOLDER}/lib64:${LD_LIBRARY_PATH}"
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

# -----------------------------------------------------------------------------

# For the XBB builds, add the bootstrap folders.
function xbb_activate()
{
  xbb_activate_bootstrap
}

# For the XBB builds, add the freshly built binaries.
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
    XBB_LDFLAGS="-L${XBB_FOLDER}/lib64 ${XBB_LDFLAGS_LIB}"
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

  export PKG_CONFIG_PATH
  export LD_LIBRARY_PATH
}

# -----------------------------------------------------------------------------

function extract()
{
  local archive_name="$1"
  (
    xbb_activate

    if [[ "${archive_name}" == *zip ]]
    then
      unzip "${archive_name}" -d "$(basename ${archive_name} ".zip")"
    else
      tar xf "${archive_name}"
    fi
  )
}

function download()
{
  local archive_name="$1"
  local url="$2"

  if [ ! -f "${XBB_DOWNLOAD_FOLDER}/${archive_name}" ]
  then
    (
      xbb_activate

      rm -f "${XBB_DOWNLOAD_FOLDER}/${archive_name}.download"
      curl --fail -L -o "${XBB_DOWNLOAD_FOLDER}/${archive_name}.download" "${url}"
      mv "${XBB_DOWNLOAD_FOLDER}/${archive_name}.download" "${XBB_DOWNLOAD_FOLDER}/${archive_name}"
    )
  fi
}

function download_and_extract()
{
  local archive_name="$1"
  local url="$2"

  download "${archive_name}" "${url}"
  extract "${XBB_DOWNLOAD_FOLDER}/${archive_name}"
}

function eval_bool()
{
  local val="$1"
  [[ "${val}" = 1 || "${val}" = true || "${val}" = yes || "${val}" = y ]]
}

do_strip_libs()
{
  (
    cd "${XBB_FOLDER}"

    xbb_activate

    local strip
    if [ -f "${XBB_FOLDER}/bin/strip" ]
    then
      strip="${XBB_FOLDER}/bin/strip"
    elif [ -f "${XBB_BOOTSTRAP_FOLDER}/bin/strip" ]
    then
      strip="${XBB_BOOTSTRAP_FOLDER}/bin/strip"
    else
      strip="strip"
    fi

    local ranlib
    if [ -f "${XBB_FOLDER}/bin/ranlib" ]
    then
      ranlib="${XBB_FOLDER}/bin/ranlib"
    elif [ -f "${XBB_BOOTSTRAP_FOLDER}/bin/ranlib" ]
    then
      ranlib="${XBB_BOOTSTRAP_FOLDER}/bin/ranlib"
    else
      ranlib="ranlib"
    fi

    echo
    echo "Stripping libraries..."

    set +e
    # -type f to skip links.
    find lib* \
      -type f \
      -name '*.so' \
      -print \
      -exec "${strip}" --strip-debug {} \;
    find lib* \
      -type f \
      -name '*.so.*' \
      -print \
      -exec "${strip}" --strip-debug {} \;
    find lib* \
      -type f \
      -name '*.a' \
      -not -path 'lib/gcc/*-w64-mingw32/*'  \
      -print \
      -exec "${strip}" --strip-debug {} \; \
      -exec "${ranlib}" {} \;
    set -e
  )
}

# -----------------------------------------------------------------------------

function do_cleaunup()
{
  rm -rf "${XBB_DOWNLOAD_FOLDER}"

  # rm -rf "${XBB_BOOTSTRAP_FOLDER}"
  rm -rf "${XBB_BUILD_FOLDER}"
  rm -rf "${XBB_TMP_FOLDER}"
  rm -rf "${XBB_INPUT_FOLDER}"
}

# -----------------------------------------------------------------------------
