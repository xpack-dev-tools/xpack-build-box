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
  # DOWNLOAD_FOLDER_PATH="${HOME}/Library/Caches/XBB"
  DOWNLOAD_FOLDER_PATH="$(dirname "${WORK_FOLDER_PATH}")/cache"

  BUILD_FOLDER_PATH="${WORK_FOLDER_PATH}/build"
  LIBS_BUILD_FOLDER_PATH="${WORK_FOLDER_PATH}/build/libs"
  SOURCES_FOLDER_PATH="${WORK_FOLDER_PATH}/sources"
  STAMPS_FOLDER_PATH="${WORK_FOLDER_PATH}/stamps"
  LOGS_FOLDER_PATH="${WORK_FOLDER_PATH}/logs"

  INSTALL_FOLDER_PATH="${XBB_FOLDER}"

  # ---------------------------------------------------------------------------

  macos_version=$(defaults read loginwindow SystemVersionStampAsString)
  xclt_version=$(xcode-select --version | sed -e 's/xcode-select version \([0-9]*\)\./\1/')

  # ---------------------------------------------------------------------------

  mkdir -p "${INSTALL_FOLDER_PATH}"

  mkdir -p "${DOWNLOAD_FOLDER_PATH}"
  mkdir -p "${BUILD_FOLDER_PATH}"
  mkdir -p "${LIBS_BUILD_FOLDER_PATH}"
  mkdir -p "${SOURCES_FOLDER_PATH}"
  mkdir -p "${STAMPS_FOLDER_PATH}"
  mkdir -p "${LOGS_FOLDER_PATH}"

  mkdir -p "${INSTALL_FOLDER_PATH}/bin"
  mkdir -p "${INSTALL_FOLDER_PATH}/include"
  mkdir -p "${INSTALL_FOLDER_PATH}/lib"

  # ---------------------------------------------------------------------------

  JOBS=${JOBS:-""}

  XBB_CPPFLAGS=""

  XBB_CFLAGS="-pipe"
  XBB_CXXFLAGS="-pipe"

  XBB_LDFLAGS=""
  XBB_LDFLAGS_LIB="${XBB_LDFLAGS}"
  XBB_LDFLAGS_APP="${XBB_LDFLAGS}"
  XBB_LDFLAGS_APP_STATIC="${XBB_LDFLAGS_APP}"

  # ---------------------------------------------------------------------------

  install -m 755 -c "$(dirname "${script_folder_path}")/helper/pkg-config-verbose" "${INSTALL_FOLDER_PATH}/bin/pkg-config-verbose"

  PKG_CONFIG="${INSTALL_FOLDER_PATH}/bin/pkg-config-verbose"

  echo "${XBB_VERSION}" >  "${INSTALL_FOLDER_PATH}/VERSION"

  # ---------------------------------------------------------------------------

  PATH=${PATH:-""}

  PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-":"}

  # Prevent pkg-config to search the system folders (configured in the
  # pkg-config at build time).
  PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-":"}

  # ---------------------------------------------------------------------------

  export XBB_CPPFLAGS
  export XBB_CFLAGS
  export XBB_CXXFLAGS
  export XBB_LDFLAGS
  export XBB_LDFLAGS_LIB
  export XBB_LDFLAGS_APP
  export XBB_LDFLAGS_APP_STATIC

  export PATH
  export PKG_CONFIG_PATH
  export PKG_CONFIG_LIBDIR
  export PKG_CONFIG

  export CC
  export CXX

  export SHELL="/bin/bash"
  export CONFIG_SHELL="/bin/bash"
}

function create_xbb_source()
{
  echo
  echo "Creating ${INSTALL_FOLDER_PATH}/xbb-source.sh..."
  cat <<'__EOF__' > "${INSTALL_FOLDER_PATH}/xbb-source.sh"
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

export TEXLIVE_FOLDER="${HOME}/opt/texlive"
__EOF__
# The above marker must start in the first column.

  if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
  then
    echo "export XBB_BOOTSTRAP_FOLDER=\"\${HOME}/opt/$(basename "${XBB_FOLDER}")\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
  else
    echo "export XBB_FOLDER=\"\${HOME}/opt/$(basename "${XBB_FOLDER}")\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"
  fi

  echo "export XBB_VERSION=\"${XBB_VERSION}\"" >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

  if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
  then

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Adjust PATH to prefer the XBB bootstrap binaries.
function xbb_activate_bootstrap()
{
  PATH="${XBB_BOOTSTRAP_FOLDER}/bin:${PATH}"

  export PATH
}
__EOF__
# The above marker must start in the first column.

  else

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Adjust PATH to prefer the XBB binaries.
function xbb_activate()
{
  PATH="${XBB_FOLDER}/bin:${PATH}"

  export PATH
}
__EOF__
# The above marker must start in the first column.

  fi

  # Note: __EOF__ is quoted to prevent substitutions here.
  cat <<'__EOF__' >> "${INSTALL_FOLDER_PATH}/xbb-source.sh"

# Add TeX to PATH.
function xbb_activate_tex()
{
  PATH="${TEXLIVE_FOLDER}/bin/$(uname -m)-darwin:${PATH}"

  export PATH
}

__EOF__
# The above marker must start in the first column.
}

# -----------------------------------------------------------------------------

# For the XBB builds, add the freshly built binaries.
function xbb_activate_installed_bin()
{
  # Add the XBB bin to the PATH.
  PATH="${INSTALL_FOLDER_PATH}/bin:${PATH}"

  export PATH
}

# For the XBB builds, add the freshly built headrs and libraries.
function xbb_activate_installed_dev()
{
  # Add XBB include in front of XBB_CPPFLAGS.
  XBB_CPPFLAGS="-I${INSTALL_FOLDER_PATH}/include ${XBB_CPPFLAGS}"

  # Add XBB lib in front of XBB_LDFLAGS.
  XBB_LDFLAGS="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS}"
  XBB_LDFLAGS_LIB="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_LIB}"
  XBB_LDFLAGS_APP="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_APP}"
  XBB_LDFLAGS_APP_STATIC="-L${INSTALL_FOLDER_PATH}/lib ${XBB_LDFLAGS_APP_STATIC}"

  # Add XBB lib in front of PKG_CONFIG_PATH.
  PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/lib/pkgconfig:${PKG_CONFIG_PATH}"

  export XBB_CPPFLAGS

  export XBB_LDFLAGS
  export XBB_LDFLAGS_LIB
  export XBB_LDFLAGS_APP
  export XBB_LDFLAGS_APP_STATIC

  export PKG_CONFIG_PATH
}

# -----------------------------------------------------------------------------

function extract()
{
  local archive_name="$1"
  local folder_name="$2"
  # local patch_file_name="$3"
  local pwd="$(pwd)"

  if [ ! -d "${folder_name}" ]
  then
    (
      xbb_activate

      echo
      echo "Extracting \"${archive_name}\"..."
      if [[ "${archive_name}" == *zip ]]
      then
        unzip "${archive_name}"
      else
        tar xf "${archive_name}"
      fi

      if [ $# -gt 2 ]
      then
        if [ ! -z "$3" ]
        then
          local patch_file_name="$3"
          local patch_path="${script_folder_path}/patches/${patch_file_name}"
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

function download()
{
  local url="$1"
  local archive_name="$2"

  if [ ! -f "${DOWNLOAD_FOLDER_PATH}/${archive_name}" ]
  then
    (
      xbb_activate

      echo
      echo "Downloading \"${archive_name}\" from \"${url}\"..."
      rm -f "${DOWNLOAD_FOLDER_PATH}/${archive_name}.download"
      mkdir -p "${DOWNLOAD_FOLDER_PATH}"
      curl --fail -L -o "${DOWNLOAD_FOLDER_PATH}/${archive_name}.download" "${url}"
      mv "${DOWNLOAD_FOLDER_PATH}/${archive_name}.download" "${DOWNLOAD_FOLDER_PATH}/${archive_name}"
    )
  else
    echo "File \"${DOWNLOAD_FOLDER_PATH}/${archive_name}\" already downloaded."
  fi
}

function download_and_extract()
{
  local url="$1"
  local archive_name="$2"
  local folder_name="$3"

  download "${url}" "${archive_name}"
  if [ $# -gt 3 ]
  then
    extract "${DOWNLOAD_FOLDER_PATH}/${archive_name}" "${folder_name}" "$4"
  else
    extract "${DOWNLOAD_FOLDER_PATH}/${archive_name}" "${folder_name}"
  fi
}

function eval_bool()
{
  local VAL="$1"
  [[ "${VAL}" = 1 || "${VAL}" = true || "${VAL}" = yes || "${VAL}" = y ]]
}


function check_binaries()
{
  local folder_path
  if [ $# -ge 1 ]
  then
    folder_path="$1"
  else
    folder_path="${INSTALL_FOLDER_PATH}"
  fi

  local binaries

  binaries=$(find "${folder_path}" -name \* -perm +111 -and ! -type d)
  for bin in ${binaries}
  do
    if is_elf "${bin}"
    then
      check_binary "${bin}"
    fi
  done
}

function is_elf()
{
  if [ $# -lt 1 ]
  then
    warning "is_elf: Missing arguments"
    exit 1
  fi
  local bin="$1"

  if [ -x "${bin}" ]
  then
    # Return 0 (true) if found.
    file ${bin} | egrep -q " Mach-O 64-bit"
  else
    return 1
  fi
}

function check_binary()
{
  local file_path="$1"

  if [ ! -x "${file_path}" ]
  then
    return 0
  fi

  if file --mime "${file_path}" | grep -q text
  then
    return 0
  fi

  echo
  otool -L "$1"
}

# -----------------------------------------------------------------------------
