# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

function do_gcc()
{
  # https://gcc.gnu.org
  # https://ftp.gnu.org/gnu/gcc/
  # https://gcc.gnu.org/wiki/InstallingGCC
  # https://gcc.gnu.org/install/build.html
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gcc-git

  # 2018-12-06, "7.4.0"

  local gcc_version="$1"

  local gcc_folder_name="gcc-${gcc_version}"
  local gcc_archive="${gcc_folder_name}.tar.xz"
  local gcc_url="https://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}/${gcc_archive}"

  local gcc_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-gcc-${gcc_version}-installed"
  if [ ! -f "${gcc_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${gcc_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gcc_url}" "${gcc_archive}" "${gcc_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${gcc_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${gcc_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      CPPFLAGS="${XBB_CPPFLAGS}"
      CPPFLAGS_FOR_TARGET="${XBB_CPPFLAGS}"
      CFLAGS="${XBB_CFLAGS} -Wno-sign-compare -Wno-varargs -Wno-tautological-compare  "
      CXXFLAGS="${XBB_CXXFLAGS} -Wno-sign-compare -Wno-varargs -Wno-tautological-compare"
      LDFLAGS="${XBB_LDFLAGS_APP}"

      export CPPFLAGS
      export CPPFLAGS_FOR_TARGET
      export CFLAGS
      export CXXFLAGS
      export LDFLAGS

      local sdk_path=""
      local print_path="$(xcode-select -print-path)"
      if [ -d "${print_path}/SDKs/MacOSX.sdk" ]
      then
        # Without Xcode, use the SDK that comes with the CLT.
        sdk_path="${print_path}/SDKs/MacOSX.sdk"
      elif [ -d "${print_path}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" ]
      then
        # With Xcode, chose the SDK from the macOS platform.
        sdk_path="${print_path}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
      elif [ -d "/usr/include" ]
      then
        # Without Xcode, on 10.10 there is no SDK, use the root.
        sdk_path="/"
      else
        echo "Cannot find SDK in ${print_path}."
        exit 1
      fi

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gcc configure..."

          bash "${SOURCES_FOLDER_PATH}/${gcc_folder_name}/configure" --help

          # The Linux build also uses:
          # --enable-__cxa_atexit \
          # --enable-install-libiberty \
          # --enable-libmpx \
          # --disable-libstdcxx-pch \
          # --enable-gnu-unique-object \
          # --enable-linker-build-id \
          # --enable-gnu-indirect-function \
          # --enable-clocale=gnu \
          # --disable-libssp \

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gcc_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --program-suffix="${XBB_GCC_SUFFIX}" \
            --with-pkgversion="${XBB_GCC_BRANDING}" \
            --with-native-system-header-dir="/usr/include" \
            --with-sysroot="${sdk_path}" \
            \
            --enable-languages=c,c++,objc,obj-c++ \
            --enable-checking=release \
            --enable-static \
            --enable-threads=posix \
            \
            --disable-multilib \
            --disable-werror \
            --disable-nls \
            --disable-bootstrap \
            \
            --disable-libunwind-exceptions \
            \
            --with-gmp="${INSTALL_FOLDER_PATH}" \
            --with-mpfr="${INSTALL_FOLDER_PATH}" \
            --with-mpc="${INSTALL_FOLDER_PATH}" \
            --with-isl="${INSTALL_FOLDER_PATH}" \

          cp "config.log" "${LOGS_FOLDER_PATH}/config-gcc-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-gcc-output.txt"
      fi

      (
        echo
        echo "Running gcc make..."

        # Build.
        # Parallel builds fail.
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-gcc-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/g++${XBB_GCC_SUFFIX}" --version
      "${INSTALL_FOLDER_PATH}/bin/g++${XBB_GCC_SUFFIX}" -dumpmachine
      "${INSTALL_FOLDER_PATH}/bin/g++${XBB_GCC_SUFFIX}" -dumpspecs | wc -l

      mkdir -p "${HOME}"/tmp
      cd "${HOME}"/tmp

      # Note: __EOF__ is quoted to prevent substitutions here.
      cat <<'__EOF__' > hello.cpp
#include <iostream>

int
main(int argc, char* argv[])
{
  std::cout << "Hello" << std::endl;
}
__EOF__

      if true
      then

        "${INSTALL_FOLDER_PATH}/bin/g++${XBB_GCC_SUFFIX}" hello.cpp -o hello

        if [ "x$(./hello)x" != "xHellox" ]
        then
          exit 1
        fi

      fi

      rm -rf hello.cpp hello
    )

    hash -r

    touch "${gcc_stamp_file_path}"

  else
    echo "Component gcc already installed."
  fi
}

# -----------------------------------------------------------------------------

function build_openssl()
{
  # https://www.openssl.org
  # https://www.openssl.org/source/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=openssl-static
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=openssl-git

  # 2017-Nov-02
  # XBB_OPENSSL_VERSION="1.1.0g"
  # The new version deprecated CRYPTO_set_locking_callback, and yum fails with
  # /usr/lib64/python2.6/site-packages/pycurl.so: undefined symbol: CRYPTO_set_locking_callback

  # 2017-Dec-07, "1.0.2n"
  # 2019-Feb-26, "1.0.2r"
  # 2019-Feb-26, "1.1.1b"

  local openssl_version="$1"

  local openssl_folder_name="openssl-${openssl_version}"
  local openssl_archive="${openssl_folder_name}.tar.gz"
  local openssl_url="https://www.openssl.org/source/${openssl_archive}"

  local openssl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-openssl-${openssl_version}-installed"
  if [ ! -f "${openssl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${openssl_folder_name}" ]
  then

    # In-source build.
    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${openssl_url}" "${openssl_archive}" "${openssl_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${openssl_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${openssl_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      # export CPPFLAGS="${XBB_CPPFLAGS} -I${BUILD_FOLDER_PATH}/${openssl_folder_name}/include"
      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f config.stamp ]
      then
        (
          echo
          echo "Running openssl configure..."

          # This config does not use the standard GNU environment definitions.
          # `Configure` is a Perl script.
          "./Configure" --help || true

          "./Configure" darwin64-x86_64-cc \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --openssldir="${INSTALL_FOLDER_PATH}/openssl" \
            no-ssl3-method

          make depend
          make -j ${JOBS}

          touch config.stamp

          # cp "configure.log" "${LOGS_FOLDER_PATH}/configure-openssl-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-openssl-output.txt"
      fi

      (
        echo
        echo "Running openssl make..."

        # Build.
        make -j ${JOBS}
        make install_sw

        strip -S "${INSTALL_FOLDER_PATH}/bin/openssl"

        if [ ! -f "${INSTALL_FOLDER_PATH}/openssl/cert.pem" ]
        then
          mkdir -p "${INSTALL_FOLDER_PATH}/openssl"

          if [ -f "/private/etc/ssl/cert.pem" ]
          then
            /usr/bin/install -v -c -m 644 "/private/etc/ssl/cert.pem" "${INSTALL_FOLDER_PATH}/openssl"
          fi
          # Used by curl.
          /usr/bin/install -v -c -m 644 "$(dirname "${script_folder_path}")/ca-bundle/ca-bundle.crt" "${INSTALL_FOLDER_PATH}/openssl"
        fi

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-openssl-output.txt"

      (
        xbb_activate_installed_bin

        echo
        "${INSTALL_FOLDER_PATH}/bin/openssl" version
      )
    )

    touch "${openssl_stamp_file_path}"

  else
    echo "Component openssl already installed."
  fi
}

function build_curl()
{
  # https://curl.haxx.se
  # https://curl.haxx.se/download/
  # https://curl.haxx.se/download/curl-7.64.1.tar.xz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=curl-git

  # 2017-10-23 "7.56.1"
  # 2017-11-29 "7.57.0"
  # 2019-03-27 "7.64.1"

  local curl_version="$1"

  local curl_folder_name="curl-${curl_version}"
  local curl_archive="${curl_folder_name}.tar.xz"
  local curl_url="https://curl.haxx.se/download/${curl_archive}"

  local curl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-curl-${curl_version}-installed"
  if [ ! -f "${curl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${curl_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${curl_url}" "${curl_archive}" "${curl_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${curl_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${curl_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-deprecated-declarations"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running curl configure..."

          bash "${SOURCES_FOLDER_PATH}/${curl_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${curl_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --disable-debug \
            --with-ssl \
            --enable-optimize \
            --disable-manual \
            --disable-ldap \
            --disable-ldaps \
            --enable-versioned-symbols \
            --enable-threaded-resolver \
            --with-gssapi \
            --with-ca-bundle="${INSTALL_FOLDER_PATH}/openssl/ca-bundle.crt"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-curl-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-curl-output.txt"
      fi

      (
        echo
        echo "Running curl make..."

        # Build.
        # Parallel builds fail
        # make -j ${JOBS}
        make
        make install

        strip -S "${INSTALL_FOLDER_PATH}/bin/curl"
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-curl-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/curl" --version
    )

    touch "${curl_stamp_file_path}"

  else
    echo "Component curl already installed."
  fi
}

function build_xz()
{
  # https://tukaani.org/xz/
  # https://sourceforge.net/projects/lzmautils/files/
  # https://tukaani.org/xz/xz-5.2.4.tar.xz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=xz-git

  # 2016-12-30 "5.2.3"
  # 2018-04-29 "5.2.4"

  local xz_version="$1"

  local xz_folder_name="xz-${xz_version}"
  local xz_archive="${xz_folder_name}.tar.xz"
  local xz_url="https://tukaani.org/xz/${xz_archive}"

  local xz_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-xz-${xz_version}-installed"
  if [ ! -f "${xz_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${xz_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${xz_url}" "${xz_archive}" "${xz_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${xz_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${xz_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running xz configure..."

          bash "${SOURCES_FOLDER_PATH}/${xz_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${xz_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --disable-rpath

          cp "config.log" "${LOGS_FOLDER_PATH}/config-xz-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-xz-output.txt"
      fi

      (
        echo
        echo "Running xz make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-xz-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/xz" --version
    )

    hash -r

    touch "${xz_stamp_file_path}"

  else
    echo "Component xz already installed."
  fi
}

function build_tar()
{
  # https://www.gnu.org/software/tar/
  # https://ftp.gnu.org/gnu/tar/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=tar-git

  # 2016-05-16 "1.29"
  # 2017-12-17 "1.30"
  # 2019-02-23 "1.32"

  local tar_version="$1"

  local tar_folder_name="tar-${tar_version}"
  local tar_archive="${tar_folder_name}.tar.xz"
  local tar_url="https://ftp.gnu.org/gnu/tar/${tar_archive}"

  local tar_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-tar-${tar_version}-installed"
  if [ ! -f "${tar_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${tar_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${tar_url}" "${tar_archive}" "${tar_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${tar_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${tar_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running tar configure..."

          bash "${SOURCES_FOLDER_PATH}/${tar_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${tar_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-tar-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-tar-output.txt"
      fi

      (
        echo
        echo "Running tar make..."

        # Build.
        # make -j ${JOBS}
        make
        make install-strip

        echo
        echo "Linking gnutar..."
        cd "${INSTALL_FOLDER_PATH}/bin"
        ln -s -v tar gnutar

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-tar-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/tar" --version
    )

    hash -r

    touch "${tar_stamp_file_path}"

  else
    echo "Component tar already installed."
  fi
}

function build_coreutils()
{
  # https://www.gnu.org/software/coreutils/
  # https://ftp.gnu.org/gnu/coreutils/

  # 2019-03-10 "8.31"

  local coreutils_version="$1"

  local coreutils_folder_name="coreutils-${coreutils_version}"
  local coreutils_archive="${coreutils_folder_name}.tar.xz"
  local coreutils_url="https://ftp.gnu.org/gnu/coreutils/${coreutils_archive}"

  local coreutils_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-coreutils-${coreutils_version}-installed"
  if [ ! -f "${coreutils_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${coreutils_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${coreutils_url}" "${coreutils_archive}" "${coreutils_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${coreutils_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${coreutils_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-pointer-sign -Wno-incompatible-pointer-types"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      # Use Apple GCC, since with GNU GCC it fails with some undefined symbols.
      export CC=clang
      export CXX=clang++

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running coreutils configure..."

          bash "${SOURCES_FOLDER_PATH}/${coreutils_folder_name}/configure" --help

          # `ar` must be excluded, it interferes with Apple similar program.
          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${coreutils_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --enable-no-install-program=ar

          cp "config.log" "${LOGS_FOLDER_PATH}/config-coreutils-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-coreutils-output.txt"
      fi

      (
        echo
        echo "Running coreutils make..."

        # Build.
        make -j ${JOBS}
        # make install-strip
        make install
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-coreutils-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/realpath" --version
    )

    hash -r

    touch "${coreutils_stamp_file_path}"

  else
    echo "Component coreutils already installed."
  fi
}

function build_pkg_config()
{
  # https://www.freedesktop.org/wiki/Software/pkg-config/
  # https://pkgconfig.freedesktop.org/releases/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=pkg-config-git

  # 2017-03-20, "0.29.2", latest

  local pkg_config_version="$1"

  local pkg_config_folder_name="pkg-config-${pkg_config_version}"
  local pkg_config_archive="${pkg_config_folder_name}.tar.gz"
  local pkg_config_url="https://pkgconfig.freedesktop.org/releases/${pkg_config_archive}"
  # local pkg_config_url="https://github.com/gnu-mcu-eclipse/files/raw/master/libs/${pkg_config_archive}"

  local pkg_config_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-pkg_config-${pkg_config_version}-installed"
  if [ ! -f "${pkg_config_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${pkg_config_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${pkg_config_url}" "${pkg_config_archive}" "${pkg_config_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${pkg_config_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${pkg_config_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-int-conversion -Wno-unused-value -Wno-unused-function -Wno-deprecated-declarations -Wno-return-type -Wno-tautological-constant-out-of-range-compare -Wno-sometimes-uninitialized"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      export CC=clang
      export CXX=clang++

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running pkg_config configure..."

          bash "${SOURCES_FOLDER_PATH}/${pkg_config_folder_name}/configure" --help
          bash "${SOURCES_FOLDER_PATH}/${pkg_config_folder_name}/glib/configure" --help

          # --with-internal-glib fails with
          # gconvert.c:61:2: error: #error GNU libiconv not in use but included iconv.h is from libiconv
          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${pkg_config_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --with-internal-glib \
            --disable-debug \
            --disable-host-tool \
            --with-pc-path=""

          cp "config.log" "${LOGS_FOLDER_PATH}/config-pkg_config-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-pkg_config-output.txt"
      fi

      (
        echo
        echo "Running pkg_config make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-pkg_config-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/pkg-config" --version
    )

    hash -r

    touch "${pkg_config_stamp_file_path}"

  else
    echo "Component pkg_config already installed."
  fi
}

function build_m4()
{
  # https://www.gnu.org/software/m4/
  # https://ftp.gnu.org/gnu/m4/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=m4-git

  # 2016-12-31, "1.4.18", latest

  local m4_version="$1"

  local m4_folder_name="m4-${m4_version}"
  local m4_archive="${m4_folder_name}.tar.xz"
  local m4_url="https://ftp.gnu.org/gnu/m4/${m4_archive}"
  local m4_patch="m4-${m4_version}.patch"

  local m4_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-m4-${m4_version}-installed"
  if [ ! -f "${m4_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${m4_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${m4_url}" "${m4_archive}" "${m4_folder_name}" "${m4_patch}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${m4_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${m4_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-incompatible-pointer-types"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running m4 configure..."

          bash "${SOURCES_FOLDER_PATH}/${m4_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${m4_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --disable-dependency-tracking

          cp "config.log" "${LOGS_FOLDER_PATH}/config-m4-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-m4-output.txt"
      fi

      (
        echo
        echo "Running m4 make..."

        # Build.
        make -j ${JOBS}
        make install-strip

        echo
        echo "Linking gm4..."
        cd "${INSTALL_FOLDER_PATH}/bin"
        ln -s -v m4 gm4

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-m4-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/m4" --version
    )

    hash -r

    touch "${m4_stamp_file_path}"

  else
    echo "Component m4 already installed."
  fi
}


function build_gawk()
{
  # https://www.gnu.org/software/gawk/
  # https://ftp.gnu.org/gnu/gawk/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gawk-git

  # 2017-10-19, "4.2.0"
  # 2018-02-25, "4.2.1"

  local gawk_version="$1"

  local gawk_folder_name="gawk-${gawk_version}"
  local gawk_archive="${gawk_folder_name}.tar.xz"
  local gawk_url="https://ftp.gnu.org/gnu/gawk/${gawk_archive}"

  local gawk_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-gawk-${gawk_version}-installed"
  if [ ! -f "${gawk_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${gawk_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gawk_url}" "${gawk_archive}" "${gawk_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${gawk_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${gawk_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gawk configure..."

          bash "${SOURCES_FOLDER_PATH}/${gawk_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gawk_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --without-libsigsegv

          cp "config.log" "${LOGS_FOLDER_PATH}/config-gawk-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-gawk-output.txt"
      fi

      (
        echo
        echo "Running gawk make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-gawk-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/awk" --version
    )

    hash -r

    touch "${gawk_stamp_file_path}"

  else
    echo "Component gawk already installed."
  fi
}

function build_sed()
{
  # https://www.gnu.org/software/sed/
  # https://ftp.gnu.org/gnu/sed/

  # 2018-12-21, "4.7"

  local sed_version="$1"

  local sed_folder_name="sed-${sed_version}"
  local sed_archive="${sed_folder_name}.tar.xz"
  local sed_url="https://ftp.gnu.org/gnu/sed/${sed_archive}"

  local sed_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-sed-${sed_version}-installed"
  if [ ! -f "${sed_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${sed_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${sed_url}" "${sed_archive}" "${sed_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${sed_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${sed_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running sed configure..."

          bash "${SOURCES_FOLDER_PATH}/${sed_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${sed_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-sed-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-sed-output.txt"
      fi

      (
        echo
        echo "Running sed make..."

        # Build.
        make -j ${JOBS}
        make install-strip

        echo
        echo "Linking gsed..."
        cd "${INSTALL_FOLDER_PATH}/bin"
        ln -s -v sed gsed
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-sed-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/sed" --version
    )

    hash -r

    touch "${sed_stamp_file_path}"

  else
    echo "Component sed already installed."
  fi
}

function build_autoconf()
{
  # https://www.gnu.org/software/autoconf/
  # https://ftp.gnu.org/gnu/autoconf/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=autoconf-git

  # 2012-04-24, "2.69", latest

  local autoconf_version="$1"

  local autoconf_folder_name="autoconf-${autoconf_version}"
  local autoconf_archive="${autoconf_folder_name}.tar.xz"
  local autoconf_url="https://ftp.gnu.org/gnu/autoconf/${autoconf_archive}"

  local autoconf_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-autoconf-${autoconf_version}-installed"
  if [ ! -f "${autoconf_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${autoconf_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${autoconf_url}" "${autoconf_archive}" "${autoconf_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${autoconf_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${autoconf_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running autoconf configure..."

          bash "${SOURCES_FOLDER_PATH}/${autoconf_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${autoconf_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-autoconf-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-autoconf-output.txt"
      fi

      (
        echo
        echo "Running autoconf make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-autoconf-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/autoconf" --version
    )

    hash -r

    touch "${autoconf_stamp_file_path}"

  else
    echo "Component autoconf already installed."
  fi
}

function build_automake()
{
  # https://www.gnu.org/software/automake/
  # https://ftp.gnu.org/gnu/automake/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=automake-git

  # 2015-01-05, "1.15"
  # 2018-02-25, "1.16"

  local automake_version="$1"

  local automake_folder_name="automake-${automake_version}"
  local automake_archive="${automake_folder_name}.tar.xz"
  local automake_url="https://ftp.gnu.org/gnu/automake/${automake_archive}"

  local automake_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-automake-${automake_version}-installed"
  if [ ! -f "${automake_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${automake_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${automake_url}" "${automake_archive}" "${automake_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${automake_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${automake_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running automake configure..."

          bash "${SOURCES_FOLDER_PATH}/${automake_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${automake_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-automake-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-automake-output.txt"
      fi

      (
        echo
        echo "Running automake make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-automake-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/automake" --version
    )

    hash -r

    touch "${automake_stamp_file_path}"

  else
    echo "Component automake already installed."
  fi
}

function build_libtool()
{
  # https://www.gnu.org/software/libtool/
  # http://gnu.mirrors.linux.ro/libtool/
  # http://mirrors.nav.ro/gnu/libtool/libtool-2.4.6.tar.xz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=libtool-git

  # 15-Feb-2015, "2.4.6", latest

  local libtool_version="$1"

  local libtool_folder_name="libtool-${libtool_version}"
  local libtool_archive="${libtool_folder_name}.tar.xz"
  local libtool_url="http://mirrors.nav.ro/gnu/libtool/${libtool_archive}"

  local libtool_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-libtool-installed"
  if [ ! -f "${libtool_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${libtool_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${libtool_url}" "${libtool_archive}" "${libtool_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${libtool_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${libtool_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running libtool configure..."

          bash "${SOURCES_FOLDER_PATH}/${libtool_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${libtool_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-libtool-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-libtool-output.txt"
      fi

      (
        echo
        echo "Running libtool make..."

        # Build.
        make -j ${JOBS}
        make install-strip

        echo
        echo "Linking glibtool..."
        cd "${INSTALL_FOLDER_PATH}/bin"
        ln -s -v libtool glibtool
        ln -s -v libtoolize glibtoolize
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-libtool-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/libtool" --version
    )

    hash -r

    touch "${libtool_stamp_file_path}"

  else
    echo "Component libtool already installed."
  fi
}

function build_gettext()
{
  # https://www.gnu.org/software/gettext/
  # https://ftp.gnu.org/gnu/gettext/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=gettext-git

  # 2016-06-09, "0.19.8"

  local gettext_version="$1"

  local gettext_folder_name="gettext-${gettext_version}"
  local gettext_archive="${gettext_folder_name}.tar.xz"
  local gettext_url="https://ftp.gnu.org/gnu/gettext/${gettext_archive}"

  local gettext_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-gettext-${gettext_version}-installed"
  if [ ! -f "${gettext_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${gettext_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${gettext_url}" "${gettext_archive}" "${gettext_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${gettext_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${gettext_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running gettext configure..."

          bash "${SOURCES_FOLDER_PATH}/${gettext_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${gettext_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-gettext-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-gettext-output.txt"
      fi

      (
        echo
        echo "Running gettext make..."

        # Build.
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-gettext-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/gettext" --version
    )

    hash -r

    touch "${gettext_stamp_file_path}"

  else
    echo "Component gettext already installed."
  fi
}

function build_patch()
{
  # https://www.gnu.org/software/patch/
  # https://ftp.gnu.org/gnu/patch/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=patch-git

  # 2015-03-06, "2.7.5"
  # 2018-02-06, "2.7.6"

  local patch_version="$1"

  local patch_folder_name="patch-${patch_version}"
  local patch_archive="${patch_folder_name}.tar.xz"
  local patch_url="https://ftp.gnu.org/gnu/patch/${patch_archive}"

  local patch_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-patch-${patch_version}-installed"
  if [ ! -f "${patch_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${patch_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${patch_url}" "${patch_archive}" "${patch_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${patch_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${patch_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running patch configure..."

          bash "${SOURCES_FOLDER_PATH}/${patch_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${patch_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-patch-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-patch-output.txt"
      fi

      (
        echo
        echo "Running patch make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-patch-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/patch" --version
    )

    hash -r

    touch "${patch_stamp_file_path}"

  else
    echo "Component patch already installed."
  fi
}

function build_diffutils()
{
  # https://www.gnu.org/software/diffutils/
  # https://ftp.gnu.org/gnu/diffutils/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=diffutils-git

  # 2017-05-21, "3.6"
  # 2018-12-31, "3.7"

  local diffutils_version="$1"

  local diffutils_folder_name="diffutils-${diffutils_version}"
  local diffutils_archive="${diffutils_folder_name}.tar.xz"
  local diffutils_url="https://ftp.gnu.org/gnu/diffutils/${diffutils_archive}"

  local diffutils_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-diffutils-${diffutils_version}-installed"
  if [ ! -f "${diffutils_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${diffutils_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${diffutils_url}" "${diffutils_archive}" "${diffutils_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${diffutils_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${diffutils_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running diffutils configure..."

          bash "${SOURCES_FOLDER_PATH}/${diffutils_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${diffutils_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-diffutils-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-diffutils-output.txt"
      fi

      (
        echo
        echo "Running diffutils make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-diffutils-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/diff" --version
    )

    hash -r

    touch "${diffutils_stamp_file_path}"

  else
    echo "Component diffutils already installed."
  fi
}

function build_bison()
{
  # https://www.gnu.org/software/bison/
  # https://ftp.gnu.org/gnu/bison/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=bison-git

  # 2015-01-23, "3.0.4"
  # Crashes with Abort trap 6.
  # 2019-02-03, "3.3.2"

  local bison_version="$1"

  local bison_folder_name="bison-${bison_version}"
  local bison_archive="${bison_folder_name}.tar.xz"
  local bison_url="https://ftp.gnu.org/gnu/bison/${bison_archive}"

  local bison_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-bison-${bison_version}-installed"
  if [ ! -f "${bison_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${bison_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${bison_url}" "${bison_archive}" "${bison_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${bison_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${bison_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running bison configure..."

          bash "${SOURCES_FOLDER_PATH}/${bison_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${bison_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-bison-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-bison-output.txt"
      fi

      (
        echo
        echo "Running bison make..."

        # Build.
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-bison-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/bison" --version
    )

    hash -r

    touch "${bison_stamp_file_path}"

  else
    echo "Component bison already installed."
  fi
}

# Not functional, it requires libtoolize
function build_flex()
{
  # https://www.gnu.org/software/flex/
  # https://github.com/westes/flex/releases
  # https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz

  # Apple uses 2.5.3
  # May 6, 2017, "2.6.4"

  local flex_version="$1"

  local flex_folder_name="flex-${flex_version}"
  local flex_archive="${flex_folder_name}.tar.gz"
  local flex_url="ttps://github.com/westes/flex/releases/download/v${flex_version}/${flex_archive}"
  # local flex_url="https://github.com/westes/flex/releases/download/v${flex_version}/libs/${flex_archive}"

  local flex_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-flex-${flex_version}-installed"
  if [ ! -f "${flex_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${flex_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${flex_url}" "${flex_archive}" "${flex_folder_name}"

    (
      cd "${SOURCES_FOLDER_PATH}/${flex_folder_name}"
      if [ ! -x "configure" ]
      then
        bash ${DEBUG} "autogen.sh"
      fi
    )

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${flex_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${flex_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running flex configure..."

          bash "${SOURCES_FOLDER_PATH}/${flex_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${flex_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-flex-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-flex-output.txt"
      fi

      (
        echo
        echo "Running flex make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-flex-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/flex" --version
    )

    hash -r

    touch "${flex_stamp_file_path}"

  else
    echo "Component flex already installed."
  fi
}

function build_make()
{
  # https://www.gnu.org/software/make/
  # https://ftp.gnu.org/gnu/make/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=make-git

  # 2016-06-10, "4.2.1"

  local make_version="$1"

  local make_folder_name="make-${make_version}"
  local make_archive="${make_folder_name}.tar.bz2"
  local make_url="https://ftp.gnu.org/gnu/make/${make_archive}"

  local make_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-make-${make_version}-installed"
  if [ ! -f "${make_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${make_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${make_url}" "${make_archive}" "${make_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${make_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${make_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running make configure..."

          bash "${SOURCES_FOLDER_PATH}/${make_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${make_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --with-guile

          cp "config.log" "${LOGS_FOLDER_PATH}/config-make-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-make-output.txt"
      fi

      (
        echo
        echo "Running make make..."

        # Build.
        make -j ${JOBS}
        make install-strip

        echo
        echo "Linking gmake..."
        cd "${INSTALL_FOLDER_PATH}/bin"
        ln -s -v make gmake
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-make-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/make" --version
    )

    hash -r

    touch "${make_stamp_file_path}"

  else
    echo "Component make already installed."
  fi
}

function build_wget()
{
  # https://www.gnu.org/software/wget/
  # https://ftp.gnu.org/gnu/wget/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=wget-git

  # 2016-06-10, "1.19"
  # 2018-12-26, "1.20.1"

  local wget_version="$1"

  local wget_folder_name="wget-${wget_version}"
  local wget_archive="${wget_folder_name}.tar.gz"
  local wget_url="https://ftp.gnu.org/gnu/wget/${wget_archive}"

  local wget_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-wget-${wget_version}-installed"
  if [ ! -f "${wget_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${wget_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${wget_url}" "${wget_archive}" "${wget_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${wget_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${wget_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-implicit-function-declaration"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"
      export LIBS="-liconv"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running wget configure..."

          bash "${SOURCES_FOLDER_PATH}/${wget_folder_name}/configure" --help

          # libpsl is not available anyway.
          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${wget_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            --without-libpsl \
            --without-included-regex \
            --enable-nls \
            --enable-dependency-tracking \
            --with-ssl=gnutls \
            --with-metalink \
            --disable-debug \
            --disable-pcre \
            --disable-pcre2

          cp "config.log" "${LOGS_FOLDER_PATH}/config-wget-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-wget-output.txt"
      fi

      (
        echo
        echo "Running wget make..."

        # Build.
        # make -j ${JOBS}
        make
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-wget-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/wget" --version
    )

    hash -r

    touch "${wget_stamp_file_path}"

  else
    echo "Component wget already installed."
  fi
}

function build_texinfo()
{
  # https://www.gnu.org/software/texinfo/
  # https://ftp.gnu.org/gnu/texinfo/
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=texinfo-svn

  # 2017-09-12, "6.5"
  # 2019-02-16, "6.6"

  local texinfo_version="$1"

  local texinfo_folder_name="texinfo-${texinfo_version}"
  local texinfo_archive="${texinfo_folder_name}.tar.gz"
  local texinfo_url="https://ftp.gnu.org/gnu/texinfo/${texinfo_archive}"

  local texinfo_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-texinfo-${texinfo_version}-installed"
  if [ ! -f "${texinfo_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${texinfo_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${texinfo_url}" "${texinfo_archive}" "${texinfo_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${texinfo_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${texinfo_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running texinfo configure..."

          bash "${SOURCES_FOLDER_PATH}/${texinfo_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${texinfo_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-texinfo-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-texinfo-output.txt"
      fi

      (
        echo
        echo "Running texinfo make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-texinfo-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/texi2pdf" --version
    )

    hash -r

    touch "${texinfo_stamp_file_path}"

  else
    echo "Component texinfo already installed."
  fi
}

function build_cmake()
{
  # https://cmake.org
  # https://github.com/Kitware/CMake/releases/
  # https://github.com/Kitware/CMake/releases/download/v3.14.0/cmake-3.14.0.tar.gz
  # https://github.com/Kitware/CMake/releases/download/v3.13.4/cmake-3.13.4.tar.gz
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=cmake-git

  # November 10, 2017, "3.9.6"
  # November 2017, "3.10.1"

  local cmake_version="$1"

  local cmake_folder_name="cmake-${cmake_version}"
  local cmake_archive="${cmake_folder_name}.tar.gz"
  local cmake_url="https://github.com/Kitware/CMake/releases/download/v${cmake_version}/${cmake_archive}"

  local cmake_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-cmake-${cmake_version}-installed"
  if [ ! -f "${cmake_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${cmake_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${cmake_url}" "${cmake_archive}" "${cmake_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${cmake_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${cmake_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      export CC=clang
      export CXX=clang++

      local which_cmake="$(which cmake)"
      if [ -z "${which_cmake}" ]
      then
        if [ ! -d "Bootstrap.cmk" ]
        then
          (
            echo
            echo "Running cmake bootstrap..."

            bash "${SOURCES_FOLDER_PATH}/${cmake_folder_name}/bootstrap" --help || true

            bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${cmake_folder_name}/bootstrap" \
              --prefix="${INSTALL_FOLDER_PATH}"

            cp "Bootstrap.cmk/cmake_bootstrap.log" "${LOGS_FOLDER_PATH}/bootstrap-cmake-log.txt"
          ) 2>&1 | tee "${LOGS_FOLDER_PATH}/bootstrap-cmake-output.txt"
        fi
      else
          (
            echo
            echo "Running cmake cmake..."

            # If more verbosity is needed:
            #  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON

            # Use the existing cmake to configure this one.
            cmake \
              -DCMAKE_INSTALL_PREFIX="${INSTALL_FOLDER_PATH}" \
              "${SOURCES_FOLDER_PATH}/${cmake_folder_name}"

          ) 2>&1 | tee "${LOGS_FOLDER_PATH}/cmake-cmake-output.txt"
      fi

      (
        echo
        echo "Running cmake make..."

        # Build.
        # Parallel builds fail.
        # make -j ${JOBS}
        make
        # make install-strip
        make install

        strip -S "${INSTALL_FOLDER_PATH}/bin/cmake"

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-cmake-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/cmake" --version
    )

    hash -r

    touch "${cmake_stamp_file_path}"

  else
    echo "Component cmake already installed."
  fi
}

function build_perl()
{
  # https://www.cpan.org
  # http://www.cpan.org/src/
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/perl

  # 2017-09-22
  local perl_version_major="5.0"
  # local perl_version="5.26.1"
  # 2018-11-29

  local perl_version="$1"

  local perl_folder_name="perl-${perl_version}"
  local perl_archive="${perl_folder_name}.tar.gz"
  local perl_url="http://www.cpan.org/src/${perl_version_major}/${perl_archive}"

  local perl_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-perl-${perl_version}-installed"
  if [ ! -f "${perl_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${perl_folder_name}" ]
  then

    # In-source build.
    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${perl_url}" "${perl_archive}" "${perl_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${perl_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${perl_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-implicit-fallthrough -Wno-nonnull -Wno-format -Wno-sign-compare -Wno-null-pointer-arithmetic"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.h" ]
      then
        (
          echo
          echo "Running perl configure..."

          bash "./Configure" --help || true

          bash ${DEBUG} "./Configure" -d -e -s \
            -Dprefix="${INSTALL_FOLDER_PATH}" \
            -Dcc="${CC}" \
            -Dccflags="${CFLAGS}"

        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-perl-output.txt"
      fi

      (
        echo
        echo "Running perl make..."

        # Build.
        make -j ${JOBS}
        #
        # make -j1 test
        make install-strip

        # https://www.cpan.org/modules/INSTALL.html
        # cpan App::cpanminus

      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-perl-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/perl" --version
    )

    hash -r

    touch "${perl_stamp_file_path}"

  else
    echo "Component perl already installed."
  fi
}

function build_makedepend()
{
  # http://www.linuxfromscratch.org/blfs/view/7.4/x/makedepend.html
  # http://xorg.freedesktop.org/archive/individual/util/makedepend-1.0.5.tar.bz2

  local makedepend_version="$1"

  local makedepend_folder_name="makedepend-${makedepend_version}"
  local makedepend_archive="${makedepend_folder_name}.tar.bz2"
  local makedepend_url="http://xorg.freedesktop.org/archive/individual/util/${makedepend_archive}"


  local makedepend_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-makedepend-${makedepend_version}-installed"
  if [ ! -f "${makedepend_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${makedepend_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${makedepend_url}" "${makedepend_archive}" "${makedepend_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${makedepend_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${makedepend_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"
      export PKG_CONFIG_PATH="${INSTALL_FOLDER_PATH}/share/pkgconfig:${PKG_CONFIG_PATH}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running makedepend configure..."

          bash "${SOURCES_FOLDER_PATH}/${makedepend_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${makedepend_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-makedepend-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-makedepend-output.txt"
      fi

      (
        echo
        echo "Running makedepend make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-makedepend-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/makedepend" || true
    )

    hash -r

    touch "${makedepend_stamp_file_path}"

  else
    echo "Component makedepend already installed."
  fi
}

function build_patchelf()
{
  # https://nixos.org/patchelf.html
  # https://nixos.org/releases/patchelf/
  # https://nixos.org/releases/patchelf/patchelf-0.10/patchelf-0.10.tar.bz2

  # 2016-02-29, "0.9"
  # 2019-03-28, "0.10"

  local patchelf_version="$1"

  local patchelf_folder_name="patchelf-${patchelf_version}"
  local patchelf_archive="${patchelf_folder_name}.tar.bz2"
  local patchelf_url="https://nixos.org/releases/patchelf/${patchelf_folder_name}/${patchelf_archive}"

  local patchelf_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-patchelf-${patchelf_version}-installed"
  if [ ! -f "${patchelf_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${patchelf_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${patchelf_url}" "${patchelf_archive}" "${patchelf_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${patchelf_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${patchelf_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running patchelf configure..."

          bash "${SOURCES_FOLDER_PATH}/${patchelf_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${patchelf_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-patchelf-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-patchelf-output.txt"
      fi

      (
        echo
        echo "Running patchelf make..."

        # Build.
        make -j ${JOBS}
        make install-strip
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-patchelf-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/patchelf" --version
    )

    hash -r

    touch "${patchelf_stamp_file_path}"

  else
    echo "Component patchelf already installed."
  fi
}

function build_dos2unix()
{
  # https://waterlan.home.xs4all.nl/dos2unix.html
  # http://dos2unix.sourceforge.net
  # https://waterlan.home.xs4all.nl/dos2unix/dos2unix-7.4.0.tar.gz

  # 30-Oct-2017, "7.4.0"

  local dos2unix_version="$1"

  local dos2unix_folder_name="dos2unix-${dos2unix_version}"
  local dos2unix_archive="${dos2unix_folder_name}.tar.gz"
  local dos2unix_url="https://waterlan.home.xs4all.nl/dos2unix/${dos2unix_archive}"

  local dos2unix_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-dos2unix-${dos2unix_version}-installed"
  if [ ! -f "${dos2unix_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${dos2unix_folder_name}" ]
  then

    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${dos2unix_url}" "${dos2unix_archive}" "${dos2unix_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${dos2unix_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${dos2unix_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      (
        echo
        echo "Running dos2unix make..."

        # Build.
        make -j ${JOBS} prefix="${INSTALL_FOLDER_PATH}" ENABLE_NLS=
        make prefix="${INSTALL_FOLDER_PATH}" strip install
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-dos2unix-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/unix2dos" --version
    )

    hash -r

    touch "${dos2unix_stamp_file_path}"

  else
    echo "Component dos2unix already installed."
  fi
}

function build_git()
{
  # https://git-scm.com/
  # https://www.kernel.org/pub/software/scm/git/
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/git

  # 30-Oct-2017, "2.15.0"
  # 24-Feb-2019, "2.21.0"

  local git_version="$1"

  local git_folder_name="git-${git_version}"
  local git_archive="${git_folder_name}.tar.xz"
  local git_url="https://www.kernel.org/pub/software/scm/git/${git_archive}"

  local git_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-git-${git_version}-installed"
  if [ ! -f "${git_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${git_folder_name}" ]
  then

    # In-source build.
    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${git_url}" "${git_archive}" "${git_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${git_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${git_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running git configure..."

          bash "./configure" --help

          bash ${DEBUG} "./configure" \
            --prefix="${INSTALL_FOLDER_PATH}"

          cp "config.log" "${LOGS_FOLDER_PATH}/config-git-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-git-output.txt"
      fi

      (
        echo
        echo "Running git make..."

        # Build.
        # make -j ${JOBS}
        # Parallel build failed.
        make
        # make install-strip
        make install
        strip -S "${INSTALL_FOLDER_PATH}/bin/git"
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-git-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/git" --version
    )

    hash -r

    touch "${git_stamp_file_path}"

  else
    echo "Component git already installed."
  fi
}

function do_python()
{
  # https://www.python.org
  # https://www.python.org/downloads/source/
  # https://www.python.org/ftp/python/2.7.16/Python-2.7.16.tar.xz
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python2

  # 2017-09-16, "2.7.14"
  # March 4, 2019, "2.7.16"

  local python_version="$1"

  local python_folder_name="Python-${python_version}"
  local python_archive="${python_folder_name}.tar.xz"
  local python_url="https://www.python.org/ftp/python/${python_version}/${python_archive}"

  local python_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-python-${python_version}-installed"
  if [ ! -f "${python_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${python_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${python_url}" "${python_archive}" "${python_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${python_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${python_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-int-in-bool-context -Wno-maybe-uninitialized -Wno-nonnull -Wno-stringop-overflow"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      export CC=clang
      export CXX=clang++

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running python configure..."

          bash "${SOURCES_FOLDER_PATH}/${python_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${python_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --without-ensurepip

          cp "config.log" "${LOGS_FOLDER_PATH}/config-python-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-python-output.txt"
      fi

      (
        echo
        echo "Running python make..."

        # Build.
        make -j ${JOBS}
        # make install-strip
        make install

        # Install setuptools and pip. Be sure the new version is used.
        # https://packaging.python.org/tutorials/installing-packages/
        echo
        echo "Installing setuptools and pip..."
        "${INSTALL_FOLDER_PATH}/bin/python2" -m ensurepip --default-pip
        "${INSTALL_FOLDER_PATH}/bin/python2" -m pip install --upgrade pip setuptools wheel
        "${INSTALL_FOLDER_PATH}/bin/pip2" --version
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-python-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/python" --version
    )

    hash -r

    touch "${python_stamp_file_path}"

  else
    echo "Component python already installed."
  fi
}

function build_python3()
{
  # https://www.python.org
  # https://www.python.org/downloads/source/
  # https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tar.xz

  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python
  # https://git.archlinux.org/svntogit/packages.git/tree/trunk/PKGBUILD?h=packages/python-pip

  # 2018-12-24, "3.7.2"
  # March 25, 2019, "3.7.3"

  local python3_version="$1"

  local python3_folder_name="Python-${python3_version}"
  local python3_archive="${python3_folder_name}.tar.xz"
  local python3_url="https://www.python.org/ftp/python/${python3_version}/${python3_archive}"

  local python3_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-python3-${python3_version}-installed"
  if [ ! -f "${python3_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${python3_folder_name}" ]
  then

    cd "${SOURCES_FOLDER_PATH}"

    download_and_extract "${python3_url}" "${python3_archive}" "${python3_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${python3_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${python3_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS} -Wno-int-in-bool-context -Wno-maybe-uninitialized -Wno-nonnull -Wno-stringop-overflow"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      export CC=clang
      export CXX=clang++

      if [ ! -f "config.status" ]
      then
        (
          echo
          echo "Running python3 configure..."

          bash "${SOURCES_FOLDER_PATH}/${python3_folder_name}/configure" --help

          bash ${DEBUG} "${SOURCES_FOLDER_PATH}/${python3_folder_name}/configure" \
            --prefix="${INSTALL_FOLDER_PATH}" \
            \
            --without-ensurepip

          cp "config.log" "${LOGS_FOLDER_PATH}/config-python3-log.txt"
        ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-python3-output.txt"
      fi

      (
        echo
        echo "Running python3 make..."

        # Build.
        make -j ${JOBS}
        # make install-strip
        make install

        # Install setuptools and pip. Be sure the new version is used.
        # https://packaging.python.org/tutorials/installing-packages/
        echo
        echo "Installing setuptools and pip..."
        "${INSTALL_FOLDER_PATH}/bin/python3" -m ensurepip --default-pip
        "${INSTALL_FOLDER_PATH}/bin/python3" -m pip install --upgrade pip setuptools wheel
        "${INSTALL_FOLDER_PATH}/bin/pip3" --version
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-python3-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/python3" --version
    )

    hash -r

    touch "${python3_stamp_file_path}"

  else
    echo "Component python3 already installed."
  fi
}

function build_scons()
{
  # http://scons.org
  # https://sourceforge.net/projects/scons/files/scons/
  # https://sourceforge.net/projects/scons/files/scons/3.0.5/scons-3.0.5.tar.gz/download
  # https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=python2-scons

  # 2017-09-16, "3.0.1"
  # 2019-03-27, "3.0.5"

  local scons_version="$1"

  local scons_folder_name="scons-${scons_version}"
  local scons_archive="${scons_folder_name}.tar.gz"
  local scons_url="https://sourceforge.net/projects/scons/files/scons/${scons_version}/${scons_archive}"

  local scons_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-scons-${scons_version}-installed"
  if [ ! -f "${scons_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${scons_folder_name}" ]
  then

    # In-source build
    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${scons_url}" "${scons_archive}" "${scons_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${scons_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${scons_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      echo
      echo "Running scons install..."

      "${INSTALL_FOLDER_PATH}/bin/python" setup.py install \
      --prefix="${INSTALL_FOLDER_PATH}" \
      --optimize=1

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/install-scons-output.txt"

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/scons" --version
    )

    hash -r

    touch "${scons_stamp_file_path}"

  else
    echo "Component scons already installed."
  fi
}

function build_meson
{
  # http://mesonbuild.com/
  # https://pypi.org/project/meson/0.50.0/#description
  (
    xbb_activate_installed_bin

    pip3 install meson==$1

    "${INSTALL_FOLDER_PATH}/bin/meson" --version
  )

  hash -r
}

function build_ninja()
{
  # https://ninja-build.org
  # https://github.com/ninja-build/ninja/releases
  # https://github.com/ninja-build/ninja/archive/v1.9.0.zip
  # https://github.com/ninja-build/ninja/archive/v1.9.0.tar.gz

  # Jan 30, 2019 "1.9.0"

  local ninja_version="$1"

  local ninja_folder_name="ninja-${ninja_version}"
  local ninja_archive="v${ninja_version}.tar.gz"
  local ninja_url="https://github.com/ninja-build/ninja/archive/${ninja_archive}"

  local ninja_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-ninja-${ninja_version}-installed"
  if [ ! -f "${ninja_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${ninja_folder_name}" ]
  then

    # In-source build
    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${ninja_url}" "${ninja_archive}" "${ninja_folder_name}"

    (
      mkdir -p "${BUILD_FOLDER_PATH}/${ninja_folder_name}"
      cd "${BUILD_FOLDER_PATH}/${ninja_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      (
        echo
        echo "Running ninja bootstrap..."

        ./configure.py --help

        echo "Patience..."

        ./configure.py \
          --bootstrap \
          --verbose \
          --with-python=$(which python2)

        /usr/bin/install -m755 -c ninja "${INSTALL_FOLDER_PATH}/bin"
      ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-ninja-output.txt"
    )

    (
      xbb_activate_installed_bin

      echo
      "${INSTALL_FOLDER_PATH}/bin/ninja" --version
    )

    hash -r

    touch "${ninja_stamp_file_path}"

  else
    echo "Component ninja already installed."
  fi
}

function build_p7zip()
{
  # https://sourceforge.net/projects/p7zip/files/p7zip/16.02/p7zip_16.02_src_all.tar.bz2/download

  # "16.02"

  local p7zip_version="$1"

  local p7zip_folder_name="p7zip_${p7zip_version}"
  local p7zip_archive="${p7zip_folder_name}_src_all.tar.bz2"
  local p7zip_url="https://sourceforge.net/projects/p7zip/files/p7zip/${p7zip_version}/${p7zip_archive}"

  local p7zip_stamp_file_path="${STAMPS_FOLDER_PATH}/stamp-p7zip-${p7zip_version}-installed"
  if [ ! -f "${p7zip_stamp_file_path}" -o ! -d "${BUILD_FOLDER_PATH}/${p7zip_folder_name}" ]
  then

    cd "${BUILD_FOLDER_PATH}"

    download_and_extract "${p7zip_url}" "${p7zip_archive}" "${p7zip_folder_name}"

    (
      cd "${BUILD_FOLDER_PATH}/${p7zip_folder_name}"

      xbb_activate
      xbb_activate_installed_bin
      xbb_activate_installed_dev

      export CPPFLAGS="${XBB_CPPFLAGS}"
      export CFLAGS="${XBB_CFLAGS}"
      export CXXFLAGS="${XBB_CXXFLAGS}"
      export LDFLAGS="${XBB_LDFLAGS_APP}"

      echo
      echo "Running p7zip make..."


      # Override the hard-coded gcc & g++.
      sed -i -e "s|CXX=g++.*|CXX=${CXX}|" makefile.machine
      sed -i -e "s|CC=gcc.*|CC=${CC}|" makefile.machine

      # Do not override the environment variables, append to them.
      sed -i -e "s|CFLAGS=|CFLAGS+=|" makefile.glb
      sed -i -e "s|CXXFLAGS=|CXXFLAGS+=|" makefile.glb

      # 7z cannot load library on macOS.
      make -j1 test

      ls -lL bin

      # Override the hard-coded '/usr/local'.
      sed -i -e "s|DEST_HOME=/usr/local|DEST_HOME=${INSTALL_FOLDER_PATH}|" install.sh

      bash install.sh
    )

    (
      xbb_activate_installed_bin

      echo
      "${XBB_FOLDER}/bin/7za" --help
    )

    hash -r

    touch "${p7zip_stamp_file_path}"

  else
    echo "Component p7zip already installed."
  fi
}

# -----------------------------------------------------------------------------
