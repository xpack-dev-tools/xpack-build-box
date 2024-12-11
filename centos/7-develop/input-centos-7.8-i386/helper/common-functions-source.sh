# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2020 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# Common functions used for building the XBB environments.

# =============================================================================

function start_timer()
{
  CONTAINER_BEGIN_SECOND=$(date +%s)
  echo
  echo "Container script \"$(basename "$0")\" started at $(date)."
}

function stop_timer()
{
  local end_second=$(date +%s)
  echo
  echo "Container script \"$(basename "$0")\" completed at $(date)."
  local delta_seconds=$((end_second-CONTAINER_BEGIN_SECOND))
  if [ ${delta_seconds} -lt 100 ]
  then
    echo "Duration: ${delta_seconds} seconds."
  else
    local delta_minutes=$(((delta_seconds+30)/60))
    echo "Duration: ${delta_minutes} minutes."
  fi
}

function do_prerequisites()
{
  start_timer

  detect_host

  if [ -f "/.dockerenv" ]
  then
    docker_prepare_env
  fi

  prepare_xbb_env

  create_xbb_source
}

function detect_host()
{
  echo
  uname -a

  HOST_UNAME="$(uname)"
  HOST_LC_UNAME=$(echo ${HOST_UNAME} | tr "[:upper:]" "[:lower:]")

  HOST_MACHINE="$(uname -m)"

  HOST_DISTRO_NAME="?" # Linux distribution name (Ubuntu|CentOS|...)
  HOST_DISTRO_LC_NAME="?" # Same, in lower case.
  HOST_DISTRO_RELEASE="?"

  HOST_NODE_ARCH="?" # Node.js process.arch (x32|x64|arm|arm64)
  HOST_NODE_PLATFORM="?" # Node.js process.platform (darwin|linux|win32)

  IS_HOST_ARM=""
  IS_HOST_INTEL=""

  if [ "${HOST_UNAME}" == "Darwin" ]
  then
    # uname -p -> i386
    # uname -m -> x86_64

    HOST_BITS="64"

    HOST_DISTRO_NAME="$(sw_vers -productName)"
    HOST_DISTRO_LC_NAME=$(echo ${HOST_DISTRO_NAME} | sed -e 's/ //g' | tr "[:upper:]" "[:lower:]")
    HOST_DISTRO_RELEASE="$(sw_vers -productVersion)"

    HOST_NODE_ARCH="x64" # For now.
    HOST_NODE_PLATFORM="darwin"

    BUILD="$(gcc --version 2>&1 | grep 'Target:' | sed -e 's/Target: //')"

  elif [ "${HOST_UNAME}" == "Linux" ]
  then
    # ----- Determine distribution name and word size -----

    # uname -p -> x86_64|i686 (unknown in recent versions, use -m)
    # uname -m -> x86_64|i686|aarch64|armv7l

    if [ "${HOST_MACHINE}" == "x86_64" ]
    then
      HOST_BITS="64"
      HOST_NODE_ARCH="x64"
      IS_HOST_INTEL="y"
    elif [ "${HOST_MACHINE}" == "i686" ]
    then
      HOST_BITS="32"
      HOST_NODE_ARCH="x32"
      IS_HOST_INTEL="y"
    elif [ "${HOST_MACHINE}" == "aarch64" ]
    then
      HOST_BITS="64"
      HOST_NODE_ARCH="arm64"
      IS_HOST_ARM="y"
    elif [ "${HOST_MACHINE}" == "armv7l" -o "${HOST_MACHINE}" == "armv8l" ]
    then
      HOST_BITS="32"
      HOST_NODE_ARCH="arm"
      IS_HOST_ARM="y"
    else
      echo "Unknown uname -m ${HOST_MACHINE}"
      exit 1
    fi

    HOST_NODE_PLATFORM="linux"

    local lsb_path=$(which lsb_release)
    if [ -z "${lsb_path}" ]
    then
      echo "Please install the lsb core package and rerun."
      exit 1
    fi

    HOST_DISTRO_NAME=$(lsb_release -si)
    HOST_DISTRO_LC_NAME=$(echo ${HOST_DISTRO_NAME} | tr "[:upper:]" "[:lower:]")

    HOST_DISTRO_RELEASE=$(lsb_release -sr)

    if [ -x "/usr/share/libtool/build-aux/config.guess" ]
    then
      BUILD="$(/usr/share/libtool/build-aux/config.guess)"
    else
      BUILD="$(gcc -dumpmachine)"
    fi

  else
    echo "Unsupported uname ${HOST_UNAME}"
    exit 1
  fi

  MACOS_SDK_PATH=""
  if [ "${HOST_UNAME}" == "Darwin" ]
  then
    local print_path="$(xcode-select -print-path)"
    if [ -d "${print_path}/SDKs/MacOSX.sdk" ]
    then
      # Without Xcode, use the SDK that comes with the CLT.
      MACOS_SDK_PATH="${print_path}/SDKs/MacOSX.sdk"
    elif [ -d "${print_path}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" ]
    then
      # With Xcode, chose the SDK from the macOS platform.
      MACOS_SDK_PATH="${print_path}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    elif [ -d "/usr/include" ]
    then
      # Without Xcode, on 10.10 there is no SDK, use the root.
      MACOS_SDK_PATH="/"
    else
      echo "Cannot find SDK in ${print_path}."
      exit 1
    fi
  fi
  export MACOS_SDK_PATH

  # x86_64-w64-mingw32 or i686-w64-mingw32
  MINGW_TARGET="${HOST_MACHINE}-w64-mingw32"

  echo
  echo "Running on ${HOST_DISTRO_NAME} ${HOST_DISTRO_RELEASE} ${HOST_MACHINE} (${HOST_BITS}-bit)."

  USER_ID=$(id -u)
  USER_NAME="$(id -u -n)"
  GROUP_ID=$(id -g)
  GROUP_NAME="$(id -g -n)"
}

function is_linux()
{
  local uname="$(uname)"
  if [ "${uname}" == "Linux" ]
  then
    return 0
  else
    return 1
  fi
}

function is_darwin()
{
  local uname="$(uname)"
  if [ "${uname}" == "Darwin" ]
  then
    return 0
  else
    return 1
  fi
}

function is_intel()
{
  local machine="$(uname -m)"
  if [ "${machine}" == "x86_64" ]
  then
    return 0
  elif [ "${machine}" == "i686" ]
  then
    return 0
  else
    return 1
  fi
}

function is_arm()
{
  local machine="$(uname -m)"
  if [ "${machine}" == "aarch64" ]
  then
    return 0
  elif [ "${machine}" == "armv8l" ]
  then
    return 0
  elif [ "${machine}" == "armv7l" ]
  then
    return 0
  else
    return 1
  fi
}

function prepare_xbb_env()
{
  XBB_PARENT_FOLDER_PATH=${XBB_PARENT_FOLDER_PATH:=""}
  RUN_LONG_TESTS=${RUN_LONG_TESTS:=""}

  if [ "${HOST_UNAME}" == "Darwin" ]
  then
    macos_version=$(defaults read loginwindow SystemVersionStampAsString)
    xclt_version=$(xcode-select --version | sed -e 's/xcode-select version \([0-9]*\)\./\1/')

    if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
    then
      # TODO
      CC=${CC:-"clang"}
      CXX=${CXX:-"clang++"}
    else
      # TODO
      prepare_gcc_env "" "-xbs"
    fi
  else
    if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
    then
      prepare_gcc_env ""
    elif [ "${XBB_LAYER}" == "xbb" ]
    then
      prepare_gcc_env "" "-xbs"
    elif [ "${XBB_LAYER}" == "xbb-test" ]
    then
      prepare_gcc_env "" "-xbb"
    else
      echo "XBB_LAYER ${XBB_LAYER} not supported."
      exit 1
    fi
  fi

  if [ "${XBB_LAYER}" == "xbb" ]
  then
    if [ ! -d "${XBB_PARENT_FOLDER_PATH}" -o ! -x "${XBB_PARENT_FOLDER_PATH}/usr/bin/${CXX}" ]
    then
      echo "XBB Bootstrap compiler not found in \"${XBB_PARENT_FOLDER_PATH}\""
      exit 1
    fi
  elif [ "${XBB_LAYER}" == "xbb-test" ]
  then
    if [ ! -d "${XBB_PARENT_FOLDER_PATH}" -o ! -x "${XBB_PARENT_FOLDER_PATH}/usr/bin/${CXX}" ]
    then
      echo "XBB compiler not found in \"${XBB_PARENT_FOLDER_PATH}\""
      exit 1
    fi
  fi

  CACHE_FOLDER_PATH="${WORK_FOLDER_PATH}/cache"

  XBB_WORK_FOLDER_PATH="${WORK_FOLDER_PATH}/$(basename "${XBB_INSTALL_FOLDER_PATH}")-${XBB_VERSION}-${HOST_DISTRO_LC_NAME}-${HOST_DISTRO_RELEASE}-${HOST_MACHINE}"

  BUILD_FOLDER_PATH="${XBB_WORK_FOLDER_PATH}/build"
  LIBS_BUILD_FOLDER_PATH="${XBB_WORK_FOLDER_PATH}/build/libs"
  SOURCES_FOLDER_PATH="${XBB_WORK_FOLDER_PATH}/sources"
  STAMPS_FOLDER_PATH="${XBB_WORK_FOLDER_PATH}/stamps"
  LOGS_FOLDER_PATH="${XBB_WORK_FOLDER_PATH}/logs"

  INSTALL_FOLDER_PATH="${XBB_INSTALL_FOLDER_PATH}"

  # ---------------------------------------------------------------------------

  mkdir -pv "${CACHE_FOLDER_PATH}"
  mkdir -pv "${BUILD_FOLDER_PATH}"
  mkdir -pv "${LIBS_BUILD_FOLDER_PATH}"
  mkdir -pv "${SOURCES_FOLDER_PATH}"
  mkdir -pv "${STAMPS_FOLDER_PATH}"
  mkdir -pv "${LOGS_FOLDER_PATH}"

  mkdir -pv "${INSTALL_FOLDER_PATH}"

  mkdir -pv "${INSTALL_FOLDER_PATH}/bin"
  mkdir -pv "${INSTALL_FOLDER_PATH}/include"
  mkdir -pv "${INSTALL_FOLDER_PATH}/lib"

  # ---------------------------------------------------------------------------

  XBB_CPPFLAGS=""

  if [ "${HOST_BITS}" == "32" ]
  then
    XBB_CPPFLAGS+=" -D_FILE_OFFSET_BITS=64"
  fi

  # Is is important for all code to be compiled sith separate sections,
  # to give the linker the chance to optize when building executables.
  XBB_CFLAGS="-pipe -O2 -ffunction-sections -fdata-sections"
  XBB_CXXFLAGS="-pipe -O2 -ffunction-sections -fdata-sections"

  XBB_CFLAGS_NO_W="${XBB_CFLAGS} -w"
  XBB_CXXFLAGS_NO_W="${XBB_CXXFLAGS} -w"

  XBB_LDFLAGS=""

  if [ "${HOST_UNAME}" == "Linux" ]
  then
    XBB_LDFLAGS+=" -Wl,--disable-new-dtags"
  fi

  # -Wl,--gc-sections may make some symbols dissapear, do not use it here.
  XBB_LDFLAGS_LIB="${XBB_LDFLAGS}"
  XBB_LDFLAGS_LIB_STATIC_GCC="${XBB_LDFLAGS_LIB}"

  XBB_LDFLAGS_APP="${XBB_LDFLAGS}"
  XBB_LDFLAGS_APP_STATIC="${XBB_LDFLAGS_APP}"
  XBB_LDFLAGS_APP_STATIC_GCC="${XBB_LDFLAGS_APP}"

  if [ "${HOST_UNAME}" == "Linux" ]
  then
    XBB_LDFLAGS_APP+=" -Wl,--gc-sections"
    XBB_LDFLAGS_APP_STATIC=" -static"

    # Minimise the risk of picking the wrong shared libraries.
    XBB_LDFLAGS_LIB_STATIC_GCC+=" -static-libgcc -static-libstdc++"
    XBB_LDFLAGS_APP_STATIC_GCC+=" -static-libgcc -static-libstdc++"
  fi

  if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
  then
    XBB_GCC_SUFFIX="-xbs"
  elif [ "${XBB_LAYER}" == "xbb" ]
  then
    XBB_GCC_SUFFIX="-xbb"
  elif [ "${XBB_LAYER}" == "xbb-test" ]
  then
    XBB_GCC_SUFFIX="-xbt"
  else
    echo "IS_* not defined."
    exit 1
  fi

  # Applications should generally use STATIC_GCC, otherwise XBB apps which
  # require GCC shared libs from bootstrap might not find them.

  # ---------------------------------------------------------------------------

  install -m 755 -c "${helper_folder_path}/pkg-config-verbose" "${INSTALL_FOLDER_PATH}/bin/pkg-config-verbose"

  PKG_CONFIG="${INSTALL_FOLDER_PATH}/bin/pkg-config-verbose"

  echo "${XBB_VERSION}" >  "${INSTALL_FOLDER_PATH}/VERSION"

  # ---------------------------------------------------------------------------

  if [ "${HOST_UNAME}" == "Darwin" ]
  then
    JOBS=${JOBS:-"$(sysctl -n hw.ncpu)"}
    SHLIB_EXT="dylib"
  else
    JOBS=${JOBS:-"$(nproc)"}
    SHLIB_EXT="so"
  fi

  # Default PATH.
  PATH=${PATH:-""}

  # Default empty PKG_CONFIG_PATH.
  PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-""}

  # Prevent pkg-config to search the system folders (configured in the
  # pkg-config at build time).
  PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-""}

  # ---------------------------------------------------------------------------

  export LANGUAGE="en_US:en"
  export LANG="en_US.UTF-8"
  export LC_ALL="en_US.UTF-8"
  export LC_COLLATE="en_US.UTF-8"
  export LC_CTYPE="UTF-8"
  export LC_MESSAGES="en_US.UTF-8"
  export LC_MONETARY="en_US.UTF-8"
  export LC_NUMERIC="en_US.UTF-8"
  export LC_TIME="en_US.UTF-8"

  export XBB_CPPFLAGS
  export XBB_CFLAGS
  export XBB_CXXFLAGS
  export XBB_CFLAGS_NO_W
  export XBB_CXXFLAGS_NO_W
  export XBB_LDFLAGS
  export XBB_LDFLAGS_LIB
  export XBB_LDFLAGS_LIB_STATIC_GCC
  export XBB_LDFLAGS_APP
  export XBB_LDFLAGS_APP_STATIC
  export XBB_LDFLAGS_APP_STATIC_GCC

  export XBB_RPATH

  export BUILD_FOLDER_PATH
  export INSTALL_FOLDER_PATH

  export PATH

  export PKG_CONFIG_PATH
  export PKG_CONFIG_LIBDIR
  export PKG_CONFIG

  export SHLIB_EXT

  set +e
  local java_home=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | sed -e 's/.*= //' | sed -e 's|/jre||' )
  set -e

  if [ ! -z "${java_home}" ]
  then
    export JAVA_HOME="${java_home}"
  fi

  export SHELL="/bin/bash"
  export CONFIG_SHELL="/bin/bash"

  test_functions=()

  echo
  echo "xbb env..."
  env | sort
}

function prepare_gcc_env()
{
  local prefix="$1"

  local suffix
  if [ $# -ge 2 ]
  then
    suffix="$2"
  else
    suffix=""
  fi

  export CC="${prefix}gcc${suffix}"
  export CXX="${prefix}g++${suffix}"
  export CPP="${prefix}cpp${suffix}"

  # On Darwin, -gcc-ar/nm/ranlib fail.
  if [ "${XBB_LAYER}" == "xbb-bootstrap" -o "${HOST_UNAME}" == "Darwin" ]
  then
    export AR="${prefix}ar"
    export NM="${prefix}nm"
    export RANLIB="${prefix}ranlib"
  else
    export AR="${prefix}gcc-ar${suffix}"
    export NM="${prefix}gcc-nm${suffix}"
    export RANLIB="${prefix}gcc-ranlib${suffix}"
  fi

  export AS="${prefix}as"
  export DLLTOOL="${prefix}dlltool"
  # libmpdec: ld: unrecognized -a option `tic-libgcc'
  # export LD="${prefix}ld"
  export OBJCOPY="${prefix}objcopy"
  export OBJDUMP="${prefix}objdump"
  export READELF="${prefix}readelf"
  export SIZE="${prefix}size"
  export STRIP="${prefix}strip"
  export WINDRES="${prefix}windres"
  export WINDMC="${prefix}windmc"
  export RC="${prefix}windres"
}

function unset_gcc_env()
{
  unset CC
  unset CXX
  unset AR
  unset AS
  unset DLLTOOL
  # unset LD
  unset NM
  unset OBJCOPY
  unset OBJDUMP
  unset RANLIB
  unset READELF
  unset SIZE
  unset STRIP
  unset WINDRES
  unset WINDMC
  unset RC
}

function prepare_library_path()
{
  # Start the path with the local XBB folder, to pick the newly compiled
  # libraries.
  if [ "${HOST_BITS}" == "64" ]
  then
    XBB_LIBRARY_PATH="${INSTALL_FOLDER_PATH}/lib64:${INSTALL_FOLDER_PATH}/lib"
  else
    XBB_LIBRARY_PATH="${INSTALL_FOLDER_PATH}/lib"
  fi

  # Add the compiler and system paths.
  XBB_LIBRARY_PATH+=":$(xbb_activate; compute_gcc_rpath "${CC}")"
  XBB_LIBRARY_PATH+=":$(xbb_activate; compute_glibc_rpath "${CC}")"

  echo "XBB_LIBRARY_PATH=${XBB_LIBRARY_PATH}"
  export XBB_LIBRARY_PATH
}

function run_tests()
{
  echo
  echo "Runnng final tests..."

  for test_function in ${test_functions[@]}
  do
    echo
    echo "Running ${test_function}..."
    ${test_function}
  done
}

# -----------------------------------------------------------------------------

# For the XBB builds, add the freshly built binaries.
function xbb_activate_installed_bin()
{
  # Add the XBB bin to the PATH.
  if [ -z "${PATH:-""}" ]
  then
    PATH="${INSTALL_FOLDER_PATH}/usr/sbin:${INSTALL_FOLDER_PATH}/usr/bin:${INSTALL_FOLDER_PATH}/sbin:${INSTALL_FOLDER_PATH}/bin"
  else
    PATH="${INSTALL_FOLDER_PATH}/usr/sbin:${INSTALL_FOLDER_PATH}/usr/bin:${INSTALL_FOLDER_PATH}/sbin:${INSTALL_FOLDER_PATH}/bin:${PATH}"
  fi

  export PATH
}

# For the XBB builds, add the freshly built headrs and libraries.
function xbb_activate_installed_dev()
{
  # Add XBB include in front of XBB_CPPFLAGS.
  XBB_CPPFLAGS="-I${INSTALL_FOLDER_PATH}/include ${XBB_CPPFLAGS}"

  if [ -d "${INSTALL_FOLDER_PATH}/lib" ]
  then
    # Add XBB lib in front of XBB_LDFLAGS.
    XBB_LDFLAGS="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS}"
    XBB_LDFLAGS_LIB="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_LIB}"
    XBB_LDFLAGS_LIB_STATIC_GCC="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_LIB_STATIC_GCC}"
    XBB_LDFLAGS_APP="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_APP}"
    XBB_LDFLAGS_APP_STATIC="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_APP_STATIC}"
    XBB_LDFLAGS_APP_STATIC_GCC="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_APP_STATIC_GCC}"

    # Add XBB lib in front of PKG_CONFIG_PATH.
    if [ -z "${PKG_CONFIG_PATH}" ]
    then
      PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/lib/pkgconfig"
    else
      PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"
    fi
  fi

  # If lib64 present and not link, add it in front of lib.
  if [ -d "${INSTALL_FOLDER_PATH}/lib64" -a ! -L "${INSTALL_FOLDER_PATH}/lib64" ]
  then
    XBB_LDFLAGS="-L${INSTALL_FOLDER_PATH}/lib64 ${XBB_LDFLAGS}"
    XBB_LDFLAGS_LIB="-L${INSTALL_FOLDER_PATH}/lib64 ${XBB_LDFLAGS_LIB}"
    XBB_LDFLAGS_LIB_STATIC_GCC="-L${INSTALL_FOLDER_PATH}/lib64 ${XBB_LDFLAGS_LIB_STATIC_GCC}"
    XBB_LDFLAGS_APP="-L${INSTALL_FOLDER_PATH}/lib64 ${XBB_LDFLAGS_APP}"
    XBB_LDFLAGS_APP_STATIC="-L${INSTALL_FOLDER_PATH}/lib64 ${XBB_LDFLAGS_APP_STATIC}"
    XBB_LDFLAGS_APP_STATIC_GCC="-L${INSTALL_FOLDER_PATH}/lib64 ${XBB_LDFLAGS_APP_STATIC_GCC}"

    # Add XBB lib in front of PKG_CONFIG_PATH.
    if [ -z "${PKG_CONFIG_PATH}" ]
    then
      PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/lib64/pkgconfig"
    else
      PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/lib64/pkgconfig:${PKG_CONFIG_PATH}"
    fi
  fi

  export XBB_CPPFLAGS

  export XBB_LDFLAGS
  export XBB_LDFLAGS_LIB
  export XBB_LDFLAGS_LIB_STATIC_GCC
  export XBB_LDFLAGS_APP
  export XBB_LDFLAGS_APP_STATIC
  export XBB_LDFLAGS_APP_STATIC_GCC

  export PKG_CONFIG_PATH
}

# -----------------------------------------------------------------------------

function create_xbb_source()
{
  echo
  echo "Creating ${INSTALL_FOLDER_PATH}/xbb-source.sh..."

  # Note: __EOF__ is NOT quoted to allow substitutions.
  cat <<__EOF__ > "${INSTALL_FOLDER_PATH}/xbb-source.sh"
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) $(date '+%Y') Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

__EOF__
# The above marker must start in the first column.

if false
then
  if [ -f "/.dockerenv" ]
  then
    if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
    then
      echo "export XBB_BOOTSTRAP_FOLDER_PATH=\"${INSTALL_FOLDER_PATH}\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    elif [ "${XBB_LAYER}" == "xbb" ]
    then
      echo "export XBB_FOLDER_PATH=\"${INSTALL_FOLDER_PATH}\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    elif [ "${XBB_LAYER}" == "xbb-test" ]
    then
      echo "export XBB_TEST_FOLDER_PATH=\"/opt/$(basename "${XBB_TEST_FOLDER_PATH}")\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    fi
  else
    if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
    then
      echo "export XBB_BOOTSTRAP_FOLDER_PATH=\"\${HOME}/opt/$(basename "${XBB_FOLDER_PATH}")\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    elif [ "${XBB_LAYER}" == "xbb" ]
    then
      echo "export XBB_FOLDER_PATH=\"\${HOME}/opt/$(basename "${XBB_FOLDER_PATH}")\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    elif [ "${XBB_LAYER}" == "xbb-test" ]
    then
      echo "export XBB_TEST_FOLDER_PATH=\"\${HOME}/opt/$(basename "${XBB_TEST_FOLDER_PATH}")\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    fi
  fi
fi

  echo "export TEXLIVE_FOLDER_PATH=\"/opt/texlive\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

  if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
  then

    # Note: __EOF__ is NOT quoted to allow substitutions.
    cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Adjust PATH to prefer the XBB bootstrap binaries.
function xbb_activate_bootstrap()
__EOF__
# The above marker must start in the first column.

  elif [ "${XBB_LAYER}" == "xbb" ]
  then

    # Note: __EOF__ is NOT quoted to allow substitutions.
    cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Adjust PATH to prefer the XBB binaries.
function xbb_activate()
__EOF__

  elif [ "${XBB_LAYER}" == "xbb-test" ]
  then

    # Note: __EOF__ is NOT quoted to allow substitutions.
    cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Adjust PATH to prefer the XBB Test binaries.
function xbb_activate()
__EOF__

  fi

  # Note: __EOF__ is NOT quoted to allow substitutions.
  cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
{
  if [ -z "\${PATH:-""}" ]
  then
    PATH="${INSTALL_FOLDER_PATH}/usr/sbin:${INSTALL_FOLDER_PATH}/usr/bin:${INSTALL_FOLDER_PATH}/sbin:${INSTALL_FOLDER_PATH}/bin"
  else
    PATH="${INSTALL_FOLDER_PATH}/usr/sbin:${INSTALL_FOLDER_PATH}/usr/bin:${INSTALL_FOLDER_PATH}/sbin:${INSTALL_FOLDER_PATH}/bin:\${PATH}"
  fi

  export PATH
}

__EOF__
# The above marker must start in the first column.

  # Adjust to TexLive conventions.
  tl_machine="${HOST_MACHINE}"
  if [ "${HOST_MACHINE}" == "i686" ]
  then
      tl_machine="i386"
  elif [ "${HOST_MACHINE}" == "armv8l" -o "${HOST_MACHINE}" == "armv7l" ]
  then
      tl_machine="armhf"
  fi

  # Note: __EOF__ is NOT quoted to allow substitutions.
  cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Add TeX to PATH.
function xbb_activate_tex()
{
  PATH="\${TEXLIVE_FOLDER_PATH}/bin/${tl_machine}-linux:\${PATH}"

  export PATH
}

__EOF__
# The above marker must start in the first column.

  # Note: __EOF__ is quoted to prevent substitutions here.
  cat <<'__EOF__' > "${INSTALL_FOLDER_PATH}/bin/get-gcc-rpath"
#!/usr/bin/env bash

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

script_name="$(basename "${script_path}")"

script_folder_path="$(dirname "${script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# -----------------------------------------------------------------------------

function compute_gcc_rpath()
{
  local cc="$1"

  # liblto_plugin.so ?
  local lib_names=( libstdc++.so libgcc_s.so libcc1.so )
  # Local by definition.
  declare -A paths
  for lib_name in ${lib_names[@]}
  do
    local file_path=$(${cc} -print-file-name="${lib_name}")
    if [ "${file_path}" == "${lib_name}" ]
    then
      continue
    fi
    local folder_path=$(dirname $(realpath ${file_path}))
    paths+=( ["${folder_path}"]="${folder_path}" )
  done

  echo "$(IFS=":"; echo "${!paths[*]}")"
}

function compute_glibc_rpath()
{
  local cc="$1"

  # liblto_plugin.so ?
  local lib_names=( libdl.so libpthread.so libnsl.so librt.so libc.so libm.so )
  # Local by definition.
  declare -A paths
  for lib_name in ${lib_names[@]}
  do
    local file_path=$(${cc} -print-file-name="${lib_name}")
    if [ "${file_path}" == "${lib_name}" ]
    then
      continue
    fi
    local folder_path=$(dirname $(realpath ${file_path}))
    paths+=( ["${folder_path}"]="${folder_path}" )
  done

  echo "$(IFS=":"; echo "${!paths[*]}")"
}

# -----------------------------------------------------------------------------

if [ $# -gt 0 ]
then
  cc="$1"
else
__EOF__
# The above marker must start in the first column.

  # Note: __EOF__ is NOT quoted to allow substitutions.
  cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/bin/get-gcc-rpath"
  cc="${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}"
fi

__EOF__
# The above marker must start in the first column.

  if [ "${HOST_BITS}" == "32" ]
  then

    # Note: __EOF__ is NOT quoted to allow substitutions.
    cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/bin/get-gcc-rpath"
gcc_rpath="${INSTALL_FOLDER_PATH}/lib"
__EOF__
# The above marker must start in the first column.

  else

    # Note: __EOF__ is NOT quoted to allow substitutions.
    cat <<__EOF__ >> "${INSTALL_FOLDER_PATH}/bin/get-gcc-rpath"
gcc_rpath="${INSTALL_FOLDER_PATH}/lib64:${INSTALL_FOLDER_PATH}/lib"
__EOF__
# The above marker must start in the first column.

  fi

  # Note: __EOF__ is quoted to prevent substitutions here.
  cat <<'__EOF__' >> "${INSTALL_FOLDER_PATH}/bin/get-gcc-rpath"
gcc_rpath+=":$(compute_gcc_rpath "${cc}")"
gcc_rpath+=":$(compute_glibc_rpath "${cc}")"

echo "${gcc_rpath}"

# -----------------------------------------------------------------------------
__EOF__
# The above marker must start in the first column.

  chmod +x "${INSTALL_FOLDER_PATH}/bin/get-gcc-rpath"

  # ---------------------------------------------------------------------------

  if false
  then

    echo "export NVM_DIR=\"${INSTALL_FOLDER_PATH}/nvm\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
# Add nvm shell functions.
function xbb_activate_nvm()
{
  if [ -s "${NVM_DIR}/nvm.sh" ]
  then
    source "${NVM_DIR}/nvm.sh"  # This loads nvm
  fi
}

__EOF__
# The above marker must start in the first column.

  fi

  if [ "${XBB_LAYER}" != "xbb-bootstrap" ]
  then

    set +e
    local java_home=$(java -XshowSettings:properties -version 2>&1 > /dev/null | grep 'java.home' | sed -e 's/.*= //' | sed -e 's|/jre||')
    set -e

    if [ ! -z "${java_home}" ]
    then
      echo "export JAVA_HOME=\"${java_home}\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    fi

    echo "export ANT_HOME=\"${INSTALL_FOLDER_PATH}/share/ant\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
    echo "export M2_HOME=\"${INSTALL_FOLDER_PATH}/share/maven\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

    echo >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

  fi

}

# -----------------------------------------------------------------------------

function extract()
{
  local archive_name="$1"
  # Must be exactly what results from expanding the archive.
  local folder_name="$2"
  # local patch_file_name="$3"
  local pwd="$(pwd)"

  if [ ! -d "${folder_name}" ]
  then
    (
      xbb_activate

      echo
      echo "Extracting \"${archive_name}\" -> \"${pwd}/${folder_name}\"..."
      if [[ "${archive_name}" == *zip ]]
      then
        unzip "${archive_name}"
      else
        tar xf "${archive_name}"
      fi

      # Docker containers run as root, adjust owner and mode.
      if [ -f "/.dockerenv" ]
      then
        chown -R $(id -u):$(id -g) "${folder_name}"
        chmod -R +w "${folder_name}"
      fi

      if [ $# -gt 2 ]
      then
        if [ ! -z "$3" ]
        then
          local patch_path="$3"
          if [ -f "${patch_path}" ]
          then
            echo "Patching..."
            cd "${folder_name}"
            patch -p0 < "${patch_path}"
          fi
        fi
      fi
    )
  else
    echo "Folder \"${pwd}/${folder_name}\" already present."
  fi
}

function _download_one()
{
  local url="$1"
  local archive_name="$2"
  local exit_code

  echo
  echo "Downloading \"${archive_name}\" from \"${url}\"..."
  rm -f "${CACHE_FOLDER_PATH}/${archive_name}.download"
  mkdir -pv "${CACHE_FOLDER_PATH}"

  set +e
  curl --fail -L -o "${CACHE_FOLDER_PATH}/${archive_name}.download" "${url}"
  exit_code=$?
  set -e

  # return true for process exit code 0.
  return ${exit_code}
}

function download()
{
  local url="$1"
  local archive_name="$2"
  local url_base="https://github.com/xpack-dev-tools/files-cache/raw/master/libs"

  if [ ! -f "${CACHE_FOLDER_PATH}/${archive_name}" ]
  then
    (
      xbb_activate

      for count in 1 2 3 4
      do
        if [ ${count} -eq 4 ]
        then
          local backup_url="${url_base}/$(basename "${url}")"
          if _download_one "${backup_url}" "${archive_name}"
          then
            break
          else
            echo "Several download attempts failed. Quit."
            exit 1
          fi
        fi
        if _download_one "${url}" "${archive_name}"
        then
          break
        fi
      done

      mv "${CACHE_FOLDER_PATH}/${archive_name}.download" "${CACHE_FOLDER_PATH}/${archive_name}"
    )
  else
    echo "File \"${CACHE_FOLDER_PATH}/${archive_name}\" already downloaded."
  fi
}

function download_and_extract()
{
  local url="$1"
  local archive_name="$2"
  # Must be exactly what results from expanding the archive.
  local folder_name="$3"

  download "${url}" "${archive_name}"
  if [ $# -gt 3 ]
  then
    extract "${CACHE_FOLDER_PATH}/${archive_name}" "${folder_name}" "$4"
  else
    extract "${CACHE_FOLDER_PATH}/${archive_name}" "${folder_name}"
  fi
}

# -----------------------------------------------------------------------------

function is_elf()
{
  if [ $# -lt 1 ]
  then
    warning "is_elf: Missing arguments"
    exit 1
  fi

  local bin_path="$1"

  # Symlinks do not match.
  if [ -L "${bin_path}" ]
  then
    return 1
  fi

  if [ -f "${bin_path}" ]
  then
    # Return 0 (true) if found.
    file ${bin_path} | egrep -q "( ELF )|( PE )|( PE32 )|( PE32\+ )|( Mach-O )"
  else
    return 1
  fi
}

function is_static()
{
  if [ $# -lt 1 ]
  then
    warning "is_static: Missing arguments"
    exit 1
  fi
  local bin="$1"

  # Symlinks do not match.
  if [ -L "${bin}" ]
  then
    return 1
  fi

  if [ -f "${bin}" ]
  then
    # Return 0 (true) if found.
    file ${bin} | egrep -q "statically linked"
  else
    return 1
  fi
}

function patch_linux_elf_origin()
{
  if [ $# -lt 1 ]
  then
    echo "patch_linux_elf_origin requires 1 args."
    exit 1
  fi

  local file_path="$1"

  local tmp_path=$(mktemp)
  rm -rf "${tmp_path}"
  cp "${file_path}" "${tmp_path}"
  if file "${tmp_path}" | grep statically
  then
    file "${file_path}"
  else
    # No need for separate lib64, it was linked to lib. (Uh?)
    patchelf --set-rpath "${INSTALL_FOLDER_PATH}/lib" "${tmp_path}"
  fi
  cp "${tmp_path}" "${file_path}"
  rm -rf "${tmp_path}"
}

function append_linux_elf_rpath()
{
  if [ $# -lt 2 ]
  then
    echo "patch_linux_elf_rpath requires 2 args."
    exit 1
  fi

  (
    local file_path="$1"
    local new_rpath_path="$2"

    if file "${file_path}" | grep "dynamically linked" >/dev/null
    then
      local crt_rpath_path="$(patchelf --print-rpath "${file_path}")"
      if [[ "${crt_rpath_path}" == *"${new_rpath_path}"* ]]
      then
        # If new path already part of the existing path.
        echo "${file_path} RPATH ${crt_rpath_path}"
        return
      fi

      if [ -z "${crt_rpath_path}" ]
      then
        patchelf --set-rpath "${new_rpath_path}" "${file_path}"
        echo "${file_path} RPATH - -> ${new_rpath_path}"
      else
        patchelf --set-rpath "${crt_rpath_path}:${new_rpath_path}" "${file_path}"
        echo "${file_path} RPATH ${crt_rpath_path} -> ${crt_rpath_path}:${new_rpath_path}"
      fi
    else
      file "${file_path}"
    fi
  )
}

# -----------------------------------------------------------------------------

function which_patchelf()
{
  (
    xbb_activate

    which patchelf
  )
}

function run_app()
{
  # Does not include the .exe extension.
  local app_path=$1
  shift

  echo
  echo "${app_path} $@"
  "${app_path}" "$@" 2>&1
}

function show_libs()
{
  # Does not include the .exe extension.
  local app_path=$1
  shift

  echo
  echo "$(basename "${app_path}"):"
  if ! is_elf "${app_path}"
  then
    file "${app_path}"
    return
  fi

  if is_static "${app_path}"
  then
    file "${app_path}"
    return
  fi

  (
    if [ "${HOST_UNAME}" == "Linux" ]
    then
      local patchelf="$(which_patchelf)"
      if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
      then
        patchelf="${INSTALL_FOLDER_PATH}/bin/patchelf"
      fi

      local readelf="$(which readelf)"
      local ldd="$(which ldd)"

      echo "${readelf} -d ${app_path} | egrep -i ..."
      "${readelf}" -d "${app_path}" | egrep -i '(SONAME)' || true
      "${readelf}" -d "${app_path}" | egrep -i '(RUNPATH|RPATH)' || true
      "${readelf}" -d "${app_path}" | egrep -i '(NEEDED)' || true
      interpreter=$("${patchelf}" --print-interpreter "${app_path}" 2>/dev/null || true)
      if [ ! -z "${interpreter}" ]
      then
        echo
        echo "${patchelf} --print-interpreter ${app_path}"
        echo "${interpreter}"
      fi
      echo
      echo "${ldd} -v ${app_path}"
      "${ldd}" -v "${app_path}" || true
    elif [ "${HOST_UNAME}" == "Darwin" ]
    then
      echo "otool -L ${app_path}"
      otool -L "${app_path}"
    fi
  )
}

# -----------------------------------------------------------------------------

function strip_static_objects()
{
  echo
  echo "Stripping debug info from static libraries and object files..."
  echo

  if [ "${HOST_UNAME}" == "Linux" ]
  then
    (
      cd "${INSTALL_FOLDER_PATH}"

      xbb_activate
      xbb_activate_installed_bin

      local strip="$(which strip)"
      local ranlib="$(which ranlib)"

      set +e

      # Should we skip mingw libraries?
      # -not -path 'lib/gcc/*-w64-mingw32/*'  \
      find * \
        -type f \
        -name '*.a'\
        -not -path '*mingw*' \
        -print \
        -exec chmod +w {} \; \
        -exec "${strip}" --strip-debug {} \; \
        -exec "${ranlib}" {} \;

      find * \
        -type f \
        -name '*.o' \
        -not -path '*mingw*' \
        -print \
        -exec chmod +w {} \; \
        -exec "${strip}" --strip-debug {} \;

      if [ "${XBB_LAYER}" != "xbb-bootstrap" ]
      then
        find * \
          -type f \
          \( -name '*.a' -o -name '*.o' \) \
          -path '*mingw*' \
          -print \
          -exec chmod +w {} \; \
          -exec "${MINGW_TARGET}-strip" --strip-debug {} \;

      fi

      set -e
    )
  fi
}

function compute_gcc_rpath()
{
  local cc="$1"

  # liblto_plugin.so ?
  local lib_names=( libstdc++.so libgcc_s.so libcc1.so )
  # Local by definition.
  declare -A paths
  for lib_name in ${lib_names[@]}
  do
    local file_path=$(${cc} -print-file-name="${lib_name}")
    if [ "${file_path}" == "${lib_name}" ]
    then
      continue
    fi
    local folder_path=$(dirname $(realpath ${file_path}))
    paths+=( ["${folder_path}"]="${folder_path}" )
  done

  echo "$(IFS=":"; echo "${!paths[*]}")"
}

function compute_glibc_rpath()
{
  local cc="$1"

  # liblto_plugin.so ?
  local lib_names=( libdl.so libpthread.so libnsl.so librt.so libc.so libm.so )
  # Local by definition.
  declare -A paths
  for lib_name in ${lib_names[@]}
  do
    local file_path=$(${cc} -print-file-name="${lib_name}")
    if [ "${file_path}" == "${lib_name}" ]
    then
      continue
    fi
    local folder_path=$(dirname $(realpath ${file_path}))
    paths+=( ["${folder_path}"]="${folder_path}" )
  done

  echo "$(IFS=":"; echo "${!paths[*]}")"
}

function patch_elf_rpath()
{
  (
    echo
    echo "Patching rpath in elf files.."
    echo

    xbb_activate
    # xbb_activate_installed_bin

    set +e
    PATCHELF="$(which patchelf)"
    set -e
    if [ -z "${PATCHELF:-""}" ]
    then
      PATCHELF="$(xbb_activate_installed_bin; which patchelf)"
    fi

    if [ -z "${PATCHELF}" ]
    then
      echo "Missing patchelf, quit."
      exit 1
    fi
    export PATCHELF

    export CHECK_RPATH_LOG="${LOGS_FOLDER_PATH}/check-rpath-log.txt"
    rm -rf "${CHECK_RPATH_LOG}"
    touch "${CHECK_RPATH_LOG}"

    if false
    then
      bash "${helper_folder_path}/patch_elf_rpath.sh" "${INSTALL_FOLDER_PATH}/bin/flex"
      "${INSTALL_FOLDER_PATH}/bin/flex" --version

      # bash "${helper_folder_path}/patch_elf_rpath.sh" "${INSTALL_FOLDER_PATH}/usr/bin/g++-xbb"
      # "${INSTALL_FOLDER_PATH}/usr/bin/g++-xbb" --version

      exit 1
    else
      if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
      then

        # All files.
        find "${INSTALL_FOLDER_PATH}" \
          -type f \
          ! -path '/*/*/include/*' \
          ! -path '/*/*/share/*' \
          ! -path '/*/*/usr/include/*' \
          ! -path '/*/*/usr/share/*' \
          ! -path '/*/*/lib/perl*/*' \
          ! -path '/*/*/lib/python*/*' \
          -exec bash ${helper_folder_path}/patch_elf_rpath.sh {} \;

      else

        folders=("${INSTALL_FOLDER_PATH}/bin")
        if [ -d "${INSTALL_FOLDER_PATH}/libexec" ]
        then
          folders+=("${INSTALL_FOLDER_PATH}/libexec")
        fi
        if [ -d "${INSTALL_FOLDER_PATH}/openssl" ]
        then
          folders+=("${INSTALL_FOLDER_PATH}/openssl")
        fi
        if [ -d "${INSTALL_FOLDER_PATH}/usr/bin" ]
        then
          folders+=("${INSTALL_FOLDER_PATH}/usr/bin")
        fi
        if [ -d "${INSTALL_FOLDER_PATH}/usr/libexec" ]
        then
          folders+=("${INSTALL_FOLDER_PATH}/usr/libexec")
        fi
        if [ -d "${INSTALL_FOLDER_PATH}/usr/${BUILD}" ]
        then
          folders+=("${INSTALL_FOLDER_PATH}/usr/${BUILD}")
        fi

        find ${folders[@]} \
          -type f \
          -exec bash ${helper_folder_path}/patch_elf_rpath.sh {} \;

        if [ -d "${INSTALL_FOLDER_PATH}/usr" ]
        then
          find "${INSTALL_FOLDER_PATH}/usr"  \
            -type f \
            -exec bash ${helper_folder_path}/patch_elf_rpath.sh {} \;
        fi

        folders=("${INSTALL_FOLDER_PATH}/lib")
        if [ -d "${INSTALL_FOLDER_PATH}/usr" ]
        then
          folders+=("${INSTALL_FOLDER_PATH}/usr")
        fi

        find ${folders[@]}  \
          -type f \
          -name '*.so*' \
          -exec bash ${helper_folder_path}/patch_elf_rpath.sh {} \;
        fi

    fi

    number_of_log_lines=$(cat "${CHECK_RPATH_LOG}" | wc -l)

    if [ ${number_of_log_lines} -gt 0 ]
    then
      echo
      echo "Check rpath failed:"
      cat "${CHECK_RPATH_LOG}"
      if [ "${XBB_LAYER}" != "xbb-test" ]
      then
        exit 1
      fi
    else
      echo
      echo "No rpath issues detected."
    fi

  ) 2>&1 | tee "${LOGS_FOLDER_PATH}/check-rpath-output.txt"
}

function patch_file_libtool_rpath()
{
  local file_path="$1"

  sed -i.bak \
      -e 's|finalize_rpath=".*"|finalize_rpath=""|' \
      -e 's|finalize_rpath=$rpath|finalize_rpath=""|' \
      -e 's|finalize_rpath+=" $libdir"|finalize_rpath=""|' \
      -e 's|func_append finalize_rpath " $libdir"||' \
      -e 's|dep_rpath+=" $flag"||' \
      -e 's|func_append dep_rpath " $flag"||' \
      -e 's|compile_rpath=$rpath|compile_rpath=""|' \
      -e 's|func_append compile_rpath " $absdir"||' \
      ${file_path}
}

export -f patch_file_libtool_rpath

# Workaround to avoid libtool issuing -rpath to the linker, since
# this prevents it using the global LD_RUN_PATH.
function patch_all_libtool_rpath()
{
  for file in $(find . -name libtool)
  do
    echo ${file}
    patch_file_libtool_rpath ${file}
  done
}

# -----------------------------------------------------------------------------

function do_cleaunup()
{
  # In bootstrap preserve download, it'll be used by xbb and removed later.
  if [ "${XBB_LAYER}" != "xbb-bootstrap" ]
  then
    rm -rf "${CACHE_FOLDER_PATH}"
  fi

  # All other can go.
  rm -rf "${XBB_WORK_FOLDER_PATH}"
}

# -----------------------------------------------------------------------------

function run_verbose()
{
  # Does not include the .exe extension.
  local app_path=$1
  shift

  echo
  echo "[${app_path} $@]"
  "${app_path}" "$@" 2>&1
}

# =============================================================================
