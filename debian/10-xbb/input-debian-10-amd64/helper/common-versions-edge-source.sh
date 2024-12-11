# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2020 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

function build_versioned_components()
{
  if [[ "${XBB_VERSION}" =~ 3\.[4] ]]
  then

    # =========================================================================

    # -------------------------------------------------------------------------

    # The main characteristic of XBB is the compiler version.

    # XBB_LLVM_VERSION="11.1.0"

    # Fortunatelly GCC 11.[12] were updated and work on Apple hardware.
    # "10.3.0" fails with:
    # error: unknown conversion type character ‘l’ in format [-Werror=format=]
    XBB_GCC_VERSION="11.2.0" # "9.4.0" # !"10.3.0" # !"11.1.0" # "9.3.0" # "9.2.0" # "8.3.0" # "7.4.0"

    if is_linux
    then
      XBB_BINUTILS_VERSION="2.36.1" # "2.34" # "2.33.1"

      # 8.x fails to compile the libstdc++ new file system classes.
      # must be the same as native, otherwise shared libraries will mess versions.
      XBB_MINGW_VERSION="9.0.0" # !"8.0.2"

      # 11.1.0 fails on Linux with
      # /libgcc/libgcov.h:49:10: fatal error: sys/mman.h: No such file or directory
      # This can be fixed with a sed patch.
      XBB_MINGW_GCC_VERSION="${XBB_GCC_VERSION}" # "9.2.0" # "8.3.0" # "7.4.0"
      XBB_MINGW_BINUTILS_VERSION="${XBB_BINUTILS_VERSION}" # "2.34" # "2.33.1"
    fi

    XBB_GDB_VERSION="11.1" # "10.2"

    libtool_version="2.4.6"

    XBB_LLVM_BRANDING="xPack Build Box ${HOST_MACHINE}"
    XBB_BINUTILS_BRANDING="xPack Build Box ${HOST_MACHINE} binutils"
    XBB_GDB_BRANDING="xPack Build Box ${HOST_MACHINE} GDB"
    XBB_GCC_BRANDING="xPack Build Box ${HOST_MACHINE} GCC"
    XBB_GLIBC_BRANDING="xPack Build Box ${HOST_MACHINE} GNU libc"

    XBB_MINGW_BINUTILS_BRANDING="xPack Build Box ${HOST_MACHINE} Mingw-w64 binutils"
    XBB_MINGW_GCC_BRANDING="xPack Build Box ${HOST_MACHINE} Mingw-w64 GCC"

    # -------------------------------------------------------------------------

    if is_linux
    then
      # Uses CC to compute the library path.
      prepare_library_path

      LD_RUN_PATH="${XBB_LIBRARY_PATH}"

      echo "LD_RUN_PATH=${LD_RUN_PATH}"
      export LD_RUN_PATH
    fi

    # For stable builds, compile everything with the bootstrap compiler,
    # not the newly compiled GCC.

    if is_darwin
    then
      build_realpath "1.0.0"
    fi

    # -------------------------------------------------------------------------
    # Native compiler.

    # New zlib, used in most of the tools.
    # depends=('glibc')
    build_zlib "1.2.11"

    # Libraries, required by gcc.
    # depends=('gcc-libs' 'sh')
    build_gmp "6.2.1" # "6.2.0" # "6.1.2"
    # depends=('gmp>=5.0')
    build_mpfr "4.1.0" # "4.0.2" # "3.1.6"
    # depends=('mpfr')
    build_mpc "1.2.1" # "1.1.0" # "1.0.3"
    # depends=('gmp')
    build_isl "0.24" # "0.22" # "0.21"

    # -------------------------------------------------------------------------

    # When all libraries are available, build the compiler(s).

    if is_linux
    then

      # It ignores the LD_RUN_PATH, it sets /opt/xbb/lib
      # Requires gmp, mpfr, mpc, isl.
      # PATCH!
      build_native_binutils "${XBB_BINUTILS_VERSION}"

      # makedepends=('binutils>=2.26' 'libmpc' 'gcc-ada' 'doxygen' 'git')
      build_native_gcc "${XBB_GCC_VERSION}"

      (
        prepare_gcc_env "" "-xbb"

        # Requires new gcc.
        # depends=('sh' 'tar' 'glibc')
        build_libtool "${libtool_version}" "-2"
      )

      build_native_gdb "${XBB_GDB_VERSION}"

      # mingw compiler

      # Build mingw-w64 binutils and gcc only on Intel Linux.
      if is_intel
      then
        # depends=('zlib')
        build_mingw_binutils "${XBB_MINGW_BINUTILS_VERSION}"

        # depends=('zlib' 'libmpc' 'mingw-w64-crt' 'mingw-w64-binutils' 'mingw-w64-winpthreads' 'mingw-w64-headers')
        # build_mingw_all "${XBB_MINGW_VERSION}" "${XBB_MINGW_GCC_VERSION}" # "5.0.4" "7.4.0"

        prepare_mingw_env "${XBB_MINGW_VERSION}"

        (
          cd "${SOURCES_FOLDER_PATH}"

          download_mingw
        )

        # Deploy the headers, they are needed by the compiler.
        build_mingw_headers

        # Build only the compiler, without libraries.
        build_mingw_gcc_first "${XBB_MINGW_GCC_VERSION}"

        # Build some native tools.
        # build_mingw_libmangle
        # build_mingw_gendef
        build_mingw_widl # Refers to mingw headers.

        (
          # xbb_activate_gcc_bootstrap_bins

          (
            # Fails if CC is defined to a native compiler.
            prepare_gcc_env "${MINGW_TARGET}-"

            build_mingw_crt
            build_mingw_winpthreads
          )

          # With the run-time available, build the C/C++ libraries and the rest.
          build_mingw_gcc_final
        )

      fi

    elif is_darwin
    then

      # By all means DO NOT build binutils on macOS, since this will
      # override Apple specific tools (ar, strip, etc) and break the
      # build in multiple ways.

      # makedepends=('binutils>=2.26' 'libmpc' 'gcc-ada' 'doxygen' 'git')
      build_native_gcc "${XBB_GCC_VERSION}" "-edge"

    else
      echo "Unsupported platform."
      exit 1
    fi

    # -------------------------------------------------------------------------

    # At this point we're mostly done, there is only some polishing to do.

    strip_static_objects

    if is_linux
    then
      patch_elf_rpath
    fi

    run_tests

    # =========================================================================

  else
    echo
    echo "Version ${XBB_VERSION} not yet supported."
  fi
}

# -----------------------------------------------------------------------------
