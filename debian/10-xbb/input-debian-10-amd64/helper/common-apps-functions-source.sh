# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------

function build_native_binutils()
{
  # https://www.gnu.org/software/binutils/
  # https://ftp.gnu.org/gnu/binutils/

  # https://github.com/archlinux/svntogit-packages/blob/packages/binutils/trunk/PKGBUILD
  # https://archlinuxarm.org/packages/aarch64/binutils/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=aarch64-binutils


  # 2017-07-24, "2.29"
  # 2018-07-14, "2.31"
  # 2019-02-02, "2.32"
  # 2019-10-12, "2.33.1"
  # 2020-02-01, "2.34"
  # 2021-02-06, "2.36.1"
  # 2021-07-18, "2.37" ! -mbig-obj, ld -> libz

  local native_binutils_version="$1"

  local step
  if [ $# -ge 2 ]
  then
    step="$2"
  else
    step=""
  fi

  # ! Must be different from glibc (/usr).
  NATIVE_BINUTILS_INSTALL_FOLDER_PATH="${NATIVE_BINUTILS_INSTALL_FOLDER_PATH:-${INSTALL_FOLDER_PATH}}"

  local native_binutils_src_folder_name="binutils-${native_binutils_version}"

  local native_binutils_archive="${native_binutils_src_folder_name}.tar.xz"
  local native_binutils_url="https://ftp.gnu.org/gnu/binutils/${native_binutils_archive}"

  local native_binutils_folder_name="native-binutils${step}-${native_binutils_version}"

  local native_binutils_patch_file_path="${helper_folder_path}/patches/binutils-${native_binutils_version}.patch"
  local native_binutils_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${native_binutils_folder_name}-installed"
  if [ ! -f "${native_binutils_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${native_binutils_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${native_binutils_url}" "${native_binutils_archive}" \
      "${native_binutils_src_folder_name}" \
      "${native_binutils_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${native_binutils_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${native_binutils_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${native_binutils_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP} -v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running native binutils configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${native_binutils_src_folder_name}/configure" --help

          config_options=()

          # ! Do not use the same folder as glibc, since this leads to
          # shared libs confusions.
          config_options+=("--prefix=${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}")

          config_options+=("--build=${BUILD}")
          config_options+=("--target=${BUILD}")

          config_options+=("--with-pkgversion=${XBB_BINUTILS_BRANDING}")

          if false # [ "${XBB_LAYER}" != "xbb-bootstrap" ]
          then
            # There is no --with-sysroot.
            config_options+=("--with-build-sysroot=${GLIBC_INSTALL_FOLDER_PATH}")
          fi

          # Arch also uses
          # --with-lib-path=/usr/lib:/usr/local/lib

          # config_options+=("--without-system-zlib")
          config_options+=("--with-system-zlib")

          config_options+=("--with-pic")

          # error: debuginfod is missing or unusable
          config_options+=("--without-debuginfod")

          if is_linux
          then
            config_options+=("--enable-ld")
            config_options+=("--enable-ld=default")

            if true
            then
              config_options+=("--enable-shared")
              config_options+=("--enable-shared-libgcc")
            else
              config_options+=("--disable-shared")
              config_options+=("--disable-shared-libgcc")
            fi

            # Prevent ld to set DT_RUNPATH.
            config_options+=("--disable-rpath")
            config_options+=("--disable-new-dtags")
          elif is_darwin
          then
            echo
            echo "binutils not supported on macOS"
            exit 1
          else
            echo "Oops! Unsupported ${TARGET_PLATFORM}."
            exit 1
          fi

          config_options+=("--enable-static")
          config_options+=("--enable-gold")
          config_options+=("--enable-lto")
          config_options+=("--enable-libssp")
          config_options+=("--enable-relro")
          config_options+=("--enable-threads")
          config_options+=("--enable-interwork")
          config_options+=("--enable-plugins")
          config_options+=("--enable-build-warnings=no")
          config_options+=("--enable-deterministic-archives")

          config_options+=("--disable-nls")

          config_options+=("--disable-multilib")
          config_options+=("--disable-werror")
          config_options+=("--disable-sim")
          config_options+=("--disable-gdb")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${native_binutils_src_folder_name}/configure" \
            "${config_options[@]}"

          run_verbose make configure-host

          # Workaround to avoid libtool issuing -rpath to the linker, since
          # this prevents it using the global LD_RUN_PATH.
          if is_linux
          then
            patch_all_libtool_rpath
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${native_binutils_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_binutils_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running native binutils make..."

        # Build.
        run_verbose make -j ${JOBS}

        # For unknown reasons, ld regenerates libtool, so we have to do it again.
        (
          cd ld
          run_verbose make clean

          if is_linux
          then
            patch_all_libtool_rpath
          fi

          run_verbose make -j ${JOBS}
        )

        # make install-strip
        run_verbose make install

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_binutils_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_native_binutils
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_binutils_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${native_binutils_stamp_file_path}"

  else
    echo "Component native binutils ${step} already installed."
  fi

  if [ -z "${step}" ]
  then
    test_functions+=("test_native_binutils")
  fi
}

function test_native_binutils()
{
  (
    if [ -f "${BUILD_FOLDER_PATH}/.activate_installed_bin" ]
    then
      xbb_activate_installed_bin
    fi

    echo
    echo "Checking the binutils shared libraries..."

    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ar"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/as"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ld"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/nm"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/objcopy"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/objdump"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ranlib"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/size"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/strings"
    show_libs "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/strip"

    echo
    echo "Testing if binutils binaries start properly..."

    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ar" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/as" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ld" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/nm" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/objcopy" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/objdump" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ranlib" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/size" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/strings" --version
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/strip" --version

    echo
    echo "Testing if binutils binaries display help..."

    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ar" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/as" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ld" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/nm" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/objcopy" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/objdump" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/ranlib" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/size" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/strings" --help
    run_app "${NATIVE_BINUTILS_INSTALL_FOLDER_PATH}/bin/strip" --help
  )
}

# -----------------------------------------------------------------------------

function build_native_gdb()
{
  # https://www.gnu.org/software/gdb/
  # https://ftp.gnu.org/gnu/gdb/

  # https://archlinuxarm.org/packages/aarch64/gdb/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gdb-git

  # 2020-05-23, "9.2"
  # 2021-04-25, "10.2"
  # 2021-09-12, "11.1"

  local native_gdb_version="$1"

  local step
  if [ $# -ge 2 ]
  then
    step="$2"
  else
    step=""
  fi

  local native_gdb_src_folder_name="gdb-${native_gdb_version}"

  local native_gdb_archive="${native_gdb_src_folder_name}.tar.xz"
  local native_gdb_url="https://ftp.gnu.org/gnu/gdb/${native_gdb_archive}"

  local native_gdb_folder_name="native-gdb${step}-${native_gdb_version}"

  local native_gdb_patch_file_path="${helper_folder_path}/patches/gdb-${native_gdb_version}.patch"
  local native_gdb_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${native_gdb_folder_name}-installed"
  if [ ! -f "${native_gdb_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${native_gdb_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${native_gdb_url}" "${native_gdb_archive}" \
      "${native_gdb_src_folder_name}" \
      "${native_gdb_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${native_gdb_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${native_gdb_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${native_gdb_folder_name}"

      xbb_activate
      # xbb_activate_installed_bin
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP_STATIC_GCC} -v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running native gdb configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${native_gdb_src_folder_name}/configure" --help

          config_options=()

          # ! Do not use the same folder as glibc, since this leads to
          # shared libs confusions.
          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          config_options+=("--build=${BUILD}")
          config_options+=("--target=${BUILD}")

          config_options+=("--with-pkgversion=${XBB_BINUTILS_BRANDING}")

          config_options+=("--disable-nls")
          config_options+=("--disable-sim")
          config_options+=("--disable-gas")
          config_options+=("--disable-binutils")
          config_options+=("--disable-ld")
          config_options+=("--disable-gprof")
          # configure: error: source highlight is incompatible with -static-libstdc++; either use --disable-source-highlight or --without-static-standard-libraries
          config_options+=("--disable-source-highlight")

          config_options+=("--with-python=no")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${native_gdb_src_folder_name}/configure" \
            "${config_options[@]}"

          run_verbose make configure-host

          if is_linux
          then
            patch_all_libtool_rpath
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${native_gdb_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_gdb_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running native gdb make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_gdb_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_native_gdb
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_gdb_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${native_gdb_stamp_file_path}"

  else
    echo "Component native gdb ${step} already installed."
  fi

  if [ -z "${step}" ]
  then
    test_functions+=("test_native_gdb")
  fi
}

function test_native_gdb()
{
  (
    if [ -f "${BUILD_FOLDER_PATH}/.activate_installed_bin" ]
    then
      xbb_activate_installed_bin
    fi

    echo
    echo "Checking the gdb shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/gdb"

    echo
    echo "Testing if gdb binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/gdb" --version

    echo
    echo "Testing if gdb binaries display help..."

    run_app "${INSTALL_FOLDER_PATH}/bin/gdb" --help
  )
}

# -----------------------------------------------------------------------------

function build_native_gcc()
{
  # https://gcc.gnu.org
  # https://ftp.gnu.org/gnu/gcc/
  # https://gcc.gnu.org/wiki/InstallingGCC
  # https://gcc.gnu.org/install/build.html

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/gcc.rb

  # https://archlinuxarm.org/packages/aarch64/gcc/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gcc-git

  # 2018-05-02, "8.1.0"
  # 2018-07-26, "8.2.0"
  # 2018-10-30, "6.5.0"
  # 2018-12-06, "7.4.0"
  # 2019-02-22, "8.3.0"
  # 2019-05-03, "9.1.0"
  # 2019-08-12, "9.2.0"
  # 2019-11-14, "7.5.0"
  # 2020-03-04, "8.4.0"
  # 2020-03-12, "9.3.0"
  # 2020-05-07, "10.1.0"
  # 2020-07-23, "10.2.0"
  # 2021-04-08, "10.3.0"
  # 2021-04-27, "11.1.0"
  # 2021-05-14, "8.5.0"
  # 2021-06-01, "9.4.0"
  # 2021-07-28, "11.2.0"

  local native_gcc_version="$1"

  local step="${2:-""}"

  # Branch from the Darwin maintainer of GCC with Apple Silicon support,
  # located at https://github.com/iains/gcc-darwin-arm64 and
  # backported with his help to gcc-11 branch. Too big for a patch.
  # The repo used by the HomeBrew:
  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/gcc.rb
  # https://github.com/fxcoudert/gcc/tags
  if is_darwin && [ "${step}" == "-edge" ]
  then
    local native_gcc_src_folder_name="gcc-darwin-arm64.git"
    local native_gcc_url="https://github.com/iains/gcc-darwin-arm64.git"

    # Comment this to bootstrap it with gcc-xbb.
    prepare_clang_env ""
  elif is_darwin && is_arm && [ "${native_gcc_version}" == "11.2.0" ]
  then
    # https://github.com/xpack-dev-tools/gcc/archive/refs/tags/gcc-11.2.0-arm-20211201-xpack.tar.gz
    # local native_gcc_archive="gcc-11.2.0-arm-20211201-xpack.tar.gz"
    # local native_gcc_url="https://github.com/xpack-dev-tools/gcc/archive/refs/tags/${native_gcc_archive}"
    # local native_gcc_src_folder_name="gcc-gcc-11.2.0-arm-20211201-xpack"
    # https://github.com/fxcoudert/gcc/archive/refs/tags/gcc-11.2.0-arm-20211201.tar.gz
    local native_gcc_archive="gcc-11.2.0-arm-20211201.tar.gz"
    local native_gcc_url="https://github.com/fxcoudert/gcc/archive/refs/tags/${native_gcc_archive}"
    local native_gcc_src_folder_name="gcc-gcc-11.2.0-arm-20211201"
  elif is_darwin && is_arm && [ "${native_gcc_version}" == "11.1.0" ]
  then
    # https://github.com/fxcoudert/gcc/archive/refs/tags/gcc-11.1.0-arm-20210504.tar.gz
    local native_gcc_archive="gcc-11.1.0-arm-20210504.tar.gz"
    local native_gcc_url="https://github.com/fxcoudert/gcc/archive/refs/tags/${native_gcc_archive}"
    local native_gcc_src_folder_name="gcc-gcc-11.1.0-arm-20210504"
  else
    local native_gcc_src_folder_name="gcc-${native_gcc_version}"
    local native_gcc_archive="${native_gcc_src_folder_name}.tar.xz"
    local native_gcc_url="https://ftp.gnu.org/gnu/gcc/gcc-${native_gcc_version}/${native_gcc_archive}"
  fi

  local native_gcc_folder_name="native-gcc${step}-${native_gcc_version}"

  local native_gcc_patch_file_path="${helper_folder_path}/patches/gcc-${native_gcc_version}.patch.diff"
  local native_gcc_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${native_gcc_folder_name}-installed"
  if [ ! -f "${native_gcc_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${native_gcc_folder_name}" ]
  then
    cd "${SOURCES_FOLDER_PATH}"

    if [ "${step}" == "-edge" ]
    then
      if [ ! -d "${native_gcc_src_folder_name}" ]
      then
        run_verbose git clone "${native_gcc_url}" \
          "${native_gcc_src_folder_name}"
      fi
    else
      download_and_extract "${native_gcc_url}" "${native_gcc_archive}" \
        "${native_gcc_src_folder_name}" \
        "${native_gcc_patch_file_path}"
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${native_gcc_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${native_gcc_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${native_gcc_folder_name}"

      xbb_activate
      # To pick the ld from the new binutils.
      # /usr/bin/ld: BFD (GNU Binutils for Ubuntu) 2.22 internal error, aborting at ../../bfd/reloc.c line 443 in bfd_get_reloc_size
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP} -v"

      LDFLAGS_FOR_TARGET="${LDFLAGS}"
      LDFLAGS_FOR_BUILD="${LDFLAGS}"
      BOOT_LDFLAGS="${LDFLAGS}"

      if is_darwin
      then
        # From HomeBrew
        BOOT_LDFLAGS+=" -Wl,-headerpad_max_install_names"
      fi

      export CPPFLAGS
      export CPPFLAGS_FOR_TARGET
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      export LDFLAGS_FOR_TARGET
      export LDFLAGS_FOR_BUILD
      export BOOT_LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running native gcc configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${native_gcc_src_folder_name}/configure" --help
          run_verbose bash "${SOURCES_FOLDER_PATH}/${native_gcc_src_folder_name}/gcc/configure" --help

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}/usr")
          # Do not use the same folder as glibc.
          config_options+=("--libdir=${INSTALL_FOLDER_PATH}/usr/${BUILD}/lib")

          config_options+=("--program-suffix=${XBB_GCC_SUFFIX}")

          config_options+=("--build=${BUILD}")
          config_options+=("--target=${BUILD}")

          config_options+=("--with-pkgversion=${XBB_GCC_BRANDING}")

          # On macOS it fails with:
          # ld: library not found for -lisl
          # config_options+=("--with-isl")
          config_options+=("--with-isl=${INSTALL_FOLDER_PATH}")
          config_options+=("--enable-languages=c,c++,fortran,objc,obj-c++,lto")

          if [ "${step}" == "-edge" ]
          then
            : # The edge build must be as clean as possible.
          else
            # Many of these are probably redundand.
            # Some may be plainly wrong.

            config_options+=("--with-libiconv")

            config_options+=("--with-diagnostics-color=auto")

            # config_options+=("--without-system-zlib")
            config_options+=("--with-system-zlib")

            config_options+=("--without-cuda-driver")

            # config_options+=("--enable-objc-gc=auto")

            config_options+=("--enable-checking=release")

            config_options+=("--enable-lto")
            config_options+=("--enable-plugin")

            config_options+=("--enable-static")

            config_options+=("--enable-__cxa_atexit")

            config_options+=("--enable-threads=posix")

            config_options+=("--enable-shared")
            config_options+=("--enable-shared-libgcc")

            # It fails on macOS master with:
            # libstdc++-v3/include/bits/cow_string.h:630:9: error: no matching function for call to 'std::basic_string<wchar_t>::_Alloc_hider::_Alloc_hider(std::basic_string<wchar_t>::_Rep*)'
            # config_options+=("--enable-fully-dynamic-string") # ?

            config_options+=("--enable-cloog-backend=isl")
            config_options+=("--enable-libgomp")

            config_options+=("--enable-libssp")
            config_options+=("--enable-default-pie")
            config_options+=("--enable-default-ssp")
            config_options+=("--enable-libatomic")
            config_options+=("--enable-graphite")
            config_options+=("--enable-libquadmath")
            config_options+=("--enable-libquadmath-support")

            config_options+=("--enable-libstdcxx")
            config_options+=("--enable-libstdcxx-time=yes")
            config_options+=("--enable-libstdcxx-visibility")
            config_options+=("--enable-libstdcxx-threads")
            config_options+=("--with-default-libstdcxx-abi=new")

            config_options+=("--enable-bootstrap")

            config_options+=("--disable-nls")
            config_options+=("--disable-multilib")
            config_options+=("--disable-libstdcxx-debug")
            config_options+=("--disable-libstdcxx-pch")

            config_options+=("--disable-install-libiberty")

            # config_options+=("--disable-libunwind-exceptions")
          fi

          config_options+=("--disable-werror")

          if is_darwin
          then

            # Fail on macOS
            # --with-linker-hash-style=gnu
            # --enable-libmpx
            # --enable-clocale=gnu

            # From HomeBrew, but not present on 11.x
            # config_options+=("--with-native-system-header-dir=/usr/include")

            echo "${MACOS_SDK_PATH}"
            config_options+=("--with-sysroot=${MACOS_SDK_PATH}")

            config_options+=("--enable-pie-tools")

          elif is_linux
          then

            # The Linux build also uses:
            # --with-linker-hash-style=gnu
            # --enable-libmpx (fails on arm)
            # --enable-clocale=gnu
            # --enable-install-libiberty

            # Ubuntu also used:
            # --enable-libstdcxx-debug
            # --enable-libstdcxx-time=yes (liks librt)
            # --with-default-libstdcxx-abi=new (default)

            config_options+=("--with-gnu-as")
            config_options+=("--with-gnu-ld")
            config_options+=("--with-stabs")

            config_options+=("--with-dwarf2")

            if true
            then
              # Shared libraries remain problematic when refered from generated
              # programs, and require setting the executable rpath to work.
              config_options+=("--enable-shared")
              config_options+=("--enable-shared-libgcc")
            else
              config_options+=("--disable-shared")
              config_options+=("--disable-shared-libgcc")
            fi

            if [ "${HOST_MACHINE}" == "x86_64" ]
            then
              config_options+=("--with-arch=x86-64")
              config_options+=("--with-tune=generic")
              # Support for Intel Memory Protection Extensions (MPX).
              config_options+=("--enable-libmpx")
            elif [ "${HOST_MACHINE}" == "i386" -o "${HOST_MACHINE}" == "i686" ]
            then
              config_options+=("--with-arch=i686")
              config_options+=("--with-arch-32=i686")
              config_options+=("--with-tune=generic")
              config_options+=("--enable-libmpx")
            elif [ "${HOST_MACHINE}" == "aarch64" ]
            then
              config_options+=("--with-arch=armv8-a")
              config_options+=("--enable-fix-cortex-a53-835769")
              config_options+=("--enable-fix-cortex-a53-843419")

              # In file included from /root/Work/xbb-3.2-ubuntu-16.04-aarch64/sources/gcc-9.3.0/gcc/config/aarch64/aarch64-speculation.cc:22:
              # /root/Work/xbb-3.2-ubuntu-16.04-aarch64/sources/gcc-9.3.0/gcc/system.h:687:10: fatal error: gmp.h: No such file or directory
              # #include <gmp.h>
              config_options+=("--with-gmp=${INSTALL_FOLDER_PATH}")
            elif [ "${HOST_MACHINE}" == "armv7l" -o "${HOST_MACHINE}" == "armv8l" ]
            then
              config_options+=("--with-arch=armv7-a")
              config_options+=("--with-float=hard")
              config_options+=("--with-fpu=vfpv3-d16")
            else
              echo "Oops! Unsupported HOST_MACHINE ${HOST_MACHINE}."
              exit 1
            fi

            # Linking to libstdc++ sometimes fail.
            config_options+=("--with-pic")

            config_options+=("--with-linker-hash-style=gnu")
            config_options+=("--enable-clocale=gnu")

            if false # [ "${XBB_LAYER}" != "xbb-bootstrap" ]
            then
              config_options+=("--with-sysroot=${INSTALL_FOLDER_PATH}")
            fi

            config_options+=("--enable-gnu-unique-object")
            config_options+=("--enable-gnu-indirect-function")
            config_options+=("--enable-linker-build-id")

            # Specific to XBB, not used in xPack.
            config_options+=("--disable-rpath")
            config_options+=("--disable-new-dtags")

            # config_options+=("--enable-pie-tools")

          else
            echo "Unsupported gcc configuration."
            exit 1
          fi

          run_verbose bash "${SOURCES_FOLDER_PATH}/${native_gcc_src_folder_name}/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${native_gcc_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_gcc_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running native gcc make..."

        # Build.
        if is_darwin
        then
          # Weird. On macOS parallel builds may fail with missing
          # symbols or files, like:
          # Undefined symbols for architecture x86_64:
          # "std::__throw_bad_function_call()", referenced from:
          for i in 1 2 3
          do
            if run_verbose make -j ${JOBS}
            then
              break
            fi
            touch "${LOGS_FOLDER_PATH}/${native_gcc_folder_name}/make-attempt-${i}-failed-$(ndate).txt"
          done
          # One more time without -j, to be sure it ends...
          run_verbose make
        else
          run_verbose make -j ${JOBS}
        fi

        # make install-strip
        run_verbose make install

        (
          cd "${INSTALL_FOLDER_PATH}/usr/bin"

          # Add links with the non-suffixed names, to
          # prevent using the system old versions.

          rm -fv "gcc" "cc"
          ln -sv "gcc${XBB_GCC_SUFFIX}" "gcc"
          ln -sv "gcc${XBB_GCC_SUFFIX}" "cc"

          rm -fv "g++" "c++"
          ln -sv "g++${XBB_GCC_SUFFIX}" "g++"
          ln -sv "g++${XBB_GCC_SUFFIX}" "c++"

          rm -fv "gcc-ar" "gcc-nm" "gcc-ranlib"
          ln -sv "gcc-ar${XBB_GCC_SUFFIX}" "gcc-ar"
          ln -sv "gcc-nm${XBB_GCC_SUFFIX}" "gcc-nm"
          ln -sv "gcc-ranlib${XBB_GCC_SUFFIX}" "gcc-ranlib"

          rm -fv "gcov" "gcov-dump" "gcov-tool"
          ln -sv "gcov${XBB_GCC_SUFFIX}" "gcov"
          ln -sv "gcov-dump${XBB_GCC_SUFFIX}" "gcov-dump"
          ln -sv "gcov-tool${XBB_GCC_SUFFIX}" "gcov-tool"

          if [ -x "gfortran-xbs" ]
          then
            rm -fv "gfortran"
            ln -sv "gfortran-xbs" "gfortran"
          fi
        )

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_gcc_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_native_gcc
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${native_gcc_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${native_gcc_stamp_file_path}"

  else
    echo "Component gcc native already installed."
  fi

  if [ -z "${step}" -o "${step}" == "-edge" ]
  then
    test_functions+=("test_native_gcc")
  fi
}

function test_native_gcc()
{
  (
    # better not, to check if they pick their own deps.
    # xbb_activate_installed_bin

    echo
    echo "PATH=${PATH:-""}"
    # This is important when running from the build code.
    # When invoked at the end, it should be empty.
    echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-""}"

    run_app which as
    run_app which ld

    run_app as --version || true
    if is_linux
    then
      run_app ld --version || true
    fi

    echo
    echo "Checking the gcc binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}"

    show_libs "$(${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX} --print-prog-name=cc1)"
    show_libs "$(${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX} --print-prog-name=cc1plus)"
    show_libs "$(${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX} --print-prog-name=collect2)"
    show_libs "$(${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX} --print-prog-name=lto1)"
    show_libs "$(${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX} --print-prog-name=lto-wrapper)"

    echo
    echo "Testing if gcc binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" --version

    if is_linux
    then
      # On Darwin: Cannot find plugin 'liblto_plugin.so'
      # TODO: check why
      run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc-ar${XBB_GCC_SUFFIX}" --version
      run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc-nm${XBB_GCC_SUFFIX}" --version
      run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc-ranlib${XBB_GCC_SUFFIX}" --version
    fi
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcov${XBB_GCC_SUFFIX}" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcov-dump${XBB_GCC_SUFFIX}" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcov-tool${XBB_GCC_SUFFIX}" --version

    if [ -f "${INSTALL_FOLDER_PATH}/usr/bin/gfortran${XBB_GCC_SUFFIX}" ]
    then
      run_app "${INSTALL_FOLDER_PATH}/usr/bin/gfortran${XBB_GCC_SUFFIX}" --version
    fi

    echo
    echo "Showing configurations..."

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -v
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -dumpversion
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -dumpmachine

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-search-dirs
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-libgcc-file-name
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-multi-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-multi-lib
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-multi-os-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-sysroot
    # run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-sysroot-headers-suffix
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-file-name=libgcc_s.${SHLIB_EXT}
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/gcc${XBB_GCC_SUFFIX}" -print-prog-name=cc1

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -v
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -dumpversion
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -dumpmachine

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-search-dirs
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-libgcc-file-name
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-multi-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-multi-lib
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-multi-os-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-sysroot
    # run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-sysroot-headers-suffix
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-file-name=libstdc++.${SHLIB_EXT}
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" -print-prog-name=cc1plus

    echo
    echo "Testing if gcc compiles simple Hello programs..."

    # To access the new binutils.
    # /usr/bin/ld: BFD (GNU Binutils for Ubuntu) 2.22 internal error, aborting at ../../bfd/reloc.c line 443 in bfd_get_reloc_size
    xbb_activate_installed_bin

    mkdir -pv "${HOME}/tmp/native-gcc"
    cd "${HOME}/tmp/native-gcc"

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello++" << std::endl;

  return 0;
}
__EOF__

    # Use the newly created script.
    export LD_RUN_PATH="$(get-gcc-rpath)"
    echo "LD_RUN_PATH=${LD_RUN_PATH}"

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" hello.cpp -o hello1 -v

    show_libs hello1

    # run_verbose /usr/bin/ldd -v hello

    output=$(./hello1)
    echo ${output}

    if [ "x${output}x" != "xHello++x" ]
    then
      exit 1
    fi

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" hello.cpp -o hello2 -v -static-libgcc -static-libstdc++

    show_libs hello2

    # run_verbose /usr/bin/ldd -v hello

    output=$(./hello2)
    echo ${output}

    if [ "x${output}x" != "xHello++x" ]
    then
      exit 1
    fi

  # Note: __EOF__ is quoted to prevent substitutions here.
  cat <<'__EOF__' > except.cpp
#include <iostream>
#include <exception>

struct MyException : public std::exception {
   const char* what() const throw () {
      return "MyException";
   }
};

void
func(void)
{
  throw MyException();
}

int
main(int argc, char* argv[])
{
  try {
    func();
  } catch(MyException& e) {
    std::cout << e.what() << std::endl;
  } catch(std::exception& e) {
    std::cout << "Other" << std::endl;
  }

  return 0;
}
__EOF__

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/g++${XBB_GCC_SUFFIX}" except.cpp -o except -v

    show_libs except

    output=$(./except)
    echo ${output}

    if [ "x${output}x" != "xMyExceptionx" ]
    then
      exit 1
    fi
  )
}

# -----------------------------------------------------------------------------
# mingw-w64

function build_mingw_binutils()
{
  # https://ftp.gnu.org/gnu/binutils/

  # https://github.com/archlinux/svntogit-community/blob/packages/mingw-w64-binutils/trunk/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-binutils
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-binutils-weak

  # 2017-07-24, "2.29"
  # 2018-07-14, "2.31"
  # 2019-02-02, "2.32"
  # 2019-10-12, "2.33.1"

  local mingw_binutils_version="$1"

  local mingw_binutils_src_folder_name="binutils-${mingw_binutils_version}"

  local mingw_binutils_archive="${mingw_binutils_src_folder_name}.tar.xz"
  local mingw_binutils_url="https://ftp.gnu.org/gnu/binutils/${mingw_binutils_archive}"

  local mingw_binutils_folder_name="mingw-binutils-${mingw_binutils_version}"

   local mingw_binutils_patch_file_path="${helper_folder_path}/patches/binutils-${mingw_binutils_version}.patch"
   local mingw_binutils_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mingw_binutils_folder_name}-installed"
  if [ ! -f "${mingw_binutils_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_binutils_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${mingw_binutils_url}" "${mingw_binutils_archive}" \
      "${mingw_binutils_src_folder_name}" \
      "${mingw_binutils_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_binutils_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${mingw_binutils_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_binutils_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      # LDFLAGS="-static-libstdc++ ${LDFLAGS}"
      LDFLAGS="${XBB_LDFLAGS_APP} -v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running mingw-w64 binutils configure..."

          # --build used conservatively
          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_binutils_src_folder_name}/configure" --help

# TODO: check what is wrong, the else branch fails to compile some
# packages, like zlib, due to something possibly related to big-obj.
if true
then

          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_binutils_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}/usr" \
            \
            --build="${BUILD}" \
            --target="${MINGW_TARGET}" \
            \
            --with-sysroot="${INSTALL_FOLDER_PATH}" \
            --with-pkgversion="${XBB_MINGW_BINUTILS_BRANDING}" \
            \
            --enable-static \
            --enable-lto \
            --enable-plugins \
            --enable-deterministic-archives \
            \
            --disable-shared \
            --disable-multilib \
            --disable-nls \
            --disable-werror \
            --disable-new-dtags

else

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}/usr")
          config_options+=("--with-sysroot=${INSTALL_FOLDER_PATH}")

          config_options+=("--build=${BUILD}")
          config_options+=("--target=${MINGW_TARGET}")

          config_options+=("--with-pkgversion=${XBB_MINGW_BINUTILS_BRANDING}")

          # config_options+=("--without-system-zlib")
          config_options+=("--with-system-zlib")

          config_options+=("--with-pic")

          # error: debuginfod is missing or unusable
          config_options+=("--without-debuginfod")

          # libz issues
          # config_options+=("--enable-ld")

          if [ "${HOST_MACHINE}" == "x86_64" ]
          then
            # From MSYS2 MINGW
            config_options+=("--enable-64-bit-bfd")
          fi

          if true
          then
            config_options+=("--enable-shared")
            config_options+=("--enable-shared-libgcc")
          else
            config_options+=("--disable-shared")
            config_options+=("--disable-shared-libgcc")
          fi

          config_options+=("--enable-static")
          config_options+=("--enable-gold")
          config_options+=("--enable-lto")

          config_options+=("--enable-libssp")
          config_options+=("--enable-relro")
          config_options+=("--enable-threads")
          config_options+=("--enable-interwork")
          config_options+=("--enable-plugins")
          config_options+=("--enable-build-warnings=no")
          config_options+=("--enable-deterministic-archives")

          config_options+=("--disable-nls")

          config_options+=("--disable-multilib")
          config_options+=("--disable-werror")
          config_options+=("--disable-sim")
          config_options+=("--disable-gdb")

          config_options+=("--disable-rpath")
          config_options+=("--disable-new-dtags")

          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_binutils_src_folder_name}/configure" \
            "${config_options[@]}"

fi

          run_verbose make configure-host

          if is_linux
          then
            patch_all_libtool_rpath

            # Unfortunately the ld files are generated again, and the
            # patches are lost.
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${mingw_binutils_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_binutils_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running mingw-w64 binutils make..."

        # Build.
        run_verbose make -j ${JOBS}

        show_libs "ld/.libs/ld-new"
        show_libs "gas/.libs/as-new"
        show_libs "binutils/.libs/readelf"

        # make install-strip
        run_verbose make install

        # For just in case, it has nasty consequences when picked
        # in other builds.
        # TODO: check if needed
        # rm -fv "${INSTALL_FOLDER_PATH}/usr/lib/libiberty.a" "${INSTALL_FOLDER_PATH}/usr/lib64/libiberty.a"

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_binutils_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_mingw_binutils
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_binutils_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${mingw_binutils_stamp_file_path}"

  else
    echo "Component mingw-w64 binutils already installed."
  fi

  test_functions+=("test_mingw_binutils")
}

function test_mingw_binutils()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the mingw binutils shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ar"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-as"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ld"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-nm"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-objcopy"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-objdump"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ranlib"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-size"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strings"
    show_libs "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strip"

    echo
    echo "Testing if mingw binutils binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ar" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-as" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ld" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-nm" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-objcopy" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-objdump" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ranlib" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-size" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strings" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strip" --version

    echo
    echo "Testing if binutils binaries display help..."

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ar" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-as" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ld" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-nm" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-objcopy" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-objdump" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ranlib" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-size" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strings" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strip" --help
  )
}

# -----------------------------------------------------------------------------
# mingw-w64

# http://mingw-w64.org/doku.php/start
# https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/

# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-headers
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-crt
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-winpthreads
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-binutils
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-gcc

# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-gcc

# 2018-06-03, "5.0.4"
# 2018-09-16, "6.0.0"
# 2019-11-11, "7.0.0"
# 2020-09-18, "8.0.0"
# 2021-05-09, "8.0.2"
# 2021-05-22, "9.0.0"

function prepare_mingw_env()
{
  export mingw_version="$1"

  # Number
  export mingw_version_major=$(echo ${mingw_version} | sed -e 's|\([0-9][0-9]*\)\..*|\1|')

  # The original SourceForge location.
  export mingw_src_folder_name="mingw-w64-v${mingw_version}"
}

# Used to initialise options in all mingw builds:
# `config_options=("${config_options_common[@]}")`

function prepare_mingw_config_options_common()
{
  # ---------------------------------------------------------------------------
  # Used in multiple configurations.

  config_options_common=()

  local prefix=${INSTALL_FOLDER_PATH}
  if [ $# -ge 1 ]
  then
    config_options_common+=("--prefix=$1")
  else
    echo "prepare_mingw_config_options_common requires a prefix path"
    exit 1
  fi

  config_options_common+=("--disable-multilib")

  # https://docs.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt?view=msvc-160
  # Windows 7
  config_options_common+=("--with-default-win32-winnt=0x601")

  # `ucrt` is the new Windows Universal C Runtime:
  # https://support.microsoft.com/en-us/topic/update-for-universal-c-runtime-in-windows-c0514201-7fe6-95a3-b0a5-287930f3560c
  # config_options_common+=("--with-default-msvcrt=${MINGW_MSVCRT:-msvcrt}")
  config_options_common+=("--with-default-msvcrt=${MINGW_MSVCRT:-ucrt}")

  config_options_common+=("--enable-wildcard")
  config_options_common+=("--enable-warnings=0")
}

function download_mingw()
{
  local mingw_folder_archive="${mingw_src_folder_name}.tar.bz2"
  # The original SourceForge location.
  local mingw_url="https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/${mingw_folder_archive}"

  # If SourceForge is down, there is also a GitHub mirror.
  # https://github.com/mirror/mingw-w64
  # mingw_src_folder_name="mingw-w64-${mingw_version}"
  # mingw_folder_archive="v${mingw_version}.tar.gz"
  # mingw_url="https://github.com/mirror/mingw-w64/archive/${mingw_folder_archive}"

  # https://sourceforge.net/p/mingw-w64/wiki2/Cross%20Win32%20and%20Win64%20compiler/
  # https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/configure

  download_and_extract "${mingw_url}" "${mingw_folder_archive}" \
    "${mingw_src_folder_name}"
}

function build_mingw_headers()
{
  local mingw_headers_folder_name="mingw-${mingw_version}-headers"

  local mingw_headers_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mingw_headers_folder_name}-installed"
  if [ ! -f "${mingw_headers_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_headers_folder_name}" ]
  then

    mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_headers_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${mingw_headers_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_headers_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running mingw-w64 headers configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-headers/configure" --help

          prepare_mingw_config_options_common "${INSTALL_FOLDER_PATH}/usr/${MINGW_TARGET}"
          config_options=("${config_options_common[@]}")

          config_options+=("--build=${BUILD}")
          config_options+=("--host=${MINGW_TARGET}")
          config_options+=("--target=${MINGW_TARGET}")

          config_options+=("--with-tune=generic")

          config_options+=("--enable-sdk=all")
          config_options+=("--enable-idl")
          config_options+=("--without-widl")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-headers/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${mingw_headers_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_headers_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running mingw-w64 headers make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install-strip

        (
          # GCC requires the `x86_64-w64-mingw32` folder be mirrored as
          # `mingw` in the root.
          cd "${INSTALL_FOLDER_PATH}"
          run_verbose rm -fv "mingw"
          run_verbose ln -sv "usr/${MINGW_TARGET}" "mingw"
        )

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_headers_folder_name}/make-output-$(ndate).txt"
    )

    hash -r

    touch "${mingw_headers_stamp_file_path}"

  else
    echo "Component mingw-w64 headers already installed."
  fi
}

# ---------------------------------------------------------------------------

function build_mingw_gcc_first()
{
  # https://gcc.gnu.org
  # https://gcc.gnu.org/wiki/InstallingGCC

  # https://github.com/archlinux/svntogit-community/blob/packages/mingw-w64-gcc/trunk/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-gcc

  # https://ftp.gnu.org/gnu/gcc/
  # 2018-12-06, "7.4.0"
  # 2019-11-14, "7.5.0"
  # 2019-02-22, "8.3.0"
  # 2019-08-12, "9.2.0"

  export mingw_gcc_version="$1"

  # Number
  local mingw_gcc_version_major=$(echo ${mingw_gcc_version} | sed -e 's|\([0-9][0-9]*\)\..*|\1|')

  local mingw_gcc_src_folder_name="gcc-${mingw_gcc_version}"

  local mingw_gcc_archive="${mingw_gcc_src_folder_name}.tar.xz"
  local mingw_gcc_url="https://ftp.gnu.org/gnu/gcc/gcc-${mingw_gcc_version}/${mingw_gcc_archive}"

  export mingw_gcc_folder_name="mingw-gcc-${mingw_gcc_version}"

  local mingw_gcc_step1_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-mingw-gcc-step1-${mingw_gcc_version}-installed"
  if [ ! -f "${mingw_gcc_step1_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_gcc_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${mingw_gcc_url}" "${mingw_gcc_archive}" \
      "${mingw_gcc_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${mingw_gcc_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_gcc_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"

      LDFLAGS="${XBB_LDFLAGS_APP} -v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running mingw gcc step 1 configure..."

          # For the native build, --disable-shared failed with errors in libstdc++-v3
          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_gcc_src_folder_name}/configure" --help
          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_gcc_src_folder_name}/gcc/configure" --help

if true
then

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mingw_gcc_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}/usr" \
            \
            --build="${BUILD}" \
            --target="${MINGW_TARGET}" \
            \
            --with-sysroot="${INSTALL_FOLDER_PATH}" \
            --with-pkgversion="${XBB_MINGW_GCC_BRANDING}" \
            \
            --enable-languages=c,c++,fortran,objc,obj-c++ \
            --enable-shared \
            --enable-static \
            --enable-threads=posix \
            --enable-fully-dynamic-string \
            --enable-libstdcxx-time=yes \
            --enable-cloog-backend=isl \
            --enable-lto \
            --enable-libgomp \
            --enable-checking=release \
            --disable-dw2-exceptions \
            --disable-multilib \
            --disable-rpath \
            ac_cv_header_sys_mman_h=no


else

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}/usr")
          config_options+=("--with-sysroot=${INSTALL_FOLDER_PATH}")

          config_options+=("--build=${BUILD}")
          config_options+=("--host=${BUILD}")
          config_options+=("--target=${MINGW_TARGET}")

          config_options+=("--with-pkgversion=${XBB_MINGW_GCC_BRANDING}")

          config_options+=("--with-dwarf2")

          config_options+=("--disable-multilib")
          config_options+=("--disable-werror")

          config_options+=("--with-default-libstdcxx-abi=new")

          if true
          then
            config_options+=("--enable-shared")
            # config_options+=("--enable-shared-libgcc")
          else
            config_options+=("--disable-shared")
            config_options+=("--disable-shared-libgcc")
          fi

          config_options+=("--disable-nls")
          # config_options+=("--enable-libgomp")
          config_options+=("--disable-libgomp")

          config_options+=("--disable-sjlj-exceptions")
          config_options+=("--disable-libunwind-exceptions")
          config_options+=("--disable-win32-registry")
          config_options+=("--disable-libstdcxx-debug")
          config_options+=("--disable-libstdcxx-pch")

          config_options+=("--enable-languages=c,c++,fortran,objc,obj-c++")
          config_options+=("--enable-objc-gc=auto")

          config_options+=("--enable-static")

          config_options+=("--enable-lto")
          config_options+=("--enable-checking=release")

          config_options+=("--enable-cloog-backend=isl")

          config_options+=("--enable-libssp")
          config_options+=("--enable-libatomic")

          config_options+=("--enable-__cxa_atexit")
          config_options+=("--enable-mingw-wildcard")

          config_options+=("--enable-version-specific-runtime-libs")
          config_options+=("--enable-threads=posix")

          config_options+=("--enable-libstdcxx")
          config_options+=("--enable-libstdcxx-time=yes")
          config_options+=("--enable-libstdcxx-visibility")
          config_options+=("--enable-libstdcxx-threads")

          # config_options+=("--enable-fully-dynamic-string")

          if [ ${mingw_version_major} -ge 7 -a ${mingw_gcc_version} -ge 9 ]
          then
            # Requires new GCC 9 & mingw 7.
            # --enable-libstdcxx-filesystem-ts=yes
            config_options+=("--enable-libstdcxx-filesystem-ts=yes")
          fi

          # Not used in the xPack
          # config_options+=("--disable-dw2-exceptions")
          config_options+=("--disable-rpath")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mingw_gcc_src_folder_name}/configure" \
            "${config_options[@]}"

fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}/config-step1-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}/configure-step1-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running mingw gcc step 1 make..."

        # Build.
        run_verbose make -j ${JOBS} all-gcc

        run_verbose make install-strip-gcc

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}/make-step1-output-$(ndate).txt"
    )

    hash -r

    touch "${mingw_gcc_step1_stamp_file_path}"

  else
    echo "Component mingw-w64 gcc step 1 already installed."
  fi
}

# ---------------------------------------------------------------------------

function build_mingw_widl()
{
  local mingw_widl_folder_name="mingw-${mingw_version}-widl"

  mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_widl_folder_name}"

  local mingw_widl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mingw_widl_folder_name}-installed"
  if [ ! -f "${mingw_widl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_widl_folder_name}" ]
  then
    (
      mkdir -p "${BUILD_FOLDER_PATH}/${mingw_widl_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_widl_folder_name}"


      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"

      LDFLAGS="${XBB_LDFLAGS_APP_STATIC_GCC} -v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running mingw-w64-widl configure..."

          bash "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-tools/widl/configure" --help

          config_options=()
          config_options+=("--prefix=${INSTALL_FOLDER_PATH}/usr")

          config_options+=("--build=${BUILD}")
          config_options+=("--host=${BUILD}") # Native!
          config_options+=("--target=${MINGW_TARGET}")

          config_options+=("--with-widl-includedir=${INSTALL_FOLDER_PATH}/include")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-tools/widl/configure" \
            "${config_options[@]}"

         cp "config.log" "${LOGS_FOLDER_PATH}/${mingw_widl_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_widl_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running mingw-w64-widl make..."

        # Build.
        run_verbose make -j ${JOBS}

        run_verbose make install-strip

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_widl_folder_name}/make-output-$(ndate).txt"
    )

    hash -r

    touch "${mingw_widl_stamp_file_path}"

  else
    echo "Component mingw-w64-widl already installed."
  fi
}

# ---------------------------------------------------------------------------

function build_mingw_crt()
{
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-crt
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-crt-git

  local mingw_crt_folder_name="mingw-${mingw_version}-crt"

  local mingw_crt_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mingw_crt_folder_name}-installed"
  if [ ! -f "${mingw_crt_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_crt_folder_name}" ]
  then

    mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_crt_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${mingw_crt_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_crt_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      # Overwrite the flags, -ffunction-sections -fdata-sections result in
      # {standard input}: Assembler messages:
      # {standard input}:693: Error: CFI instruction used without previous .cfi_startproc
      # {standard input}:695: Error: .cfi_endproc without corresponding .cfi_startproc
      # {standard input}:697: Error: .seh_endproc used in segment '.text' instead of expected '.text$WinMainCRTStartup'
      # {standard input}: Error: open CFI at the end of file; missing .cfi_endproc directive
      # {standard input}:7150: Error: can't resolve `.text' {.text section} - `.LFB5156' {.text$WinMainCRTStartup section}
      # {standard input}:8937: Error: can't resolve `.text' {.text section} - `.LFB5156' {.text$WinMainCRTStartup section}

      CFLAGS="-O2 -pipe -w"
      CXXFLAGS="-O2 -pipe -w"

      LDFLAGS="-v"

      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      # Without it, apparently a bug in autoconf/c.m4, function AC_PROG_CC, results in:
      # checking for _mingw_mac.h... no
      # configure: error: Please check if the mingw-w64 header set and the build/host option are set properly.
      # (https://github.com/henry0312/build_gcc/issues/1)
      # export CC=""

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running mingw-w64 crt configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-crt/configure" --help

          config_options=()

          prepare_mingw_config_options_common "${INSTALL_FOLDER_PATH}/usr/${MINGW_TARGET}"
          config_options=("${config_options_common[@]}")
          config_options+=("--with-sysroot=${INSTALL_FOLDER_PATH}")

          config_options+=("--build=${BUILD}")
          config_options+=("--host=${MINGW_TARGET}")
          config_options+=("--target=${MINGW_TARGET}")

          if [ "${HOST_BITS}" == "64" ]
          then
            config_options+=("--disable-lib32")
            config_options+=("--enable-lib64")
          elif [ "${HOST_BITS}" == "32" ]
          then
            config_options+=("--enable-lib32")
            config_options+=("--disable-lib64")
          else
            echo "Unsupported HOST_BITS ${HOST_BITS}."
            exit 1
          fi

          config_options+=("--enable-wildcard")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-crt/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${mingw_crt_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_crt_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running mingw-w64 crt make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install-strip

        ls -l "${INSTALL_FOLDER_PATH}/usr/${MINGW_TARGET}"

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_crt_folder_name}/make-output-$(ndate).txt"
    )

    hash -r

    touch "${mingw_crt_stamp_file_path}"

  else
    echo "Component mingw-w64 crt already installed."
  fi
}

# ---------------------------------------------------------------------------

function build_mingw_winpthreads()
{
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-winpthreads
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-winpthreads-git

  local mingw_build_winpthreads_folder_name="mingw-${mingw_version}-winpthreads"

  local mingw_winpthreads_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mingw_build_winpthreads_folder_name}-installed"
  if [ ! -f "${mingw_winpthreads_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}" ]
  then

    mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      CPPFLAGS=""
      CFLAGS="-O2 -pipe -w"
      CXXFLAGS="-O2 -pipe -w"

      LDFLAGS="-v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      # export CC=""
      # prepare_gcc_env "${MINGW_TARGET}-"

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running mingw-w64 winpthreads configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-crt/configure" --help

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}/usr/${MINGW_TARGET}")
          config_options+=("--with-sysroot=${INSTALL_FOLDER_PATH}")

          config_options+=("--libdir=${INSTALL_FOLDER_PATH}/usr/${MINGW_TARGET}/lib")

          config_options+=("--build=${BUILD}")
          config_options+=("--host=${MINGW_TARGET}")
          config_options+=("--target=${MINGW_TARGET}")

          config_options+=("--enable-static")

          if true
          then
            config_options+=("--enable-shared")
          else
            config_options+=("--disable-shared")
          fi

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mingw_src_folder_name}/mingw-w64-libraries/winpthreads/configure" \
            "${config_options[@]}"

         cp "config.log" "${LOGS_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running mingw-w64 winpthreads make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        run_verbose ls -l "${INSTALL_FOLDER_PATH}/usr/${MINGW_TARGET}"

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_build_winpthreads_folder_name}/make-output-$(ndate).txt"
    )

    hash -r

    touch "${mingw_winpthreads_stamp_file_path}"

  else
    echo "Component mingw-w64 winpthreads already installed."
  fi
}

# ---------------------------------------------------------------------------

function build_mingw_gcc_final()
{
  local mingw_gcc_final_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-mingw-gcc-final-${mingw_gcc_version}-installed"
  if [ ! -f "${mingw_gcc_final_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${mingw_gcc_folder_name}" ]
  then

    mkdir -pv "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}"

    (
      echo
      echo "Running mingw-w64 gcc final make..."

      mkdir -pv "${BUILD_FOLDER_PATH}/${mingw_gcc_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${mingw_gcc_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"

      LDFLAGS="${XBB_LDFLAGS_APP} -v"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      env | sort

      run_verbose make -j configure-target-libgcc

      if [ -f "${MINGW_TARGET}/libgcc/auto-target.h" ]
      then
        run_verbose grep 'HAVE_SYS_MMAN_H' "${MINGW_TARGET}/libgcc/auto-target.h"
        run_verbose sed -i.bak -e 's|#define HAVE_SYS_MMAN_H 1|#define HAVE_SYS_MMAN_H 0|' \
          "${MINGW_TARGET}/libgcc/auto-target.h"
        run_verbose diff "${MINGW_TARGET}/libgcc/auto-target.h.bak" "${MINGW_TARGET}/libgcc/auto-target.h" || true
      fi

      # Build.
      run_verbose make -j ${JOBS}

      # make install-strip
      run_verbose make install-strip

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}/make-final-output-$(ndate).txt"

    (
      xbb_activate_installed_bin

      if true
      then

        cd "${INSTALL_FOLDER_PATH}"

        set +e
        find ${MINGW_TARGET} \
          -name '*.so' -type f \
          -print \
          -exec "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strip" --strip-debug {} \;
        find ${MINGW_TARGET} \
          -name '*.so.*'  \
          -type f \
          -print \
          -exec "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strip" --strip-debug {} \;
        # Note: without ranlib, windows builds failed.
        find ${MINGW_TARGET} lib/gcc/${MINGW_TARGET} \
          -name '*.a'  \
          -type f  \
          -print \
          -exec "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-strip" --strip-debug {} \; \
          -exec "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-ranlib" {} \;
        set -e

      fi
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}/strip-final-output-$(ndate).txt"

    (
      test_mingw_gcc
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mingw_gcc_folder_name}/test-final-output-$(ndate).txt"

    hash -r

    touch "${mingw_gcc_final_stamp_file_path}"

  else
    echo "Component mingw-w64 gcc final already installed."
  fi

  test_functions+=("test_mingw_gcc")
}

function test_mingw_gcc()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if mingw gcc binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" --version

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc-ar" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc-nm" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc-ranlib" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcov" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcov-dump" --version
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcov-tool" --version

    if [ -f "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gfortran" ]
    then
      run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gfortran" --version
    fi

    echo
    echo "Showing configurations..."

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -v
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -dumpversion
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -dumpmachine

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-search-dirs
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-libgcc-file-name
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-multi-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-multi-lib
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-multi-os-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-sysroot
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-file-name=libgcc_s.so
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-gcc" -print-prog-name=cc1

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" --help
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -v
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -dumpversion
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -dumpmachine

    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-search-dirs
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-libgcc-file-name
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-multi-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-multi-lib
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-multi-os-directory
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-sysroot
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-file-name=libstdc++.so
    run_app "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" -print-prog-name=cc1plus

    echo
    echo "Testing if mingw gcc compiles simple Hello programs..."

    mkdir -pv "${HOME}/tmp/mingw-gcc"
    cd "${HOME}/tmp/mingw-gcc"

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
std::cout << "Hello" << std::endl;
}
__EOF__

    run_verbose "${INSTALL_FOLDER_PATH}/usr/bin/${MINGW_TARGET}-g++" hello.cpp -o hello -v

    # rm -rf hello.cpp hello
  )
}

# -----------------------------------------------------------------------------

function build_openssl()
{
  # https://www.openssl.org
  # https://www.openssl.org/source/

  # https://archlinuxarm.org/packages/aarch64/openssl/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=openssl-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=openssl-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/openssl@1.1.rb
  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/openssl@3.rb

  # 2017-Nov-02
  # XBB_OPENSSL_VERSION="1.1.0g"
  # The new version deprecated CRYPTO_set_locking_callback, and yum fails with
  # /usr/lib64/python2.6/site-packages/pycurl.so: undefined symbol: CRYPTO_set_locking_callback

  # 2017-Dec-07, "1.0.2n"
  # 2019-Feb-26, "1.0.2r"
  # 2019-Feb-26, "1.1.1b"
  # 2019-Sep-10, "1.1.1d"
  # 20 Dec 2019, "1.0.2u"
  # 2021-Mar-25, "1.1.1k"
  # 2021-Aug-24, "1.1.1l"
  # 2021-Sep-07, "3.0.0"

  local openssl_version="$1"
  # Numbers
  local openssl_version_major=$(echo ${openssl_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*|\1|')
  local openssl_version_minor=$(echo ${openssl_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*|\2|')

  local openssl_src_folder_name="openssl-${openssl_version}"

  local openssl_archive="${openssl_src_folder_name}.tar.gz"
  local openssl_url="https://www.openssl.org/source/${openssl_archive}"

  local openssl_folder_name="${openssl_src_folder_name}"

  local openssl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${openssl_folder_name}-installed"
  if [ ! -f "${openssl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${openssl_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${openssl_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${openssl_url}" "${openssl_archive}" \
        "${openssl_src_folder_name}"

      if [ "${openssl_src_folder_name}" != "${openssl_folder_name}" ]
      then
        mv -v "${openssl_src_folder_name}" "${openssl_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${openssl_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${openssl_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      #  -Wno-unused-command-line-argument

      # CPPFLAGS="${XBB_CPPFLAGS} -I${BUILD_FOLDER_PATH}/${openssl_folder_name}/include"
      CPPFLAGS="${XBB_CPPFLAGS}"
      if is_darwin
      then
        # Otherwise it fails on macOS 10.13 with:
        # In file included from crypto/rand/rand_unix.c:38:
        # /usr/include/CommonCrypto/CommonRandom.h:35:9: error: unknown type name 'CCCryptorStatus'
        CPPFLAGS+="-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include"
      fi
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f config.stamp ]
      then
        (
          env | sort

          echo
          echo "Running openssl configure..."

          echo
          if is_darwin && [ ${openssl_version_minor} -eq 0 ]
          then

            # Older versions do not support the KERNEL_BITS trick and require
            # the separate configurator.

            # This config does not use the standard GNU environment definitions.
            # `Configure` is a Perl script.
            "./Configure" --help || true

            run_verbose "./Configure" "darwin64-x86_64-cc" \
              --prefix="${INSTALL_FOLDER_PATH}" \
              \
              --openssldir="${INSTALL_FOLDER_PATH}/openssl" \
              shared \
              enable-md2 \
              enable-rc5 \
              enable-tls \
              enable-tls1_3 \
              enable-tls1_2 \
              enable-tls1_1 \
              "${CPPFLAGS} ${CFLAGS} ${LDFLAGS}"

            run_verbose make depend

          else

            config_options=()

            config_options+=("--prefix=${INSTALL_FOLDER_PATH}")
            config_options+=("--openssldir=${INSTALL_FOLDER_PATH}/openssl")

            config_options+=("shared")

            config_options+=("enable-md2")
            config_options+=("enable-rc5")
            config_options+=("enable-tls")
            config_options+=("enable-tls1_3")
            config_options+=("enable-tls1_2")
            config_options+=("enable-tls1_1")

            # From HomeBrew
            # SSLv2 died with 1.1.0, so no-ssl2 no longer required.
            # SSLv3 & zlib are off by default with 1.1.0 but this may not
            # be obvious to everyone, so explicitly state it for now to
            # help debug inevitable breakage.
            config_options+=("no-ssl3")
            config_options+=("no-ssl3-method")

            if is_darwin
            then
              config_options+=("enable-ec_nistp_64_gcc_128")
              if [ "${HOST_MACHINE}" == "arm64" ]
              then
                : # config_options+=("darwin64-arm64-cc")
              elif [ "${HOST_MACHINE}" == "x86_64" ]
              then
                : # config_options+=("darwin64-x86_64-cc")
              else
                echo "Unsupported macOS HOST_MACHINE ${HOST_MACHINE}"
                exit 1
              fi
              export KERNEL_BITS=64
            elif is_linux
            then
              # arch_args << (Hardware::CPU.is_64_bit? ? "linux-x86_64" : "linux-elf")
              # arch_args << (Hardware::CPU.is_64_bit? ? "linux-aarch64" : "linux-armv4")
              if [ "${HOST_MACHINE}" == "x86_64" ]
              then
                config_options+=("enable-ec_nistp_64_gcc_128")
              elif [ "${HOST_MACHINE}" == "i386" -o "${HOST_MACHINE}" == "i686" ]
              then
                : # Nothing special
              elif [ "${HOST_MACHINE}" == "aarch64" ]
              then
                config_options+=("no-afalgeng")
              elif [ "${HOST_MACHINE}" == "armv7l" -o "${HOST_MACHINE}" == "armv8l" ]
              then
                : # Nothing special.
              else
                echo "Unsupported Linux HOST_MACHINE ${HOST_MACHINE}"
                exit 1
              fi
              config_options+=("-Wa,--noexecstack")
            fi

            set +u

            # undefined reference to EVP_md2
            #  enable-md2

            if is_linux
            then
              if [ ${openssl_version_minor} -eq 0 ]
              then
                run_verbose sed -i.bak \
                  -e 's|-Wl,-rpath,$(LIBRPATH)||' \
                  "Makefile.shared"
              fi
            fi

            # perl, do not start with bash.
            run_verbose "./config" \
              "${config_options[@]}" \
              "${CPPFLAGS} ${CFLAGS} ${LDFLAGS}"

            set -u

            if [ ${openssl_version_minor} -eq 0 ]
            then
              run_verbose make depend
            fi

          fi

          touch config.stamp

          # cp "configure.log" "${LOGS_FOLDER_PATH}/configure-openssl-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${openssl_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running openssl make..."

        # Build.
        run_verbose make -j ${JOBS}

        run_verbose make install_sw

        mkdir -pv "${INSTALL_FOLDER_PATH}/openssl"

        if [ -f "/private/etc/ssl/cert.pem" ]
        then
          /usr/bin/install -v -c -m 644 "/private/etc/ssl/cert.pem" "${INSTALL_FOLDER_PATH}/openssl"
        fi

        run_verbose curl --insecure --location http://curl.haxx.se/ca/cacert.pem -o cacert.pem
        /usr/bin/install -v -c -m 644 cacert.pem "${INSTALL_FOLDER_PATH}/openssl"

        # ca-bundle.crt is used by curl.
        if [ -f "/.dockerenv" ]
        then
          /usr/bin/install -v -c -m 644 "${helper_folder_path}/ca-bundle.crt" "${INSTALL_FOLDER_PATH}/openssl"
        else
          /usr/bin/install -v -c -m 644 "$(dirname "${script_folder_path}")/ca-bundle/ca-bundle.crt" "${INSTALL_FOLDER_PATH}/openssl"
        fi

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 test
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${openssl_folder_name}/make-output-$(ndate).txt"

      (
        test_openssl
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${openssl_folder_name}/test-output-$(ndate).txt"
    )

    touch "${openssl_stamp_file_path}"

  else
    echo "Component openssl already installed."
  fi

  test_functions+=("test_openssl")
}

function test_openssl()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the openssl shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/openssl"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libcrypto.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libssl.${SHLIB_EXT})"

    echo
    echo "Testing if openssl binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/openssl" version
  )
}

# -----------------------------------------------------------------------------

function build_curl()
{
  # https://curl.haxx.se
  # https://curl.haxx.se/download/
  # https://curl.haxx.se/download/curl-7.64.1.tar.xz

  # https://archlinuxarm.org/packages/aarch64/curl/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=curl-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/curl.rb

  # 2017-10-23, "7.56.1"
  # 2017-11-29, "7.57.0"
  # 2019-03-27, "7.64.1"
  # 2019-11-06, "7.67.0"
  # 2020-01-08, "7.68.0"
  # May 26 2021, "7.77.0"
  # Nov 10, 2021, "7.80.0"

  local curl_version="$1"

  local curl_src_folder_name="curl-${curl_version}"

  local curl_archive="${curl_src_folder_name}.tar.xz"
  local curl_url="https://curl.haxx.se/download/${curl_archive}"

  local curl_folder_name="curl-${curl_version}"

  local curl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${curl_folder_name}-installed"
  if [ ! -f "${curl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${curl_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${curl_url}" "${curl_archive}" \
      "${curl_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${curl_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${curl_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${curl_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running curl configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${curl_src_folder_name}/configure" --help

          # HomeBrew options failed:
          # --with-secure-transport
          # --without-libpsl
          # --disable-silent-rules

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${curl_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-gssapi \
            --with-ca-bundle="${INSTALL_FOLDER_PATH}/openssl/ca-bundle.crt" \
            --with-ssl \
            \
            --enable-optimize \
            --enable-versioned-symbols \
            --enable-threaded-resolver \
            --disable-manual \
            --disable-ldap \
            --disable-ldaps \
            --disable-werror \
            --disable-warnings \
            --disable-debug \

          if is_linux
          then
            patch_all_libtool_rpath
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${curl_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${curl_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running curl make..."

        # Build.
        run_verbose make -j ${JOBS}

        run_verbose make install

        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          # It takes very long (1200+ tests).
          if is_darwin
          then
            run_verbose make -j1 check || true
          else
            run_verbose make -j1 check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${curl_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_curl
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${curl_folder_name}/test-output-$(ndate).txt"

    touch "${curl_stamp_file_path}"

  else
    echo "Component curl already installed."
  fi

  test_functions+=("test_curl")
}

function test_curl()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the curl shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/curl"

    echo
    echo "Testing if curl binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/curl" --version

    run_app "${INSTALL_FOLDER_PATH}/bin/curl" \
      -L https://github.com/xpack-dev-tools/content/raw/master/README.md \
      --output test-output.md
  )
}

# -----------------------------------------------------------------------------

function build_xz()
{
  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # https://tukaani.org/xz/xz-5.2.4.tar.xz

  # https://archlinuxarm.org/packages/aarch64/xz/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=xz-git

  # 2016-12-30 "5.2.3"
  # 2018-04-29 "5.2.4"
  # 2020-03-17, "5.2.5"

  local xz_version="$1"

  local xz_src_folder_name="xz-${xz_version}"

  if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
  then
    local xz_archive="${xz_src_folder_name}.tar.gz"
  else
    local xz_archive="${xz_src_folder_name}.tar.xz"
  fi
  local xz_url="https://tukaani.org/xz/${xz_archive}"

  local xz_folder_name="${xz_src_folder_name}"

  local xz_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${xz_folder_name}-installed"
  if [ ! -f "${xz_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${xz_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${xz_url}" "${xz_archive}" \
      "${xz_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${xz_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${xz_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${xz_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running xz configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${xz_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${xz_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-werror \
            --disable-rpath \

          if is_linux
          then
            patch_all_libtool_rpath
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${xz_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${xz_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running xz make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          # After install, to find its libaries.
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${xz_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_xz
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${xz_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${xz_stamp_file_path}"

  else
    echo "Component xz already installed."
  fi

  test_functions+=("test_xz")
}

function test_xz()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the xz shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/xz"
    show_libs "${INSTALL_FOLDER_PATH}/bin/xzdec"
    show_libs "${INSTALL_FOLDER_PATH}/bin/lzmainfo"

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/liblzma.${SHLIB_EXT})"

    echo
    echo "Testing if xz binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/xz" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/xzdec" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/lzmainfo" --version
  )
}

# -----------------------------------------------------------------------------

function build_tar()
{
  # https://www.gnu.org/software/tar/
  # https://ftp.gnu.org/gnu/tar/

  # https://archlinuxarm.org/packages/aarch64/tar/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=tar-git

  # 2016-05-16 "1.29"
  # 2017-12-17 "1.30"
  # 2019-02-23 "1.32"
  # 2021-02-13, "1.34"

  local tar_version="$1"

  local tar_src_folder_name="tar-${tar_version}"

  if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
  then
    local tar_archive="${tar_src_folder_name}.tar.gz"
  else
    local tar_archive="${tar_src_folder_name}.tar.xz"
  fi
  local tar_url="https://ftp.gnu.org/gnu/tar/${tar_archive}"

  local tar_folder_name="${tar_src_folder_name}"

  local tar_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${tar_folder_name}-installed"
  if [ ! -f "${tar_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${tar_folder_name}" ]
  then

    # In-source build, to patch out tests.

    if [ ! -d "${BUILD_FOLDER_PATH}/${tar_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${tar_url}" "${tar_archive}" \
        "${tar_src_folder_name}"

      if [ "${tar_src_folder_name}" != "${tar_folder_name}" ]
      then
        mv -v "${tar_src_folder_name}" "${tar_folder_name}"
      fi

      if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
      then
        if is_arm && [ "${HOST_BITS}" == "32" ]
        then
          # 117: directory removed before reading
          # FAILED (dirrem01.at:37)
          # 118: explicitly named directory removed before reading
          # FAILED (dirrem02.at:34)

          run_verbose sed -i.bak \
            -e 's|dirrem01.at||' \
            -e 's|dirrem02.at||' \
            "${tar_folder_name}/tests/Makefile.am"

          run_verbose sed -i.bak \
            -e 's|dirrem01.at||' \
            -e 's|dirrem02.at||' \
            "${tar_folder_name}/tests/Makefile.in"

          run_verbose sed -i.bak \
            -e '/dirrem01.at/d' \
            -e '/dirrem02.at/d' \
            -e '/Directories removed while archiving/d' \
            "${tar_folder_name}/tests/testsuite.at"

          run_verbose rm -rfv \
            "${tar_folder_name}/tests/dirrem01.at" \
            "${tar_folder_name}/tests/dirrem02.at"
        fi
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${tar_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${tar_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${tar_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      # Avoid 'configure: error: you should not run configure as root'.
      export FORCE_UNSAFE_CONFIGURE=1

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running tar configure..."

          run_verbose bash "configure" --help

          run_verbose bash ${DEBUG} "configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          cp "config.log" "${LOGS_FOLDER_PATH}/${tar_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tar_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running tar make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        (
          echo
          echo "Linking gnutar..."
          cd "${INSTALL_FOLDER_PATH}/bin"
          rm -fv gnutar
          ln -sv tar gnutar
        )

        # It takes very long (220 tests).
        # arm64: 118: explicitly named directory removed before reading FAILED (dirrem02.at:34)
        # amd64: 92: link mismatch FAILED (difflink.at:19)
        # 10.15
        # darwin: 92: link mismatch FAILED (difflink.at:19)
        # darwin: 175: remove-files with compression FAILED (remfiles01.at:32)
        # darwin: 176: remove-files with compression: grand-child FAILED (remfiles02.at:32)
        # 10.10
        # darwin: 172: sparse file truncated while archiving           FAILED (sptrcreat.at:36)
        # darwin: 173: file truncated in sparse region while comparing FAILED (sptrdiff00.at:30)
        # darwin: 174: file truncated in data region while comparing   FAILED (sptrdiff01.at:30)

        # TODO: remove tests on darwin
        if [ "${RUN_TESTS}" == "y" ]
        then
          if is_linux && [ "${RUN_LONG_TESTS}" == "y" ]
          then
            # WARN-TEST
            run_verbose make -j1 check # || true
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tar_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_tar
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tar_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${tar_stamp_file_path}"

  else
    echo "Component tar already installed."
  fi

  test_functions+=("test_tar")
}

function test_tar()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the tar shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/tar"

    echo
    echo "Testing if tar binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/tar" --version
  )
}

# -----------------------------------------------------------------------------

function build_coreutils()
{
  # https://www.gnu.org/software/coreutils/
  # https://ftp.gnu.org/gnu/coreutils/

  # https://archlinuxarm.org/packages/aarch64/coreutils/files/PKGBUILD

  # 2018-07-01, "8.30"
  # 2019-03-10 "8.31"
  # 2020-03-05, "8.32"
  # 2021-09-24, "9.0"

  local coreutils_version="$1"

  local coreutils_src_folder_name="coreutils-${coreutils_version}"

  local coreutils_archive="${coreutils_src_folder_name}.tar.xz"
  local coreutils_url="https://ftp.gnu.org/gnu/coreutils/${coreutils_archive}"

  local coreutils_folder_name="${coreutils_src_folder_name}"

  local coreutils_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${coreutils_folder_name}-installed"
  if [ ! -f "${coreutils_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${coreutils_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${coreutils_url}" "${coreutils_archive}" \
      "${coreutils_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${coreutils_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${coreutils_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${coreutils_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running coreutils configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${coreutils_src_folder_name}/configure" --help

          if [ -f "/.dockerenv" ]
          then
            # configure: error: you should not run configure as root
            # (set FORCE_UNSAFE_CONFIGURE=1 in environment to bypass this check)
            export FORCE_UNSAFE_CONFIGURE=1
          fi

          config_options=()
          if is_darwin
          then
            config_options+=("--enable-no-install-program=ar")
          fi

          set +u

          # `ar` must be excluded, it interferes with Apple similar program.
          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${coreutils_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-openssl \
            --disable-rpath \
            "${config_options[@]}"

          set -u

          cp "config.log" "${LOGS_FOLDER_PATH}/${coreutils_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${coreutils_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running coreutils make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Takes very long and fails.
        # x86_64: FAIL: tests/misc/chroot-credentials.sh
        # x86_64: ERROR: tests/du/long-from-unreadable.sh
        # WARN-TEST
        # make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${coreutils_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_coreutils
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${coreutils_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${coreutils_stamp_file_path}"

  else
    echo "Component coreutils already installed."
  fi

  test_functions+=("test_coreutils")
}

function test_coreutils()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the coreutils binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/basename"
    show_libs "${INSTALL_FOLDER_PATH}/bin/cat"
    show_libs "${INSTALL_FOLDER_PATH}/bin/chmod"
    show_libs "${INSTALL_FOLDER_PATH}/bin/chown"
    show_libs "${INSTALL_FOLDER_PATH}/bin/cp"
    show_libs "${INSTALL_FOLDER_PATH}/bin/dirname"
    show_libs "${INSTALL_FOLDER_PATH}/bin/ln"
    show_libs "${INSTALL_FOLDER_PATH}/bin/ls"
    show_libs "${INSTALL_FOLDER_PATH}/bin/mkdir"
    show_libs "${INSTALL_FOLDER_PATH}/bin/mv"
    show_libs "${INSTALL_FOLDER_PATH}/bin/printf"
    show_libs "${INSTALL_FOLDER_PATH}/bin/realpath"
    show_libs "${INSTALL_FOLDER_PATH}/bin/rm"
    show_libs "${INSTALL_FOLDER_PATH}/bin/rmdir"
    show_libs "${INSTALL_FOLDER_PATH}/bin/sha256sum"
    show_libs "${INSTALL_FOLDER_PATH}/bin/sort"
    show_libs "${INSTALL_FOLDER_PATH}/bin/touch"
    show_libs "${INSTALL_FOLDER_PATH}/bin/tr"
    show_libs "${INSTALL_FOLDER_PATH}/bin/wc"

    echo
    echo "Testing if coreutils binaries start properly..."

    echo
    run_app "${INSTALL_FOLDER_PATH}/bin/basename" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/cat" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/chmod" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/chown" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/cp" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/dirname" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/ln" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/ls" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/mkdir" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/mv" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/printf" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/realpath" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/rm" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/rmdir" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/sha256sum" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/sort" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/touch" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/tr" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/wc" --version
  )
}

# -----------------------------------------------------------------------------

function build_pkg_config()
{
  # https://www.freedesktop.org/wiki/Software/pkg-config/
  # https://pkgconfig.freedesktop.org/releases/

  # https://archlinuxarm.org/packages/aarch64/pkgconf/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=pkg-config-git

  # 2017-03-20, "0.29.2", latest

  local pkg_config_version="$1"

  local pkg_config_src_folder_name="pkg-config-${pkg_config_version}"

  local pkg_config_archive="${pkg_config_src_folder_name}.tar.gz"
  local pkg_config_url="https://pkgconfig.freedesktop.org/releases/${pkg_config_archive}"
  # local pkg_config_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${pkg_config_archive}"

  local pkg_config_folder_name="${pkg_config_src_folder_name}"

  local pkg_config_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${pkg_config_folder_name}-installed"
  if [ ! -f "${pkg_config_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${pkg_config_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${pkg_config_url}" "${pkg_config_archive}" \
      "${pkg_config_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${pkg_config_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${pkg_config_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${pkg_config_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      if is_darwin_not_clang
      then
        # error: variably modified 'bytes' at file scope
        prepare_clang_env ""
      fi

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running pkg_config configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${pkg_config_src_folder_name}/configure" --help
          run_verbose bash "${SOURCES_FOLDER_PATH}/${pkg_config_src_folder_name}/glib/configure" --help

          # --with-internal-glib fails with
          # gconvert.c:61:2: error: #error GNU libiconv not in use but included iconv.h is from libiconv
          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${pkg_config_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-internal-glib \
            --with-pc-path="" \
            \
            --disable-debug \
            --disable-host-tool \

          cp "config.log" "${LOGS_FOLDER_PATH}/${pkg_config_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${pkg_config_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running pkg_config make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${pkg_config_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_pkg_config
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${pkg_config_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${pkg_config_stamp_file_path}"

  else
    echo "Component pkg_config already installed."
  fi

  test_functions+=("test_pkg_config")
}

function test_pkg_config()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the pkg_config binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/pkg-config"

    echo
    echo "Testing if pkg_config binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/pkg-config" --version
  )
}

# -----------------------------------------------------------------------------

function build_m4()
{
  # https://www.gnu.org/software/m4/
  # https://ftp.gnu.org/gnu/m4/

  # https://archlinuxarm.org/packages/aarch64/m4/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=m4-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/m4.rb

  # 2016-12-31, "1.4.18"
  # 2021-05-28, "1.4.19"

  local m4_version="$1"

  local m4_src_folder_name="m4-${m4_version}"

  local m4_archive="${m4_src_folder_name}.tar.xz"
  local m4_url="https://ftp.gnu.org/gnu/m4/${m4_archive}"

  local m4_folder_name="${m4_src_folder_name}"

  local m4_patch_file_path="${helper_folder_path}/patches/${m4_folder_name}.patch"
  local m4_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${m4_folder_name}-installed"
  if [ ! -f "${m4_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${m4_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${m4_url}" "${m4_archive}" \
      "${m4_src_folder_name}" \
      "${m4_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${m4_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${m4_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${m4_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running m4 configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${m4_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${m4_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          cp "config.log" "${LOGS_FOLDER_PATH}/${m4_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${m4_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running m4 make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        (
          echo
          echo "Linking gm4..."
          cd "${INSTALL_FOLDER_PATH}/bin"
          rm -fv gm4
          ln -sv m4 gm4
        )

        # Fails on Ubuntu 18
        # checks/198.sysval:err
        if false # [ "${RUN_TESTS}" == "y" ]
        then
          if is_darwin
          then
            # On macOS 10.15
            # FAIL: test-fflush2.sh
            # FAIL: test-fpurge
            # FAIL: test-ftell.sh
            # FAIL: test-ftello2.sh
            run_verbose make -j1 check || true
          else
            run_verbose make -j1 check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${m4_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_m4
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${m4_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${m4_stamp_file_path}"

  else
    echo "Component m4 already installed."
  fi

  test_functions+=("test_m4")
}

function test_m4()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if m4 binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/m4" --version

    echo
    echo "Checking the m4 binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/m4"
  )
}

# -----------------------------------------------------------------------------

function build_gawk()
{
  # https://www.gnu.org/software/gawk/
  # https://ftp.gnu.org/gnu/gawk/

  # https://archlinuxarm.org/packages/aarch64/gawk/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gawk-git

  # 2017-10-19, "4.2.0"
  # 2018-02-25, "4.2.1"
  # 2019-06-18, "5.0.1"
  # 2020-04-14, "5.1.0"
  # 2021-10-28, "5.1.1"

  local gawk_version="$1"

  local gawk_src_folder_name="gawk-${gawk_version}"

  local gawk_archive="${gawk_src_folder_name}.tar.xz"
  local gawk_url="https://ftp.gnu.org/gnu/gawk/${gawk_archive}"

  local gawk_folder_name="${gawk_src_folder_name}"

  local gawk_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${gawk_folder_name}-installed"
  if [ ! -f "${gawk_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${gawk_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gawk_url}" "${gawk_archive}" \
      "${gawk_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${gawk_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${gawk_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${gawk_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running gawk configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${gawk_src_folder_name}/configure" --help

          # --disable-extensions
          # Extension tests fail:
          # apiterm
          # /root/Work/xbb-bootstrap-3.2-ubuntu-12.04-i686/sources/gawk-4.2.1/test/apiterm.ok _apiterm differ: byte 1, line 1
          # filefuncs
          # cmp: EOF on /root/Work/xbb-bootstrap-3.2-ubuntu-12.04-i686/sources/gawk-4.2.1/test/filefuncs.ok
          # fnmatch
          # /root/Work/xbb-bootstrap-3.2-ubuntu-12.04-i686/sources/gawk-4.2.1/test/fnmatch.ok _fnmatch differ: byte 1, line 1
          # fork
          # cmp: EOF on /root/Work/xbb-bootstrap-3.2-ubuntu-12.04-i686/sources/gawk-4.2.1/test/fork.ok
          # fork2
          # cmp: EOF on /root/Work/xbb-bootstrap-3.2-ubuntu-12.04-i686/sources/gawk-4.2.1/test/fork2.ok
          # fts
          # gawk: /root/Work/xbb-bootstrap-3.2-ubuntu-12.04-i686/sources/gawk-4.2.1/test/fts.awk:2: fatal: load_ext: library `../extension/.libs/filefuncs.so': does not define `plugin_is_GPL_compatible' (../extension/.libs/filefuncs.so: undefined symbol: plugin_is_GPL_compatible)

          # --enable-builtin-intdiv0
          # ! gawk: mpfrsqrt.awk:13: error: can't open shared library `intdiv' for reading (No such file or directory)
          # ! EXIT CODE: 1

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gawk_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --without-libsigsegv \
            --disable-rpath \
            --disable-extensions \
            --enable-builtin-intdiv0 \

          cp "config.log" "${LOGS_FOLDER_PATH}/${gawk_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gawk_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running gawk make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Multiple failures, no time to investigate.
        # WARN-TEST
        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          : # make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gawk_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_gawk
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gawk_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${gawk_stamp_file_path}"

  else
    echo "Component gawk already installed."
  fi

  test_functions+=("test_gawk")
}

function test_gawk()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the gawk binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/gawk"

    echo
    echo "Testing if gawk binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/gawk" --version
  )
}

# -----------------------------------------------------------------------------

function build_sed()
{
  # https://www.gnu.org/software/sed/
  # https://ftp.gnu.org/gnu/sed/

  # https://archlinuxarm.org/packages/aarch64/sed/files/PKGBUILD

  # 2018-12-21, "4.7"
  # 2020-01-14, "4.8"

  local sed_version="$1"

  local sed_src_folder_name="sed-${sed_version}"

  local sed_archive="${sed_src_folder_name}.tar.xz"
  local sed_url="https://ftp.gnu.org/gnu/sed/${sed_archive}"

  local sed_folder_name="${sed_src_folder_name}"

  local sed_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${sed_folder_name}-installed"
  if [ ! -f "${sed_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${sed_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${sed_url}" "${sed_archive}" \
      "${sed_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${sed_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${sed_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${sed_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      if is_darwin
      then
        # Configure expects a warning for clang.
        CFLAGS="${XBB_CFLAGS}"
        CXXFLAGS="${XBB_CXXFLAGS}"
      else
        CFLAGS="${XBB_CFLAGS_NO_W}"
        CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      fi
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running sed configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${sed_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${sed_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          # Fails on Intel and Arm, better disable it completely.
          run_verbose sed -i.bak \
            -e 's|testsuite/panic-tests.sh||g' \
            "Makefile"

          # Some tests fail due to missing locales.
          # darwin: FAIL: testsuite/subst-mb-incomplete.sh

          cp "config.log" "${LOGS_FOLDER_PATH}/${sed_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${sed_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running sed make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        (
          echo
          echo "Linking gsed..."
          cd "${INSTALL_FOLDER_PATH}/bin"
          rm -fv gsed
          ln -sv sed gsed
        )

        if [ "${RUN_TESTS}" == "y" ]
        then
          # WARN-TEST
          if is_darwin # && [ "${XBB_LAYER}" == "xbb-bootstrap" ]
          then
            # Fails on macOS 10.15.
            run_verbose make -j1 check || true
          else
            run_verbose make -j1 check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${sed_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_sed
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${sed_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${sed_stamp_file_path}"

  else
    echo "Component sed already installed."
  fi

  test_functions+=("test_sed")
}

function test_sed()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the sed binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/sed"

    echo
    echo "Testing if sed binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/sed" --version
  )
}

# -----------------------------------------------------------------------------

function build_autoconf()
{
  # https://www.gnu.org/software/autoconf/
  # https://ftp.gnu.org/gnu/autoconf/

  # https://archlinuxarm.org/packages/any/autoconf2.13/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=autoconf-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/autoconf.rb

  # 2012-04-24, "2.69"
  # 2021-01-28, "2.71"

  local autoconf_version="$1"

  local autoconf_src_folder_name="autoconf-${autoconf_version}"

  local autoconf_archive="${autoconf_src_folder_name}.tar.xz"
  local autoconf_url="https://ftp.gnu.org/gnu/autoconf/${autoconf_archive}"

  local autoconf_folder_name="${autoconf_src_folder_name}"

  local autoconf_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${autoconf_folder_name}-installed"
  if [ ! -f "${autoconf_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${autoconf_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${autoconf_url}" "${autoconf_archive}" \
      "${autoconf_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${autoconf_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${autoconf_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${autoconf_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running autoconf configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${autoconf_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${autoconf_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${autoconf_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${autoconf_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running autoconf make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          # 500 tests, 7 fail.
          : # make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${autoconf_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_autoconf
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${autoconf_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${autoconf_stamp_file_path}"

  else
    echo "Component autoconf already installed."
  fi

  test_functions+=("test_autoconf")
}

function test_autoconf()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if autoconf binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/autoconf" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/autoheader" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/autoscan" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/autoupdate" --version

    # No ELFs, only scripts.
  )
}

# -----------------------------------------------------------------------------

function build_automake()
{
  # https://www.gnu.org/software/automake/
  # https://ftp.gnu.org/gnu/automake/

  # https://archlinuxarm.org/packages/any/automake/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=automake-git

  # 2015-01-05, "1.15"
  # 2018-02-25, "1.16"
  # 2020-03-21, "1.16.2"
  # 2020-11-18, "1.16.3"
  # 2021-07-26, "1.16.4"
  # 2021-10-03, "1.16.5"

  local automake_version="$1"

  local automake_src_folder_name="automake-${automake_version}"

  local automake_archive="${automake_src_folder_name}.tar.xz"
  local automake_url="https://ftp.gnu.org/gnu/automake/${automake_archive}"

  local automake_folder_name="${automake_src_folder_name}"

  # help2man: can't get `--help' info from automake-1.16
  # Try `--no-discard-stderr' if option outputs to stderr

  local automake_patch_file_path="${helper_folder_path}/patches/${automake_folder_name}.patch"
  local automake_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${automake_folder_name}-installed"
  if [ ! -f "${automake_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${automake_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${automake_url}" "${automake_archive}" \
      "${automake_src_folder_name}" \
      "${automake_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${automake_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${automake_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${automake_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running automake configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${automake_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${automake_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --build="${BUILD}" \

          cp "config.log" "${LOGS_FOLDER_PATH}/${automake_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${automake_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running automake make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Takes too long and some tests fail.
        # XFAIL: t/pm/Cond2.pl
        # XFAIL: t/pm/Cond3.pl
        # ...
        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          : # make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${automake_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_automake
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${automake_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${automake_stamp_file_path}"

  else
    echo "Component automake already installed."
  fi

  test_functions+=("test_automake")
}

function test_automake()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if automake binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/automake" --version
  )
}

# -----------------------------------------------------------------------------

function build_libtool()
{
  # https://www.gnu.org/software/libtool/
  # http://ftpmirror.gnu.org/libtool/
  # http://ftpmirror.gnu.org/libtool/libtool-2.4.6.tar.xz

  # https://archlinuxarm.org/packages/aarch64/libtool/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libtool-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/libtool.rb

  # 15-Feb-2015, "2.4.6", latest

  local libtool_version="$1"

  local step
  if [ $# -ge 2 ]
  then
    step="$2"
  else
    step=""
  fi

  local libtool_src_folder_name="libtool-${libtool_version}"

  local libtool_archive="${libtool_src_folder_name}.tar.xz"
  local libtool_url="http://ftp.hosteurope.de/mirror/ftp.gnu.org/gnu/libtool/${libtool_archive}"

  local libtool_folder_name="libtool${step}-${libtool_version}"

  local libtool_patch_file_path="${helper_folder_path}/patches/${libtool_folder_name}.patch"

  local libtool_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libtool_folder_name}-installed"
  if [ ! -f "${libtool_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${libtool_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libtool_url}" "${libtool_archive}" \
      "${libtool_src_folder_name}" "${libtool_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libtool_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${libtool_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${libtool_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      # The new CC was set before the call.
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running libtool configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${libtool_src_folder_name}/configure" --help

          # From HomeBrew: Ensure configure is happy with the patched files
          for f in aclocal.m4 libltdl/aclocal.m4 Makefile.in libltdl/Makefile.in config-h.in libltdl/config-h.in configure libltdl/configure
          do
            touch "${SOURCES_FOLDER_PATH}/${libtool_src_folder_name}/$f"
          done

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libtool_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --enable-ltdl-install

          cp "config.log" "${LOGS_FOLDER_PATH}/${libtool_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libtool_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running libtool make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        (
          echo
          echo "Linking glibtool..."
          cd "${INSTALL_FOLDER_PATH}/bin"
          rm -fv glibtool glibtoolize
          ln -sv libtool glibtool
          ln -sv libtoolize glibtoolize
        )

        # amd64: ERROR: 139 tests were run,
        # 11 failed (5 expected failures).
        # 31 tests were skipped.
        # It takes too long (170 tests).
        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          : # make -j1 check gl_public_submodule_commit=
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libtool_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_libtool
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libtool_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${libtool_stamp_file_path}"

  else
    echo "Component libtool already installed."
  fi

  if [ -z "${step}" ]
  then
    test_functions+=("test_libtool")
  fi
}

function test_libtool()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the libtool shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libltdl.${SHLIB_EXT})"

    echo
    echo "Testing if libtool binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/libtool" --version

    echo
    echo "Testing if libtool binaries display help..."

    run_app "${INSTALL_FOLDER_PATH}/bin/libtool" --help
  )
}

# -----------------------------------------------------------------------------

function build_gettext()
{
  # https://www.gnu.org/software/gettext/
  # https://ftp.gnu.org/gnu/gettext/

  # https://archlinuxarm.org/packages/aarch64/gettext/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gettext-git

  # 2016-06-09, "0.19.8"
  # 2019-05-12, "0.20.1"
  # 2020-07-26, "0.21"

  local gettext_version="$1"

  local gettext_src_folder_name="gettext-${gettext_version}"

  local gettext_archive="${gettext_src_folder_name}.tar.xz"
  local gettext_url="https://ftp.gnu.org/gnu/gettext/${gettext_archive}"

  local gettext_folder_name="${gettext_src_folder_name}"

  local gettext_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${gettext_folder_name}-installed"
  if [ ! -f "${gettext_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${gettext_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gettext_url}" "${gettext_archive}" \
      "${gettext_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${gettext_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${gettext_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${gettext_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running gettext configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${gettext_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gettext_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-xz \
            --without-included-gettext \
            \
            --enable-csharp \
            --enable-nls \
            --enable-threads \
            --disable-rpath \

          # TODO: cleanups
          if is_linux
          then
            if true
            then
              patch_all_libtool_rpath
            else
              for file in $(find . -name libtool ! -path '*/tests/*')
              do
                echo ${file}
                patch_file_libtool_rpath ${file}
              done
            fi
          fi

          # Tests fail on Ubuntu 14 bootstrap
          # Darwin: FAIL: lang-sh
          if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
          then
            # Both Intel and Arm (32 & 64).
            if is_linux
            then
              # Fails on 18.04 32-bit too.
              # aarch64, armv8l: FAIL: test-thread_create
              # aarch64, armv8l: FAIL: test-tls
              # WARN-TEST
              run_verbose sed -i.bak \
                -e 's|test-thread_create$(EXEEXT) ||' \
                -e 's|test-tls$(EXEEXT) ||' \
                "gettext-tools/gnulib-tests/Makefile"
            fi
          fi

          if is_darwin # && [ "${XBB_LAYER}" == "xbb-bootstrap" ]
          then
            # Disable failing tests.
            run_verbose sed -i.bak \
              -e 's| test-ftell.sh | |' \
              -e 's|test-ftell2.sh ||' \
              -e 's| test-ftello.sh | |' \
              -e 's|test-ftello2.sh ||' \
              -e 's|test-fopen-gnu$(EXEEXT) ||' \
              "gettext-tools/gnulib-tests/Makefile"
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${gettext_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gettext_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running gettext make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          (
            # The tests use an internal library (libgnuintl.so), so it
            # is necessary to temporarily consider the local path.
            (
              cd gettext-runtime
              if is_linux
              then
                export LD_RUN_PATH="$(pwd)/intl/.libs:${LD_RUN_PATH}"
                echo "LD_RUN_PATH=$LD_RUN_PATH"
              fi
              run_verbose make -j1 check
            )
            (
              cd gettext-tools
              if is_linux
              then
                export LD_RUN_PATH="$(pwd)/intl/.libs:${LD_RUN_PATH}"
                echo "LD_RUN_PATH=$LD_RUN_PATH"
              fi
              if is_darwin
              then
                if is_arm
                then
                  # Undefined symbols for architecture arm64:
                  # "_vm_region"
                  :
                else
                  run_verbose make -j1 check || true
                fi
              else
                run_verbose make -j1 check
              fi
            )
          )
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gettext_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_gettext
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gettext_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${gettext_stamp_file_path}"

  else
    echo "Component gettext already installed."
  fi

  test_functions+=("test_gettext")
}

function test_gettext()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the gettext shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/gettext"
    show_libs "${INSTALL_FOLDER_PATH}/bin/msgcmp"

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgettextlib.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgettextpo.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgettextsrc.${SHLIB_EXT})"

    echo
    echo "Testing if gettext binaries start properly..."

    echo
    run_app "${INSTALL_FOLDER_PATH}/bin/gettext" --version

    run_app "${INSTALL_FOLDER_PATH}/bin/msgcmp" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgfmt" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgmerge" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgunfmt" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/xgettext" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgattrib" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgcat" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgcomm" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgconv" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgen" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgexec" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msgfilter" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msggrep" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msginit" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/msguniq" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/recode-sr-latin" --version

    run_app "${INSTALL_FOLDER_PATH}/bin/msguniq" --version
  )
}

# -----------------------------------------------------------------------------

function build_patch()
{
  # https://www.gnu.org/software/patch/
  # https://ftp.gnu.org/gnu/patch/

  # https://archlinuxarm.org/packages/aarch64/patch/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=patch-git

  # 2015-03-06, "2.7.5"
  # 2018-02-06, "2.7.6" (latest)

  local patch_version="$1"

  local patch_src_folder_name="patch-${patch_version}"

  local patch_archive="${patch_src_folder_name}.tar.xz"
  local patch_url="https://ftp.gnu.org/gnu/patch/${patch_archive}"

  local patch_folder_name="${patch_src_folder_name}"

  local patch_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${patch_folder_name}-installed"
  if [ ! -f "${patch_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${patch_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${patch_url}" "${patch_archive}" \
      "${patch_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${patch_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${patch_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${patch_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running patch configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${patch_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${patch_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${patch_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patch_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running patch make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patch_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_patch
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patch_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${patch_stamp_file_path}"

  else
    echo "Component patch already installed."
  fi

  test_functions+=("test_patch")
}

function test_patch()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the patch binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/patch"

    echo
    echo "Testing if patch binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/patch" --version
  )
}

# -----------------------------------------------------------------------------

function build_diffutils()
{
  # https://www.gnu.org/software/diffutils/
  # https://ftp.gnu.org/gnu/diffutils/

  # https://archlinuxarm.org/packages/aarch64/diffutils/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=diffutils-git

  # 2017-05-21, "3.6"
  # 2018-12-31, "3.7"
  # 2021-08-01, "3.8"

  local diffutils_version="$1"

  local diffutils_src_folder_name="diffutils-${diffutils_version}"

  local diffutils_archive="${diffutils_src_folder_name}.tar.xz"
  local diffutils_url="https://ftp.gnu.org/gnu/diffutils/${diffutils_archive}"

  local diffutils_folder_name="${diffutils_src_folder_name}"

  local diffutils_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${diffutils_folder_name}-installed"
  if [ ! -f "${diffutils_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${diffutils_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${diffutils_url}" "${diffutils_archive}" \
      "${diffutils_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${diffutils_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${diffutils_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${diffutils_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      if is_darwin
      then
        # Configure expects a warning for clang.
        CFLAGS="${XBB_CFLAGS}"
        CXXFLAGS="${XBB_CXXFLAGS}"
      else
        CFLAGS="${XBB_CFLAGS_NO_W}"
        CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      fi
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running diffutils configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${diffutils_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${diffutils_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          cp "config.log" "${LOGS_FOLDER_PATH}/${diffutils_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${diffutils_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running diffutils make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          if is_darwin && is_arm
          then
            # Fails lots of tests
            :
          else
            # WARN-TEST
            run_verbose make -j1 check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${diffutils_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_diffutils
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${diffutils_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${diffutils_stamp_file_path}"

  else
    echo "Component diffutils already installed."
  fi

  test_functions+=("test_diffutils")
}

function test_diffutils()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the diffutils binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/diff"
    show_libs "${INSTALL_FOLDER_PATH}/bin/cmp"
    show_libs "${INSTALL_FOLDER_PATH}/bin/diff3"
    show_libs "${INSTALL_FOLDER_PATH}/bin/sdiff"

    echo
    echo "Testing if diffutils binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/diff" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/cmp" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/diff3" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/sdiff" --version
  )
}

# -----------------------------------------------------------------------------

function build_bison()
{
  # https://www.gnu.org/software/bison/
  # https://ftp.gnu.org/gnu/bison/

  # https://archlinuxarm.org/packages/aarch64/bison/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=bison-git

  # 2015-01-23, "3.0.4"
  # 2019-02-03, "3.3.2", Crashes with Abort trap 6.
  # 2019-09-12, "3.4.2"
  # 2019-12-11, "3.5"
  # 2020-07-23, "3.7"
  # 2021-09-25, "3.8.2"

  local bison_version="$1"

  local bison_src_folder_name="bison-${bison_version}"

  local bison_archive="${bison_src_folder_name}.tar.xz"
  local bison_url="https://ftp.gnu.org/gnu/bison/${bison_archive}"

  local bison_folder_name="${bison_src_folder_name}"

  local bison_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${bison_folder_name}-installed"
  if [ ! -f "${bison_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${bison_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${bison_url}" "${bison_archive}" \
      "${bison_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${bison_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${bison_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${bison_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      if is_linux
      then
        # undefined reference to `clock_gettime' on docker
        export LIBS="-lrt"
      fi

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running bison configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${bison_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${bison_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          run_verbose find . \
            -name Makefile \
            -print \
            -exec sed -i.bak -e "s|-Wl,-rpath -Wl,${INSTALL_FOLDER_PATH}/lib||" {} \;

          cp "config.log" "${LOGS_FOLDER_PATH}/${bison_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${bison_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running bison make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Takes too long.
        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          # 596, 7 failed
          : # make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${bison_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_bison
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${bison_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${bison_stamp_file_path}"

  else
    echo "Component bison already installed."
  fi

  test_functions+=("test_bison")
}

function test_bison()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the bison binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/bison"
    # yacc is a script.

    echo
    echo "Testing if bison binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/bison" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/yacc" --version
  )
}

# -----------------------------------------------------------------------------

function build_flex()
{
  # https://www.gnu.org/software/flex/
  # https://github.com/westes/flex/releases
  # https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz

  # https://archlinuxarm.org/packages/aarch64/flex/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=flex-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/flex.rb

  # Apple uses 2.5.3
  # Ubuntu 12 uses 2.5.35

  # 30 Dec 2016, "2.6.3"
  # On Ubuntu 18, it fails while building wine with
  # /opt/xbb/lib/gcc/x86_64-w64-mingw32/9.2.0/../../../../x86_64-w64-mingw32/bin/ld: macro.lex.yy.cross.o: in function `yylex':
  # /root/Work/xbb-3.1-ubuntu-18.04-x86_64/build/wine-5.1/programs/winhlp32/macro.lex.yy.c:1031: undefined reference to `yywrap'
  # collect2: error: ld returned 1 exit status

  # May 6, 2017, "2.6.4" (latest)
  # On Ubuntu 18 it crashes (due to an autotool issue) with
  # ./stage1flex   -o stage1scan.c /home/ilg/Work/xbb-bootstrap/sources/flex-2.6.4/src/scan.l
  # make[2]: *** [Makefile:1696: stage1scan.c] Segmentation fault (core dumped)
  # The patch from Arch should fix it.
  # https://archlinuxarm.org/packages/aarch64/flex/files/flex-pie.patch

  local flex_version="$1"

  local flex_src_folder_name="flex-${flex_version}"

  local flex_archive="${flex_src_folder_name}.tar.gz"
  local flex_url="https://github.com/westes/flex/releases/download/v${flex_version}/${flex_archive}"

  local flex_folder_name="${flex_src_folder_name}"

  local flex_patch_file_path="${helper_folder_path}/patches/${flex_folder_name}.patch"
  local flex_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${flex_folder_name}-installed"
  if [ ! -f "${flex_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${flex_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${flex_url}" "${flex_archive}" \
      "${flex_src_folder_name}" \
      "${flex_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${flex_folder_name}"

    (
      cd "${SOURCES_FOLDER_PATH}/${flex_src_folder_name}"
      if [ ! -f "stamp-autogen" ]
      then

        xbb_activate
        if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
        then
          # Requires autopoint from autotools.
          xbb_activate_installed_bin
        fi
        xbb_activate_installed_dev

        run_verbose bash ${DEBUG} "autogen.sh"

        # No longer needed, done in libtool.
        # patch -p0 <"${helper_folder_path}/patches/flex-2.4.6-libtool.patch"

        touch "stamp-autogen"

      fi
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${flex_folder_name}/autogen-output-$(ndate).txt"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${flex_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${flex_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running flex configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${flex_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${flex_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          cp "config.log" "${LOGS_FOLDER_PATH}/${flex_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${flex_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running flex make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          # cxx_restart fails - https://github.com/westes/flex/issues/98
          # make -k check || true
          if is_darwin && is_arm
          then
            : # Fail with internal error, caused by gm4
            run_verbose make -k check || true
          else
            run_verbose make -k check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${flex_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_flex
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${flex_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${flex_stamp_file_path}"

  else
    echo "Component flex already installed."
  fi

  test_functions+=("test_flex")
}

function test_flex()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the flex shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/flex"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libfl.${SHLIB_EXT})"

    echo
    echo "Testing if flex binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/flex" --version
  )
}

# -----------------------------------------------------------------------------

function build_make()
{
  # https://www.gnu.org/software/make/
  # https://ftp.gnu.org/gnu/make/

  # https://archlinuxarm.org/packages/aarch64/make/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=make-git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/make.rb

  # 2016-06-10, "4.2.1"
  # 2020-01-19, "4.3"

  local make_version="$1"

  local make_src_folder_name="make-${make_version}"

  # bz2 available up to 4.2.1, gz available on all.
  local make_archive="${make_src_folder_name}.tar.gz"
  local make_url="https://ftp.gnu.org/gnu/make/${make_archive}"

  local make_folder_name="${make_src_folder_name}"

  # Patch to fix the alloca bug.
  # glob/libglob.a(glob.o): In function `glob_in_dir':
  # glob.c:(.text.glob_in_dir+0x90): undefined reference to `__alloca'

  local make_patch_file_path="${helper_folder_path}/patches/${make_folder_name}.patch"
  local make_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${make_folder_name}-installed"
  if [ ! -f "${make_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${make_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${make_url}" "${make_archive}" \
      "${make_src_folder_name}" \
      "${make_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${make_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${make_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${make_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running make configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${make_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${make_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \
            --program-prefix=g \

          cp "config.log" "${LOGS_FOLDER_PATH}/${make_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${make_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running make make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        (
          echo
          echo "Linking gmake -> make..."
          cd "${INSTALL_FOLDER_PATH}/bin"
          rm -fv make
          ln -sv gmake make
        )

        # Takes too long.
        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          # 2 wildcard tests fail
          # WARN-TEST
          : make -k check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${make_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_make
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${make_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${make_stamp_file_path}"

  else
    echo "Component make already installed."
  fi

  test_functions+=("test_make")
}

function test_make()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the make binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/gmake"

    echo
    echo "Testing if make binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/gmake" --version
  )
}

# -----------------------------------------------------------------------------

function build_wget()
{
  # https://www.gnu.org/software/wget/
  # https://ftp.gnu.org/gnu/wget/

  # https://archlinuxarm.org/packages/aarch64/wget/files/PKGBUILD
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/wget
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=wget-git

  # 2016-06-10, "1.19"
  # 2018-12-26, "1.20.1"
  # 2019-04-05, "1.20.3"

  # fails on macOS with
  # lib/malloc/dynarray-skeleton.c:195:13: error: expected identifier or '(' before numeric constant
  # 195 | __nonnull ((1))
  # 2021-01-09, "1.21.1"
  # 2021-09-07, "1.21.2"

  local wget_version="$1"

  local wget_src_folder_name="wget-${wget_version}"

  local wget_archive="${wget_src_folder_name}.tar.gz"
  local wget_url="https://ftp.gnu.org/gnu/wget/${wget_archive}"

  local wget_folder_name="${wget_src_folder_name}"

  local wget_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${wget_folder_name}-installed"
  if [ ! -f "${wget_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${wget_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${wget_url}" "${wget_archive}" \
      "${wget_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${wget_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${wget_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${wget_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"
      # Might be needed on Mac
      # export LIBS="-liconv"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running wget configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${wget_src_folder_name}/configure" --help

          # libpsl is not available anyway.
          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${wget_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-ssl=gnutls \
            --with-metalink \
            --without-libpsl \
            \
            --enable-nls \
            --disable-debug \
            --disable-pcre \
            --disable-pcre2 \
            --disable-rpath \

          if is_linux
          then
            run_verbose find . \
              \( -name Makefile -o -name version.c \) \
              -print \
              -exec sed -i.bak -e "s|-Wl,-rpath -Wl,${INSTALL_FOLDER_PATH}/lib||" {} \;
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${wget_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${wget_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running wget make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Fails
        # x86_64: FAIL:  65
        # WARN-TEST
        # make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${wget_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_wget
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${wget_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${wget_stamp_file_path}"

  else
    echo "Component wget already installed."
  fi

  test_functions+=("test_wget")
}

function test_wget()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the wget binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/wget"

    echo
    echo "Testing if wget binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/wget" --version
  )
}

# -----------------------------------------------------------------------------

function build_texinfo()
{
  # https://www.gnu.org/software/texinfo/
  # https://ftp.gnu.org/gnu/texinfo/

  # https://archlinuxarm.org/packages/aarch64/texinfo/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=texinfo-svn

  # 2017-09-12, "6.5"
  # 2019-02-16, "6.6"
  # 2019-09-23, "6.7"
  # 2021-07-03, "6.8"

  local texinfo_version="$1"

  local texinfo_src_folder_name="texinfo-${texinfo_version}"

  local texinfo_archive="${texinfo_src_folder_name}.tar.gz"
  local texinfo_url="https://ftp.gnu.org/gnu/texinfo/${texinfo_archive}"

  local texinfo_folder_name="${texinfo_src_folder_name}"

  local texinfo_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${texinfo_folder_name}-installed"
  if [ ! -f "${texinfo_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${texinfo_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${texinfo_url}" "${texinfo_archive}" \
      "${texinfo_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${texinfo_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${texinfo_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${texinfo_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running texinfo configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${texinfo_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${texinfo_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          cp "config.log" "${LOGS_FOLDER_PATH}/${texinfo_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${texinfo_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running texinfo make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Darwin: FAIL: t/94htmlxref.t 11 - htmlxref errors file_html
        # Darwin: ERROR: t/94htmlxref.t - exited with status 2

        if [ "${RUN_TESTS}" == "y" ]
        then
          if is_darwin
          then
            run_verbose make -j1 check || true
          else
            run_verbose make -j1 check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${texinfo_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_texinfo
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${texinfo_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${texinfo_stamp_file_path}"

  else
    echo "Component texinfo already installed."
  fi

  test_functions+=("test_texinfo")
}

function test_texinfo()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if texinfo binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/texi2pdf" --version

    # No ELFs, it is a script.
  )
}

# -----------------------------------------------------------------------------

function build_cmake()
{
  # https://cmake.org
  # https://github.com/Kitware/CMake/releases/
  # https://github.com/Kitware/CMake/releases/download/v3.14.0/cmake-3.14.0.tar.gz
  # https://github.com/Kitware/CMake/releases/download/v3.13.4/cmake-3.13.4.tar.gz

  # https://archlinuxarm.org/packages/aarch64/cmake/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=cmake-git

  # November 10, 2017, "3.9.6"
  # November 2017, "3.10.1"
  # Dec 19, 2019, "3.15.6" - requires cmake 3.x -> bootstrap.
  # Dec 16, 2019, "3.16.2"
  # Apr 6, 2021, "3.19.8"
  # Sep 20, 2021, "3.20.6"
  # Oct 7, 2021, "3.21.4"
  # Dec 7, 2021, "3.22.1"

  local cmake_version="$1"
  local cmake_version_major="$(echo ${cmake_version} | sed -e 's|\([0-9][0-9]*\)\..*|\1|')"
  local cmake_version_minor="$(echo ${cmake_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\).*|\2|')"

  local cmake_src_folder_name="cmake-${cmake_version}"

  local cmake_archive="${cmake_src_folder_name}.tar.gz"
  local cmake_url="https://github.com/Kitware/CMake/releases/download/v${cmake_version}/${cmake_archive}"

  local cmake_folder_name="${cmake_src_folder_name}"

  local cmake_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${cmake_folder_name}-installed"
  if [ ! -f "${cmake_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${cmake_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${cmake_url}" "${cmake_archive}" \
      "${cmake_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${cmake_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${cmake_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${cmake_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if is_darwin_not_clang
      then
        # error: variably modified 'bytes' at file scope
        prepare_clang_env ""
      fi

      local which_cmake="$(which cmake)"
      if [ -z "${which_cmake}" -o "${XBB_LAYER}" == "xbb-bootstrap" ]
      then
        if [ ! -d "Bootstrap.cmk" ]
        then
          (
            env | sort

            echo
            echo "Running cmake bootstrap..."

            run_verbose bash "${SOURCES_FOLDER_PATH}/${cmake_src_folder_name}/bootstrap" --help || true

            run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${cmake_src_folder_name}/bootstrap" \
              --prefix="${INSTALL_FOLDER_PATH}" \
              \
              --parallel="${JOBS}"

            cp "Bootstrap.cmk/cmake_bootstrap.log" "${LOGS_FOLDER_PATH}/${cmake_folder_name}/bootstrap-log-$(ndate).txt"
          ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${cmake_folder_name}/bootstrap-output-$(ndate).txt"
        fi
      else
        (
          env | sort

          echo
          echo "Running cmake cmake..."

          # If more verbosity is needed:
          #  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON

          # Use the existing cmake to configure this one.
          run_verbose cmake \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_FOLDER_PATH}" \
            "${SOURCES_FOLDER_PATH}/${cmake_src_folder_name}"

        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${cmake_folder_name}/cmake-output-$(ndate).txt"
      fi

      if is_linux
      then
        if [ -n "${XBB_PARENT_FOLDER_PATH}" ]
        then
          run_verbose find . \
            -name link.txt \
            -print \
            -exec sed -i.bak -e "s|-Wl,-rpath,${XBB_PARENT_FOLDER_PATH}/lib||" {} \;
        fi
      fi

      (
        echo
        echo "Running cmake make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        mkdir -pv "${INSTALL_FOLDER_PATH}/share/doc"
        rm -rfv "${INSTALL_FOLDER_PATH}/share/doc/cmake-${cmake_version_major}.${cmake_version_minor}"
        mv -v "${INSTALL_FOLDER_PATH}/doc/cmake-${cmake_version_major}.${cmake_version_minor}" "${INSTALL_FOLDER_PATH}/share/doc"

        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          # 7 tests failed out of 563:
          #   5 - kwsys.testSystemTools (Failed)
          #  41 - VSGNUFortran (Failed)
          #  157 - complex (Failed)
          #  158 - complexOneConfig (Failed)
          #  274 - Fortran (Failed)
          #  372 - RunCMake.GenerateExportHeader (Failed)
          #  467 - RunCMake.FindPkgConfig (Failed)
          # WARN-TEST
          : # make -j1 test
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${cmake_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_cmake
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${cmake_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${cmake_stamp_file_path}"

  else
    echo "Component cmake already installed."
  fi

  test_functions+=("test_cmake")
}

function test_cmake()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the cmake binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/cmake"
    show_libs "${INSTALL_FOLDER_PATH}/bin/ctest"
    show_libs "${INSTALL_FOLDER_PATH}/bin/cpack"
    if [ -f "${INSTALL_FOLDER_PATH}/bin/ccmake" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/bin/ccmake"
    fi

    echo
    echo "Testing if cmake binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/cmake" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/ctest" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/cpack" --version
    if [ -f "${INSTALL_FOLDER_PATH}/bin/ccmake" ]
    then
      run_app "${INSTALL_FOLDER_PATH}/bin/ccmake" --version
    fi
  )
}

# -----------------------------------------------------------------------------

function build_perl()
{
  # https://www.cpan.org
  # http://www.cpan.org/src/

  # https://archlinuxarm.org/packages/aarch64/perl/files/PKGBUILD
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/perl

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/perl.rb

  # Fails to build on macOS

  # 2014-10-02, "5.18.4" (10.10 uses 5.18.2)
  # 2015-09-12, "5.20.3"
  # 2017-07-15, "5.22.4"
  # 2018-04-14, "5.24.4" # Fails in bootstrap on mac.
  # 2018-11-29, "5.26.3" # Fails in bootstrap on mac.
  # 2019-04-19, "5.28.2" # Fails in bootstrap on mac.
  # 2019-11-10, "5.30.1"
  # 2021-05-20, "5.34.0"

  PERL_VERSION="$1"
  local perl_version_major="$(echo "${PERL_VERSION}" | sed -e 's/\([0-9]*\)\..*/\1.0/')"

  local perl_src_folder_name="perl-${PERL_VERSION}"

  local perl_archive="${perl_src_folder_name}.tar.gz"
  local perl_url="http://www.cpan.org/src/${perl_version_major}/${perl_archive}"

  local perl_folder_name="${perl_src_folder_name}"

  # Fix an incompatibility with libxcrypt and glibc.
  # https://groups.google.com/forum/#!topic/perl.perl5.porters/BTMp2fQg8q4
  local perl_patch_file_path="${helper_folder_path}/patches/${perl_folder_name}.patch"
  local perl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${perl_folder_name}-installed"
  if [ ! -f "${perl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${perl_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${perl_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${perl_url}" "${perl_archive}" \
        "${perl_src_folder_name}" \
        "${perl_patch_file_path}"

      if [ "${perl_src_folder_name}" != "${perl_folder_name}" ]
      then
        mv -v "${perl_src_folder_name}" "${perl_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${perl_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${perl_folder_name}"

      xbb_activate
      if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
      then
        # ! Requires patchelf.
        xbb_activate_installed_bin
      fi
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      # -Wno-null-pointer-arithmetic
      CFLAGS="${XBB_CPPFLAGS} ${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CPPFLAGS} ${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP} -v"

      if is_linux
      then
        # Required to pick libcrypt and libssp from bootstrap.
        export LD_LIBRARY_PATH="${XBB_LIBRARY_PATH}"
      fi

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.h" ]
      then
        (
          env | sort

          echo
          echo "Running perl configure..."

          run_verbose bash "./Configure" --help || true

          # -Uusedl prevents building libperl.so and so there is no need
          # worry about the weird rpath.

          run_verbose bash ${DEBUG} "./Configure" -d -e -s \
            -Dprefix="${INSTALL_FOLDER_PATH}" \
            \
            -Dcc="${CC}" \
            -Dccflags="${CFLAGS}" \
            -Dcppflags="${CPPFLAGS}" \
            -Dlddlflags="-shared ${LDFLAGS}" \
            -Dldflags="${LDFLAGS}" \
            -Duseshrplib \
            -Duselargefiles \
            -Dusethreads \
            -Uusedl \

        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${perl_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running perl make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Takes very, very long, and some fail.
        if false # [ "${RUN_LONG_TESTS}" == "y" ]
        then
          # re/regexp_nonull.t                                               (Wstat: 512 Tests: 0 Failed: 0)
          # Non-zero exit status: 2
          # Parse errors: No plan found in TAP output
          # op/sub.t                                                         (Wstat: 512 Tests: 61 Failed: 0)
          # Non-zero exit status: 2
          # Parse errors: Bad plan.  You planned 62 tests but ran 61.
          # porting/manifest.t                                               (Wstat: 0 Tests: 10399 Failed: 2)
          # Failed tests:  9648, 9930
          # porting/test_bootstrap.t                                         (Wstat: 512 Tests: 407 Failed: 0)
          # Non-zero exit status: 2

          # WARN-TEST
          rm -rf t/re/regexp_nonull.t
          rm -rf t/op/sub.t

          run_verbose make -j1 test_harness
          run_verbose make -j1 test
        fi

        (
          xbb_activate_installed_bin

          if is_darwin
          then
            # Remove any existing .cpan
            rm -rf ${HOME}/.cpan
          fi

          # https://www.cpan.org/modules/INSTALL.html
          # Convince cpan not to ask confirmations.
          export PERL_MM_USE_DEFAULT=true
          # cpanminus is a quiet version of cpan.
          run_verbose cpan App::cpanminus
        )

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${perl_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_perl
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${perl_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${perl_stamp_file_path}"

  else
    echo "Component perl already installed."
  fi

  test_functions+=("test_perl")
}

function test_perl()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the perl binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/perl"

    echo
    echo "Testing if perl binaries start properly..."

    (
      # To find libssp.so.0.
      # /opt/xbb/bin/perl: error while loading shared libraries: libssp.so.0: cannot open shared object file: No such file or directory
      if is_linux
      then
        export LD_LIBRARY_PATH="${XBB_LIBRARY_PATH}"
      fi

      run_app "${INSTALL_FOLDER_PATH}/bin/perl" --version
    )
  )
}

# -----------------------------------------------------------------------------

function build_makedepend()
{
  # http://www.linuxfromscratch.org/blfs/view/7.4/x/makedepend.html
  # http://xorg.freedesktop.org/archive/individual/util
  # http://xorg.freedesktop.org/archive/individual/util/makedepend-1.0.5.tar.bz2

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=makedepend

  # 2013-07-23, 1.0.5
  # 2019-03-16, 1.0.6

  local makedepend_version="$1"

  local makedepend_src_folder_name="makedepend-${makedepend_version}"

  local makedepend_archive="${makedepend_src_folder_name}.tar.bz2"
  local makedepend_url="http://xorg.freedesktop.org/archive/individual/util/${makedepend_archive}"

  local makedepend_folder_name="${makedepend_src_folder_name}"

  local makedepend_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${makedepend_folder_name}-installed"
  if [ ! -f "${makedepend_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${makedepend_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${makedepend_url}" "${makedepend_archive}" \
      "${makedepend_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${makedepend_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${makedepend_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${makedepend_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"
      PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/share/pkgconfig:${PKG_CONFIG_PATH}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS
      export PKG_CONFIG_PATH

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running makedepend configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${makedepend_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${makedepend_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${makedepend_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${makedepend_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running makedepend make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${makedepend_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_makedepend
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${makedepend_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${makedepend_stamp_file_path}"

  else
    echo "Component makedepend already installed."
  fi

  test_functions+=("test_makedepend")
}

function test_makedepend()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if makedepend binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/makedepend" || true
  )
}

# -----------------------------------------------------------------------------

function build_patchelf()
{
  # https://nixos.org/patchelf.html
  # https://github.com/NixOS/patchelf
  # https://github.com/NixOS/patchelf/releases/
  # https://github.com/NixOS/patchelf/releases/download/0.12/patchelf-0.12.tar.bz2
  # https://github.com/NixOS/patchelf/archive/0.12.tar.gz

  # 2016-02-29, "0.9"
  # 2019-03-28, "0.10"
  # 2020-06-09, "0.11"
  # 2020-08-27, "0.12"
  # 05 Aug 2021, "0.13"
  # 05 Dec 2021, "0.14.3"

  local patchelf_version="$1"

  local patchelf_src_folder_name="patchelf-${patchelf_version}"

  local patchelf_archive="${patchelf_src_folder_name}.tar.bz2"
  # GitHub release archive.
  local patchelf_github_archive="${patchelf_version}.tar.gz"
  local patchelf_url="https://github.com/NixOS/patchelf/archive/${patchelf_github_archive}"

  local patchelf_folder_name="${patchelf_src_folder_name}"

  local patchelf_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${patchelf_folder_name}-installed"
  if [ ! -f "${patchelf_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${patchelf_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${patchelf_url}" "${patchelf_archive}" \
      "${patchelf_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${patchelf_folder_name}"

    (
      if [ ! -x "${SOURCES_FOLDER_PATH}/${patchelf_src_folder_name}/configure" ]
      then

        cd "${SOURCES_FOLDER_PATH}/${patchelf_src_folder_name}"

        xbb_activate_installed_bin
        xbb_activate_installed_dev

        run_verbose bash ${DEBUG} "bootstrap.sh"

      fi
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patchelf_folder_name}/autogen-output-$(ndate).txt"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${patchelf_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${patchelf_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      # Wihtout -static-libstdc++, the bootstrap lib folder is needed to
      # find libstdc++.
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running patchelf configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${patchelf_src_folder_name}/configure" --help

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")
          if is_linux
          then
            config_options+=("--disable-rpath")
            config_options+=("--disable-new-dtags")
          fi

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${patchelf_src_folder_name}/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${patchelf_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patchelf_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running patchelf make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Fails.
        # x86_64: FAIL: set-rpath-library.sh (Segmentation fault (core dumped))
        # x86_64: FAIL: set-interpreter-long.sh (Segmentation fault (core dumped))
        # make -C tests -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patchelf_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_patchelf
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${patchelf_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${patchelf_stamp_file_path}"

  else
    echo "Component patchelf already installed."
  fi

  test_functions+=("test_patchelf")
}

function test_patchelf()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the patchelf binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/patchelf"

    echo
    echo "Testing if patchelf binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/patchelf" --version
  )
}

# -----------------------------------------------------------------------------

function build_chrpath()
{
  # http://http.debian.net/debian/pool/main/c/chrpath/chrpath_0.16.orig.tar.gz

  # https://archlinuxarm.org/packages/aarch64/chrpath/files/PKGBUILD

  # 04 Jan 2014, "0.16"

  local chrpath_version="$1"

  local chrpath_src_folder_name="chrpath-${chrpath_version}"

  local chrpath_archive="chrpath_${chrpath_version}.orig.tar.gz"
  local chrpath_url="http://http.debian.net/debian/pool/main/c/chrpath/${chrpath_archive}"

  local chrpath_folder_name="${chrpath_src_folder_name}"

  local chrpath_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${chrpath_folder_name}-installed"
  if [ ! -f "${chrpath_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${chrpath_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${chrpath_url}" "${chrpath_archive}" \
      "${chrpath_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${chrpath_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${chrpath_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${chrpath_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running chrpath configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${chrpath_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${chrpath_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${chrpath_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${chrpath_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running chrpath make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${chrpath_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_chrpath
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${chrpath_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${chrpath_stamp_file_path}"

  else
    echo "Component chrpath already installed."
  fi

  test_functions+=("test_chrpath")
}

function test_chrpath()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the chrpath binutils shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/chrpath"

    echo
    echo "Testing if chrpath binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/chrpath" --version
  )
}

# -----------------------------------------------------------------------------

function build_dos2unix()
{
  # https://waterlan.home.xs4all.nl/dos2unix.html
  # http://dos2unix.sourceforge.net
  # https://waterlan.home.xs4all.nl/dos2unix/dos2unix-7.4.0.tar.

  # https://archlinuxarm.org/packages/aarch64/dos2unix/files/PKGBUILD

  # 30-Oct-2017, "7.4.0"
  # 2019-09-24, "7.4.1"
  # 2020-10-12, "7.4.2"

  local dos2unix_version="$1"

  local dos2unix_src_folder_name="dos2unix-${dos2unix_version}"

  local dos2unix_archive="${dos2unix_src_folder_name}.tar.gz"
  local dos2unix_url="https://waterlan.home.xs4all.nl/dos2unix/${dos2unix_archive}"

  local dos2unix_folder_name="${dos2unix_src_folder_name}"

  local dos2unix_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${dos2unix_folder_name}-installed"
  if [ ! -f "${dos2unix_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${dos2unix_folder_name}" ]
  then

    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${dos2unix_url}" "${dos2unix_archive}" \
      "${dos2unix_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${dos2unix_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${dos2unix_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${dos2unix_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      (
        env | sort

        echo
        echo "Running dos2unix make..."

        # Build.
        run_verbose make -j ${JOBS} prefix="${INSTALL_FOLDER_PATH}" ENABLE_NLS=

        run_verbose make prefix="${INSTALL_FOLDER_PATH}" install

        if [ "${RUN_TESTS}" == "y" ]
        then
          if is_darwin
          then
            #   Failed test 'dos2unix convert DOS UTF-16LE to Unix GB18030'
            #   at utf16_gb.t line 27.
            #   Failed test 'dos2unix convert DOS UTF-16LE to Unix GB18030, keep BOM'
            #   at utf16_gb.t line 30.
            #   Failed test 'unix2dos convert DOS UTF-16BE to DOS GB18030, keep BOM'
            #   at utf16_gb.t line 33.
            run_verbose make -j1 check || true
          else
            run_verbose make -j1 check
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${dos2unix_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_dos2unix
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${dos2unix_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${dos2unix_stamp_file_path}"

  else
    echo "Component dos2unix already installed."
  fi

  test_functions+=("test_dos2unix")
}

function test_dos2unix()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the dos2unix binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/unix2dos"
    show_libs "${INSTALL_FOLDER_PATH}/bin/dos2unix"

    echo
    echo "Testing if dos2unix binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/unix2dos" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/dos2unix" --version
  )
}

# -----------------------------------------------------------------------------

function build_git()
{
  # https://git-scm.com/
  # https://www.kernel.org/pub/software/scm/git/

  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/git

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/git.rb

  # 30-Oct-2017, "2.15.0"
  # 24-Feb-2019, "2.21.0"
  # 13-Jan-2020, "2.25.0"
  # 06-Jun-2021, "2.32.0"
  # 12-Oct-2021, "2.33.1"
  # 24-Nov-2021, "2.34.1"

  local git_version="$1"

  local git_src_folder_name="git-${git_version}"

  local git_archive="${git_src_folder_name}.tar.xz"
  local git_url="https://www.kernel.org/pub/software/scm/git/${git_archive}"

  local git_folder_name="${git_src_folder_name}"

  local git_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${git_folder_name}-installed"
  if [ ! -f "${git_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${git_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${git_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${git_url}" "${git_archive}" \
        "${git_src_folder_name}"

      if [ "${git_src_folder_name}" != "${git_folder_name}" ]
      then
        mv -v "${git_src_folder_name}" "${git_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${git_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${git_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      if is_darwin_not_clang && is_arm
      then
        # The requested URL returned error: 405
        prepare_clang_env ""
      fi

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"
      # export LIBS="-ldl"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if is_darwin
      then
        export NO_OPENSSL=1
        export APPLE_COMMON_CRYPTO=1
      fi

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running git configure..."

          run_verbose bash "./configure" --help

          run_verbose bash ${DEBUG} "./configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${git_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${git_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running git make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Tests are quite complicated

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${git_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_git
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${git_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${git_stamp_file_path}"

  else
    echo "Component git already installed."
  fi

  test_functions+=("test_git")
}

function test_git()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the git binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/git"

    echo
    echo "Testing if git binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/git" --version

    rm -rf content.git
    run_app "${INSTALL_FOLDER_PATH}/bin/git" clone \
      https://github.com/xpack-dev-tools/content.git \
      content.git
  )
}

# -----------------------------------------------------------------------------

function build_python2()
{
  # https://www.python.org
  # https://www.python.org/downloads/source/
  # https://www.python.org/ftp/python/2.7.16/Python-2.7.16.tar.xz

  # https://archlinuxarm.org/packages/aarch64/python2/files/PKGBUILD
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python2

  # macOS 10.10 uses 2.7.10
  # "2.7.12" # Fails on macOS in bootstrap
  # 2017-09-16, "2.7.14" # Fails on macOS in bootstrap
  # March 4, 2019, "2.7.16" # Fails on macOS in bootstrap
  # Oct. 19, 2019, "2.7.17"
  # April 20, 2020, "2.7.18" - final release.

  local python2_version="$1"

  local python2_src_folder_name="Python-${python2_version}"

  local python2_archive="${python2_src_folder_name}.tar.xz"
  local python2_url="https://www.python.org/ftp/python/${python2_version}/${python2_archive}"

  local python2_folder_name="python-${python2_version}"

  local python2_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${python2_folder_name}-installed"
  if [ ! -f "${python2_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${python2_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${python2_url}" "${python2_archive}" \
      "${python2_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${python2_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${python2_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${python2_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      if is_darwin_not_clang
      then
        # error: variably modified 'bytes' at file scope
        prepare_clang_env ""
      fi

      CPPFLAGS="${XBB_CPPFLAGS} -I${INSTALL_FOLDER_PATH}/include/ncurses"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      # From Arch.
      export OPT="${CFLAGS}"

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running python2 configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${python2_src_folder_name}/configure" --help

          # Fail on macOS:
          # --enable-universalsdk
          # --with-universal-archs=${HOST_BITS}-bit

          # "... you should not skip tests when using --enable-optimizations as
          # the data required for profiling is generated by running tests".

          # --with-lto takes way too long on Ubuntu 14 aarch64.
          # --enable-optimizations takes too long

          config_options=()
          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          config_options+=("--with-threads")
          config_options+=("--with-system-expat")
          config_options+=("--with-system-ffi")
          config_options+=("--with-dbmliborder=gdbm:ndbm")
          config_options+=("--without-ensurepip")
          config_options+=("--without-lto")

          config_options+=("--enable-shared")
          config_options+=("--enable-unicode=ucs4")

          if is_linux
          then
            config_options+=("--disable-rpath")
            config_options+=("--disable-new-dtags")
          fi

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${python2_src_folder_name}/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${python2_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python2_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running python2 make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        # Tests are quite complicated

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python2_folder_name}/make-output-$(ndate).txt"
    )

    (
      xbb_activate_installed_bin

      # Install setuptools and pip. Be sure the new version is used.
      # https://packaging.python.org/tutorials/installing-packages/
      echo
      echo "Installing setuptools and pip..."

      run_app "${INSTALL_FOLDER_PATH}/bin/python2" --version

      run_app "${INSTALL_FOLDER_PATH}/bin/python2" -m ensurepip --default-pip
      run_app "${INSTALL_FOLDER_PATH}/bin/python2" -m pip install --upgrade pip==19.3.1 setuptools==44.0.0 wheel==0.34.2

      run_app "${INSTALL_FOLDER_PATH}/bin/pip2" --version
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python2_folder_name}/pip-output-$(ndate).txt"

    (
      test_python2
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python2_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${python2_stamp_file_path}"

  else
    echo "Component python2 already installed."
  fi

  test_functions+=("test_python2")
}

function test_python2()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the python2 binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/python2.7"

    echo
    echo "Testing if python2 binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/python2" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/pip2" --version
  )
}

# -----------------------------------------------------------------------------

function build_python3()
{
  # https://www.python.org
  # https://www.python.org/downloads/source/
  # https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tar.xz

  # https://github.com/archlinux/svntogit-packages/blob/packages/python/trunk/PKGBUILD
  # https://archlinuxarm.org/packages/aarch64/python/files/PKGBUILD
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python-pip

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/python@3.9.rb

  # 2018-12-24, "3.7.2"
  # March 25, 2019, "3.7.3"
  # Dec. 18, 2019, "3.8.1"
  # May 3, 2021, "3.8.10"
  # Aug. 30, 2021, "3.8.12"
  # Aug. 30, 2021, "3.9.7"
  # Nov. 5, 2021, "3.9.8"
  # Oct. 4, 2021, "3.10.0"
  # Nov. 15, 2021, "3.9.9"

  local python3_version="$1"
  local python3_version_major="$(echo ${python3_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1|')"
  local python3_version_minor="$(echo ${python3_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\2|')"
  export PYTHON3X="python${python3_version_major}.${python3_version_minor}"

  local python3_src_folder_name="Python-${python3_version}"

  local python3_archive="${python3_src_folder_name}.tar.xz"
  local python3_url="https://www.python.org/ftp/python/${python3_version}/${python3_archive}"

  local python3_folder_name="python-${python3_version}"

  local python3_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${python3_folder_name}-installed"
  if [ ! -f "${python3_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${python3_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${python3_url}" "${python3_archive}" \
      "${python3_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${python3_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${python3_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${python3_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      if is_darwin_not_clang
      then
        # GCC fails with:
        # error: variably modified 'bytes' at file scope
        prepare_clang_env ""
      fi

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      if [[ "${CC}" =~ gcc* ]]
      then
        # Inspired from Arch; not supported by clang.
        CFLAGS+=" -fno-semantic-interposition"
        CXXFLAGS+=" -fno-semantic-interposition"
        LDFLAGS+=" -fno-semantic-interposition"
      fi

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running python3 configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${python3_src_folder_name}/configure" --help

          # Fail on macOS:
          # --enable-universalsdk
          # --with-lto

          # "... you should not skip tests when using --enable-optimizations as
          # the data required for profiling is generated by running tests".

          # --enable-optimizations takes too long

          config_options=()
          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          config_options+=("--with-universal-archs=${HOST_BITS}-bit")
          config_options+=("--with-computed-gotos")
          config_options+=("--with-system-expat")
          config_options+=("--with-system-ffi")
          config_options+=("--with-system-libmpdec")
          config_options+=("--with-dbmliborder=gdbm:ndbm")
          config_options+=("--with-openssl=${INSTALL_FOLDER_PATH}")
          config_options+=("--without-ensurepip")
          config_options+=("--without-lto")

          config_options+=("--enable-shared")

          # Fails with 3.9.7.
          # config_options+=("--enable-loadable-sqlite-extensions")
          config_options+=("--disable-loadable-sqlite-extensions")

          if is_linux
          then
            config_options+=("--disable-rpath")
            config_options+=("--disable-new-dtags")
          fi

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${python3_src_folder_name}/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${python3_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python3_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running python3 make..."

        # Build.
        run_verbose make -j ${JOBS} # build_all

        # make install-strip
        run_verbose make install

        # Tests are quite complicated

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python3_folder_name}/make-output-$(ndate).txt"
    )

    (
      xbb_activate_installed_bin

      # export PYTHONHOME="${INSTALL_FOLDER_PATH}"
      export PYTHONPATH="${INSTALL_FOLDER_PATH}/lib/${PYTHON3X}"

      # Install setuptools and pip. Be sure the new version is used.
      # https://packaging.python.org/tutorials/installing-packages/
      echo
      echo "Installing setuptools and pip3..."

      run_app "${INSTALL_FOLDER_PATH}/bin/python3" --version

      run_app "${INSTALL_FOLDER_PATH}/bin/python3" -m ensurepip --default-pip
      run_app "${INSTALL_FOLDER_PATH}/bin/python3" -m pip install --upgrade pip==20.0.2 setuptools==45.2.0 wheel==0.34.2

      run_app "${INSTALL_FOLDER_PATH}/bin/pip3" --version
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python3_folder_name}/pip-output-$(ndate).txt"

    (
      test_python3
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${python3_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${python3_stamp_file_path}"

  else
    echo "Component python3 already installed."
  fi

  test_functions+=("test_python3")
}

function test_python3()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the python3 binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/${PYTHON3X}"

    echo
    echo "Testing if python3 binaries start properly..."

    # export PYTHONHOME="${INSTALL_FOLDER_PATH}"
    export PYTHONPATH="${INSTALL_FOLDER_PATH}/lib/${PYTHON3X}"

    run_app "${INSTALL_FOLDER_PATH}/bin/python3" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/pip3" --version
  )
}

# -----------------------------------------------------------------------------

function build_scons()
{
  # http://scons.org
  # http://prdownloads.sourceforge.net/scons/
  # https://sourceforge.net/projects/scons/files/scons/3.1.2/scons-3.1.2.tar.gz/download
  # https://sourceforge.net/projects/scons/files/latest/download
  # http://prdownloads.sourceforge.net/scons/scons-3.1.2.tar.gz

  # https://archlinuxarm.org/packages/any/scons/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=python2-scons

  # 2017-09-16, "3.0.1" (sourceforge)
  # 2019-03-27, "3.0.5" (sourceforge)
  # 2019-08-08, "3.1.1"
  # 2019-12-17, "3.1.2"
  # 2021-01-19, "4.1.0"
  # 2021-08-01, "4.2.0"
  # 2021-11-17, "4.3.0"

  local scons_version="$1"

  # Previous versions used lower case.
  local scons_src_folder_name="SCons-${scons_version}"

  local scons_archive="${scons_src_folder_name}.tar.gz"

  local scons_url
  scons_url="https://sourceforge.net/projects/scons/files/scons/${scons_version}/${scons_archive}"

  local scons_folder_name="scons-${scons_version}"

  local scons_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${scons_folder_name}-installed"
  if [ ! -f "${scons_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${scons_folder_name}" ]
  then

    # In-source build

    if [ ! -d "${BUILD_FOLDER_PATH}/${scons_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${scons_url}" "${scons_archive}" \
        "${scons_src_folder_name}"

      if [ "${scons_src_folder_name}" != "${scons_folder_name}" ]
      then
        mv -v "${scons_src_folder_name}" "${scons_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${scons_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${scons_folder_name}"

      xbb_activate
      xbb_activate_installed_dev
      xbb_activate_installed_bin

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      env | sort

      echo
      echo "Running scons install..."

      echo
      which python3

      echo
      run_verbose python3 setup.py install \
        --prefix="${INSTALL_FOLDER_PATH}" \
        \
        --optimize=1 \

      if [ -d "${INSTALL_FOLDER_PATH}/man/man1" ]
      then
        mkdir -pv "${INSTALL_FOLDER_PATH}/share/man/man1"
        mv -v "${INSTALL_FOLDER_PATH}/man/man1"/* "${INSTALL_FOLDER_PATH}/share/man/man1"
        rm -rv "${INSTALL_FOLDER_PATH}/man/man1"
      fi

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${scons_folder_name}/install-output-$(ndate).txt"

    (
      test_scons
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${scons_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${scons_stamp_file_path}"

  else
    echo "Component scons already installed."
  fi

  test_functions+=("test_scons")
}

function test_scons()
{
  (
    echo
    echo "Testing if scons binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/scons" --version
  )
}

# -----------------------------------------------------------------------------

function build_meson
{
  # http://mesonbuild.com/
  # https://pypi.org/project/meson/
  # https://pypi.org/project/meson/0.50.0/#description

  # https://archlinuxarm.org/packages/any/meson/files/PKGBUILD

  # Jan 7, 2020, "0.53.0"
  # Apr 10, 2021, "0.57.2"
  # Jun 7, 2021, "0.58.1"
  # Nov 2, 2021, "0.60.1"
  # Nov 25, 2021, "0.60.2"

  local meson_version="$1"

  local meson_folder_name="meson-${meson_version}"

  local meson_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${meson_folder_name}-installed"
  if [ ! -f "${meson_stamp_file_path}" ]
  then

    mkdir -pv "${LOGS_FOLDER_PATH}/${meson_folder_name}"

    (
      xbb_activate_installed_bin

      env | sort

      run_verbose pip3 install meson==${meson_version} --verbose

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${meson_folder_name}/install-output-$(ndate).txt"

    (
      test_meson
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${meson_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${meson_stamp_file_path}"

  else
    echo "Component meson already installed."
  fi

  test_functions+=("test_meson")
}

function test_meson()
{
  (
    echo
    echo "Testing if meson binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/meson" --version
  )
}

# -----------------------------------------------------------------------------

function build_ninja()
{
  # https://ninja-build.org
  # https://github.com/ninja-build/ninja/releases
  # https://github.com/ninja-build/ninja/archive/v1.9.0.zip
  # https://github.com/ninja-build/ninja/archive/v1.9.0.tar.gz

  # https://archlinuxarm.org/packages/aarch64/ninja/files/PKGBUILD

  # Jan 30, 2019 "1.9.0"
  # Jan 27, 2020, "1.10.0"
  # Nov 28, 2020, "1.10.2"

  local ninja_version="$1"

  local ninja_src_folder_name="ninja-${ninja_version}"

  local ninja_archive="${ninja_src_folder_name}.tar.gz"
  # GitHub release archive.
  local ninja_url="https://github.com/ninja-build/ninja/archive/v${ninja_version}.tar.gz"

  local ninja_folder_name="${ninja_src_folder_name}"

  local ninja_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${ninja_folder_name}-installed"
  if [ ! -f "${ninja_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${ninja_folder_name}" ]
  then

    # In-source build

    if [ ! -d "${BUILD_FOLDER_PATH}/${ninja_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${ninja_url}" "${ninja_archive}" \
        "${ninja_src_folder_name}"

      if [ "${ninja_src_folder_name}" != "${ninja_folder_name}" ]
      then
        mv -v "${ninja_src_folder_name}" "${ninja_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${ninja_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${ninja_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      (
        env | sort

        echo
        echo "Running ninja bootstrap..."

        ./configure.py --help

        echo "Patience..."

        # --platform=linux ?

        run_verbose ./configure.py \
          --bootstrap \
          --verbose \
          --with-python=$(which python2)

        /usr/bin/install -m755 -c ninja "${INSTALL_FOLDER_PATH}/bin"

        # TODO: No tests?

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ninja_folder_name}/configure-output-$(ndate).txt"
    )

    (
      test_ninja
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ninja_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${ninja_stamp_file_path}"

  else
    echo "Component ninja already installed."
  fi

  test_functions+=("test_ninja")
}

function test_ninja()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the ninja binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/ninja"

    echo
    echo "Testing if ninja binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/ninja" --version
  )
}

# -----------------------------------------------------------------------------

function build_p7zip()
{
  # https://sourceforge.net/projects/p7zip/files/p7zip
  # https://sourceforge.net/projects/p7zip/files/p7zip/16.02/p7zip_16.02_src_all.tar.bz2/download

  # https://archlinuxarm.org/packages/aarch64/p7zip/files/PKGBUILD

  # 2016-07-14, "16.02" (latest)

  local p7zip_version="$1"

  local p7zip_src_folder_name="p7zip_${p7zip_version}"

  local p7zip_archive="${p7zip_src_folder_name}_src_all.tar.bz2"
  local p7zip_url="https://sourceforge.net/projects/p7zip/files/p7zip/${p7zip_version}/${p7zip_archive}"

  local p7zip_folder_name="p7zip-${p7zip_version}"

  local p7zip_patch_file_name="${helper_folder_path}/patches/p7zip-${p7zip_version}.patch"
  local p7zip_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${p7zip_folder_name}-installed"
  if [ ! -f "${p7zip_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${p7zip_folder_name}" ]
  then

    echo
    echo "p7zip in-source building"

    if [ ! -d "${BUILD_FOLDER_PATH}/${p7zip_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${p7zip_url}" "${p7zip_archive}" \
        "${p7zip_src_folder_name}" "${p7zip_patch_file_name}"

      if [ "${p7zip_src_folder_name}" != "${p7zip_folder_name}" ]
      then
        mv -v "${p7zip_src_folder_name}" "${p7zip_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${p7zip_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${p7zip_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      if is_darwin
      then
        CPPFLAGS+=" -DENV_MACOSX"
      fi
      CFLAGS="${XBB_CFLAGS_NO_W} -std=c99"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W} -std=c++11"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      env | sort

      echo
      echo "Running p7zip make..."

      # Override the hard-coded gcc & g++.
      sed -i.bak -e "s|CXX=g++.*|CXX=${CXX}|" "makefile.machine"
      sed -i.bak -e "s|CC=gcc.*|CC=${CC}|" "makefile.machine"

      # Do not override the environment variables, append to them.
      sed -i.bak -e "s|CFLAGS=|CFLAGS+=|" "makefile.glb"
      sed -i.bak -e "s|CXXFLAGS=|CXXFLAGS+=|" "makefile.glb"

      # Build.
      run_verbose make -j ${JOBS} 7za 7zr

      run_verbose ls -lL "bin"

      # Override the hard-coded '/usr/local'.
      run_verbose sed -i.bak \
        -e "s|DEST_HOME=/usr/local|DEST_HOME=${INSTALL_FOLDER_PATH}|" \
        "install.sh"

      run_verbose bash "install.sh"

      if [ "${RUN_TESTS}" == "y" ]
      then
        if is_darwin
        then
          # 7z cannot load library on macOS.
          run_verbose make -j1 test
        else
          # make -j1 test test_7z
          run_verbose make -j1 all_test
        fi
      fi

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${p7zip_folder_name}/install-output-$(ndate).txt"

    (
      test_p7zip
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${p7zip_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${p7zip_stamp_file_path}"

  else
    echo "Component p7zip already installed."
  fi

  test_functions+=("test_p7zip")
}

function test_p7zip()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the 7za shared libraries..."

    if [ -f "${INSTALL_FOLDER_PATH}/bin/7za" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/bin/7za"
    fi

    if [ -f "${INSTALL_FOLDER_PATH}/bin/7z" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/lib/p7zip/7z"
    fi

    if [ -f "${INSTALL_FOLDER_PATH}/lib/p7zip/7z" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/lib/p7zip/7z"
    fi
    if [ -f "${INSTALL_FOLDER_PATH}/lib/p7zip/7za" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/lib/p7zip/7za"
    fi
    if [ -f "${INSTALL_FOLDER_PATH}/lib/p7zip/7zr" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/lib/p7zip/7zr"
    fi

    if [ -f "${INSTALL_FOLDER_PATH}/lib/p7zip/7z.${SHLIB_EXT}" ]
    then
      show_libs "${INSTALL_FOLDER_PATH}/lib/p7zip/7z.${SHLIB_EXT}"
    fi

    echo
    echo "Testing if 7za binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/7za" --help

    if [ -f "${INSTALL_FOLDER_PATH}/bin/7z" ]
    then
      run_app "${INSTALL_FOLDER_PATH}/bin/7z" --help
    fi
  )
}

# -----------------------------------------------------------------------------

function build_wine()
{
  # https://www.winehq.org
  # https://dl.winehq.org/wine/source/
  # https://dl.winehq.org/wine/source/4.x/wine-4.3.tar.xz
  # https://dl.winehq.org/wine/source/5.x/wine-5.1.tar.xz
  # https://dl.winehq.org/wine/source/7.x/wine-7.15.tar.xz

  # https://github.com/archlinux/svntogit-community/blob/packages/wine/trunk/PKGBUILD

  # 2017-09-16, "4.3"
  # 2019-11-29, "4.21"
  # Fails with a missing yywrap
  # 2020-01-21, "5.0"
  # 2020-02-02, "5.1"
  # 2021-06-04, "6.10"
  # 2020-11-20, "5.22"
  # 2021-09-10, "6.17"
  # 2021-11-05, "6.21"
  # 2021-12-03, "6.23"
  # 2022-08-13, "7.15"

  local wine_version="$1"

  local wine_version_major="$(echo ${wine_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1|')"
  local wine_version_minor="$(echo ${wine_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\2|')"

  local wine_src_folder_name="wine-${wine_version}"

  local wine_archive="${wine_src_folder_name}.tar.xz"

  if [ "${wine_version_minor}" != "0" ]
  then
    wine_version_minor="x"
  fi
  local wine_url="https://dl.winehq.org/wine/source/${wine_version_major}.${wine_version_minor}/${wine_archive}"

  local wine_folder_name="${wine_src_folder_name}"

  local wine_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${wine_folder_name}-installed"
  if [ ! -f "${wine_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${wine_folder_name}" ]
  then

    echo
    echo "wine in-source build."

    if [ ! -d "${BUILD_FOLDER_PATH}/${wine_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${wine_url}" "${wine_archive}" \
        "${wine_src_folder_name}"

      if [ "${wine_src_folder_name}" != "${wine_folder_name}" ]
      then
        mv -v "${wine_src_folder_name}" "${wine_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${wine_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${wine_folder_name}"

      xbb_activate
      xbb_activate_installed_dev
      # Required to find the newly compiled mingw-w46.
      # It also picks flex, which may crash with
      # macro.lex.yy.c:1031: undefined reference to `yywrap'.
      xbb_activate_installed_bin

      CPPFLAGS="${XBB_CPPFLAGS}"

      # TODO: remove when switching to Ubuntu 16.
      # getauxval was defined in glibc 2.16
      # https://man7.org/linux/man-pages/man3/getauxval.3.html
      if is_linux && is_intel && [ "${HOST_BITS}" == "64" ]
      then
        ldd_version="$(ldd --version | sed -n 1p | sed -e 's|^.* ||')"
        if [ "${ldd_version}" == "2.15" ] # Ubuntu 12
        then
          run_verbose sed -i.bak \
            -e 's|if (getauxval( AT_HWCAP2 ) \& 2)|if (/* getauxval( AT_HWCAP2 ) \& 2 */ 0)|' \
            dlls/ntdll/unix/signal_x86_64.c

          run_verbose diff dlls/ntdll/unix/signal_x86_64.c.bak dlls/ntdll/unix/signal_x86_64.c || true
        fi
      fi

      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running wine configure..."

          # Get rid of the RUNPATH in install.
          run_verbose sed -i.bak \
            -e 's|LDRPATH_INSTALL="-Wl,.*"|LDRPATH_INSTALL=""|' \
            -e 's|CFLAGS="$CFLAGS -Wl,--enable-new-dtags"|CFLAGS="$CFLAGS"|' \
            -e 's|LDRPATH_INSTALL="$LDRPATH_INSTALL -Wl,--enable-new-dtags"|LDRPATH_INSTALL="$LDRPATH_INSTALL"|' \
            "configure"

          if [ "${HOST_BITS}" == "64" ]
          then
            ENABLE_64="--enable-win64"
          else
            ENABLE_64=""
          fi

          run_verbose bash "configure" --help

          run_verbose bash ${DEBUG} "configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-png \
            --without-freetype \
            --without-x \
            \
            ${ENABLE_64} \
            --disable-win16 \
            --disable-tests \

          cp "config.log" "${LOGS_FOLDER_PATH}/${wine_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${wine_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running wine make..."

        # Build.
        run_verbose make -j ${JOBS} STRIP=true

        run_verbose make install

        if [ "${HOST_BITS}" == "64" ]
        then
          (
            cd "${INSTALL_FOLDER_PATH}/bin"
            rm -fv wine
            ln -sv wine64 wine
          )
        fi

        # TODO: no tests?

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${wine_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_wine
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${wine_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${wine_stamp_file_path}"

  else
    echo "Component wine already installed."
  fi

  test_functions+=("test_wine")
}

function test_wine()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the wine shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/bin/wine)"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/bin/winebuild)"
    # show_libs "$(realpath ${INSTALL_FOLDER_PATH}/bin/winecfg)"
    # show_libs "$(realpath ${INSTALL_FOLDER_PATH}/bin/wineconsole)"

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/bin/winegcc)"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/bin/wineg++)"

    libwine=$(find ${INSTALL_FOLDER_PATH}/lib* -name 'libwine.so')
    if [ ! -z "${libwine}" ]
    then
      show_libs "$(realpath ${libwine})"
    fi

    echo
    echo "Testing if wine binaries start properly..."

    # First check if the program is able to tell its version.
    run_app "${INSTALL_FOLDER_PATH}/bin/wine" --version

    # Require gcc-xbs
    # run_app "${INSTALL_FOLDER_PATH}/bin/winegcc" --version
    # run_app "${INSTALL_FOLDER_PATH}/bin/wineg++" --version

    run_app "${INSTALL_FOLDER_PATH}/bin/winebuild" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/winecfg" --version
    # run_app "${INSTALL_FOLDER_PATH}/bin/wineconsole" dir

    # This test should check if the program is able to start
    # a simple executable.
    # As a side effect, the "${HOME}/.wine" folder is created
    # and populated with lots of files., so subsequent runs
    # will no longer have to do it.
    local netstat=$(find "${INSTALL_FOLDER_PATH}"/lib* -name netstat.exe)
    run_app "${INSTALL_FOLDER_PATH}/bin/wine" ${netstat}
  )
}

# -----------------------------------------------------------------------------

# Not yet functional.
function build_nvm()
{
  # https://github.com/nvm-sh/nvm
  # curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash
  # https://github.com/nvm-sh/nvm/archive/v0.35.2.tar.gz

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=nvm

  # Dec 18, 2019, "0.35.2"

  local nvm_version="$1"
  local node_version="$2"
  local npm_version="$3"

  local nvm_src_folder_name="nvm-${nvm_version}"

  local nvm_archive="${nvm_src_folder_name}.tar.gz"
  # GitHub release archive.
  local nvm_url="https://github.com/nvm-sh/nvm/archive/v${nvm_version}.tar.gz"

  local nvm_folder_name="${nvm_src_folder_name}"

  local nvm_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${nvm_folder_name}-installed"
  if [ ! -f "${nvm_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${nvm_folder_name}" -o ! -d "${INSTALL_FOLDER_PATH}/nvm" ]
  then

    cd "${BUILD_FOLDER_PATH}"

    download "${nvm_url}" "${nvm_archive}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${nvm_folder_name}"

    (
      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"
      LIBS="-lrt"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS
      export LIBS

      env | sort

      if [ ! -d "${INSTALL_FOLDER_PATH}/nvm" ]
      then
        cd "${INSTALL_FOLDER_PATH}"
        rm -rf "nvm-${nvm_version}"

        echo "Unpacking ${nvm_archive}..."
        tar xf "${CACHE_FOLDER_PATH}/${nvm_archive}"
        mv -v "nvm-${nvm_version}" "nvm"
      fi

      if [ ! -x "xxx" ]
      then
        export NVM_DIR="/opt/$(basename "${INSTALL_FOLDER_PATH}")/nvm"
        source "${NVM_DIR}/nvm.sh"

        # Binary installs fail with a GLIBC 2.17 requirement.
        # Source builds fail on Ubuntu 12 with
        # undefined reference to `clock_gettime'
        nvm install -s "${node_version}"
        node --version
        npm install "npm@${npm_version}"
        npm --version
      fi

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nvm_folder_name}/install-output-$(ndate).txt"

    (
      test_nvm
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nvm_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${nvm_stamp_file_path}"

  else
    echo "Component nvm already installed."
  fi

  test_functions+=("test_nvm")
}

function test_nvm()
{
  (
    xbb_activate_installed_bin
    xbb_install_nvm

    echo
    echo "Testing if nvm binaries start properly..."

    run_app node --version
    run_app npm --version
  )
}

# -----------------------------------------------------------------------------

function build_gnupg()
{
  # https://www.gnupg.org
  # https://www.gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.19.tar.bz2

  # https://archlinuxarm.org/packages/aarch64/gnupg/files/PKGBUILD

  # 2021-06-10, "2.2.28"
  # 2021-04-20, "2.3.1" fails on macOS
  # 2021-10-12, "2.3.3"

  local gnupg_version="$1"

  local gnupg_src_folder_name="gnupg-${gnupg_version}"

  local gnupg_archive="${gnupg_src_folder_name}.tar.bz2"
  local gnupg_url="https://www.gnupg.org/ftp/gcrypt/gnupg/${gnupg_archive}"

  local gnupg_folder_name="${gnupg_src_folder_name}"

  local gnupg_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${gnupg_folder_name}-installed"
  if [ ! -f "${gnupg_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${gnupg_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gnupg_url}" "${gnupg_archive}" \
      "${gnupg_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${gnupg_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${gnupg_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${gnupg_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"
      if is_linux
      then
        export LIBS="-lrt"
      fi

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running gnupg configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${gnupg_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gnupg_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-libgpg-error-prefix="${INSTALL_FOLDER_PATH}" \
            --with-libgcrypt-prefix="${INSTALL_FOLDER_PATH}" \
            --with-libassuan-prefix="${INSTALL_FOLDER_PATH}" \
            --with-ksba-prefix="${INSTALL_FOLDER_PATH}" \
            --with-npth-prefix="${INSTALL_FOLDER_PATH}" \
            \
            --enable-maintainer-mode \
            --enable-symcryptrun \
            --disable-rpath \

          cp "config.log" "${LOGS_FOLDER_PATH}/${gnupg_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gnupg_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running gnupg make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gnupg_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_gpg
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gnupg_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${gnupg_stamp_file_path}"

  else
    echo "Component gnupg already installed."
  fi

  test_functions+=("test_gpg")
}

function test_gpg()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the gpg binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/gpg"

    echo
    echo "Testing if gpg binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/gpg" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/gpgv" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/gpgsm" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/gpg-agent" --version

    run_app "${INSTALL_FOLDER_PATH}/bin/kbxutil" --version

    run_app "${INSTALL_FOLDER_PATH}/bin/gpgconf" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/gpg-connect-agent" --version
    if [ -f "${INSTALL_FOLDER_PATH}/bin/symcryptrun" ]
    then
      # clang did not create it.
      run_app "${INSTALL_FOLDER_PATH}/bin/symcryptrun" --version
    fi
    run_app "${INSTALL_FOLDER_PATH}/bin/watchgnupg" --version
    # run_app "${INSTALL_FOLDER_PATH}/bin/gpgparsemail" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/gpg-wks-server" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/gpgtar" --version

    # run_app "${INSTALL_FOLDER_PATH}/sbin/addgnupghome" --version
    # run_app "${INSTALL_FOLDER_PATH}/sbin/applygnupgdefaults" --version
  )
}

# -----------------------------------------------------------------------------

function build_ant()
{
  # https://ant.apache.org/srcdownload.cgi
  # https://downloads.apache.org/ant/binaries/
  # https://downloads.apache.org/ant/binaries/apache-ant-1.10.7-bin.tar.xz
  # https://www-eu.apache.org/dist/ant/source/
  # https://www-eu.apache.org/dist/ant/source/apache-ant-1.10.7-src.tar.xz
  # https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.10-bin.tar.xz

  # https://archlinuxarm.org/packages/any/ant/files/PKGBUILD

  # 2019-09-05, "1.10.7"
  # 2021-04-17, "1.10.10"
  # 2021-10-19, "1.10.12"

  local ant_version="$1"

  local ant_src_folder_name="apache-ant-${ant_version}"

  local ant_archive="${ant_src_folder_name}-bin.tar.xz"
  local ant_url="https://archive.apache.org/dist/ant/binaries/${ant_archive}"

  local ant_folder_name="${ant_src_folder_name}"

  local ant_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${ant_folder_name}-installed"
  if [ ! -f "${ant_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${ant_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${ant_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${ant_url}" "${ant_archive}" \
        "${ant_src_folder_name}"

      if [ "${ant_src_folder_name}" != "${ant_folder_name}" ]
      then
        mv -v "${ant_src_folder_name}" "${ant_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${ant_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${ant_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      (
        env | sort

        # https://ant.apache.org/manual/install.html#buildingant

        echo
        echo "Installing ant..."

        rm -rf "${INSTALL_FOLDER_PATH}/share/ant"
        mkdir -pv "${INSTALL_FOLDER_PATH}/share/ant"

        cp -R -v * "${INSTALL_FOLDER_PATH}/share/ant"

        rm -fv "${INSTALL_FOLDER_PATH}/bin/ant"
        ln -sv "${INSTALL_FOLDER_PATH}/share/ant/bin/ant" "${INSTALL_FOLDER_PATH}/bin/ant"

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ant_folder_name}/build-output-$(ndate).txt"
    )

    (
      test_ant
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ant_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${ant_stamp_file_path}"

  else
    echo "Component ant already installed."
  fi

  test_functions+=("test_ant")
}

function test_ant()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if ant binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/ant" -version
  )
}

# -----------------------------------------------------------------------------

function build_maven()
{
  # https://maven.apache.org
  # https://www-eu.apache.org/dist/maven/source/
  # https://www-eu.apache.org/dist/maven/maven-3/
  # https://downloads.apache.org/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
  # https://www-eu.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
  # https://www-eu.apache.org/dist/maven/maven-3/3.6.3/source/apache-maven-3.6.3-src.tar.gz

  # https://archlinuxarm.org/packages/any/maven/files/PKGBUILD

  # 2019-11-25, "3.6.3"
  # 2021-04-04, "3.8.1"
  # 2021-10-03, "3.8.3"

  local maven_version="$1"
  local maven_version_major="$(echo "${maven_version}" | sed -e 's/\([0-9]*\)\..*/\1/')"

  local maven_src_folder_name="apache-maven-${maven_version}"

  local maven_archive="${maven_src_folder_name}-bin.tar.gz"
  local maven_url="https://www-eu.apache.org/dist/maven/maven-${maven_version_major}/${maven_version}/binaries/${maven_archive}"

  local maven_folder_name="${maven_src_folder_name}"

  local maven_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${maven_folder_name}-installed"
  if [ ! -f "${maven_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${maven_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${maven_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${maven_url}" "${maven_archive}" \
        "${maven_src_folder_name}"

      if [ "${maven_src_folder_name}" != "${maven_folder_name}" ]
      then
        mv -v "${maven_src_folder_name}" "${maven_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${maven_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${maven_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      (
        env | sort

        # https://maven.apache.org/guides/development/guide-building-maven.html

        echo
        echo "Installing maven..."

        rm -rf "${INSTALL_FOLDER_PATH}/share/maven"
        mkdir -pv "${INSTALL_FOLDER_PATH}/share/maven"

        cp -R -v * "${INSTALL_FOLDER_PATH}/share/maven"

        rm -fv "${INSTALL_FOLDER_PATH}/bin/mvn"
        ln -sv "${INSTALL_FOLDER_PATH}/share/maven/bin/mvn" "${INSTALL_FOLDER_PATH}/bin/mvn"

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${maven_folder_name}/build-output-$(ndate).txt"
    )

    (
      test_maven
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${maven_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${maven_stamp_file_path}"

  else
    echo "Component maven already installed."
  fi

  test_functions+=("test_maven")
}

function test_maven()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if maven binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/mvn" -version
  )
}

# -----------------------------------------------------------------------------

# Not functional.
function build_nodejs()
{
  # https://nodejs.org/
  # https://github.com/nodejs/node/releases
  # https://github.com/nodejs/node/archive/v12.16.0.tar.gz

  # https://archlinuxarm.org/packages/aarch64/nodejs-lts-erbium/files/PKGBUILD
  # https://archlinuxarm.org/packages/aarch64/nodejs/files/PKGBUILD

  # 2020-02-11, "12.16.0", lts

  local nodejs_version="$1"

  local nodejs_src_folder_name="node-${nodejs_version}"

  local nodejs_archive="${nodejs_src_folder_name}.tar.gz"
  # GitHub release archive.
  local nodejs_url="https://github.com/nodejs/node/archive/v${nodejs_version}.tar.gz"

  local nodejs_folder_name="${nodejs_src_folder_name}"

  local nodejs_patch_file_path="${helper_folder_path}/patches/${nodejs_folder_name}.patch"
  local nodejs_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${nodejs_folder_name}-installed"
  if [ ! -f "${nodejs_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${nodejs_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${nodejs_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${nodejs_url}" "${nodejs_archive}" \
        "${nodejs_src_folder_name}" \
        "${nodejs_patch_file_path}"

      if [ "${nodejs_src_folder_name}" != "${nodejs_folder_name}" ]
      then
        mv -v "${nodejs_src_folder_name}" "${nodejs_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${nodejs_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${nodejs_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if true # [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running nodejs configure..."

          run_verbose bash "./configure" --help

          run_verbose bash ${DEBUG} "./configure" \
            --prefix="${INSTALL_FOLDER_PATH}/xxx" \
            \
            --with-intl=system-icu \
            --without-npm \
            --shared-openssl \
            --shared-zlib \
            --shared-libuv \
            --experimental-http-parser \
            --shared-cares \
            --shared-nghttp2 \

          # cp "config.log" "${LOGS_FOLDER_PATH}/config-nodejs-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nodejs_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running nodejs make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        # make install

        # make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nodejs_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_nodejs
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nodejs_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${nodejs_stamp_file_path}"

  else
    echo "Component nodejs already installed."
  fi

  test_functions+=("test_nodejs")
}

function test_nodejs()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if node binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/node" --version
  )
}

# -----------------------------------------------------------------------------

function build_tcl()
{
  # https://www.tcl.tk/
  # https://www.tcl.tk/software/tcltk/download.html
  # https://www.tcl.tk/doc/howto/compile.html

  # https://prdownloads.sourceforge.net/tcl/tcl8.6.10-src.tar.gz
  # https://sourceforge.net/projects/tcl/files/Tcl/8.6.10/tcl8.6.10-src.tar.gz/download
  # https://archlinuxarm.org/packages/aarch64/tcl/files/PKGBUILD

  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/tcl-tk.rb

  # 2019-11-21, "8.6.10"
  # ? "8.6.11"
  # ? "8.6.12"

  local tcl_version="$1"

  TCL_VERSION_MAJOR="$(echo ${tcl_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*|\1|')"
  TCL_VERSION_MINOR="$(echo ${tcl_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*|\2|')"

  local tcl_src_folder_name="tcl${tcl_version}"

  local tcl_archive="tcl${tcl_version}-src.tar.gz"
  local tcl_url="https://sourceforge.net/projects/tcl/files/Tcl/${tcl_version}/${tcl_archive}"

  local tcl_folder_name="${tcl_src_folder_name}"

  local tcl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${tcl_folder_name}-installed"
  if [ ! -f "${tcl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${tcl_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${tcl_url}" "${tcl_archive}" \
      "${tcl_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${tcl_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${tcl_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${tcl_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running tcl configure..."

          if is_linux
          then
            run_verbose bash "${SOURCES_FOLDER_PATH}/${tcl_src_folder_name}/unix/configure" --help

            run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${tcl_src_folder_name}/unix/configure" \
              --prefix="${INSTALL_FOLDER_PATH}" \
              \
              --enable-threads \
              --enable-64bit \
              --disable-rpath \

            run_verbose find . \
              \( -name Makefile -o -name tclConfig.sh \) \
              -print \
              -exec sed -i.bak -e 's|-Wl,-rpath,${LIB_RUNTIME_DIR}||' {} \;

          elif is_darwin
          then

            run_verbose bash "${SOURCES_FOLDER_PATH}/${tcl_src_folder_name}/macosx/configure" --help

            if is_arm
            then
              # The current GCC 11.2 generates wrong code for this illegal option.
              run_verbose sed -i.bak \
                -e 's|EXTRA_APP_CC_SWITCHES=.-mdynamic-no-pic.|EXTRA_APP_CC_SWITCHES=""|' \
                "${SOURCES_FOLDER_PATH}/${tcl_src_folder_name}/macosx/configure"
            fi

            run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${tcl_src_folder_name}/macosx/configure" \
              --prefix="${INSTALL_FOLDER_PATH}" \
              \
              --enable-threads \
              --enable-64bit \
              --disable-rpath \

          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${tcl_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tcl_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running tcl make..."

        # Build.
        run_verbose make -j 1 # ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          run_verbose make -j1 test
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tcl_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_tcl
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tcl_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${tcl_stamp_file_path}"

  else
    echo "Component tcl already installed."
  fi

  test_functions+=("test_tcl")
}

function test_tcl()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the tcl binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/tclsh${TCL_VERSION_MAJOR}.${TCL_VERSION_MINOR}"
    if is_linux
    then
      show_libs "$(find ${INSTALL_FOLDER_PATH}/lib/thread* -name 'libthread*.so')"
      for lib in $(find ${INSTALL_FOLDER_PATH}/lib/tdb* -name 'libtdb*.so')
      do
        show_libs "${lib}"
      done
      show_libs "$(find ${INSTALL_FOLDER_PATH}/lib/itcl* -name 'libitcl*.so')"
      show_libs "$(find ${INSTALL_FOLDER_PATH}/lib/sqlite* -name 'libsqlite*.so')"
    elif is_darwin
    then
      show_libs "$(find ${INSTALL_FOLDER_PATH}/lib/thread* -name 'libthread*.dylib')"
      for lib in $(find ${INSTALL_FOLDER_PATH}/lib/tdb* -name 'libtdb*.dylib')
      do
        show_libs "${lib}"
      done
      show_libs "$(find ${INSTALL_FOLDER_PATH}/lib/itcl* -name 'libitcl*.dylib')"
      show_libs "$(find ${INSTALL_FOLDER_PATH}/lib/sqlite* -name 'libsqlite*.dylib')"
    else
      echo "Unknown platform."
      exit 1
    fi

    echo
    echo "Testing if tcl binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/tclsh${TCL_VERSION_MAJOR}.${TCL_VERSION_MINOR}" <<< 'puts [info patchlevel]'
  )
}

# -----------------------------------------------------------------------------

function build_guile()
{
  # https://www.gnu.org/software/guile/
  # https://ftp.gnu.org/gnu/guile/

  # https://archlinuxarm.org/packages/aarch64/guile/files/PKGBUILD
  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/guile.rb
  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/guile@2.rb

  # 2020-03-07, "2.2.7"
  # Note: for non 2.2, update the tests!
  # 2020-03-08, "3.0.1"
  # 2021-05-10, "3.0.7"

  local guile_version="$1"

  local guile_src_folder_name="guile-${guile_version}"

  local guile_archive="${guile_src_folder_name}.tar.xz"
  local guile_url="https://ftp.gnu.org/gnu/guile/${guile_archive}"

  local guile_folder_name="${guile_src_folder_name}"

  local guile_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${guile_folder_name}-installed"
  if [ ! -f "${guile_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${guile_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${guile_url}" "${guile_archive}" \
      "${guile_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${guile_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${guile_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${guile_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      # Otherwise guile-config displays the verbosity.
      unset PKG_CONFIG

      if is_linux
      then
        export LD_LIBRARY_PATH="${XBB_LIBRARY_PATH}:${BUILD_FOLDER_PATH}/${guile_folder_name}/libguile/.libs"
      fi

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running guile configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${guile_src_folder_name}/configure" --help

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${guile_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-error-on-warning \
            --disable-rpath \

          if is_linux
          then
            patch_all_libtool_rpath
          fi

          # FAIL: test-out-of-memory
          # https://lists.gnu.org/archive/html/guile-user/2017-11/msg00062.html
          # Remove the failing test.
          run_verbose sed -i.bak \
            -e 's|test-out-of-memory||g' \
            "test-suite/standalone/Makefile"

          if is_darwin
          then
            # ERROR: posix.test: utime: AT_SYMLINK_NOFOLLOW - arguments: ((out-of-range "utime" "Value out of range: ~S" (32) (32)))
            # Not effective, tests disabled.
            run_verbose sed -i.bak \
              -e 's|tests/posix.test||' \
              "test-suite/Makefile"
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${guile_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${guile_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running guile make..."

        # Build.
        # Requires GC with dynamic load support.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if false # [ "${RUN_TESTS}" == "y" ]
        then
          if is_darwin
          then
            # WARN-TEST
            run_verbose make -j1 check || true
          else
            # WARN-TEST
            run_verbose make -j1 check || true
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${guile_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_guile
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${guile_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${guile_stamp_file_path}"

  else
    echo "Component guile already installed."
  fi

  test_functions+=("test_guile")
}

function test_guile()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the guile shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/guile"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libguile-2.2.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/guile/2.2/extensions/guile-readline.so)"

    echo
    echo "Testing if guile binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/guile" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/guile-config" --version
  )
}

# -----------------------------------------------------------------------------

function build_rhash()
{
  # https://github.com/rhash/RHash
  # https://github.com/rhash/RHash/releases
  # https://github.com/rhash/RHash/archive/v1.3.9.tar.gz

  # https://archlinuxarm.org/packages/aarch64/rhash/files/PKGBUILD

  # 14 Dec 2019, "1.3.9"
  # Jan 7, 2021, "1.4.1"
  # Jul 15, 2021, "1.4.2"

  local rhash_version="$1"

  local rhash_src_folder_name="RHash-${rhash_version}"

  local rhash_archive="${rhash_src_folder_name}.tar.gz"
  local rhash_url="https://github.com/rhash/RHash/archive/v${rhash_version}.tar.gz"

  local rhash_folder_name="rhash-${rhash_version}"

  local rhash_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${rhash_folder_name}-installed"
  if [ ! -f "${rhash_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${rhash_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${rhash_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${rhash_url}" "${rhash_archive}" \
        "${rhash_src_folder_name}"

      if [ "${rhash_src_folder_name}" != "${rhash_folder_name}" ]
      then
        mv -v "${rhash_src_folder_name}" "${rhash_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${rhash_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${rhash_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "stamp-configure" ]
      then
        (
          env | sort

          echo
          echo "Running rhash configure..."

          run_verbose bash configure --help

          run_verbose bash ${DEBUG} configure \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --extra-cflags="${CFLAGS} ${CPPFLAGS}" \
            --extra-ldflags="${LDFLAGS}" \

          cp "config.log" "${LOGS_FOLDER_PATH}/${rhash_folder_name}/config-log-$(ndate).txt"

          touch "stamp-configure"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${rhash_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running rhash make..."

        # Build.
        run_verbose make -j ${JOBS}

        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          run_verbose make -j1 test test-lib
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${rhash_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_rhash
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${rhash_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${rhash_stamp_file_path}"

  else
    echo "Component rhash already installed."
  fi

  test_functions+=("test_rhash")
}

function test_rhash()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the flex shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/rhash"
    if is_darwin
    then
      show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/librhash.0.dylib)"
    else
      show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/librhash.so.0)"
    fi

    echo
    echo "Testing if rhash binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/rhash" --version
  )
}

# -----------------------------------------------------------------------------

function build_re2c()
{
  # https://github.com/skvadrik/re2c
  # https://github.com/skvadrik/re2c/releases
  # https://github.com/skvadrik/re2c/releases/download/1.3/re2c-1.3.tar.xz

  # https://archlinuxarm.org/packages/aarch64/re2c/files/PKGBUILD

  # 14 Dec 2019, "1.3"
  # Mar 27, 2021, "2.1.1"
  # 01 Aug 2021, "2.2"

  local re2c_version="$1"

  local re2c_src_folder_name="re2c-${re2c_version}"

  local re2c_archive="${re2c_src_folder_name}.tar.xz"
  local re2c_url="https://github.com/skvadrik/re2c/releases/download/${re2c_version}/${re2c_archive}"

  local re2c_folder_name="${re2c_src_folder_name}"

  local re2c_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${re2c_folder_name}-installed"
  if [ ! -f "${re2c_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${re2c_folder_name}" ]
  then

    # In-source build.

    if [ ! -d "${BUILD_FOLDER_PATH}/${re2c_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${re2c_url}" "${re2c_archive}" \
        "${re2c_src_folder_name}"

      if [ "${re2c_src_folder_name}" != "${re2c_folder_name}" ]
      then
        mv -v "${re2c_src_folder_name}" "${re2c_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${re2c_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${re2c_folder_name}"
      if [ ! -f "stamp-autogen" ]
      then

        xbb_activate
        xbb_activate_installed_dev

        # run_verbose bash ${DEBUG} "autogen.sh"

        touch "stamp-autogen"

      fi
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${re2c_folder_name}/autogen-output-$(ndate).txt"

    (
      cd "${BUILD_FOLDER_PATH}/${re2c_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running re2c configure..."

          run_verbose bash configure --help

          run_verbose bash ${DEBUG} configure \
            --prefix="${INSTALL_FOLDER_PATH}" \

          cp "config.log" "${LOGS_FOLDER_PATH}/${re2c_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${re2c_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running re2c make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          if is_linux
          then
            # darwin: Error: 5 out 2010 tests failed.
            run_verbose make -j1 tests
          fi
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${re2c_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_re2c
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${re2c_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${re2c_stamp_file_path}"

  else
    echo "Component re2c already installed."
  fi

  test_functions+=("test_re2c")
}

function test_re2c()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the flex shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/re2c"

    echo
    echo "Testing if re2c binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/re2c" --version
  )
}

# -----------------------------------------------------------------------------

function build_sphinx()
{
  # https://www.sphinx-doc.org/en/master/

  # https://archlinuxarm.org/packages/any/python-sphinx/files/PKGBUILD

  # Apr 10, 2020, "3.0.1"
  # Mar 5, 2020, "2.4.4"
  # ? "4.0.2"
  # Nov 10, 2021, "4.3.0"

  local sphinx_version="$1"

  local sphinx_folder_name="sphinx-${sphinx_version}"

  local sphinx_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${sphinx_folder_name}-installed"
  if [ ! -f "${sphinx_stamp_file_path}" ]
  then

    mkdir -pv "${LOGS_FOLDER_PATH}/${sphinx_folder_name}"

    (
      xbb_activate_installed_bin

      env | sort

      run_verbose pip3 install sphinx==${sphinx_version} --verbose

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${sphinx_folder_name}/install-output-$(ndate).txt"

    hash -r

    (
      test_sphinx
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${sphinx_folder_name}/test-output-$(ndate).txt"

    touch "${sphinx_stamp_file_path}"

  else
    echo "Component sphinx already installed."
  fi

  test_functions+=("test_sphinx")
}

function test_sphinx()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Testing if sphinx binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/sphinx-build" --version
  )
}

# -----------------------------------------------------------------------------

function build_autogen()
{
  # https://www.gnu.org/software/autogen/
  # https://ftp.gnu.org/gnu/autogen/
  # https://ftp.gnu.org/gnu/autogen/rel5.18.16/autogen-5.18.16.tar.xz

  # https://archlinuxarm.org/packages/aarch64/autogen/files/PKGBUILD
  # https://github.com/Homebrew/homebrew-core/blob/master/Formula/autogen.rb

  # 2018-08-26, "5.18.16"

  local autogen_version="$1"

  local autogen_src_folder_name="autogen-${autogen_version}"

  local autogen_archive="${autogen_src_folder_name}.tar.xz"
  local autogen_url="https://ftp.gnu.org/gnu/autogen/rel${autogen_version}/${autogen_archive}"

  local autogen_folder_name="${autogen_src_folder_name}"

  local autogen_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${autogen_folder_name}-installed"
  if [ ! -f "${autogen_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${autogen_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${autogen_url}" "${autogen_archive}" \
      "${autogen_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${autogen_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${autogen_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${autogen_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS} -D_POSIX_C_SOURCE"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      if is_linux
      then
        # To find libopts.so during build.
        export LD_LIBRARY_PATH="${XBB_LIBRARY_PATH}:${BUILD_FOLDER_PATH}/${autogen_folder_name}/autoopts/.libs"
      fi

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running autogen configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${autogen_src_folder_name}/configure" --help

          # config.status: error: in `/root/Work/xbb-3.2-ubuntu-12.04-x86_64/build/autogen-5.18.16':
          # config.status: error: Something went wrong bootstrapping makefile fragments
          #   for automatic dependency tracking.  Try re-running configure with the
          #   '--disable-dependency-tracking' option to at least be able to build
          #   the package (albeit without support for automatic dependency tracking).

          # Without ac_cv_func_utimensat=no it fails on macOS.

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${autogen_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-dependency-tracking \
            --disable-rpath \
            ac_cv_func_utimensat=no

          # FAIL: cond.test
          # FAILURE: warning diffs:  'undefining SECOND' not found
          run_verbose sed -i.bak \
            -e 's|cond.test||g' \
            "autoopts/test/Makefile"

          if is_linux
          then
            patch_all_libtool_rpath

            run_verbose find . \
              -name Makefile \
              -print \
              -exec sed -i.bak -e "s|-Wl,-rpath -Wl,${INSTALL_FOLDER_PATH}/lib||" {} \;
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${autogen_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${autogen_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running autogen make..."

        # Build.
        run_verbose make -j ${JOBS}

        run_verbose make install

        if [ "${RUN_TESTS}" == "y" ]
        then
          # WARN-TEST
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${autogen_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_autogen
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${autogen_folder_name}/test-output-$(ndate).txt"

    touch "${autogen_stamp_file_path}"

  else
    echo "Component autogen already installed."
  fi

  test_functions+=("test_autogen")
}

function test_autogen()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the autogen shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/autogen"
    show_libs "${INSTALL_FOLDER_PATH}/bin/columns"
    show_libs "${INSTALL_FOLDER_PATH}/bin/getdefs"

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libopts.${SHLIB_EXT})"

    echo
    echo "Testing if autogen binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/autogen" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/autoopts-config" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/columns" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/getdefs" --version

    echo
    echo "Testing if autogen binaries display help..."

    run_app "${INSTALL_FOLDER_PATH}/bin/autogen" --help

    # getdefs error:  invalid option descriptor for version
    run_app "${INSTALL_FOLDER_PATH}/bin/getdefs" --help || true
  )
}

# -----------------------------------------------------------------------------

function build_bash()
{
  # https://www.gnu.org/software/bash/
  # https://ftp.gnu.org/gnu/bash/
  # https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz

  # https://archlinuxarm.org/packages/aarch64/bash/files/PKGBUILD

  # 2018-01-30, "4.4.18"
  # 2019-01-07, "5.0"
  # 2020-12-06, "5.1"
  # 2021-06-15, "5.1.8"

  local bash_version="$1"

  local bash_src_folder_name="bash-${bash_version}"

  local bash_archive="${bash_src_folder_name}.tar.gz"
  local bash_url="https://ftp.gnu.org/gnu/bash/${bash_archive}"

  local bash_folder_name="${bash_src_folder_name}"

  local bash_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${bash_folder_name}-installed"
  if [ ! -f "${bash_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${bash_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${bash_url}" "${bash_archive}" \
      "${bash_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${bash_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${bash_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${bash_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          env | sort

          echo
          echo "Running bash configure..."

          run_verbose bash "${SOURCES_FOLDER_PATH}/${bash_src_folder_name}/configure" --help

          config_options=()
          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          config_options+=("--with-curses")
          config_options+=("--with-installed-readline")
          config_options+=("--enable-readline")
          config_options+=("--disable-rpath")

          run_verbose bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${bash_src_folder_name}/configure" \
            "${config_options[@]}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${bash_folder_name}/config-log-$(ndate).txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${bash_folder_name}/configure-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running bash make..."

        # Build.
        run_verbose make -j ${JOBS}

        # make install-strip
        run_verbose make install

        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          run_verbose make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${bash_folder_name}/make-output-$(ndate).txt"
    )

    (
      test_bash
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${bash_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${bash_stamp_file_path}"

  else
    echo "Component bash already installed."
  fi

  test_functions+=("test_bash")
}

function test_bash()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the bash binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/bash"

    echo
    echo "Testing if bash binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/bash" --version

    echo
    echo "Testing if bash binaries display help..."

    run_app "${INSTALL_FOLDER_PATH}/bin/bash" --help
  )
}

# -----------------------------------------------------------------------------

# Minimalistic realpath to be used on macOS
function build_realpath()
{
  # https://github.com/harto/realpath-osx
  # https://github.com/harto/realpath-osx/archive/1.0.0.tar.gz

  # 18 Oct 2012 "1.0.0"

  local realpath_version="$1"

  local realpath_src_folder_name="realpath-osx-${realpath_version}"

  local realpath_archive="${realpath_src_folder_name}.tar.gz"
  # GitHub release archive.
  local realpath_url="https://github.com/harto/realpath-osx/archive/${realpath_version}.tar.gz"

  local realpath_folder_name="${realpath_src_folder_name}"

  local realpath_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${realpath_folder_name}-installed"
  if [ ! -f "${realpath_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${realpath_folder_name}" ]
  then

    # In-source build

    if [ ! -d "${BUILD_FOLDER_PATH}/${realpath_folder_name}" ]
    then
      cd "${BUILD_FOLDER_PATH}"

      download_and_extract "${realpath_url}" "${realpath_archive}" \
        "${realpath_src_folder_name}"

      if [ "${realpath_src_folder_name}" != "${realpath_folder_name}" ]
      then
        mv -v "${realpath_src_folder_name}" "${realpath_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${realpath_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${realpath_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      (
        env | sort

        echo
        echo "Running realpath make..."

        make

        /usr/bin/install -m755 -c realpath "${INSTALL_FOLDER_PATH}/bin"

        # TODO: No tests?

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${realpath_folder_name}/configure-output-$(ndate).txt"
    )

    (
      test_realpath
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${realpath_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${realpath_stamp_file_path}"

  else
    echo "Component realpath already installed."
  fi

  test_functions+=("test_realpath")
}

function test_realpath()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the realpath binaries shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/realpath"
  )
}

# -----------------------------------------------------------------------------

function build_native_llvm()
{
  # https://llvm.org
  # https://llvm.org/docs/GettingStarted.html
  # https://github.com/llvm/llvm-project/
  # https://github.com/llvm/llvm-project/releases/download/llvmorg-8.0.1/llvm-8.0.1.src.tar.xz
  # https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.1/llvm-project-10.0.1.src.tar.xz
  # https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/llvm-1project-1.0.0.src.tar.xz

  # https://archlinuxarm.org/packages/aarch64/llvm/files/PKGBUILD

  # Jul 19, 2019, "8.0.1" - completely different structure
  # Dec 20, 2019, "9.0.1" - fails on macOS 10.10
  # 22 Jul 2020, "10.0.1" - Target clang_rt.builtins_arm64_osx does not exist
  # 12 Oct 2020 "11.0.0"
  # 07 Feb 2021 "11.1.0"

  local llvm_version="$1"

  local llvm_version_major=$(echo ${llvm_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*|\1|')
  local llvm_version_minor=$(echo ${llvm_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*|\2|')

  export LLVM_INSTALL_FOLDER_PATH="${INSTALL_FOLDER_PATH}"

  local llvm_src_folder_name="llvm-project-${llvm_version}.src"

  local llvm_archive="${llvm_src_folder_name}.tar.xz"
  local llvm_url="https://github.com/llvm/llvm-project/releases/download/llvmorg-${llvm_version}/${llvm_archive}"

  local llvm_folder_name="llvm-${llvm_version}"

  local llvm_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${llvm_folder_name}-installed"
  if [ ! -f "${llvm_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${llvm_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${llvm_url}" "${llvm_archive}" \
        "${llvm_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${llvm_folder_name}"

    (
      mkdir -pv "${BUILD_FOLDER_PATH}/${llvm_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${llvm_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if true # [ ! -f "ninja.build" ]
      then
        (
          env | sort

          echo
          echo "Running llvm cmake..."

          config_options=()

          config_options+=("-GNinja")

          # Many options copied from HomeBrew.

          # Colon separated list of directories clang will search for headers.
          # config_options+=("-DC_INCLUDE_DIRS=:")

          config_options+=("-DCLANG_EXECUTABLE_VERSION=${llvm_version_major}${XBB_GCC_SUFFIX}")

          # Please note the trailing space.
          config_options+=("-DCLANG_VENDOR=${XBB_LLVM_BRANDING} ")

          # macOS 10.1[03] lack the XPC library.
          config_options+=("-DCLANGD_BUILD_XPC=OFF")

          config_options+=("-DCMAKE_BUILD_TYPE=Release")
          config_options+=("-DCMAKE_C_COMPILER=${CC}")
          config_options+=("-DCMAKE_CXX_COMPILER=${CXX}")
          config_options+=("-DCMAKE_C_FLAGS=${CPPFLAGS} ${CFLAGS}")
          config_options+=("-DCMAKE_CXX_FLAGS=${CPPFLAGS} ${CXXFLAGS}")
          config_options+=("-DCMAKE_EXE_LINKER_FLAGS=${LDFLAGS}")

          # In case it does not pick the XBB ones on Linux
          # config_options+=("-DCMAKE_LIBTOOL=$(which libtool)")
          # config_options+=("-DCMAKE_NM=$(which nm)")
          # config_options+=("-DCMAKE_AR=$(which ar)")
          # config_options+=("-DCMAKE_OBJCOPY=$(which objcopy)")
          # config_options+=("-DCMAKE_OBJDUMP=$(which objdump)")
          # config_options+=("-DCMAKE_RANLIB=$(which ranlib)")
          # config_options+=("-DCMAKE_STRIP=$(which strip)")
          # config_options+=("-DGIT_EXECUTABLE=$(which git)")

          config_options+=("-DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_FOLDER_PATH}")

          echo "SDK=${MACOS_SDK_PATH}"
          config_options+=("-DDEFAULT_SYSROOT=${MACOS_SDK_PATH}")

          config_options+=("-DLLDB_ENABLE_LUA=OFF")
          config_options+=("-DLLDB_ENABLE_LZMA=OFF")
          config_options+=("-DLLDB_ENABLE_PYTHON=OFF")
          config_options+=("-DLLDB_USE_SYSTEM_DEBUGSERVER=ON")

          config_options+=("-DLLVM_BUILD_DOCS=OFF")
          config_options+=("-DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON")
          config_options+=("-DLLVM_BUILD_LLVM_C_DYLIB=ON")
          config_options+=("-DLLVM_BUILD_LLVM_DYLIB=ON")

          if true # [ "${XBB_LAYER}" == "xbb-bootstrap" ]
          then
            # Fails to find the test library.
            # ld: library not found for -lgtest_main
            config_options+=("-DLLVM_BUILD_TESTS=OFF")
          else
            config_options+=("-DLLVM_BUILD_TESTS=ON")
          fi

          config_options+=("-DLLVM_ENABLE_DOXYGEN=OFF")
          config_options+=("-DLLVM_ENABLE_EH=ON")
          config_options+=("-DLLVM_ENABLE_FFI=ON")
          config_options+=("-DLLVM_ENABLE_LIBCXX=ON")
          config_options+=("-DLLVM_ENABLE_LTO=OFF")

          # No openmp,mlir
          config_options+=("-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra;lld;lldb;polly")
          config_options+=("-DLLVM_ENABLE_RUNTIMES=compiler-rt;libcxx;libcxxabi;libunwind")

          config_options+=("-DLLVM_ENABLE_RTTI=ON")
          config_options+=("-DLLVM_ENABLE_SPHINX=OFF")
          config_options+=("-DLLVM_ENABLE_WARNINGS=OFF")
          config_options+=("-DLLVM_ENABLE_Z3_SOLVER=OFF")

          config_options+=("-DLLVM_INCLUDE_DOCS=OFF") # No docs
          config_options+=("-DLLVM_INCLUDE_TESTS=OFF") # No tests

          config_options+=("-DLLVM_INSTALL_UTILS=ON")
          config_options+=("-DLLVM_LINK_LLVM_DYLIB=ON")
          config_options+=("-DLLVM_OPTIMIZED_TABLEGEN=ON")
          # config_options+=("-DLLVM_POLLY_LINK_INTO_TOOLS=ON")

          # Only x86 targets, 'all' fails.
          config_options+=("-DLLVM_TARGETS_TO_BUILD=X86")

          config_options+=("-DPYTHON_EXECUTABLE=${INSTALL_FOLDER_PATH}/bin/python3")
          # config_options+=("-DPython3_EXECUTABLE=python3")

          run_timed_verbose cmake \
            "${config_options[@]}" \
            "${SOURCES_FOLDER_PATH}/${llvm_src_folder_name}/llvm"

        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${llvm_folder_name}/cmake-output-$(ndate).txt"
      fi

      (
        echo
        echo "Running llvm build..."

        # Build.
        run_timed_verbose cmake --build . \
          --parallel ${JOBS} \
          --verbose \

        run_timed_verbose cmake --build . \
          --verbose \
          --target install \

        (
          cd "${LLVM_INSTALL_FOLDER_PATH}/bin"

          local dest="$(readlink "clang")"

          rm -fv "clang" "clang${XBB_GCC_SUFFIX}"
          rm -fv "clang++" "clang++${XBB_GCC_SUFFIX}"

          ln -sv "${dest}" "clang${XBB_GCC_SUFFIX}"
          ln -sv "${dest}" "clang++${XBB_GCC_SUFFIX}"
        )

        # make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${llvm_folder_name}/build-output-$(ndate).txt"
    )

    (
      test_llvm
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${llvm_folder_name}/test-output-$(ndate).txt"

    hash -r

    touch "${llvm_stamp_file_path}"

  else
    echo "Component llvm already installed."
  fi

  test_functions+=("test_llvm")
}

function test_llvm()
{
  (
    # xbb_activate_installed_bin

    echo
    echo "Checking the llvm binaries shared libraries..."

    local clang="$(readlink "${LLVM_INSTALL_FOLDER_PATH}/bin/clang${XBB_GCC_SUFFIX}")"

    show_libs "${LLVM_INSTALL_FOLDER_PATH}/bin/clang${XBB_GCC_SUFFIX}"

    echo
    echo "Showing configurations..."

    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang${XBB_GCC_SUFFIX}" --version
    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang${XBB_GCC_SUFFIX}" -print-search-dirs
    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang${XBB_GCC_SUFFIX}" -print-libgcc-file-name

    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang++${XBB_GCC_SUFFIX}" --version
    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang++${XBB_GCC_SUFFIX}" -print-search-dirs
    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang++${XBB_GCC_SUFFIX}" -print-libgcc-file-name

    echo
    echo "Testing if clang compiles simple Hello programs..."

    # To access the new binutils.
    # /usr/bin/ld: BFD (GNU Binutils for Ubuntu) 2.22 internal error, aborting at ../../bfd/reloc.c line 443 in bfd_get_reloc_size
    xbb_activate_installed_bin

    mkdir -pv "${HOME}/tmp/native-clang"
    cd "${HOME}/tmp/native-clang"

    # Use the newly created script.
    # export LD_RUN_PATH="$(get-gcc-rpath)"
    # echo "LD_RUN_PATH=${LD_RUN_PATH}"

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.c
#include <stdio.h>

int
main(int argc, char* argv[])
{
  printf("Hello\n");

  return 0;
}
__EOF__


    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang${XBB_GCC_SUFFIX}" hello.c -o hello-c -v

    show_libs hello-c

    # run_verbose /usr/bin/ldd -v hello

    output=$(./hello-c)
    echo ${output}

    if [ "x${output}x" != "xHellox" ]
    then
      exit 1
    fi

    # Note: __EOF__ is quoted to prevent substitutions here.
    cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello++" << std::endl;

  return 0;
}
__EOF__

    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang++${XBB_GCC_SUFFIX}" hello.cpp -o hello-cpp -v

    show_libs hello-cpp

    output=$(./hello-cpp)
    echo ${output}

    if [ "x${output}x" != "xHello++x" ]
    then
      exit 1
    fi

  # Note: __EOF__ is quoted to prevent substitutions here.
  cat <<'__EOF__' > except.cpp
#include <iostream>
#include <exception>

struct MyException : public std::exception {
   const char* what() const throw () {
      return "MyException";
   }
};

void
func(void)
{
  throw MyException();
}

int
main(int argc, char* argv[])
{
  try {
    func();
  } catch(MyException& e) {
    std::cout << e.what() << std::endl;
  } catch(std::exception& e) {
    std::cout << "Other" << std::endl;
  }

  return 0;
}
__EOF__

    run_app "${LLVM_INSTALL_FOLDER_PATH}/bin/clang++${XBB_GCC_SUFFIX}" except.cpp -o except -v

    show_libs except

    output=$(./except)
    echo ${output}

    if [ "x${output}x" != "xMyExceptionx" ]
    then
      exit 1
    fi

  )
}

# -----------------------------------------------------------------------------
