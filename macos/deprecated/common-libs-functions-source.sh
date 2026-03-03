# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

function build_zlib()
{
  # http://zlib.net
  # http://zlib.net/fossils/
  # http://zlib.net/fossils/zlib-1.2.11.tar.gz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=zlib-git

  # 2017-01-15 "1.2.11"

  local zlib_version="$1"

  local zlib_folder_name="zlib-${zlib_version}"
  local zlib_archive="${zlib_folder_name}.tar.gz"
  local zlib_url="http://zlib.net/fossils/${zlib_archive}"
  # local zlib_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${zlib_archive}"

  local zlib_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-zlib-${zlib_version}-installed"
  if [ ! -f "${zlib_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${zlib_url}" "${zlib_archive}" "${zlib_folder_name}"

    (
      if [ ! -d "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}" ]
      then
        mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}"
        # Copy the sources in the build folder.
        cp -r "${SOURCES_FOLDER_PATH}/${zlib_folder_name}"/* \
          "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}"
      fi
      cd "${LIBS_BUILD_FOLDER_PATH}/${zlib_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CFLAGS="${XBB_CFLAGS} -fPIC"

      (
        echo
        echo "Running zlib configure..."

        bash "./configure" --help

        bash ${DEBUG} "./configure" \
          --prefix="${INSTALL_FOLDER_PATH}"

        cp "configure.log" "${LOGS_FOLDER_PATH}/configure-zlib-log.txt"
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-zlib-output.txt"

      (
        echo
        echo "Running zlib make..."

        # Build.
        make -j ${JOBS}
        make install
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-zlib-output.txt"
    )

    touch "${zlib_stamp_file_path}"

  else
    echo "Library zlib already installed."
  fi
}

function build_gmp()
{
  # https://gmplib.org
  # https://gmplib.org/download/gmp/
  # https://gmplib.org/download/gmp/gmp-6.1.2.tar.xz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gmp-hg

  # 16-Dec-2016 "6.1.2"

  local gmp_version="$1"

  local gmp_folder_name="gmp-${gmp_version}"
  local gmp_archive="${gmp_folder_name}.tar.xz"
  local gmp_url="https://gmplib.org/download/gmp/${gmp_archive}"
  # local gmp_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${gmp_archive}"

  local gmp_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-gmp-${gmp_version}-installed"
  if [ ! -f "${gmp_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${gmp_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gmp_url}" "${gmp_archive}" "${gmp_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${gmp_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${gmp_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"
      export ABI="64"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gmp configure..."

          bash "${SOURCES_FOLDER_PATH}/${gmp_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gmp_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-gmp-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-gmp-output.txt"
      fi

      (
        echo
        echo "Running gmp make..."

        # Build.
        # Parallel builds fail.
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-gmp-output.txt"
    )

    touch "${gmp_stamp_file_path}"

  else
    echo "Library gmp already installed."
  fi
}

function build_mpfr()
{
  # http://www.mpfr.org
  # http://www.mpfr.org/mpfr-3.1.6
  # https://www.mpfr.org/mpfr-4.0.2/mpfr-4.0.2.tar.xz
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/mpfr

  # 7 September 2017 "3.1.6"
  # Fails mpc
  # 31 January 2019 "4.0.2"

  local mpfr_version="$1"

  local mpfr_folder_name="mpfr-${mpfr_version}"
  local mpfr_archive="${mpfr_folder_name}.tar.xz"
  local mpfr_url="https://www.mpfr.org/${mpfr_folder_name}/${mpfr_archive}"
  # local mpfr_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${mpfr_archive}"

  local mpfr_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-mpfr-${mpfr_version}-installed"
  if [ ! -f "${mpfr_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${mpfr_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${mpfr_url}" "${mpfr_archive}" "${mpfr_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${mpfr_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${mpfr_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running mpfr configure..."

          bash "${SOURCES_FOLDER_PATH}/${mpfr_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mpfr_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-mpfr-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-mpfr-output.txt"
      fi

      (
        echo
        echo "Running mpfr make..."

        # Build.
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-mpfr-output.txt"
    )

    touch "${mpfr_stamp_file_path}"

  else
    echo "Library mpfr already installed."
  fi
}

function build_mpc()
{
  # http://www.multiprecision.org/
  # ftp://ftp.gnu.org/gnu/mpc
  # https://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/libmpc

  # February 2015 "1.0.3"

  local mpc_version="$1"

  local mpc_folder_name="mpc-${mpc_version}"
  local mpc_archive="${mpc_folder_name}.tar.gz"
  local mpc_url="ftp://ftp.gnu.org/gnu/mpc/${mpc_archive}"

  local mpc_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-mpc-${mpc_version}-installed"
  if [ ! -f "${mpc_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${mpc_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${mpc_url}" "${mpc_archive}" "${mpc_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${mpc_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${mpc_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running mpc configure..."

          bash "${SOURCES_FOLDER_PATH}/${mpc_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${mpc_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-mpc-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-mpc-output.txt"
      fi

      (
        echo
        echo "Running mpc make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-mpc-output.txt"
    )

    touch "${mpc_stamp_file_path}"

  else
    echo "Library mpc already installed."
  fi
}

function build_isl()
{
  # http://isl.gforge.inria.fr
  # http://isl.gforge.inria.fr/isl-0.21.tar.xz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=isl

  # 2016-12-20 "0.18"
  # 2019-03-26 "0.21"

  local isl_version="$1"

  local isl_folder_name="isl-${isl_version}"
  local isl_archive="${isl_folder_name}.tar.xz"
  local isl_url="http://isl.gforge.inria.fr/${isl_archive}"
  # local isl_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${isl_archive}"

  local isl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-isl-${isl_version}-installed"
  if [ ! -f "${isl_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${isl_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${isl_url}" "${isl_archive}" "${isl_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${isl_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${isl_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running isl configure..."

          bash "${SOURCES_FOLDER_PATH}/${isl_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${isl_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-isl-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-isl-output.txt"
      fi

      (
        echo
        echo "Running isl make..."

        # Build.
        # Parallel builds fail
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-isl-output.txt"
    )

    touch "${isl_stamp_file_path}"

  else
    echo "Library isl already installed."
  fi
}

function build_nettle()
{
  # https://www.lysator.liu.se/~nisse/nettle/
  # https://ftp.gnu.org/gnu/nettle/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=nettle-git

  # 2017-11-19, "3.4"
  # 2018-12-04, "3.4.1"

  local nettle_version="$1"

  local nettle_folder_name="nettle-${nettle_version}"
  local nettle_archive="${nettle_folder_name}.tar.gz"
  local nettle_url="ftp://ftp.gnu.org/gnu/nettle/${nettle_archive}"

  local nettle_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-nettle-${nettle_version}-installed"
  if [ ! -f "${nettle_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${nettle_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${nettle_url}" "${nettle_archive}" "${nettle_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${nettle_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${nettle_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running nettle configure..."

          bash "${SOURCES_FOLDER_PATH}/${nettle_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${nettle_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --disable-documentation

          cp "config.log" "${LOGS_FOLDER_PATH}/config-nettle-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-nettle-output.txt"
      fi

      (
        echo
        echo "Running nettle make..."

        # Build.
        # make -j ${JOBS}
        make
        # make install-strip
        # For unknown reasons, on 32-bits make install-info fails
        # (`install-info --info-dir="/opt/xbb/share/info" nettle.info` returns 1)
        # Make the other install targets.
        make install-headers install-static install-pkgconfig install-shared-nettle  install-shared-hogweed
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-nettle-output.txt"
    )

    touch "${nettle_stamp_file_path}"

  else
    echo "Library nettle already installed."
  fi
}

function build_tasn1()
{
  # https://www.gnu.org/software/libtasn1/
  # http://ftp.gnu.org/gnu/libtasn1/
  # https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.12.tar.gz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libtasn1-git

  # 2017-11-19, "4.12"
  # 2018-01-16, "4.13"

  local tasn1_version="$1"

  local tasn1_folder_name="libtasn1-${tasn1_version}"
  local tasn1_archive="${tasn1_folder_name}.tar.gz"
  local tasn1_url="ftp://ftp.gnu.org/gnu/libtasn1/${tasn1_archive}"

  local tasn1_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-tasn1-${tasn1_version}-installed"
  if [ ! -f "${tasn1_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${tasn1_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${tasn1_url}" "${tasn1_archive}" "${tasn1_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${tasn1_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${tasn1_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-logical-op -Wno-missing-prototypes -Wno-implicit-fallthrough -Wno-format-truncation"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running tasn1 configure..."

          bash "${SOURCES_FOLDER_PATH}/${tasn1_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${tasn1_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-tasn1-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-tasn1-output.txt"
      fi

      (
        echo
        echo "Running tasn1 make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-tasn1-output.txt"
    )

    touch "${tasn1_stamp_file_path}"

  else
    echo "Library tasn1 already installed."
  fi
}

function build_expat()
{
  # https://libexpat.github.io
  # https://github.com/libexpat/libexpat/releases
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=expat-git

  # Nov 1, 2017, "2.2.5"
  # Aug 15, 2018, "2.2.6"

  local expat_version="$1"

  local expat_folder_name="expat-${expat_version}"
  local expat_archive="${expat_folder_name}.tar.bz2"
  local expat_release="R_$(echo ${expat_version} | sed -e 's|[.]|_|g')"
  # local expat_url="ftp://ftp.gnu.org/gnu/expat/${expat_archive}"
  local expat_url="https://github.com/libexpat/libexpat/releases/download/${expat_release}/${expat_archive}"

  local expat_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-expat-${expat_version}-installed"
  if [ ! -f "${expat_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${expat_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${expat_url}" "${expat_archive}" "${expat_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${expat_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${expat_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running expat configure..."

          bash "${SOURCES_FOLDER_PATH}/${expat_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${expat_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-expat-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-expat-output.txt"
      fi

      (
        echo
        echo "Running expat make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-expat-output.txt"
    )

    touch "${expat_stamp_file_path}"

  else
    echo "Library expat already installed."
  fi
}

function build_libffi()
{
  # https://sourceware.org/libffi/
  # https://sourceware.org/pub/libffi/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libffi-git

  # 12-Nov-2014, "3.2.1", latest

  local libffi_version="$1"

  local libffi_folder_name="libffi-${libffi_version}"
  # .gz only.
  local libffi_archive="${libffi_folder_name}.tar.gz"
  # local libffi_url="ftp://ftp.gnu.org/gnu/libffi/${libffi_archive}"
  local libffi_url="https://sourceware.org/pub/libffi/${libffi_archive}"

  local libffi_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-libffi-${libffi_version}-installed"
  if [ ! -f "${libffi_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libffi_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libffi_url}" "${libffi_archive}" "${libffi_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${libffi_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libffi_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libffi configure..."

          bash "${SOURCES_FOLDER_PATH}/${libffi_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libffi_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --enable-pax_emutramp

          cp "config.log" "${LOGS_FOLDER_PATH}/config-libffi-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-libffi-output.txt"
      fi

      (
        echo
        echo "Running libffi make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-libffi-output.txt"
    )

    touch "${libffi_stamp_file_path}"

  else
    echo "Library libffi already installed."
  fi
}

function build_libiconv()
{
  # https://www.gnu.org/software/libiconv/
  # https://ftp.gnu.org/pub/gnu/libiconv/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libiconv

  # 2017-02-02, "1.15", latest

  local libiconv_version="$1"

  local libiconv_folder_name="libiconv-${libiconv_version}"
  local libiconv_archive="${libiconv_folder_name}.tar.gz"
  local libiconv_url="ftp://ftp.gnu.org/gnu/libiconv/${libiconv_archive}"

  local libiconv_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-libiconv-${libiconv_version}-installed"
  if [ ! -f "${libiconv_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${libiconv_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libiconv_url}" "${libiconv_archive}" "${libiconv_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${libiconv_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${libiconv_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libiconv configure..."

          bash "${SOURCES_FOLDER_PATH}/${libiconv_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libiconv_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-libiconv-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-libiconv-output.txt"
      fi

      (
        echo
        echo "Running libiconv make..."

        # Build.
        make -j ${JOBS}
        make install-strip

        # Does not leave a pkgconfig/iconv.pc;
        # Pass -liconv explicitly.
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-libiconv-output.txt"
    )

    touch "${libiconv_stamp_file_path}"

  else
    echo "Library libiconv already installed."
  fi
}

function build_gnutls()
{
  # http://www.gnutls.org/
  # https://www.gnupg.org/ftp/gcrypt/gnutls/
  # https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.7.tar.xz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gnutls-git

  # 2017-10-21, "3.6.1"
  # 2019-03-27, "3.6.7"

  local gnutls_version="$1"
  local gnutls_version_major="$(echo ${gnutls_version} | sed -e 's|\([0-9][0-9]*\.[0-9][0-9]*\)\.[0-9][0-9]*|\1|')"

  local gnutls_folder_name="gnutls-${gnutls_version}"
  local gnutls_archive="${gnutls_folder_name}.tar.xz"
  local gnutls_url="https://www.gnupg.org/ftp/gcrypt/gnutls/v${gnutls_version_major}/${gnutls_archive}"

  local gnutls_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-gnutls-${gnutls_version}-installed"
  if [ ! -f "${gnutls_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${gnutls_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gnutls_url}" "${gnutls_archive}" "${gnutls_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${gnutls_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${gnutls_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-parentheses -Wno-bad-function-cast -Wno-unused-macros -Wno-bad-function-cast -Wno-unused-variable -Wno-pointer-sign -Wno-implicit-fallthrough -Wno-format-truncation -Wno-missing-prototypes -Wno-missing-declarations -Wno-shadow -Wno-sign-compare -Wno-unknown-warning-option -Wno-static-in-inline -Wno-implicit-function-declaration -Wno-strict-prototypes -Wno-tautological-pointer-compare"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      export CC=clang
      export CXX=clang++

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gnutls configure..."

          bash "${SOURCES_FOLDER_PATH}/${gnutls_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gnutls_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --without-p11-kit \
            --enable-guile \
            --with-included-unistring

          cp "config.log" "${LOGS_FOLDER_PATH}/config-gnutls-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-gnutls-output.txt"
      fi

      (
        echo
        echo "Running gnutls make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-gnutls-output.txt"
    )

    touch "${gnutls_stamp_file_path}"

  else
    echo "Library gnutls already installed."
  fi
}

function build_util_macros()
{
  # http://www.linuxfromscratch.org/blfs/view/7.4/x/util-macros.html
  # http://xorg.freedesktop.org/releases/individual/util/util-macros-1.17.1.tar.bz2

  local util_macros_version="$1"

  local util_macros_folder_name="util-macros-${util_macros_version}"
  local util_macros_archive="${util_macros_folder_name}.tar.bz2"
  local util_macros_url="http://xorg.freedesktop.org/releases/individual/util/${util_macros_archive}"

  local util_macros_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-util_macros-${util_macros_version}-installed"
  if [ ! -f "${util_macros_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${util_macros_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${util_macros_url}" "${util_macros_archive}" "${util_macros_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${util_macros_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${util_macros_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running util_macros configure..."

          bash "${SOURCES_FOLDER_PATH}/${util_macros_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${util_macros_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-util_macros-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-util_macros-output.txt"
      fi

      (
        echo
        echo "Running util_macros make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-util_macros-output.txt"
    )

    touch "${util_macros_stamp_file_path}"

  else
    echo "Library util_macros already installed."
  fi
}

function build_xorg_xproto()
{
  # http://www.linuxfromscratch.org/blfs/view/7.4/x/x7proto.html
  # https://www.x.org/releases/individual/proto/xproto-7.0.31.tar.bz2

  local xorg_xproto_version="$1"

  local xorg_xproto_folder_name="xproto-${xorg_xproto_version}"
  local xorg_xproto_archive="${xorg_xproto_folder_name}.tar.bz2"
  local xorg_xproto_url="https://www.x.org/releases/individual/proto/${xorg_xproto_archive}"

  local xorg_xproto_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-xorg_xproto-${xorg_xproto_version}-installed"
  if [ ! -f "${xorg_xproto_stamp_file_path}" -o ! -d "${LIBS_BUILD_FOLDER_PATH}/${xorg_xproto_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${xorg_xproto_url}" "${xorg_xproto_archive}" "${xorg_xproto_folder_name}"

    (
      mkdir -p "${LIBS_BUILD_FOLDER_PATH}/${xorg_xproto_folder_name}"
      cd "${LIBS_BUILD_FOLDER_PATH}/${xorg_xproto_folder_name}"

      xbb_activate
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_LIB}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running xorg_xproto configure..."

          bash "${SOURCES_FOLDER_PATH}/${xorg_xproto_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${xorg_xproto_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-xorg_xproto-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-xorg_xproto-output.txt"
      fi

      (
        echo
        echo "Running xorg_xproto make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-xorg_xproto-output.txt"
    )

    touch "${xorg_xproto_stamp_file_path}"

  else
    echo "Library xorg_xproto already installed."
  fi
}

