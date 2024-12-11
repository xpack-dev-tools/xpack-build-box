# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------

function build_zlib()
{
  # http://zlib.net
  # http://zlib.net/fossils/
  # http://zlib.net/fossils/zlib-1.2.11.tar.gz

  # https://archlinuxarm.org/packages/aarch64/zlib/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-git

  # 2017-01-15 "1.2.11" (latest)

  local zlib_version="$1"

  local zlib_src_folder_name="zlib-${zlib_version}"

  local zlib_archive="${zlib_src_folder_name}.tar.gz"
  local zlib_url="http://zlib.net/fossils/${zlib_archive}"
  # local zlib_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${zlib_archive}"

  local zlib_folder_name="${zlib_src_folder_name}"

  local zlib_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${zlib_folder_name}-installed"
  if [ ! -f "${zlib_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${zlib_url}" "${zlib_archive}" \
      "${zlib_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${zlib_folder_name}"

    (
      if [ ! -d "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}" ]
      then
        mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}"
        # Copy the sources in the build folder.
        cp -r "${SOURCES_FOLDER_PATH}/${zlib_src_folder_name}"/* \
          "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}"
      fi
      cd "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      # -fPIC makes possible to include static libs in shared libs.
      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W} -fPIC"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB} -v"

      env | sort

      (
        echo
        echo "Running zlib configure..."

        bash "./configure" --help

        bash ${DEBUG} "./configure" \
          --prefix="${INSTALL_FOLDER_PATH}"

        cp "configure.log" "${LOGS_FOLDER_PATH}/${zlib_folder_name}/configure-log.txt"
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${zlib_folder_name}/configure-output.txt"

      (
        echo
        echo "Running zlib make..."

        # Build.
        make -j ${JOBS}

        make install

        make -j1 test

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${zlib_folder_name}/make-output.txt"
    )

    (
      test_zlib
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${zlib_folder_name}/test-output.txt"

    touch "${zlib_stamp_file_path}"

  else
    echo "Library zlib already installed."
  fi

  test_functions+=("test_zlib")
}

function test_zlib()
{
  (
    xbb_activate

    echo
    echo "Checking the zlib shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libz.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_gmp()
{
  # https://gmplib.org
  # https://gmplib.org/download/gmp/
  # https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz

  # https://archlinuxarm.org/packages/aarch64/gmp/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gmp-hg

  # 16-Dec-2016 "6.1.2"
  # 17-Jan-2020 "6.2.0"

  local gmp_version="$1"

  local gmp_src_folder_name="gmp-${gmp_version}"

  local gmp_archive="${gmp_src_folder_name}.tar.xz"
  local gmp_url="https://gmplib.org/download/gmp/${gmp_archive}"
  # local gmp_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${gmp_archive}"

  local gmp_folder_name="${gmp_src_folder_name}"

  local gmp_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${gmp_folder_name}-installed"
  if [ ! -f "${gmp_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${gmp_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gmp_url}" "${gmp_archive}" \
      "${gmp_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${gmp_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${gmp_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${gmp_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"

      # Static fails one cxx test (t-misc) on Intel 64
      # export LDFLAGS="${XBB_LDFLAGS_LIB}"
      export LDFLAGS="${XBB_LDFLAGS_LIB} -v"

      # Mandatory, it fails on 32-bits.
      # export ABI="${HOST_BITS}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gmp configure..."

          bash "${SOURCES_FOLDER_PATH}/${gmp_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gmp_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --build="${BUILD}" \
            \
            --enable-cxx \
            --enable-fat

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${gmp_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gmp_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running gmp make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gmp_folder_name}/make-output.txt"
    )

    (
      test_gmp
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gmp_folder_name}/test-output.txt"

    touch "${gmp_stamp_file_path}"

  else
    echo "Library gmp already installed."
  fi

  test_functions+=("test_gmp")
}

function test_gmp()
{
  (
    xbb_activate

    echo
    echo "Checking the gmp shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgmp.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgmpxx.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_mpfr()
{
  # http://www.mpfr.org
  # https://ftp.gnu.org/gnu/mpfr/
  # https://ftp.gnu.org/gnu/mpfr/mpfr-3.1.6.tar.xz
  # https://www.mpfr.org/mpfr-4.0.2/mpfr-4.0.2.tar.xz

  # https://archlinuxarm.org/packages/aarch64/mpfr/files/PKGBUILD
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/mpfr

  # 7 September 2017 "3.1.6"
  # 31 January 2019 "4.0.2" Fails mpc

  local mpfr_version="$1"

  local mpfr_src_folder_name="mpfr-${mpfr_version}"

  local mpfr_archive="${mpfr_src_folder_name}.tar.xz"
  local mpfr_url="https://ftp.gnu.org/gnu/mpfr/${mpfr_archive}"

  local mpfr_folder_name="${mpfr_src_folder_name}"

  local mpfr_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mpfr_folder_name}-installed"
  if [ ! -f "${mpfr_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${mpfr_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${mpfr_url}" "${mpfr_archive}" \
      "${mpfr_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${mpfr_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${mpfr_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${mpfr_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB} -v"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running mpfr configure..."

          bash "${SOURCES_FOLDER_PATH}/${mpfr_src_folder_name}/configure" --help

          config_options=()
          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          config_options+=("--enable-thread-safe")
          config_options+=("--enable-shared")

          if is_linux
          then
            config_options+=("--disable-new-dtags")
          fi

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mpfr_src_folder_name}/configure" \
            ${config_options[@]}

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${mpfr_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mpfr_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running mpfr make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

        if [[ "${mpfr_version}" =~ 4\.* ]]
        then
          # Not available in 3.x
          make -j1 check-exported-symbols
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mpfr_folder_name}/make-output.txt"
    )

    (
      test_mpfr
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mpfr_folder_name}/test-output.txt"

    touch "${mpfr_stamp_file_path}"

  else
    echo "Library mpfr already installed."
  fi

  test_functions+=("test_mpfr")
}

function test_mpfr()
{
  (
    xbb_activate

    echo
    echo "Checking the mpfr shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libmpfr.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_mpc()
{
  # http://www.multiprecision.org/
  # https://ftp.gnu.org/gnu/mpc
  # https://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz

  # https://archlinuxarm.org/packages/aarch64/mpc/files/PKGBUILD
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/libmpc

  # 2015-02-20 "1.0.3"
  # 2018-01-11 "1.1.0"

  local mpc_version="$1"

  local mpc_src_folder_name="mpc-${mpc_version}"

  local mpc_archive="${mpc_src_folder_name}.tar.gz"
  local mpc_url="ftp://ftp.gnu.org/gnu/mpc/${mpc_archive}"

  local mpc_folder_name="${mpc_src_folder_name}"

  local mpc_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${mpc_folder_name}-installed"
  if [ ! -f "${mpc_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${mpc_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${mpc_url}" "${mpc_archive}" \
      "${mpc_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${mpc_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${mpc_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${mpc_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running mpc configure..."

          bash "${SOURCES_FOLDER_PATH}/${mpc_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mpc_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${mpc_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mpc_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running mpc make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mpc_folder_name}/make-output.txt"
    )

    (
      test_mpc
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${mpc_folder_name}/test-output.txt"

    touch "${mpc_stamp_file_path}"

  else
    echo "Library mpc already installed."
  fi

  test_functions+=("test_mpc")
}

function test_mpc()
{
  (
    xbb_activate

    echo
    echo "Checking the mpc shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libmpc.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_isl()
{
  # http://isl.gforge.inria.fr
  # http://isl.gforge.inria.fr/isl-0.21.tar.xz

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=isl

  # 2016-12-20 "0.18"
  # 2019-03-26 "0.21"
  # 2020-01-16 "0.22"

  local isl_version="$1"

  local isl_src_folder_name="isl-${isl_version}"

  local isl_archive="${isl_src_folder_name}.tar.xz"
  local isl_url="http://isl.gforge.inria.fr/${isl_archive}"
  # local isl_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${isl_archive}"

  local isl_folder_name="${isl_src_folder_name}"

  local isl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${isl_folder_name}-installed"
  if [ ! -f "${isl_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${isl_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${isl_url}" "${isl_archive}" \
      "${isl_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${isl_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${isl_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${isl_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if is_linux
      then
        # The c++ test fails without it.
        export LD_LIBRARY_PATH="${XBB_LIBRARY_PATH}"
      fi

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running isl configure..."

          bash "${SOURCES_FOLDER_PATH}/${isl_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${isl_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-gmp-prefix="${INSTALL_FOLDER_PATH}" \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${isl_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${isl_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running isl make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${isl_folder_name}/make-output.txt"
    )

    (
      test_isl
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${isl_folder_name}/test-output.txt"

    touch "${isl_stamp_file_path}"

  else
    echo "Library isl already installed."
  fi

  test_functions+=("test_isl")
}

function test_isl()
{
  (
    xbb_activate

    echo
    echo "Checking the isl shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libisl.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_nettle()
{
  # https://www.lysator.liu.se/~nisse/nettle/
  # https://ftp.gnu.org/gnu/nettle/

  # https://archlinuxarm.org/packages/aarch64/nettle/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=nettle-git

  # 2017-11-19, "3.4"
  # 2018-12-04, "3.4.1"
  # 2019-06-27, "3.5.1"

  local nettle_version="$1"

  local nettle_src_folder_name="nettle-${nettle_version}"

  local nettle_archive="${nettle_src_folder_name}.tar.gz"
  local nettle_url="ftp://ftp.gnu.org/gnu/nettle/${nettle_archive}"

  local nettle_folder_name="${nettle_src_folder_name}"

  local nettle_patch_file_path="${helper_folder_path}/patches/${nettle_folder_name}.patch"
  local nettle_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${nettle_folder_name}-installed"
  if [ ! -f "${nettle_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${nettle_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${nettle_url}" "${nettle_archive}" \
      "${nettle_src_folder_name}" "${nettle_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${nettle_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${nettle_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${nettle_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running nettle configure..."

          bash "${SOURCES_FOLDER_PATH}/${nettle_src_folder_name}/configure" --help

          # -disable-static

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${nettle_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --enable-mini-gmp \
            --disable-documentation \
            --disable-arm-neon \
            --disable-assembler \

          cp "config.log" "${LOGS_FOLDER_PATH}/${nettle_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nettle_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running nettle make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        # For unknown reasons, on 32-bits make install-info fails
        # (`install-info --info-dir="/opt/xbb/share/info" nettle.info` returns 1)
        # Make the other install targets.
        make install-headers install-static install-pkgconfig install-shared-nettle install-shared-hogweed

        if is_darwin
        then
          # dlopen failed: dlopen(../libnettle.so, 2): image not found
          # /Users/ilg/Work/xbb-3.1-macosx-x86_64/sources/nettle-3.5.1/run-tests: line 57: 46731 Abort trap: 6           "$1" $testflags
          # darwin: FAIL: dlopen
          # WARN-TEST
          make -j1 -k check || true
        else
          # Takes very long on armhf.
          make -j1 -k check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nettle_folder_name}/make-output.txt"
    )

    (
      test_nettle
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${nettle_folder_name}/test-output.txt"

    touch "${nettle_stamp_file_path}"

  else
    echo "Library nettle already installed."
  fi

  test_functions+=("test_nettle")
}

function test_nettle()
{
  (
    xbb_activate

    echo
    echo "Checking the nettle shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libnettle.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_tasn1()
{
  # https://www.gnu.org/software/libtasn1/
  # http://ftp.gnu.org/gnu/libtasn1/
  # https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.12.tar.gz

  # https://archlinuxarm.org/packages/aarch64/libtasn1/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libtasn1-git

  # 2017-11-19, "4.12"
  # 2018-01-16, "4.13"
  # 2019-11-21, "4.15.0"

  local tasn1_version="$1"

  local tasn1_src_folder_name="libtasn1-${tasn1_version}"

  local tasn1_archive="${tasn1_src_folder_name}.tar.gz"
  local tasn1_url="ftp://ftp.gnu.org/gnu/libtasn1/${tasn1_archive}"

  local tasn1_folder_name="${tasn1_src_folder_name}"

  local tasn1_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${tasn1_folder_name}-installed"
  if [ ! -f "${tasn1_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${tasn1_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${tasn1_url}" "${tasn1_archive}" \
      "${tasn1_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${tasn1_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${tasn1_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${tasn1_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running tasn1 configure..."

          bash "${SOURCES_FOLDER_PATH}/${tasn1_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${tasn1_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${tasn1_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tasn1_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running tasn1 make..."

        # Build.
        CODE_COVERAGE_LDFLAGS=${LDFLAGS} make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tasn1_folder_name}/make-output.txt"
    )

    (
      test_tasn1
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${tasn1_folder_name}/test-output.txt"

    touch "${tasn1_stamp_file_path}"

  else
    echo "Library tasn1 already installed."
  fi

  test_functions+=("test_tasn1")
}


function test_tasn1()
{
  (
    xbb_activate

    echo
    echo "Checking the tasn1 shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libtasn1.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_expat()
{
  # https://libexpat.github.io
  # https://github.com/libexpat/libexpat/releases

  # https://archlinuxarm.org/packages/aarch64/expat/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=expat-git

  # Nov 1, 2017, "2.2.5"
  # Aug 15, 2018, "2.2.6"
  # 26 Sep 2019, "2.2.9"

  local expat_version="$1"

  local expat_src_folder_name="expat-${expat_version}"

  local expat_archive="${expat_src_folder_name}.tar.bz2"
  local expat_release="R_$(echo ${expat_version} | sed -e 's|[.]|_|g')"
  # local expat_url="ftp://ftp.gnu.org/gnu/expat/${expat_archive}"
  local expat_url="https://github.com/libexpat/libexpat/releases/download/${expat_release}/${expat_archive}"

  local expat_folder_name="${expat_src_folder_name}"

  local expat_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${expat_folder_name}-installed"
  if [ ! -f "${expat_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${expat_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${expat_url}" "${expat_archive}" \
      "${expat_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${expat_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${expat_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${expat_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running expat configure..."

          bash "${SOURCES_FOLDER_PATH}/${expat_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${expat_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${expat_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${expat_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running expat make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${expat_folder_name}/make-output.txt"
    )

    (
      test_expat
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${expat_folder_name}/test-output.txt"

    touch "${expat_stamp_file_path}"

  else
    echo "Library expat already installed."
  fi

  test_functions+=("test_expat")
}

function test_expat()
{
  (
    xbb_activate

    echo
    echo "Checking the expat shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libexpat.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libffi()
{
  # https://github.com/libffi/libffi
  # https://sourceware.org/libffi/ (deprecated?)

  # https://archlinuxarm.org/packages/aarch64/libffi/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libffi-git

  # https://github.com/libffi/libffi/archive/v3.2.1.tar.gz

  # 12-Nov-2014, "3.2.1", latest on sourceware.org
  # 23 Nov 2019, "3.3"

  local libffi_version="$1"

  local libffi_src_folder_name="libffi-${libffi_version}"

  # .gz only.
  local libffi_archive="${libffi_src_folder_name}.tar.gz"
  # local libffi_url="ftp://ftp.gnu.org/gnu/libffi/${libffi_archive}"
  # local libffi_url="https://sourceware.org/pub/libffi/${libffi_archive}"
  # GitHub release archive.
  local libffi_url="https://github.com/libffi/libffi/archive/v${libffi_version}.tar.gz"

  local libffi_folder_name="${libffi_src_folder_name}"

  local libffi_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libffi_folder_name}-installed"
  if [ ! -f "${libffi_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libffi_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libffi_url}" "${libffi_archive}" \
      "${libffi_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libffi_folder_name}"

    (
      if [ ! -x "${SOURCES_FOLDER_PATH}/${libffi_src_folder_name}/configure" ]
      then

        cd "${SOURCES_FOLDER_PATH}/${libffi_src_folder_name}"

        xbb_activate
        xbb_activate_installed_dev

        run_app bash ${DEBUG} "autogen.sh"

      fi
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libffi_folder_name}/autogen-output.txt"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libffi_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libffi_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libffi configure..."

          bash "${SOURCES_FOLDER_PATH}/${libffi_src_folder_name}/configure" --help

          #  --disable-static

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libffi_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --enable-pax_emutramp \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libffi_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libffi_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libffi make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libffi_folder_name}/make-output.txt"
    )

    (
      test_libffi
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libffi_folder_name}/test-output.txt"

    touch "${libffi_stamp_file_path}"

  else
    echo "Library libffi already installed."
  fi

  test_functions+=("test_libffi")
}

function test_libffi()
{
  (
    xbb_activate

    echo
    echo "Checking the libffi shared libraries..."

    local libffi="$(find ${INSTALL_FOLDER_PATH}/lib* -name libffi.${SHLIB_EXT})"
    show_libs "$(realpath ${libffi})"
  )
}

# -----------------------------------------------------------------------------

# Normally not used.
function build_libiconv()
{
  # https://www.gnu.org/software/libiconv/
  # https://ftp.gnu.org/pub/gnu/libiconv/

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libiconv

  # 2017-02-02, "1.15"
  # 2019-04-26, "1.16"

  # Warning, GCC 9.2 gets confused by it. If really needed, it must
  # be installed in a separate folder. See --prefix below.

  local libiconv_version="$1"

  local libiconv_src_folder_name="libiconv-${libiconv_version}"

  local libiconv_archive="${libiconv_src_folder_name}.tar.gz"
  local libiconv_url="ftp://ftp.gnu.org/gnu/libiconv/${libiconv_archive}"

  local libiconv_folder_name="${libiconv_src_folder_name}"

  local libiconv_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libiconv_folder_name}-installed"
  if [ ! -f "${libiconv_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libiconv_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libiconv_url}" "${libiconv_archive}" \
      "${libiconv_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libiconv_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libiconv_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libiconv_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libiconv configure..."

          bash "${SOURCES_FOLDER_PATH}/${libiconv_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libiconv_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}/libiconv"

          cp "config.log" "${LOGS_FOLDER_PATH}/${libiconv_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libiconv_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libiconv make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libiconv_folder_name}/make-output.txt"
    )

    (
      test_libiconv
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libiconv_folder_name}/test-output.txt"

    touch "${libiconv_stamp_file_path}"

  else
    echo "Library libiconv already installed."
  fi

  test_functions+=("test_libiconv")
}

function test_libiconv()
{
  (
    xbb_activate

    echo
    echo "Checking the libiconv shared libraries..."

    # TODO: add
  )
}

# -----------------------------------------------------------------------------

function build_gnutls()
{
  # http://www.gnutls.org/
  # https://www.gnupg.org/ftp/gcrypt/gnutls/
  # https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.7.tar.xz

  # https://archlinuxarm.org/packages/aarch64/gnutls/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gnutls-git

  # 2017-10-21, "3.6.1"
  # 2019-03-27, "3.6.7"
  # 2019-12-02, "3.6.11.1"

  local gnutls_version="$1"
  # The first two digits.
  local gnutls_version_major_minor="$(echo ${gnutls_version} | sed -e 's|\([0-9][0-9]*\.[0-9][0-9]*\)\.[0-9].*|\1|')"

  local gnutls_src_folder_name="gnutls-${gnutls_version}"

  local gnutls_archive="${gnutls_src_folder_name}.tar.xz"
  local gnutls_url="https://www.gnupg.org/ftp/gcrypt/gnutls/v${gnutls_version_major_minor}/${gnutls_archive}"

  local gnutls_folder_name="${gnutls_src_folder_name}"

  local gnutls_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${gnutls_folder_name}-installed"
  if [ ! -f "${gnutls_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${gnutls_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gnutls_url}" "${gnutls_archive}" \
      "${gnutls_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${gnutls_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${gnutls_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${gnutls_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB} -v"

      if is_darwin
      then
        # lib/system/certs.c:49 error: variably modified 'bytes' at file scope
        export CC=clang
        export CXX=clang++
      fi

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gnutls configure..."

          bash "${SOURCES_FOLDER_PATH}/${gnutls_src_folder_name}/configure" --help

          # --disable-static

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gnutls_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-guile-site-dir=no \
            --with-included-unistring \
            --without-p11-kit \
            \
            --disable-doc \
            --disable-full-test-suite \
            --disable-guile \
            --disable-rpath \

          patch_all_libtool_rpath

          #    -e 's|-rpath $(guileextensiondir)||' \
          #    -e 's|-rpath $(pkglibdir)||' \
          #    -e 's|-rpath $(libdir)||' \

          run_app find . \
            -name Makefile \
            -print \
            -exec sed -i.bak \
              -e "s|-Wl,-rpath -Wl,${INSTALL_FOLDER_PATH}/lib||" \
              {} \;

          if is_darwin && [ "${XBB_LAYER}" == "xbb-bootstrap" ]
          then
            run_app sed -i.bak \
              -e 's| test-ciphers.sh | |' \
              -e 's| override-ciphers | |' \
              tests/slow/Makefile
          fi

          if [ "${XBB_LAYER}" == "xbb" -o "${XBB_LAYER}" == "xbb-test" ]
          then
            if is_arm && [ "${HOST_BITS}" == "32" ]
            then
              # On Arm
              # server:242: server: Handshake has failed (The operation timed out)
              # FAIL: srp
              # WARN-TEST
              run_app sed -i.bak \
                -e 's|srp$(EXEEXT) ||' \
                tests/Makefile
            fi
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${gnutls_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gnutls_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running gnutls make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        # It takes very, very long. use --disable-full-test-suite
        # i386: FAIL: srp
        if [ "${RUN_LONG_TESTS}" == "y" ]
        then
          make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gnutls_folder_name}/make-output.txt"
    )

    (
      test_gnutls
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gnutls_folder_name}/test-output.txt"

    touch "${gnutls_stamp_file_path}"

  else
    echo "Library gnutls already installed."
  fi

  test_functions+=("test_gnutls")
}

function test_gnutls()
{
  (
    xbb_activate

    echo
    echo "Testing if gnutls binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/psktool" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/certtool" --version

    echo
    echo "Checking the gnutls shared libraries..."

    show_libs "${INSTALL_FOLDER_PATH}/bin/psktool"
    show_libs "${INSTALL_FOLDER_PATH}/bin/gnutls-cli-debug"
    show_libs "${INSTALL_FOLDER_PATH}/bin/certtool"
    show_libs "${INSTALL_FOLDER_PATH}/bin/srptool"
    show_libs "${INSTALL_FOLDER_PATH}/bin/ocsptool"
    show_libs "${INSTALL_FOLDER_PATH}/bin/gnutls-serv"
    show_libs "${INSTALL_FOLDER_PATH}/bin/gnutls-cli"
  )
}

# -----------------------------------------------------------------------------

function build_util_macros()
{
  # http://www.linuxfromscratch.org/blfs/view/
  # http://www.linuxfromscratch.org/blfs/view/7.4/x/util-macros.html

  # http://xorg.freedesktop.org/releases/individual/util
  # http://xorg.freedesktop.org/releases/individual/util/util-macros-1.17.1.tar.bz2

  # https://archlinuxarm.org/packages/any/xorg-util-macros/files/PKGBUILD

  # 2013-09-07, "1.17.1"
  # 2018-03-05, "1.19.2"

  local util_macros_version="$1"

  local util_macros_src_folder_name="util-macros-${util_macros_version}"

  local util_macros_archive="${util_macros_src_folder_name}.tar.bz2"
  local util_macros_url="http://xorg.freedesktop.org/releases/individual/util/${util_macros_archive}"

  local util_macros_folder_name="${util_macros_src_folder_name}"

  local util_macros_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${util_macros_folder_name}-installed"
  if [ ! -f "${util_macros_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${util_macros_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${util_macros_url}" "${util_macros_archive}" \
      "${util_macros_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${util_macros_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${util_macros_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${util_macros_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running util_macros configure..."

          bash "${SOURCES_FOLDER_PATH}/${util_macros_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${util_macros_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${util_macros_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${util_macros_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running util_macros make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${util_macros_folder_name}/make-output.txt"
    )

    (
      test_util_macros
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${util_macros_folder_name}/test-output.txt"

    touch "${util_macros_stamp_file_path}"

  else
    echo "Library util_macros already installed."
  fi

  test_functions+=("test_util_macros")
}

function test_util_macros()
{
  (
    xbb_activate

    echo
    echo "Nothing to test..."
  )
}

# -----------------------------------------------------------------------------

function build_xorg_xproto()
{
  # https://www.x.org/releases/individual/proto/
  # https://www.x.org/releases/individual/proto/xproto-7.0.31.tar.bz2

  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=xorgproto-git

  # 2016-09-23, "7.0.31" (latest)

  local xorg_xproto_version="$1"

  local xorg_xproto_src_folder_name="xproto-${xorg_xproto_version}"

  local xorg_xproto_archive="${xorg_xproto_src_folder_name}.tar.bz2"
  local xorg_xproto_url="https://www.x.org/releases/individual/proto/${xorg_xproto_archive}"

  local xorg_xproto_folder_name="${xorg_xproto_src_folder_name}"

  # Add aarch64 to the list of Arm architectures.
  local xorg_xproto_patch_file_path="${helper_folder_path}/patches/${xorg_xproto_folder_name}.patch"
  local xorg_xproto_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${xorg_xproto_folder_name}-installed"
  if [ ! -f "${xorg_xproto_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${xorg_xproto_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${xorg_xproto_url}" "${xorg_xproto_archive}" \
      "${xorg_xproto_src_folder_name}" "${xorg_xproto_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${xorg_xproto_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${xorg_xproto_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${xorg_xproto_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running xorg_xproto configure..."

          bash "${SOURCES_FOLDER_PATH}/${xorg_xproto_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${xorg_xproto_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --build="${BUILD}" \
            \
            --without-xmlto \
            --without-xsltproc \
            --without-fop \

          cp "config.log" "${LOGS_FOLDER_PATH}/${xorg_xproto_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${xorg_xproto_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running xorg_xproto make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${xorg_xproto_folder_name}/make-output.txt"
    )

    (
      test_xorg_xproto
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${xorg_xproto_folder_name}/test-output.txt"

    touch "${xorg_xproto_stamp_file_path}"

  else
    echo "Library xorg_xproto already installed."
  fi

  test_functions+=("test_xorg_xproto")
}

function test_xorg_xproto()
{
  (
    xbb_activate

    echo "Nothing to test..."
  )
}

# -----------------------------------------------------------------------------

function build_libpng()
{
  # To ensure builds stability, use slightly older releases.
  # https://sourceforge.net/projects/libpng/files/libpng16/
  # https://sourceforge.net/projects/libpng/files/libpng16/older-releases/

  # https://archlinuxarm.org/packages/aarch64/libpng/files/PKGBUILD
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libpng-git
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=mingw-w64-libpng

  # 2017-09-16
  # 2018-12-01, "1.6.36"
  # 2019-04-14, "1.6.3"

  local libpng_version="$1"

  local libpng_src_folder_name="libpng-${libpng_version}"

  local libpng_archive="${libpng_src_folder_name}.tar.gz"
  local libpng_url="https://sourceforge.net/projects/libpng/files/libpng16/${libpng_version}/${libpng_archive}"

  local libpng_folder_name="${libpng_src_folder_name}"

  local libpng_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libpng_folder_name}-installed"
  if [ ! -f "${libpng_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libpng_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libpng_url}" "${libpng_archive}" \
      "${libpng_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libpng_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libpng_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libpng_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libpng configure..."

          bash "${SOURCES_FOLDER_PATH}/${libpng_src_folder_name}/configure" --help

          # --disable-static

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libpng_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --enable-arm-neon=no \
            --disable-rpath \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libpng_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libpng_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libpng make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        (
          if is_linux
          then
            export LD_LIBRARY_PATH="${LD_RUN_PATH}"
          fi
          # Takes very long on armhf.
          make -j1 check
        )

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libpng_folder_name}/make-output.txt"
    )

    (
      test_libpng
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libpng_folder_name}/test-output.txt"

    touch "${libpng_stamp_file_path}"

  else
    echo "Library libpng already installed."
  fi

  test_functions+=("test_libpng")
}

function test_libpng()
{
  (
    xbb_activate

    # echo
    # echo "Testing if libpng binaries start properly..."

    # Has no --version and returns error.
    # run_app "${INSTALL_FOLDER_PATH}/bin/pngfix"

    echo
    echo "Checking the libpng shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libpng16.${SHLIB_EXT})"
    show_libs "${INSTALL_FOLDER_PATH}/bin/pngfix"
  )
}

# -----------------------------------------------------------------------------

function build_libmpdec()
{
  # http://www.bytereef.org/mpdecimal/index.html
  # https://www.bytereef.org/mpdecimal/download.html
  # https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-2.4.2.tar.gz

  # https://archlinuxarm.org/packages/aarch64/mpdecimal/files/PKGBUILD

  # 2016-02-28, "2.4.2"

  local libmpdec_version="$1"

  local libmpdec_src_folder_name="mpdecimal-${libmpdec_version}"

  local libmpdec_archive="${libmpdec_src_folder_name}.tar.gz"
  local libmpdec_url="https://www.bytereef.org/software/mpdecimal/releases/${libmpdec_archive}"

  local libmpdec_folder_name="${libmpdec_src_folder_name}"

  local libmpdec_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libmpdec_folder_name}-installed"
  if [ ! -f "${libmpdec_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libmpdec_folder_name}" ]
  then

    # In-source build

    if [ ! -d "${LIBS_BUILD_FOLDER_PATH}/${libmpdec_folder_name}" ]
    then
      cd "${LIBS_BUILD_FOLDER_PATH}"

      download_and_extract "${libmpdec_url}" "${libmpdec_archive}" \
        "${libmpdec_src_folder_name}"

      if [ "${libmpdec_src_folder_name}" != "${libmpdec_folder_name}" ]
      then
        mv -v "${libmpdec_src_folder_name}" "${libmpdec_folder_name}"
      fi
    fi

    mkdir -pv "${LOGS_FOLDER_PATH}/${libmpdec_folder_name}"

    (
      cd "${LIBS_BUILD_FOLDER_PATH}/${libmpdec_src_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB} -v"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libmpdec configure..."

          bash "configure" --help

          bash ${DEBUG} "configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libmpdec_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libmpdec_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libmpdec make..."

        # Build.
        make -j ${JOBS}

        make install

        if is_linux
        then
          # TODO
          # Fails shared on darwin
          make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libmpdec_folder_name}/make-output.txt"
    )

    (
      test_libmpdec
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libmpdec_folder_name}/test-output.txt"

    touch "${libmpdec_stamp_file_path}"

  else
    echo "Library libmpdec already installed."
  fi

  test_functions+=("test_libmpdec")
}

function test_libmpdec()
{
  (
    xbb_activate

    echo
    echo "Checking the libmpdec shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libmpdec.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libgpg_error()
{
  # https://gnupg.org/ftp/gcrypt/libgpg-error

  # https://archlinuxarm.org/packages/aarch64/libgpg-error/files/PKGBUILD

  # 2020-02-07, "1.37"

  local libgpg_error_version="$1"

  local libgpg_error_src_folder_name="libgpg-error-${libgpg_error_version}"

  local libgpg_error_archive="${libgpg_error_src_folder_name}.tar.bz2"
  local libgpg_error_url="https://gnupg.org/ftp/gcrypt/libgpg-error/${libgpg_error_archive}"

  local libgpg_error_folder_name="${libgpg_error_src_folder_name}"

  local libgpg_error_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libgpg_error_folder_name}-installed"
  if [ ! -f "${libgpg_error_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libgpg_error_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libgpg_error_url}" "${libgpg_error_archive}" \
      "${libgpg_error_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libgpg_error_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libgpg_error_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libgpg_error_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libgpg-error configure..."

          bash "${SOURCES_FOLDER_PATH}/${libgpg_error_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libgpg_error_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          patch_all_libtool_rpath

          # WARN-TEST
          # FAIL: t-syserror (disabled)
          # Interestingly enough, initially (before dismissing install-strip)
          # it passed.
          run_app sed -i.bak -e 's|t-syserror$(EXEEXT)||' "tests/Makefile"

          cp "config.log" "${LOGS_FOLDER_PATH}/${libgpg_error_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libgpg_error_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libgpg-error make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        # WARN-TEST
        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libgpg_error_folder_name}/make-output.txt"
    )

    (
      test_libgpg_error
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libgpg_error_folder_name}/test-output.txt"

    touch "${libgpg_error_stamp_file_path}"

  else
    echo "Library libgpg-error already installed."
  fi

  test_functions+=("test_libgpg_error")
}

function test_libgpg_error()
{
  (
    xbb_activate

    echo
    echo "Checking the libpng_error shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgpg-error.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libgcrypt()
{
  # https://gnupg.org/ftp/gcrypt/libgcrypt
  # https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.8.5.tar.bz2

  # https://archlinuxarm.org/packages/aarch64/libgcrypt/files/PKGBUILD

  # 2019-08-29, "1.8.5"

  local libgcrypt_version="$1"

  local libgcrypt_src_folder_name="libgcrypt-${libgcrypt_version}"

  local libgcrypt_archive="${libgcrypt_src_folder_name}.tar.bz2"
  local libgcrypt_url="https://gnupg.org/ftp/gcrypt/libgcrypt/${libgcrypt_archive}"

  local libgcrypt_folder_name="${libgcrypt_src_folder_name}"

  local libgcrypt_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libgcrypt_folder_name}-installed"
  if [ ! -f "${libgcrypt_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libgcrypt_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libgcrypt_url}" "${libgcrypt_archive}" \
      "${libgcrypt_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libgcrypt_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libgcrypt_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libgcrypt_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB} -v"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libgcrypt configure..."

          bash "${SOURCES_FOLDER_PATH}/${libgcrypt_src_folder_name}/configure" --help

          config_options=()
          if [ "${HOST_MACHINE}" != "aarch64" ]
          then
            config_options+=("--disable-neon-support")
            config_options+=("--disable-arm-crypto-support")
          fi

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")
          config_options+=("--with-libgpg-error-prefix=${INSTALL_FOLDER_PATH}")

          config_options+=("--disable-doc")
          config_options+=("--disable-large-data-tests")

          # For Darwin, there are problems with the assembly code.
          config_options+=("--disable-asm")
          config_options+=("--disable-amd64-as-feature-detection")

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libgcrypt_src_folder_name}/configure" \
            ${config_options[@]}

          patch_all_libtool_rpath

          if [ "${HOST_MACHINE}" != "aarch64" ]
          then
            # fix screwed up capability detection
            sed -i.bak -e '/HAVE_GCC_INLINE_ASM_AARCH32_CRYPTO 1/d' "config.h"
            sed -i.bak -e '/HAVE_GCC_INLINE_ASM_NEON 1/d' "config.h"
          fi

          cp "config.log" "${LOGS_FOLDER_PATH}/${libgcrypt_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libgcrypt_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libgcrypt make..."

        # Build.
        make -j ${JOBS}

        # Check after install, otherwise mac test fails:
        # dyld: Library not loaded: /Users/ilg/opt/xbb/lib/libgcrypt.20.dylib
        # Referenced from: /Users/ilg/Work/xbb-3.1-macosx-10.15.3-x86_64/build/libs/libgcrypt-1.8.5/tests/.libs/random

        make -j1 check

        # make install-strip
        make install

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libgcrypt_folder_name}/make-output.txt"
    )

    (
      test_libgcrypt
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libgcrypt_folder_name}/test-output.txt"

    touch "${libgcrypt_stamp_file_path}"

  else
    echo "Library libgcrypt already installed."
  fi

  test_functions+=("test_libgcrypt")
}

function test_libgcrypt()
{
  (
    xbb_activate

    echo
    echo "Testing if libgcrypt binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/libgcrypt-config" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/dumpsexp" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/hmac256" --version
    run_app "${INSTALL_FOLDER_PATH}/bin/mpicalc" --version

    echo
    echo "Checking the libgcrypt shared libraries..."

    # show_libs "${INSTALL_FOLDER_PATH}/bin/libgcrypt-config"
    show_libs "${INSTALL_FOLDER_PATH}/bin/dumpsexp"
    show_libs "${INSTALL_FOLDER_PATH}/bin/hmac256"
    show_libs "${INSTALL_FOLDER_PATH}/bin/mpicalc"

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgcrypt.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libassuan()
{
  # https://gnupg.org/ftp/gcrypt/libassuan
  # https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.3.tar.bz2

  # https://archlinuxarm.org/packages/aarch64/libassuan/files/PKGBUILD

  # 2019-02-11, "2.5.3"

  local libassuan_version="$1"

  local libassuan_src_folder_name="libassuan-${libassuan_version}"

  local libassuan_archive="${libassuan_src_folder_name}.tar.bz2"
  local libassuan_url="https://gnupg.org/ftp/gcrypt/libassuan/${libassuan_archive}"

  local libassuan_folder_name="${libassuan_src_folder_name}"

  local libassuan_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libassuan_folder_name}-installed"
  if [ ! -f "${libassuan_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libassuan_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libassuan_url}" "${libassuan_archive}" \
      "${libassuan_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libassuan_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libassuan_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libassuan_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libassuan configure..."

          bash "${SOURCES_FOLDER_PATH}/${libassuan_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libassuan_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-libgpg-error-prefix="${INSTALL_FOLDER_PATH}" \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libassuan_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libassuan_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libassuan make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libassuan_folder_name}/make-output.txt"
    )

    (
      test_libassuan
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libassuan_folder_name}/test-output.txt"

    touch "${libassuan_stamp_file_path}"

  else
    echo "Library libassuan already installed."
  fi

  test_functions+=("test_libassuan")
}

function test_libassuan()
{
  (
    xbb_activate

    echo
    echo "Testing if libassuan binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/libassuan-config" --version

    echo
    echo "Checking the libassuan shared libraries..."

    # show_libs "${INSTALL_FOLDER_PATH}/bin/libassuan-config"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libassuan.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libksba()
{
  # https://gnupg.org/ftp/gcrypt/libksba
  # https://gnupg.org/ftp/gcrypt/libksba/libksba-1.3.5.tar.bz2

  # https://archlinuxarm.org/packages/aarch64/libksba/files/PKGBUILD

  # 2016-08-22, "1.3.5"

  local libksba_version="$1"

  local libksba_src_folder_name="libksba-${libksba_version}"

  local libksba_archive="${libksba_src_folder_name}.tar.bz2"
  local libksba_url="https://gnupg.org/ftp/gcrypt/libksba/${libksba_archive}"

  local libksba_folder_name="${libksba_src_folder_name}"

  local libksba_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libksba_folder_name}-installed"
  if [ ! -f "${libksba_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libksba_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libksba_url}" "${libksba_archive}" \
      "${libksba_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libksba_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libksba_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libksba_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libksba configure..."

          bash "${SOURCES_FOLDER_PATH}/${libksba_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libksba_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --with-libgpg-error-prefix="${INSTALL_FOLDER_PATH}" \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libksba_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libksba_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libksba make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libksba_folder_name}/make-output.txt"
    )

    (
      test_libksba
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libksba_folder_name}/test-output.txt"

    touch "${libksba_stamp_file_path}"

  else
    echo "Library libksba already installed."
  fi

  test_functions+=("test_libksba")
}

function test_libksba()
{
  (
    xbb_activate

    echo
    echo "Testing if libksba binaries start properly..."

    run_app "${INSTALL_FOLDER_PATH}/bin/ksba-config" --version

    echo
    echo "Checking the libksba shared libraries..."

    # show_libs "${INSTALL_FOLDER_PATH}/bin/ksba-config"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libksba.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_npth()
{
  # https://gnupg.org/ftp/gcrypt/npth
  # https://gnupg.org/ftp/gcrypt/npth/npth-1.6.tar.bz2

  # https://archlinuxarm.org/packages/aarch64/npth/files/PKGBUILD

  # 2018-07-16, "1.6"

  local npth_version="$1"

  local npth_src_folder_name="npth-${npth_version}"

  local npth_archive="${npth_src_folder_name}.tar.bz2"
  local npth_url="https://gnupg.org/ftp/gcrypt/npth/${npth_archive}"

  local npth_folder_name="${npth_src_folder_name}"

  local npth_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${npth_folder_name}-installed"
  if [ ! -f "${npth_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${npth_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${npth_url}" "${npth_archive}" \
      "${npth_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${npth_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${npth_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${npth_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if is_darwin
      then
        # /usr/include/os/base.h:113:20: error: missing binary operator before token "("
        # #if __has_extension(attribute_overloadable)

        export CC=clang
        export CXX=clang++
      fi

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running npth configure..."

          bash "${SOURCES_FOLDER_PATH}/${npth_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${npth_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/${npth_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${npth_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running npth make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${npth_folder_name}/make-output.txt"
    )

    (
      test_npth
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${npth_folder_name}/test-output.txt"

    touch "${npth_stamp_file_path}"

  else
    echo "Library npth already installed."
  fi

  test_functions+=("test_npth")
}

function test_npth()
{
  (
    xbb_activate

    echo
    echo "Checking the npth shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libnpth.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libxcrypt()
{
  # Replacement for the old libcrypt.so.1.

  # https://github.com/besser82/libxcrypt
  # https://github.com/besser82/libxcrypt/archive/v4.4.15.tar.gz

  # 26 Jul 2018, "4.1.1"
  # 26 Oct 2018, "4.2.3"
  # 14 Nov 2018, "4.3.4"
  # Requires new autotools.
  # m4/ax_valgrind_check.m4:80: warning: macro `AM_EXTRA_RECURSIVE_TARGETS' not found in library
  # Feb 25 2020, "4.4.15"

  local libxcrypt_version="$1"

  local libxcrypt_src_folder_name="libxcrypt-${libxcrypt_version}"

  local libxcrypt_archive="${libxcrypt_src_folder_name}.tar.gz"
  # GitHub release archive.
  local libxcrypt_url="https://github.com/besser82/libxcrypt/archive/v${libxcrypt_version}.tar.gz"

  local libxcrypt_folder_name="${libxcrypt_src_folder_name}"

  local libxcrypt_patch_file_path="${helper_folder_path}/patches/${libxcrypt_folder_name}.patch"
  local libxcrypt_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libxcrypt_folder_name}-installed"
  if [ ! -f "${libxcrypt_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libxcrypt_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libxcrypt_url}" "${libxcrypt_archive}" \
      "${libxcrypt_src_folder_name}" "${libxcrypt_patch_file_path}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libxcrypt_folder_name}"

    if [ ! -x "${SOURCES_FOLDER_PATH}/${libxcrypt_src_folder_name}/configure" ]
    then
      (
        cd "${SOURCES_FOLDER_PATH}/${libxcrypt_src_folder_name}"

        xbb_activate
        if [ "${XBB_LAYER}" == "xbb-bootstrap" ]
        then
          # Requires the new autotools.
          xbb_activate_installed_bin
        fi
        xbb_activate_installed_dev

        if [ -f "autogen.sh" ]
        then
          bash ${DEBUG} autogen.sh
        elif [ -f "bootstrap" ]
        then
          bash ${DEBUG} bootstrap
        else
          #
          autoreconf -fiv
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libxcrypt_folder_name}/autogen-output.txt"

    fi

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libxcrypt_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libxcrypt_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libxcrypt configure..."

          bash "${SOURCES_FOLDER_PATH}/${libxcrypt_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libxcrypt_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libxcrypt_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libxcrypt_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libxcrypt make..."

        # Build.
        make -j ${JOBS}

        # install is not able to rewrite them.
        rm -rfv "${INSTALL_FOLDER_PATH}"/lib*/libxcrypt.*
        rm -rfv "${INSTALL_FOLDER_PATH}"/lib*/libowcrypt.*
        rm -rfv "${INSTALL_FOLDER_PATH}"/lib/pkgconfig/libcrypt.pc

        # make install-strip
        make install

        if is_darwin
        then
          # macOS FAIL: test/symbols-static.sh
          # macOS FAIL: test/symbols-renames.sh
          make -j1 check || true
        else
          make -j1 check
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libxcrypt_folder_name}/make-output.txt"
    )

    (
      test_libxcrypt
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libxcrypt_folder_name}/test-output.txt"

    touch "${libxcrypt_stamp_file_path}"

  else
    echo "Library libxcrypt already installed."
  fi

  test_functions+=("test_libxcrypt")
}

function test_libxcrypt()
{
  (
    xbb_activate

    echo
    echo "Checking the libxcrypt shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libcrypt.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_libunistring()
{
  # https://www.gnu.org/software/libunistring/
  # https://ftp.gnu.org/gnu/libunistring/
  # https://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.xz

  # https://archlinuxarm.org/packages/aarch64/libunistring/files/PKGBUILD

  # 2018-05-25 "0.9.10"

  local libunistring_version="$1"

  local libunistring_src_folder_name="libunistring-${libunistring_version}"

  local libunistring_archive="${libunistring_src_folder_name}.tar.xz"
  local libunistring_url="https://ftp.gnu.org/gnu/libunistring/${libunistring_archive}"

  local libunistring_folder_name="${libunistring_src_folder_name}"

  local libunistring_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${libunistring_folder_name}-installed"
  if [ ! -f "${libunistring_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libunistring_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libunistring_url}" "${libunistring_archive}" \
      "${libunistring_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${libunistring_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${libunistring_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libunistring_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libunistring configure..."

          bash "${SOURCES_FOLDER_PATH}/${libunistring_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libunistring_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --disable-rpath \

          patch_all_libtool_rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/${libunistring_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libunistring_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running libunistring make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libunistring_folder_name}/make-output.txt"
    )

    (
      test_libunistring
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${libunistring_folder_name}/test-output.txt"

    touch "${libunistring_stamp_file_path}"

  else
    echo "Library libunistring already installed."
  fi

  test_functions+=("test_libunistring")
}

function test_libunistring()
{
  (
    xbb_activate

    echo
    echo "Checking the libunistring shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libunistring.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_gc()
{
  # https://www.hboehm.info/gc
  # https://github.com/ivmai/bdwgc/releases/
  # https://github.com/ivmai/bdwgc/releases/download/v8.0.4/gc-8.0.4.tar.gz

  # https://archlinuxarm.org/packages/aarch64/gc/files/PKGBUILD

  # 2 Mar 2019 "8.0.4"

  local gc_version="$1"

  local gc_src_folder_name="gc-${gc_version}"

  local gc_archive="${gc_src_folder_name}.tar.gz"
  local gc_url="https://github.com/ivmai/bdwgc/releases/download/v${gc_version}/${gc_archive}"

  local gc_folder_name="${gc_src_folder_name}"

  local gc_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${gc_folder_name}-installed"
  if [ ! -f "${gc_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${gc_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gc_url}" "${gc_archive}" \
      "${gc_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${gc_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${gc_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${gc_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS_NO_W}"
      export CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      env | sort

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gc configure..."

          bash "${SOURCES_FOLDER_PATH}/${gc_src_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gc_src_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --enable-cplusplus \
            --disable-docs \

          # Skip the tests folder from patching, since the tests use
          # internal shared libraries.
          run_app find . \
            -name "libtool" \
            ! -path 'tests' \
            -print \
            -exec bash patch_file_libtool_rpath {} \;

          cp "config.log" "${LOGS_FOLDER_PATH}/${gc_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gc_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running gc make..."

        # TODO: check if required
        # make clean

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gc_folder_name}/make-output.txt"
    )

    (
      test_gc
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${gc_folder_name}/test-output.txt"

    touch "${gc_stamp_file_path}"

  else
    echo "Library gc already installed."
  fi

  test_functions+=("test_gc")
}

function test_gc()
{
  (
    xbb_activate

    echo
    echo "Checking the gc shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgc.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libgccpp.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libcord.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_ncurses()
{
  # https://invisible-island.net/ncurses/
  # ftp://ftp.invisible-island.net/pub/ncurses
  # ftp://ftp.invisible-island.net/pub/ncurses/ncurses-6.2.tar.gz

  # depends=(glibc gcc-libs)
  # https://archlinuxarm.org/packages/aarch64/ncurses/files/PKGBUILD
  # http://deb.debian.org/debian/pool/main/n/ncurses/ncurses_6.1+20181013.orig.tar.gz.asc

  # https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-ncurses/PKGBUILD
  # https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-ncurses/001-use-libsystre.patch
  # https://github.com/msys2/MSYS2-packages/blob/master/ncurses/PKGBUILD

  # _4421.c:1364:15: error: expected ‘)’ before ‘int’
  # ../include/curses.h:1906:56: note: in definition of macro ‘mouse_trafo’
  # 1906 | #define mouse_trafo(y,x,to_screen) wmouse_trafo(stdscr,y,x,to_screen)

  # 26 Feb 2011, "5.8" # build fails
  # 27 Jan 2018, "5.9" # build fails
  # 27 Jan 2018, "6.1"
  # 12 Feb 2020, "6.2"

  local ncurses_version="$1"
  local ncurses_version_major="$(echo ${ncurses_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1|')"
  local ncurses_version_minor="$(echo ${ncurses_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\2|')"

  # The folder name as resulted after being extracted from the archive.
  local ncurses_src_folder_name="ncurses-${ncurses_version}"

  local ncurses_archive="${ncurses_src_folder_name}.tar.gz"
  local ncurses_url="ftp://ftp.invisible-island.net/pub/ncurses/${ncurses_archive}"

  # The folder name  for build, licenses, etc.
  local ncurses_folder_name="${ncurses_src_folder_name}"

  local ncurses_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${ncurses_folder_name}-installed"
  if [ ! -f "${ncurses_stamp_file_path}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${ncurses_url}" "${ncurses_archive}" \
      "${ncurses_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${ncurses_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${ncurses_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${ncurses_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_LIB}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running ncurses configure..."

          bash "${SOURCES_FOLDER_PATH}/${ncurses_src_folder_name}/configure" --help

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          # Without --with-pkg-config-libdir= it'll try to write the .pc files in the
          # xbb folder, probbaly by using the dirname of pkg-config.

          config_options+=("--with-terminfo-dirs=/etc/terminfo")
          config_options+=("--with-default-terminfo-dir=/etc/terminfo:/lib/terminfo:/usr/share/terminfo")
          config_options+=("--with-gpm")
          config_options+=("--with-versioned-syms")
          config_options+=("--with-xterm-kbs=del")

          config_options+=("--enable-termcap")
          config_options+=("--enable-const")
          config_options+=("--enable-symlinks")

          config_options+=("--with-shared")
          config_options+=("--with-normal")
          config_options+=("--with-cxx")
          config_options+=("--with-cxx-binding")
          config_options+=("--with-cxx-shared")
          config_options+=("--with-pkg-config-libdir=${INSTALL_FOLDER_PATH}/lib/pkgconfig")

          # Fails on Linux, with missing _nc_cur_term, which is there.
          config_options+=("--without-pthread")

          config_options+=("--without-ada")
          config_options+=("--without-debug")
          config_options+=("--without-manpages")
          config_options+=("--without-tack")
          config_options+=("--without-tests")

          config_options+=("--enable-pc-files")
          config_options+=("--enable-sp-funcs")
          config_options+=("--enable-ext-colors")
          config_options+=("--enable-interop")

          config_options+=("--disable-lib-suffixes")
          config_options+=("--disable-overwrite")
          config_options+=("--disable-rpath")

          NCURSES_DISABLE_WIDEC=${NCURSES_DISABLE_WIDEC:-""}

          if [ "${NCURSES_DISABLE_WIDEC}" == "y" ]
          then
            config_options+=("--disable-widec")
          fi

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${ncurses_src_folder_name}/configure" \
            ${config_options[@]}

          cp "config.log" "${LOGS_FOLDER_PATH}/${ncurses_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ncurses_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running ncurses make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        # The test programs are interactive

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ncurses_folder_name}/make-output.txt"
    )

    (
      test_ncurses
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${ncurses_folder_name}/test-output.txt"

    touch "${ncurses_stamp_file_path}"

  else
    echo "Library ncurses already installed."
  fi

  test_functions+=("test_ncurses")
}

function test_ncurses()
{
  (
    xbb_activate

    echo
    echo "Checking the ncurses shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libncurses.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libpanel.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libmenu.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libform.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------

function build_readline()
{
  # https://tiswww.case.edu/php/chet/readline/rltop.html
  # https://ftp.gnu.org/gnu/readline/
  # https://ftp.gnu.org/gnu/readline/readline-8.0.tar.gz

  # depends=(glibc gcc-libs)
  # https://archlinuxarm.org/packages/aarch64/readline/files/PKGBUILD

  # 2019-01-07, "8.0"

  local readline_version="$1"
  local readline_version_major="$(echo ${readline_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\1|')"
  local readline_version_minor="$(echo ${readline_version} | sed -e 's|\([0-9][0-9]*\)\.\([0-9][0-9]*\)|\2|')"

  # The folder name as resulted after being extracted from the archive.
  local readline_src_folder_name="readline-${readline_version}"

  local readline_archive="${readline_src_folder_name}.tar.gz"
  local readline_url="https://ftp.gnu.org/gnu/readline/${readline_archive}"

  # The folder name  for build, licenses, etc.
  local readline_folder_name="${readline_src_folder_name}"

  local readline_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-${readline_folder_name}-installed"
  if [ ! -f "${readline_stamp_file_path}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${readline_url}" "${readline_archive}" \
      "${readline_src_folder_name}"

    mkdir -pv "${LOGS_FOLDER_PATH}/${readline_folder_name}"

    (
      mkdir -pv "${LIBS_BUILD_FOLDER_PATH}/${readline_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${readline_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS_NO_W}"
      CXXFLAGS="${XBB_CXXFLAGS_NO_W}"
      LDFLAGS="${XBB_LDFLAGS_LIB}"

      export CPPFLAGS
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running readline configure..."

          bash "${SOURCES_FOLDER_PATH}/${readline_src_folder_name}/configure" --help

          config_options=()

          config_options+=("--prefix=${INSTALL_FOLDER_PATH}")

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${readline_src_folder_name}/configure" \
            ${config_options[@]}

          run_app find . \
            -name Makefile \
            -print \
            -exec sed -i.bak -e 's|-Wl,-rpath,$(libdir)||' {} \;

          cp "config.log" "${LOGS_FOLDER_PATH}/${readline_folder_name}/config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${readline_folder_name}/configure-output.txt"
      fi

      (
        echo
        echo "Running readline make..."

        # Build.
        make -j ${JOBS}

        # make install-strip
        make install

        make -j1 check

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${readline_folder_name}/make-output.txt"
    )

    (
      test_readline
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/${readline_folder_name}/test-output.txt"

    touch "${readline_stamp_file_path}"

  else
    echo "Library readline already installed."
  fi

  test_functions+=("test_readline")
}

function test_readline()
{
  (
    xbb_activate

    echo
    echo "Checking the readline shared libraries..."

    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libreadline.${SHLIB_EXT})"
    show_libs "$(realpath ${INSTALL_FOLDER_PATH}/lib/libhistory.${SHLIB_EXT})"
  )
}

# -----------------------------------------------------------------------------
