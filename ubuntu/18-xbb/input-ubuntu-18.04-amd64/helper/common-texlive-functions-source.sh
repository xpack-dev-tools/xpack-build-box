# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2020 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# Common functions used for building the XBB environments.

function set_tl_edition_folder()
{
  TL_EDITION_YEAR=${TL_EDITION_YEAR:-"2018"}
  if [ "${TL_EDITION_YEAR}" == "2018" ]
  then
    TL_EDITION_FOLDER_NAME="install-tl-20180414"
  elif [ "${TL_EDITION_YEAR}" == "2019" ]
  then
    TL_EDITION_FOLDER_NAME="install-tl-20190410"
  elif [ "${TL_EDITION_YEAR}" == "2020" ]
  then
    TL_EDITION_FOLDER_NAME="install-tl-20200406"
  elif [ "${TL_EDITION_YEAR}" == "2021" ]
  then
    TL_EDITION_FOLDER_NAME="install-tl-20210324"
  else
    echo "Unsupported year ${TL_EDITION_YEAR}"
    exit 1
  fi
}

function do_texlive()
{
  local tl_edition_year="$1"
  local tl_edition_folder_name="$2"
  local tl_scheme="$3"

  local tl_archive_name="install-tl-unx.tar.gz"
  local tl_cached_archive_name="install-tl-unx-${tl_edition_year}.tar.gz"

  TL_FOLDER_PATH="${WORK_FOLDER_PATH}/${tl_edition_folder_name}"

  # tl_url="http://mirror.ctan.org/"
  # tl_repo_url="${tl_url}"/systems/texlive/tlnet
  # tl_archive_url="${tl_url}"/systems/texlive/tlnet/${tl_archive_name}

  # tl_url="ftp://tug.org/historic"
  # local tl_url="ftp://ftp.math.utah.edu/pub/tex/historic"
  local tl_url="https://ftp.tu-chemnitz.de/pub/tug/historic"
  local tl_repo_url="${tl_url}/systems/texlive/${tl_edition_year}/tlnet-final"
  local tl_archive_url="${tl_url}/systems/texlive/${tl_edition_year}/${tl_archive_name}"

  # ---------------------------------------------------------------------------

  mkdir -pv "${WORK_FOLDER_PATH}"
  cd "${WORK_FOLDER_PATH}"

  # Download the install tools.
  download_and_extract "${tl_archive_url}" "${tl_cached_archive_name}" "${tl_edition_folder_name}"

  # ---------------------------------------------------------------------------

  if [ ! -f "/.dockerenv" ]
  then
    if [ -d "${INSTALL_FOLDER_PATH}" ]
    then
      rm -rf "${INSTALL_FOLDER_PATH}.bak"
      echo "Backing-up previous install..."
      mv "${INSTALL_FOLDER_PATH}" "${INSTALL_FOLDER_PATH}.bak"
    fi
  fi

  local tl_work_folder_path="${WORK_FOLDER_PATH}/${tl_edition_folder_name}"

  mkdir -pv "${INSTALL_FOLDER_PATH}"

  # ---------------------------------------------------------------------------

  cd "${tl_work_folder_path}"

  # Create the texlive.profile used to automate the install.
  # These definitions are specific to TeX Live 2016/2018.
  mkdir -pv "${HOME}/tmp"
  local tmp_profile="$(mktemp "${tl_work_folder_path}/texlive-profile-${tl_edition_year}-XXXXXX")"

  echo
  echo "Profile file '${tmp_profile}'"

  # Note: __EOF__ is not quoted to allow local substitutions.
  cat <<__EOF__ >> "${tmp_profile}"
# texlive.profile
TEXDIR ${INSTALL_FOLDER_PATH}
TEXMFCONFIG ~/.texlive/texmf-config
TEXMFHOME  ~/texmf
TEXMFLOCAL ${INSTALL_FOLDER_PATH}/texmf-local
TEXMFSYSCONFIG ${INSTALL_FOLDER_PATH}/texmf-config
TEXMFSYSVAR ${INSTALL_FOLDER_PATH}/texmf-var
TEXMFVAR  ~/.texlive/texmf-var

option_doc 0
option_src 0

__EOF__

  # ---------------------------------------------------------------------------

  # https://www.tug.org/texlive/doc/install-tl.html

  (
    # Adjust to TexLive conventions.
    # Recent versions for macOS use `universal-darwin`.
    tl_machine="${HOST_MACHINE}"
    if [  "${HOST_MACHINE}" == "i386" -o "${HOST_MACHINE}" == "i686" ]
    then
       tl_machine="i386"
    elif [ "${HOST_MACHINE}" == "armv8l" -o "${HOST_MACHINE}" == "armv7l" ]
    then
       tl_machine="armhf"
    fi
    tl_uname="${HOST_LC_UNAME}"

    # Schemes: basic (~100 packs), medium (~1000 packs), full (~3400)

    # The distribution for current year does not have `texlive.tlpdb`,
    # and using `-repository` fails, thus it must be checked before.
    local tl_pdb_url="${tl_repo_url}/tlpkg/texlive.tlpdb"
    set +e
    curl --silent --fail --location --insecure -o "/tmp/texlive.tlpdb" "${tl_pdb_url}"
    exit_code=$?
    set -e

    echo
    echo "Running install-tl..."
    if [ ${exit_code} -eq 0 ]
    then
      time run_verbose "${TL_FOLDER_PATH}/install-tl" \
        -repository "${tl_repo_url}" \
        -no-gui \
        -lang en \
        -profile "${tmp_profile}" \
        -scheme "${tl_scheme}"
    else
      time run_verbose "${TL_FOLDER_PATH}/install-tl" \
        -no-gui \
        -lang en \
        -profile "${tmp_profile}" \
        -scheme "${tl_scheme}"
    fi

    ls -l "${INSTALL_FOLDER_PATH}/bin/"
    if [ -d "${INSTALL_FOLDER_PATH}/bin/universal-darwin" ]
    then
      PATH="${INSTALL_FOLDER_PATH}/bin/universal-darwin:${PATH}"
    elif [ -d "${INSTALL_FOLDER_PATH}/bin/x86_64-darwinlegacy" ]
    then
      PATH="${INSTALL_FOLDER_PATH}/bin/x86_64-darwinlegacy:${PATH}"
    elif [ -d "${INSTALL_FOLDER_PATH}/bin/${tl_machine}-${tl_uname}" ]
    then
      PATH="${INSTALL_FOLDER_PATH}/bin/${tl_machine}-${tl_uname}:${PATH}"
    else
      echo "Cannot configure PATH. Quit."
      exit 1
    fi

    echo "PATH=${PATH}"
    export PATH

    run_verbose tlmgr install collection-fontsrecommended

    # Keep no backups (not required, simply makes cache bigger).
    run_verbose tlmgr option -- autobackup 0

    if [ -f "${INSTALL_FOLDER_PATH}/install-tl.log" ]
    then
      run_verbose cp -v "${INSTALL_FOLDER_PATH}/install-tl.log" "${tl_work_folder_path}"
    fi
  )
}

# =============================================================================
