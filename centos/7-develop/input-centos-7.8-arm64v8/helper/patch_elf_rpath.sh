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

function is_linux()
{
  if [ "$(uname)" == "Linux" ]
  then
    return 0
  fi

  return 1
}

function is_darwin()
{
  if [ "$(uname)" == "Darwin" ]
  then
    return 0
  fi

  return 1
}

function is_elf()
{
  if [ $# -lt 1 ]
  then
    warning "is_elf: Missing arguments"
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
    file ${bin} | egrep -q "( ELF )|( PE )|( PE32 )|( PE32\+ )|( Mach-O )"
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

function is_dynamic()
{
  if [ $# -lt 1 ]
  then
    warning "is_dynamic: Missing arguments"
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
    file ${bin} | egrep -q "dynamically linked"
  else
    return 1
  fi
}

function is_shared()
{
  if [ $# -lt 1 ]
  then
    warning "is_shared: Missing arguments"
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
    file ${bin} | egrep -q "shared"
  else
    return 1
  fi
}

function is_executable()
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
    file ${bin} | egrep -q "executable"
  else
    return 1
  fi
}

function is_linux_sys_so()
{
  local lib_name="$1"

  # Do not add these two, they are present if the toolchain is installed,
  # but this is not guaranteed, so better copy them from the xbb toolchain.
  # libstdc++.so.6
  # libgcc_s.so.1

  # Shared libraries that are expected to be present on any Linux.
  # Note the X11 libraries.
if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
then
  local sys_lib_names=(\
    librt.so.1 \
    libm.so.6 \
    libc.so.6 \
    libutil.so.1 \
    libpthread.so.0 \
    libgomp.so.1 \
    libdl.so.2 \
    ld-linux.so.2 \
    ld-linux.so.3 \
    ld-linux-x86-64.so.2 \
    ld-linux-armhf.so.3 \
    ld-linux-arm64.so.1 \
    ld-linux-aarch64.so.1 \
    libX11.so.6 \
    libXau.so.6 \
    libxcb.so.1 \
    libz.so.1 \
    \
    libgcc_s.so.1 \
    libstdc++.so.6 \
    libnsl.so.1 \
  )
else
  if [ ! -f "${BUILD_FOLDER_PATH}/.activate_installed_bin" ]
  then
    # For the moment they are the same, but a separate glibc may
    # have a different list.
    local sys_lib_names=(\
      "-"
    )
    local sys_lib_names_=(\
      libdl.so.2 \
      libc.so.6 \
      libm.so.6 \
      libpthread.so.0 \
      librt.so.1 \
      libgcc_s.so.1 \
      libstdc++.so.6 \
      libnsl.so.1 \
      libgomp.so.1 \
      libutil.so.1 \
      ld-linux.so.2 \
      ld-linux.so.3 \
      ld-linux-x86-64.so.2 \
      ld-linux-armhf.so.3 \
      ld-linux-arm64.so.1 \
      ld-linux-aarch64.so.1 \
    )
  else
    local sys_lib_names=(\
      "-"
    )
  fi
fi

  local sys_lib_name
  for sys_lib_name in "${sys_lib_names[@]}"
  do
    if [ "${lib_name}" == "${sys_lib_name}" ]
    then
      return 0 # True
    fi
  done
  return 1 # False
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

# -----------------------------------------------------------------------------

function main()
{
  if [ $# -lt 1 ]
  then
    echo "Usage: patch_elf_rpath <file>"
    exit 1
  fi

  file_path="$1"

  if [ -L "${file_path}" ]
  then
    exit 0
  fi

# echo "${file_path}"

  if [[ "${file_path}" == *\.dll ]]
  then
    exit 0
  fi

  if ! is_elf "${file_path}"
  then
    exit 0
  fi

  if is_darwin
  then
    strip -S "${file_path}"

    # TODO add possible other checks.

    echo "  $(basename ${file_path}) ${file_path}"
    exit 0
  fi

  # ---------------------------------------------------------------------------

  if is_static "${file_path}"
  then
    exit 0
  fi

  if ! is_dynamic "${file_path}"
  then
    exit 0
  fi

  # echo "${file_path} passed"
  # exit 0

  # ---------------------------------------------------------------------------

  patchelf="${PATCHELF:-$(which patchelf)}"
  if [ -z "${patchelf:-""}" ]
  then
    echo "Missing patchelf, quit."
    exit 1
  fi

  # ---------------------------------------------------------------------------

  # http://man7.org/linux/man-pages/man8/ld.so.8.html
  # RPATH if not RUNPATH
  # LD_LIBRARY_PATH
  # RUNPATH
  # /etc/ld.so.cache
  # /lib:/usr/lib or /lib64:/usr/lib64, if not -z nodeflib

  # https://manpages.debian.org/unstable/patchelf/patchelf.1.en.html

  # ---------------------------------------------------------------------------
  # Strip.

  # Anecdotal evidences show that strip and patchelf do not work together.

  if is_shared "${file_path}"
  then
    strip --strip-debug "${file_path}"
  elif is_executable "${file_path}"
  then
    # warning: allocated section `.dynsym' not in segment
    strip --strip-unneeded "${file_path}"
    # Plus that apparently only --strip-debug is patchelf friendly.
    # strip --strip-debug "${file_path}"
  else
    echo "  ? $(file ${file_path})"
    exit 1
  fi

  # ---------------------------------------------------------------------------
  # Be sure there are shared dependencies.

  shlibs="$(readelf -d "${file_path}" | grep '(NEEDED)' | sed -e 's|.*\[\(.*\)\].*|\1|')"
  if [ -z "${shlibs:-""}" ]
  then
    # Has no dependencies.
    echo "  $(basename ${file_path}) -"
    exit 0
  fi

  # ---------------------------------------------------------------------------
  # Get the current rpath/runpath.

  set +e
  runpath="$(readelf -d "${file_path}" | egrep '(RUNPATH)' | sed -e 's|.*\[\(.*\)\].*|\1|')"
  crt_rpath="$(readelf -d "${file_path}" | egrep '(RPATH)' | sed -e 's|.*\[\(.*\)\].*|\1|')"
  set -e
  # crt_rpath="$(${patchelf} --print-rpath ${file_path})"

  if [ -z "${crt_rpath}" ]
  then
    folder_paths=()
  else
    save_ifs=${IFS}
    IFS=: folder_paths=( ${crt_rpath} )
    IFS=${save_ifs}
  fi

  declare -A paths

  if [ ${#folder_paths[@]} -gt 0 ]
  then
    for path in ${folder_paths[@]}
    do
      # echo ${path}
      local abs_path
      set +e
      if [[ "${path}" == \$ORIGIN* ]]
      then
        abs_path=$(realpath "$(echo "${path}" | sed -e "s|\$ORIGIN|$(dirname ${file_path})|" 2>/dev/null)")
      else
        abs_path="$(realpath "${path}" 2>/dev/null)"
      fi
      set -e
      if [ ! -z "${abs_path}" ]
      then
        paths+=( ["${abs_path}"]="${abs_path}" )
      fi
    done
  fi

  save_ifs=${IFS}
  IFS=: ld_run_paths=( ${XBB_LIBRARY_PATH} )
  IFS=${save_ifs}

  for path in ${ld_run_paths[@]}
  do
    # echo ${path}
    paths+=( ["${path}"]="${path}" )
  done

  new_ld_run_paths="$(IFS=":"; echo "${!paths[*]}")"

  # echo "${new_ld_run_paths}"

  # ---------------------------------------------------------------------------

  show_details=""
  errors=()

  if [ -n "${runpath}" ]
  then
    errors+=("    has RUNPATH")
    show_details="y"
  fi

  shlibs_names=( $shlibs )
  found_names=()
  found_in_system_names=()

  crt_rpath="$(${patchelf} --print-rpath ${file_path})"
  interpreter="$(${patchelf} --print-interpreter "${file_path}" 2>/dev/null)"

  save_ifs=${IFS}
  IFS=: folder_paths=( ${crt_rpath} )
  IFS=${save_ifs}

  # echo ${shlibs_names[@]}
  # echo ${folder_paths[@]}

  for lib_name in ${shlibs_names[@]}
  do
    found=""

    if [ ${#folder_paths[@]} -gt 0 ]
    then
      for folder_path in ${folder_paths[@]}
      do
        if [ -f "${folder_path}/${lib_name}" ]
        then
          found="y"
          found_names+=( "${lib_name}" )
          break
        fi
      done
    fi

    if [ "${found}" != "y" ]
    then
      errors+=("    ${lib_name} not found")
      show_details="y"
    fi

  done

  set +u
  msg="[$(IFS=" "; echo "${found_names[*]}")]"

  msg+=" RPATH=$(IFS=":"; echo "${folder_paths[*]}")"

  if [ -n "${interpreter}" ]
  then
    : # msg+=" LD=${interpreter}"
  fi
  echo "  $(basename ${file_path}) ${msg}"
  for err in ${errors[@]}
  do
    echo "${err}"
  done
  set -u

  if [ "${show_details}" == "y" ]
  then
    local ldd="$(which ldd)"

    run_app "${patchelf}" --print-interpreter "${file_path}" || true
    run_app "${patchelf}" --print-rpath "${file_path}" || true
    run_app "${ldd}" -v "${file_path}"
    echo

    echo "  ${file_path} ${msg}" >> "${CHECK_RPATH_LOG}"
    for err in ${errors[@]}
    do
      echo "${err}" >> "${CHECK_RPATH_LOG}"
    done

  fi
}

# -----------------------------------------------------------------------------

main "$@"

exit 0
