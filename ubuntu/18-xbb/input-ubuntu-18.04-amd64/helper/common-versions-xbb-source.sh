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
  if [[ "${XBB_VERSION}" =~ 3\.5 ]]
  then

    # =========================================================================

    # Problematic tests (WARN-TEST)
    # - nettle
    # - gnutls (long)
    # - libxcrypt on darwin
    # - tar
    # - coreutils
    # - m4 on darwin
    # - gawk (long)
    # - sed
    # - automake
    # - gettext
    # - bison (long)
    # - make (long)
    # - wget
    # - texinfo (darwin)
    # - tcl (long)
    # - guile (!)
    # - re2c (darwin)
    # - glibc
    # - guile (1 test disabled)
    # - autogen (1 test disabled)

    # -------------------------------------------------------------------------

    # The main characteristic of XBB is the compiler version.

    # XBB_LLVM_VERSION="11.1.0"

    # Fortunatelly GCC 11.[12] were updated and work on Apple hardware.
    # "10.3.0" fails with:
    # error: unknown conversion type character ‘l’ in format [-Werror=format=]
    XBB_GCC_VERSION="11.2.0" # "9.4.0" # !"10.3.0" # !"11.1.0" # "9.3.0" # "9.2.0" # "8.3.0" # "7.4.0"

    if is_linux
    then
      # Patch!
      XBB_BINUTILS_VERSION="2.37" # "2.36.1" # "2.34" # "2.33.1"

      # 8.x fails to compile the libstdc++ new file system classes.
      # must be the same as native, otherwise shared libraries will mess versions.
      XBB_MINGW_VERSION="9.0.0" # !"8.0.2"

      # 11.1.0 fails on Linux with
      # /libgcc/libgcov.h:49:10: fatal error: sys/mman.h: No such file or directory
      # This can be fixed with a sed patch.
      XBB_MINGW_GCC_VERSION="${XBB_GCC_VERSION}" # "9.2.0" # "8.3.0" # "7.4.0"
      XBB_MINGW_BINUTILS_VERSION="${XBB_BINUTILS_VERSION}" # "2.34" # "2.33.1"

      # Hack to avoid libz.1.so not found in binutils linker.
      export ACCEPT_SYSTEM_LIBZ="y"
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

    # Replacement for the old libcrypt.so.1.
    build_libxcrypt "4.4.26" # "4.4.22" # "4.4.15"

    # depends=('perl')
    build_openssl "1.1.1l" # "1.1.1k" # "1.1.1d" # "1.0.2u" # "1.1.1d" # "1.0.2r" # "1.1.1b"

    # Libraries, required by gnutls.
    # depends=('glibc')
    build_tasn1 "4.18.0" # "4.17.0" # "4.15.0" # "4.13"
    # Library, required by Python.
    # depends=('glibc')
    build_expat "2.4.1" # "2.2.9" # "2.2.6"
    # depends=('glibc')
    build_libffi "3.4.2" # "3.2.1"

    build_libunistring "0.9.10"

    # Required by Python
    build_libmpdec "2.5.1" # "2.4.2"

    # Libary, required by tar.
    # depends=('sh')
    build_xz "5.2.5" # "5.2.4"

    # Requires openssl.
    # depends=('glibc' 'gmp')
    # PATCH!
    build_nettle "3.7.3" # "3.5.1" # "3.4.1"

    # Library, required by wget.
    # depends=()
    # Harmful for GCC 9.
    # build_libiconv "1.16" # "1.15"

    # Required by bash.
    build_ncurses "6.2"

    # depends=('glibc' 'ncurses' 'libncursesw.so')
    build_readline "8.1" # "8.0"

    # On macOS use the official binaries, which install in:
    # 2.7.17 -> /Library/Frameworks/Python.framework/Versions/2.7
    # 3.7.6 -> /Library/Frameworks/Python.framework/Versions/3.7
    # 3.8.1 -> /Library/Frameworks/Python.framework/Versions/3.8 (too new)

    # pip3 install meson=="0.53.1"

    # Fails on Darwin.
    # 0:01:39 load avg: 1.70 [187/400] test_io
    # python.exe(15636,0x7fff75763300) malloc: *** mach_vm_map(size=9223372036854775808) failed (error code=3)
    # *** error: can't allocate region
    # *** set a breakpoint in malloc_error_break to debug
    # python.exe(15636,0x7fff75763300) malloc: *** mach_vm_map(size=9223372036854775808) failed (error code=3)
    # *** error: can't allocate region
    # *** set a breakpoint in malloc_error_break to debug
    # python.exe(15636,0x7fff75763300) malloc: *** mach_vm_map(size=9223372036854775808) failed (error code=3)
    # *** error: can't allocate region
    # *** set a breakpoint in malloc_error_break to debug

    # error: [Errno 54] Connection reset by peer
    # 0:05:27 load avg: 1.64 [311/400] test_startfile -- test_ssl failed (env changed)

    # macOS 10.13/11.6 use 2.7.16, close enough.
    # On Apple Silicon it fails, it is not worth the effort.
    # On Ubuntu 18 there is 2.7.17; not much difference with 2.7.18.
    # depends=('bzip2' 'gdbm' 'openssl' 'zlib' 'expat' 'sqlite' 'libffi')
    # build_python2 "2.7.18" # "2.7.16" # "2.7.10" # "2.7.12" # "2.7.14" #  # "2.7.14"

    # homebrew: gdbm, mpdecimal, openssl, readline, sqlite, xz; bzip2, expat, libffi, ncurses, unzip, zlib
    # arch: 'bzip2' 'expat' 'gdbm' 'libffi' 'libnsl' 'libxcrypt' 'openssl' 'zlib'
    build_python3 "3.9.9" # "3.9.8" # "3.9.7" # "3.8.10" # "3.7.6" # "3.8.1" # "3.7.3"

    # The necessary bits to build these optional modules were not found:
    # _bz2                  _dbm                  _gdbm
    # _sqlite3              _tkinter              _uuid
    # Failed to build these modules:
    # _curses               _curses_panel         _decimal

    # depends=('python3')
    # "4.1.0" fails on macOS 10.13
    build_scons "4.2.0" # "3.1.2" # "3.0.5"

    # depends=('python3')
    build_meson "0.60.2" # "0.60.1" # "0.58.1" # "0.53.1" # "0.50.0"

    build_sphinx "4.3.0" # "4.0.2" # "2.4.4"

    # -------------------------------------------------------------------------

    # depends=('glibc' 'glib2 (internal)')
    build_pkg_config "0.29.2"

    # depends=('ca-certificates' 'krb5' 'libssh2' 'openssl' 'zlib' 'libpsl' 'libnghttp2')
    build_curl "7.80.0" # "7.77.0" # "7.68.0" # "7.64.1"

    # tar with xz support.
    # depends=('glibc')
    build_tar "1.34" # "1.32"

    # Required before guile.
    build_libtool "${libtool_version}"

    # Required by guile.
    build_gc "8.0.6" # "8.2.0" # "8.0.4"

    # depends=(gmp libltdl ncurses texinfo libunistring gc libffi)
    # 3.x is too new, autogen requires 2.x
    build_guile "2.2.7"

    # Requires guile 2.x.
    build_autogen "5.18.16"

    # After autogen, requires libopts.so.25.
    # depends=('glibc' 'libidn2' 'libtasn1' 'libunistring' 'nettle' 'p11-kit' 'readline' 'zlib')
    build_gnutls "3.7.2" # "3.6.11.1" # "3.6.7"

    # "8.32" fails on aarch64 with:
    # coreutils-8.32/src/ls.c:3026:24: error: 'SYS_getdents' undeclared (first use in this function); did you mean 'SYS_getdents64'?
    build_coreutils "9.0" # "8.31" # !"8.32" # "8.31"

    # -------------------------------------------------------------------------
    # GNU tools

    # depends=('glibc')
    # PATCH!
    # "1.4.19" tests fail on amd64.
    build_m4 "1.4.19" # "1.4.18" # !"1.4.19" # "1.4.18"

    # depends=('glibc' 'mpfr')
    build_gawk "5.1.1" # "5.1.0" # "5.0.1" # "4.2.1"

    # depends ?
    build_sed "4.8" # "4.7"

    # depends=('sh' 'perl' 'awk' 'm4' 'texinfo')
    build_autoconf "2.71" # "2.69"
    # depends=('sh' 'perl')
    # PATCH!
    build_automake "1.16.5" # "1.16.3" # "1.16"

    # depends=('glibc' 'glib2' 'libunistring' 'ncurses')
    build_gettext "0.21" # "0.20.1" # "0.19.8"

    # depends=('glibc' 'attr')
    build_patch "2.7.6"

    # depends=('libsigsegv')
    build_diffutils "3.8" # "3.7"

    # depends=('glibc')
    build_bison "3.8.2" # "3.7" # "3.5" # "3.3.2"

    # depends=('glibc' 'guile')
    # PATCH!
    build_make "4.3" # "4.2.1"

    # depends=('readline>=7.0' glibc ncurses)
    # "5.1" fails on amd64 with:
    # bash-5.1/bashline.c:65:10: fatal error: builtins/builtext.h: No such file or directory
    build_bash "5.1.8" # "5.0" # !"5.1" # "5.0"

    # -------------------------------------------------------------------------
    # Third party tools

    # depends=('libutil-linux' 'gnutls' 'libidn' 'libpsl>=0.7.1-3' 'gpgme')
    # "1.21.[12]" fails on macOS with
    # lib/malloc/dynarray-skeleton.c:195:13: error: expected identifier or '(' before numeric constant
    # 195 | __nonnull ((1))
    build_wget "1.20.3" # "1.20.1"

    # Required to build PDF manuals.
    # depends=('coreutils')
    build_texinfo "6.8" # "6.7" # "6.6"

    # depends ?
    # Warning: buggy!
    # "0.12" weird tag
    build_patchelf "0.14.3" # "0.13.1" # "0.12" # "0.10"

    # depends=('glibc')
    build_dos2unix "7.4.2" # "7.4.1" # "7.4.0"

    if is_darwin && is_arm
    then
      # Still problematic, building GCC in XBB fails with missing __Z5yyendv...
      :
    else
      # macOS 10.10 uses 2.5.3, an update is not mandatory.
      # depends=('glibc' 'm4' 'sh')
      # PATCH!
      build_flex "2.6.4" # "2.6.3" fails in wine
    fi

    # macOS 10.1[03] uses 5.18.2.
    # macOS 11.6 uses 5.30.2
    # HiRes.c:2037:17: error: use of undeclared identifier 'CLOCK_REALTIME'
    #     clock_id = CLOCK_REALTIME;
    #
    # depends=('gdbm' 'db' 'glibc')
    # old PATCH!
    build_perl "5.34.0" # "5.32.0" # "5.30.1" # "5.18.2" # "5.30.1" # "5.28.1"

    # Give other a chance to use it.
    # However some (like Python) test for Tk too.
    build_tcl "8.6.12" # "8.6.11" # "8.6.10"

    # depends=('curl' 'libarchive' 'shared-mime-info' 'jsoncpp' 'rhash')
    build_cmake "3.22.1" # "3.21.4" #  "3.20.6" # "3.19.8" # "3.16.2" # "3.13.4"

    # Requires scons
    # depends=('python2')
    build_ninja "1.10.2" # "1.10.0" # "1.9.0"

    # depends=('curl' 'expat>=2.0' 'perl-error' 'perl>=5.14.0' 'openssl' 'pcre2' 'grep' 'shadow')
    build_git "2.34.1" # "2.33.1" # "2.32.0" # "2.25.0" # "2.21.0"

    build_p7zip "16.02"

    # "1.4.[12]" fail on amd64 with
    # librhash/librhash.so.0: undefined reference to `aligned_alloc'
    build_rhash "1.4.2" # "1.3.9" # !"1.4.2" # !"1.4.1" # "1.3.9"

    build_re2c "2.2" # "2.1.1" # "1.3"

    # -------------------------------------------------------------------------

    # $1=nvm_version
    # $2=node_version
    # $3=npm_version
    # build_nvm "0.35.2" "12.16.0" "6.13.7"

    build_libgpg_error "1.42" # "1.41" # "1.37"
    # "1.9.3" Fails many tests on macOS
    build_libgcrypt "1.9.4" # "1.8.8" # "1.8.7" # "1.8.5"
    build_libassuan "2.5.5" # "2.5.4" # "2.5.3"
    # patched
    build_libksba "1.6.0" # "1.5.0" # "1.3.5"

    build_npth "1.6"

    # "2.3.1" fails on macOS 10.13, requires libgcrypt 1.9
    # "2.2.28" fails on amd64
    build_gnupg  "2.3.3" # "2.2.26" # !"2.2.28" # "2.2.26" # "2.2.19"

    # -------------------------------------------------------------------------

    # makedepend is needed by openssl
    build_util_macros "1.19.3" # "1.19.2" # "1.17.1"
    # PATCH!
    build_xorg_xproto "7.0.31" # Needs a patch for aarch64.
    build_makedepend "1.0.6" # "1.0.5"

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
      build_native_gcc "${XBB_GCC_VERSION}"

      (
        prepare_gcc_env "" "-xbb"

        # Requires new gcc.
        # depends=('sh' 'tar' 'glibc')
        build_libtool "${libtool_version}" "-2"
      )

      # Fails to install on Apple Silicon
      # build_native_gdb "${XBB_GDB_VERSION}"
    else
      echo "Unsupported platform."
      exit 1
    fi

    # -------------------------------------------------------------------------
    # Requires mingw-w64 GCC.

    # Build wine only on Intel Linux.
    if is_linux && is_intel
    then

      # Required by wine.
      build_libpng "1.6.37"

      # depends=('libpng')
      # "6.17" requires a patch on Ubuntu 12 to disable getauxval()
      # "5.22" fails meson tests in 32-bit.
      build_wine "6.23" # "6.17" # "5.22" # "5.1" # "5.0" # "4.3"

      # configure: OpenCL 64-bit development files not found, OpenCL won't be supported.
      # configure: pcap 64-bit development files not found, wpcap won't be supported.
      # configure: libdbus 64-bit development files not found, no dynamic device support.
      # configure: lib(n)curses 64-bit development files not found, curses won't be supported.
      # configure: libsane 64-bit development files not found, scanners won't be supported.
      # configure: libv4l2 64-bit development files not found.
      # configure: libgphoto2 64-bit development files not found, digital cameras won't be supported.
      # configure: libgphoto2_port 64-bit development files not found, digital cameras won't be auto-detected.
      # configure: liblcms2 64-bit development files not found, Color Management won't be supported.
      # configure: libpulse 64-bit development files not found or too old, Pulse won't be supported.
      # configure: gstreamer-1.0 base plugins 64-bit development files not found, GStreamer won't be supported.
      # configure: OSS sound system found but too old (OSSv4 needed), OSS won't be supported.
      # configure: libudev 64-bit development files not found, plug and play won't be supported.
      # configure: libSDL2 64-bit development files not found, SDL2 won't be supported.
      # configure: libFAudio 64-bit development files not found, XAudio2 won't be supported.
      # configure: libcapi20 64-bit development files not found, ISDN won't be supported.
      # configure: libcups 64-bit development files not found, CUPS won't be supported.
      # configure: fontconfig 64-bit development files not found, fontconfig won't be supported.
      # configure: libgsm 64-bit development files not found, gsm 06.10 codec won't be supported.
      # configure: libkrb5 64-bit development files not found (or too old), Kerberos won't be supported.
      # configure: libtiff 64-bit development files not found, TIFF won't be supported.
      # configure: libmpg123 64-bit development files not found (or too old), mp3 codec won't be supported.
      # configure: libopenal 64-bit development files not found (or too old), OpenAL won't be supported.
      # configure: libvulkan and libMoltenVK 64-bit development files not found, Vulkan won't be supported.
      # configure: vkd3d 64-bit development files not found (or too old), Direct3D 12 won't be supported.
      # configure: libldap (OpenLDAP) 64-bit development files not found, LDAP won't be supported.

      # configure: WARNING: libxml2 64-bit development files not found (or too old), XML won't be supported.
      # configure: WARNING: libxslt 64-bit development files not found, xslt won't be supported.
      # configure: WARNING: libjpeg 64-bit development files not found, JPEG won't be supported.
      # configure: WARNING: No sound system was found. Windows applications will be silent.
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

  elif [[ "${XBB_VERSION}" =~ 3\.4\.1 ]]
  then
    if is_linux
    then
      # Uses CC to compute the library path.
      prepare_library_path

      LD_RUN_PATH="${XBB_LIBRARY_PATH}"

      echo "LD_RUN_PATH=${LD_RUN_PATH}"
      export LD_RUN_PATH
    fi

    # Upgrade wine
    # -------------------------------------------------------------------------
    # Requires mingw-w64 GCC.

    # Build wine only on Intel Linux.
    if is_linux && is_intel
    then

      # Required by wine.
      # build_libpng "1.6.37"

      # depends=('libpng')
      build_wine "7.15" # "6.17" # "5.22" # "5.1" # "5.0" # "4.3"
    fi

    strip_static_objects

    if is_linux
    then
      patch_elf_rpath
    fi

    run_tests

  elif [[ "${XBB_VERSION}" =~ 3\.4 ]]
  then

    # =========================================================================

    # Problematic tests (WARN-TEST)
    # - nettle
    # - gnutls (long)
    # - libxcrypt on darwin
    # - tar
    # - coreutils
    # - m4 on darwin
    # - gawk (long)
    # - sed
    # - automake
    # - gettext
    # - bison (long)
    # - make (long)
    # - wget
    # - texinfo (darwin)
    # - tcl (long)
    # - guile (!)
    # - re2c (darwin)
    # - glibc
    # - guile (1 test disabled)
    # - autogen (1 test disabled)

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

      # Hack to avoid libz.1.so not found in binutils linker.
      export ACCEPT_SYSTEM_LIBZ="y"
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

    # Replacement for the old libcrypt.so.1.
    build_libxcrypt "4.4.26" # "4.4.22" # "4.4.15"

    # depends=('perl')
    build_openssl "1.1.1l" # "1.1.1k" # "1.1.1d" # "1.0.2u" # "1.1.1d" # "1.0.2r" # "1.1.1b"

    # Libraries, required by gnutls.
    # depends=('glibc')
    build_tasn1 "4.18.0" # "4.17.0" # "4.15.0" # "4.13"
    # Library, required by Python.
    # depends=('glibc')
    build_expat "2.4.1" # "2.2.9" # "2.2.6"
    # depends=('glibc')
    build_libffi "3.4.2" # "3.2.1"

    build_libunistring "0.9.10"

    # Required by Python
    build_libmpdec "2.5.1" # "2.4.2"

    # Libary, required by tar.
    # depends=('sh')
    build_xz "5.2.5" # "5.2.4"

    # Requires openssl.
    # depends=('glibc' 'gmp')
    # PATCH!
    build_nettle "3.7.3" # "3.5.1" # "3.4.1"

    # Library, required by wget.
    # depends=()
    # Harmful for GCC 9.
    # build_libiconv "1.16" # "1.15"

    # Required by bash.
    build_ncurses "6.2"

    # depends=('glibc' 'ncurses' 'libncursesw.so')
    build_readline "8.1" # "8.0"

    # On macOS use the official binaries, which install in:
    # 2.7.17 -> /Library/Frameworks/Python.framework/Versions/2.7
    # 3.7.6 -> /Library/Frameworks/Python.framework/Versions/3.7
    # 3.8.1 -> /Library/Frameworks/Python.framework/Versions/3.8 (too new)

    # pip3 install meson=="0.53.1"

    # Fails on Darwin.
    # 0:01:39 load avg: 1.70 [187/400] test_io
    # python.exe(15636,0x7fff75763300) malloc: *** mach_vm_map(size=9223372036854775808) failed (error code=3)
    # *** error: can't allocate region
    # *** set a breakpoint in malloc_error_break to debug
    # python.exe(15636,0x7fff75763300) malloc: *** mach_vm_map(size=9223372036854775808) failed (error code=3)
    # *** error: can't allocate region
    # *** set a breakpoint in malloc_error_break to debug
    # python.exe(15636,0x7fff75763300) malloc: *** mach_vm_map(size=9223372036854775808) failed (error code=3)
    # *** error: can't allocate region
    # *** set a breakpoint in malloc_error_break to debug

    # error: [Errno 54] Connection reset by peer
    # 0:05:27 load avg: 1.64 [311/400] test_startfile -- test_ssl failed (env changed)

    # macOS 10.13/11.6 use 2.7.16, close enough.
    # On Apple Silicon it fails, it is not worth the effort.
    # On Ubuntu 18 there is 2.7.17; not much difference with 2.7.18.
    # depends=('bzip2' 'gdbm' 'openssl' 'zlib' 'expat' 'sqlite' 'libffi')
    # build_python2 "2.7.18" # "2.7.16" # "2.7.10" # "2.7.12" # "2.7.14" #  # "2.7.14"

    # homebrew: gdbm, mpdecimal, openssl, readline, sqlite, xz; bzip2, expat, libffi, ncurses, unzip, zlib
    # arch: 'bzip2' 'expat' 'gdbm' 'libffi' 'libnsl' 'libxcrypt' 'openssl' 'zlib'
    build_python3 "3.9.8" # "3.9.7" # "3.8.10" # "3.7.6" # "3.8.1" # "3.7.3"

    # The necessary bits to build these optional modules were not found:
    # _bz2                  _dbm                  _gdbm
    # _sqlite3              _tkinter              _uuid
    # Failed to build these modules:
    # _curses               _curses_panel         _decimal

    # depends=('python3')
    # "4.1.0" fails on macOS 10.13
    build_scons "4.2.0" # "3.1.2" # "3.0.5"

    # depends=('python3')
    build_meson "0.60.1" # "0.58.1" # "0.53.1" # "0.50.0"

    build_sphinx "4.3.0" # "4.0.2" # "2.4.4"

    # -------------------------------------------------------------------------

    # depends=('glibc' 'glib2 (internal)')
    build_pkg_config "0.29.2"

    # depends=('ca-certificates' 'krb5' 'libssh2' 'openssl' 'zlib' 'libpsl' 'libnghttp2')
    build_curl "7.80.0" # "7.77.0" # "7.68.0" # "7.64.1"

    # tar with xz support.
    # depends=('glibc')
    build_tar "1.34" # "1.32"

    # Required before guile.
    build_libtool "${libtool_version}"

    # Required by guile.
    build_gc "8.0.6" # "8.2.0" # "8.0.4"

    # depends=(gmp libltdl ncurses texinfo libunistring gc libffi)
    # 3.x is too new, autogen requires 2.x
    build_guile "2.2.7"

    # Requires guile 2.x.
    build_autogen "5.18.16"

    # After autogen, requires libopts.so.25.
    # depends=('glibc' 'libidn2' 'libtasn1' 'libunistring' 'nettle' 'p11-kit' 'readline' 'zlib')
    build_gnutls "3.7.2" # "3.6.11.1" # "3.6.7"

    # "8.32" fails on aarch64 with:
    # coreutils-8.32/src/ls.c:3026:24: error: 'SYS_getdents' undeclared (first use in this function); did you mean 'SYS_getdents64'?
    build_coreutils "9.0" # "8.31" # !"8.32" # "8.31"

    # -------------------------------------------------------------------------
    # GNU tools

    # depends=('glibc')
    # PATCH!
    # "1.4.19" tests fail on amd64.
    build_m4 "1.4.19" # "1.4.18" # !"1.4.19" # "1.4.18"

    # depends=('glibc' 'mpfr')
    build_gawk "5.1.1" # "5.1.0" # "5.0.1" # "4.2.1"

    # depends ?
    build_sed "4.8" # "4.7"

    # depends=('sh' 'perl' 'awk' 'm4' 'texinfo')
    build_autoconf "2.71" # "2.69"
    # depends=('sh' 'perl')
    # PATCH!
    build_automake "1.16.5" # "1.16.3" # "1.16"

    # depends=('glibc' 'glib2' 'libunistring' 'ncurses')
    build_gettext "0.21" # "0.20.1" # "0.19.8"

    # depends=('glibc' 'attr')
    build_patch "2.7.6"

    # depends=('libsigsegv')
    build_diffutils "3.8" # "3.7"

    # depends=('glibc')
    build_bison "3.8.2" # "3.7" # "3.5" # "3.3.2"

    # depends=('glibc' 'guile')
    # PATCH!
    build_make "4.3" # "4.2.1"

    # depends=('readline>=7.0' glibc ncurses)
    # "5.1" fails on amd64 with:
    # bash-5.1/bashline.c:65:10: fatal error: builtins/builtext.h: No such file or directory
    build_bash "5.1.8" # "5.0" # !"5.1" # "5.0"

    # -------------------------------------------------------------------------
    # Third party tools

    # depends=('libutil-linux' 'gnutls' 'libidn' 'libpsl>=0.7.1-3' 'gpgme')
    # "1.21.[12]" fails on macOS with
    # lib/malloc/dynarray-skeleton.c:195:13: error: expected identifier or '(' before numeric constant
    # 195 | __nonnull ((1))
    build_wget "1.20.3" # "1.20.1"

    # Required to build PDF manuals.
    # depends=('coreutils')
    build_texinfo "6.8" # "6.7" # "6.6"

    # depends ?
    # Warning: buggy!
    # "0.12" weird tag
    build_patchelf "0.14.3" # "0.13.1" # "0.12" # "0.10"

    # depends=('glibc')
    build_dos2unix "7.4.2" # "7.4.1" # "7.4.0"

    if is_darwin && is_arm
    then
      # Still problematic, building GCC in XBB fails with missing __Z5yyendv...
      :
    else
      # macOS 10.10 uses 2.5.3, an update is not mandatory.
      # depends=('glibc' 'm4' 'sh')
      # PATCH!
      build_flex "2.6.4" # "2.6.3" fails in wine
    fi

    # macOS 10.1[03] uses 5.18.2.
    # macOS 11.6 uses 5.30.2
    # HiRes.c:2037:17: error: use of undeclared identifier 'CLOCK_REALTIME'
    #     clock_id = CLOCK_REALTIME;
    #
    # depends=('gdbm' 'db' 'glibc')
    # old PATCH!
    build_perl "5.34.0" # "5.32.0" # "5.30.1" # "5.18.2" # "5.30.1" # "5.28.1"

    # Give other a chance to use it.
    # However some (like Python) test for Tk too.
    build_tcl "8.6.12" # "8.6.11" # "8.6.10"

    # depends=('curl' 'libarchive' 'shared-mime-info' 'jsoncpp' 'rhash')
    build_cmake "3.21.4" #  "3.20.6" # "3.19.8" # "3.16.2" # "3.13.4"

    # Requires scons
    # depends=('python2')
    build_ninja "1.10.2" # "1.10.0" # "1.9.0"

    # depends=('curl' 'expat>=2.0' 'perl-error' 'perl>=5.14.0' 'openssl' 'pcre2' 'grep' 'shadow')
    build_git "2.34.1" # "2.33.1" # "2.32.0" # "2.25.0" # "2.21.0"

    build_p7zip "16.02"

    # "1.4.[12]" fail on amd64 with
    # librhash/librhash.so.0: undefined reference to `aligned_alloc'
    build_rhash "1.4.2" # "1.3.9" # !"1.4.2" # !"1.4.1" # "1.3.9"

    build_re2c "2.2" # "2.1.1" # "1.3"

    # -------------------------------------------------------------------------

    # $1=nvm_version
    # $2=node_version
    # $3=npm_version
    # build_nvm "0.35.2" "12.16.0" "6.13.7"

    build_libgpg_error "1.42" # "1.41" # "1.37"
    # "1.9.3" Fails many tests on macOS
    build_libgcrypt "1.9.4" # "1.8.8" # "1.8.7" # "1.8.5"
    build_libassuan "2.5.5" # "2.5.4" # "2.5.3"
    # patched
    build_libksba "1.6.0" # "1.5.0" # "1.3.5"

    build_npth "1.6"

    # "2.3.1" fails on macOS 10.13, requires libgcrypt 1.9
    # "2.2.28" fails on amd64
    build_gnupg  "2.3.3" # "2.2.26" # !"2.2.28" # "2.2.26" # "2.2.19"

    # -------------------------------------------------------------------------

    # makedepend is needed by openssl
    build_util_macros "1.19.3" # "1.19.2" # "1.17.1"
    # PATCH!
    build_xorg_xproto "7.0.31" # Needs a patch for aarch64.
    build_makedepend "1.0.6" # "1.0.5"

    # -------------------------------------------------------------------------

    # Avoid Java for now, not longer available on Apple Silicon.
    if false
    then
      build_ant "1.10.12" # "1.10.10" # "1.10.7"

      build_maven "3.8.3" # "3.8.1" # "3.6.3"
    fi

    # Not ready, dependency libs not yet in.
    # build_nodejs "12.16.0"

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
      build_native_gcc "${XBB_GCC_VERSION}"

      (
        prepare_gcc_env "" "-xbb"

        # Requires new gcc.
        # depends=('sh' 'tar' 'glibc')
        build_libtool "${libtool_version}" "-2"
      )

      # Fails to install on Apple Silicon
      # build_native_gdb "${XBB_GDB_VERSION}"
    else
      echo "Unsupported platform."
      exit 1
    fi

    # -------------------------------------------------------------------------
    # Requires mingw-w64 GCC.

    # Build wine only on Intel Linux.
    if is_linux && is_intel
    then

      # Required by wine.
      build_libpng "1.6.37"

      # depends=('libpng')
      # "6.17" requires a patch on Ubuntu 12 to disable getauxval()
      # "5.22" fails meson tests in 32-bit.
      build_wine "6.17" # "5.22" # "5.1" # "5.0" # "4.3"

      # configure: OpenCL 64-bit development files not found, OpenCL won't be supported.
      # configure: pcap 64-bit development files not found, wpcap won't be supported.
      # configure: libdbus 64-bit development files not found, no dynamic device support.
      # configure: lib(n)curses 64-bit development files not found, curses won't be supported.
      # configure: libsane 64-bit development files not found, scanners won't be supported.
      # configure: libv4l2 64-bit development files not found.
      # configure: libgphoto2 64-bit development files not found, digital cameras won't be supported.
      # configure: libgphoto2_port 64-bit development files not found, digital cameras won't be auto-detected.
      # configure: liblcms2 64-bit development files not found, Color Management won't be supported.
      # configure: libpulse 64-bit development files not found or too old, Pulse won't be supported.
      # configure: gstreamer-1.0 base plugins 64-bit development files not found, GStreamer won't be supported.
      # configure: OSS sound system found but too old (OSSv4 needed), OSS won't be supported.
      # configure: libudev 64-bit development files not found, plug and play won't be supported.
      # configure: libSDL2 64-bit development files not found, SDL2 won't be supported.
      # configure: libFAudio 64-bit development files not found, XAudio2 won't be supported.
      # configure: libcapi20 64-bit development files not found, ISDN won't be supported.
      # configure: libcups 64-bit development files not found, CUPS won't be supported.
      # configure: fontconfig 64-bit development files not found, fontconfig won't be supported.
      # configure: libgsm 64-bit development files not found, gsm 06.10 codec won't be supported.
      # configure: libkrb5 64-bit development files not found (or too old), Kerberos won't be supported.
      # configure: libtiff 64-bit development files not found, TIFF won't be supported.
      # configure: libmpg123 64-bit development files not found (or too old), mp3 codec won't be supported.
      # configure: libopenal 64-bit development files not found (or too old), OpenAL won't be supported.
      # configure: libvulkan and libMoltenVK 64-bit development files not found, Vulkan won't be supported.
      # configure: vkd3d 64-bit development files not found (or too old), Direct3D 12 won't be supported.
      # configure: libldap (OpenLDAP) 64-bit development files not found, LDAP won't be supported.

      # configure: WARNING: libxml2 64-bit development files not found (or too old), XML won't be supported.
      # configure: WARNING: libxslt 64-bit development files not found, xslt won't be supported.
      # configure: WARNING: libjpeg 64-bit development files not found, JPEG won't be supported.
      # configure: WARNING: No sound system was found. Windows applications will be silent.
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
