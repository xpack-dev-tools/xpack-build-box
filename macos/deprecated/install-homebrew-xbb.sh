#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# DEPRECATED! Use `build-xbb.sh` instead.

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

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# This script installs the macOS XBB (xPack Build Box) using Homebrew tools.
# The challenge is to lock all tools to a specific version. Since Homebrew
# does not allow to explicitly install a specific version of a package,
# the workaround is to revert to a specific date which is known to have
# functional packages.
# This is done by checking out a specific commit id from the homebrew-core
# repository.
# There is still no guarantee that this works, but no better solution
# was identified.
# Another complication is caused by brew insisting on updating itself to the
# latest version, which is not guaranteed to work with the old formulas.
# To prevent this it is mandatory to define HOMEBREW_NO_AUTO_UPDATE in the
# environment before calling brew.

# -----------------------------------------------------------------------------

# Definitions.

XBB_FOLDER=${XBB_FOLDER:-"${HOME}/opt/homebrew/xbb"}

macos_version=$(defaults read loginwindow SystemVersionStampAsString)
xcode_version=$(xcodebuild -version | grep Xcode | sed -e 's/Xcode //')
xclt_version=$(xcode-select --version | sed -e 's/xcode-select version \([0-9]*\)\./\1/')
echo "macOS version ${macos_version}"
echo "Xcode version ${xcode_version}"
echo "XCode Command Line Tools version ${xclt_version}"

brew_git_url="https://github.com/Homebrew/brew.git"
homebrew_core_git_url="https://github.com/Homebrew/homebrew-core.git"

install_gcc="y"
install_perl="y"
install_qemu_libs=""

use_master_archive=""

# 2.x releases support only:
# - Mojave (10.14)
# - High-sierra (10.13)
# - Sierra (10.12)

# No longer supported (since 2.0.0, 1 February 2019 at 16:22:17 EET)
# - El Capitan (10.11)
# - Yosemite (10.10) <- !
# - Mavericks (10.9)

if [[ "${macos_version}" =~ 10\.13\.* ]]
then
  # fails in gawk
  # 17 February 2019 at 14:59:18 EET, 117c24f4b6294e037431d3a850ced6955d53e26f
  # brew_git_commit_id="2.0.2"
  # 22 February 2019 at 13:56:00 EET
  # homebrew_core_git_commit_id="d85a6e77835a964adba81b90fc508f0f672bb974"

  # Error: undefined method `strip' for :provided_until_xcode43:Symbol
  # 24 January 2019 at 11:24:36 EET, 6a912c369125caca5e1e3929e942bbb946ce6367
  # brew_git_commit_id="1.9.3"
  # 24 January 2018 at 10:09:12 EET
  # homebrew_core_git_commit_id="dcb056fc8533ebf1edbc0b600712ebbd5bd476ac"

  # Error: Calling needs :cxx11 is disabled! There is no replacement.
  # 17 February 2019 at 14:59:18 EET, 117c24f4b6294e037431d3a850ced6955d53e26f
  # brew_git_commit_id="2.0.2"
  # 24 January 2018 at 10:09:12 EET
  # homebrew_core_git_commit_id="dcb056fc8533ebf1edbc0b600712ebbd5bd476ac"

  # Latest now.
  # 22 February 2019 at 17:56:50 EET, 2f056da40c1c98398eaed272bd2f85cd9156cdc4
  brew_git_commit_id="2f056da40c1c98398eaed272bd2f85cd9156cdc4"
  # 22 February 2019 at 13:56:00 EET
  homebrew_core_git_commit_id="d85a6e77835a964adba81b90fc508f0f672bb974"

  install_perl="n"
elif [[ "${macos_version}" =~ 10\.10\.* ]]
then
  # 24 January 2019 at 11:24:36, 6a912c369125caca5e1e3929e942bbb946ce6367, 1.9.3
  brew_git_commit_id="1.9.3"
  # 24 January 2018 at 10:09:12 EET
  homebrew_core_git_commit_id="dcb056fc8533ebf1edbc0b600712ebbd5bd476ac"
fi

# ---
  # brew_git_url="https://github.com/Homebrew/brew.git"
  # Fails with :cxx is disabled! There is no replacement.
  # brew_git_commit_id="2.0.1"

  # Fails on macOS 10.13, was ok on 10.10
  # Error: Your Xcode (1) is too outdated.
  # Please update to Xcode 9.2 (or delete it).
  # brew_git_commit_id="1.5.4"

  # Fails with:
  # Error: undefined method `strip' for :provided_until_xcode43:Symbol
  # brew_git_commit_id="1.9.3"
  # 24 January 2019 at 11:24:36, 6a912c369125caca5e1e3929e942bbb946ce6367, 1.9.3

  # 28 Mar 2018: 0141aa62b0a8d9043ec6d6a5b0890b7908924f79
  # 24 January 2018 at 10:09:12, dcb056fc8533ebf1edbc0b600712ebbd5bd476ac (1.9.3)
  # 15 Feb 2018: 39e72cdec0cadefbdf17bccea59f7f23b5837639

  # homebrew_core_git_url="https://github.com/Homebrew/homebrew-core.git"
  # The current production macOS XBB uses the 15 Feb 2018 formulas.
  # homebrew_core_git_commit_id="39e72cdec0cadefbdf17bccea59f7f23b5837639"
  # homebrew_core_git_commit_id="dcb056fc8533ebf1edbc0b600712ebbd5bd476ac"
# ---


# -----------------------------------------------------------------------------
# Check if brew is in the bath. This is not good, since it does not
# guarantee the use of the XBB specific versions.

set +e
which_brew=$(which brew)
if [ ! -z "${which_brew}" ]
then
  echo
  echo "'${which_brew}' found in PATH."
  echo "Remove '$(dirname ${which_brew})' from PATH and try again..."
  exit 1
fi
set -e

# -----------------------------------------------------------------------------

echo
if [ -d "${XBB_FOLDER}" ]
then
  echo "Renaming existing '${XBB_FOLDER}' -> '${XBB_FOLDER}.bak'..."
  rm -rf "${XBB_FOLDER}.bak"
  mv "${XBB_FOLDER}" "${XBB_FOLDER}.bak"
fi

echo "Creating '${XBB_FOLDER}'..."
mkdir -p "${XBB_FOLDER}"

PATH=${XBB_FOLDER}/bin:${PATH}

# -----------------------------------------------------------------------------
# Install the Homebrew tools.


# Run in a subshell to isolate the homebrew install from the packages install.
if [ "${use_master_archive}" == "y" ]
then
  brew_master_url=https://github.com/Homebrew/brew/tarball/master

  echo
  echo "Downloading and unpacking Homebrew/brew..."
  bash -c "(curl -L ${brew_master_url} | tar -x --strip 1 -C "${XBB_FOLDER}" -f -)"
else
  # brew_git_commit_id="1.5.4"
  folder_name="$(basename "${XBB_FOLDER}")"

  cd "$(dirname "${XBB_FOLDER}")"

  echo
  echo "Cloning Homebrew/brew..."
  git clone ${brew_git_url} "${folder_name}"

  cd "${folder_name}"
  git checkout -b xbb ${brew_git_commit_id}

  cd "${XBB_FOLDER}"
  mkdir -p Library/Taps/homebrew
  cd Library/Taps/homebrew

  echo
  echo "Cloning Homebrew/homebrew-core..."
  git clone ${homebrew_core_git_url} homebrew-core

  cd homebrew-core

  echo
  echo "Checking out ${homebrew_core_git_commit_id}"
  git checkout -b xbb ${homebrew_core_git_commit_id}

fi

export HOMEBREW_NO_EMOJI=1
export HOMEBREW_NO_AUTO_UPDATE=1

cd "${script_folder_path}"

echo
brew config

brew --version

# -----------------------------------------------------------------------------
# Install the XBB required packages.

echo
echo "Installing..."

# This is generally the most complicated package, if it does not pass it is
# useless to install all other packages.
if [ "$install_gcc" == "y" ]
then
  # Must be updated after xcode updates, to match the new location of
  # system headers, otherwise builds fail complaining about cpp problems.
  brew install gcc@7
fi

if true
then

  brew install curl
  brew link curl --force

  brew install autoconf automake
  brew install cmake
  brew install pkg-config

  # Required by QEMU
  brew install gettext
  brew link gettext --force

  # makeinfo required to build openOCD & QEMU manuals.
  brew install texinfo
  brew link texinfo --force

  # libtool required to build openOCD (bootstrap)
  brew install libtool

  brew install readline
  brew link readline --force

  # gawk & gsed required by GCC
  brew install gawk
  brew install gnu-sed

  # Same packages as for CentOS XBB (missing 'patch')

  # On recent versions perl fails a test; skip it if necessary.
  if [ "$install_perl" == "y" ]
  then
    brew install perl
  fi

  brew install git
  brew install python python@3

  brew install flex
  brew link flex --force

  brew install dos2unix
  brew install wget
  brew install make
  brew install diffutils

  brew install m4
  brew link m4 --force

  brew install bison
  brew link bison --force

  brew install gpatch

  brew install sqlite
  brew link sqlite --force

  brew install openssl
  brew link openssl --force

  brew install gnu-tar
  brew install xz

  brew install gdb

  # To build the µOS++ reference pages
  brew install doxygen

fi

if false
then
  # Needed when the separate gcc-7.2.0 patched is addded.
  brew install gmp
  brew install isl
  brew install libmpc
  brew install mpfr
fi

if [ "${install_qemu_libs}" == "y" ]
then
  # Normally not needed, since the build scripts compile them too.
  brew install \
    libpng \
    jpeg \
    sdl2 \
    sdl2_image \
    pixman \
    glib \
    libffi \
    libxml2 \
    libiconv \

  brew link libxml2 --force
  brew link libffi --force
  brew link libiconv --force

  brew list --versions \
    libpng \
    jpeg \
    sdl2 \
    sdl2_image \
    pixman \
    glib \
    libffi \
    libxml2 \
    libiconv \

fi

echo
brew config

# -----------------------------------------------------------------------------

# To use Homebrew, add something like this to ~/.profile
echo
echo alias axbb=\'export PATH=${XBB_FOLDER}/bin:\${PATH}; export HOMEBREW_NO_AUTO_UPDATE=1\'

if [ "$install_gcc" != "y" ]
then
  echo
  echo "Don't forget to run install-patched-gcc.sh to install a patched GCC 7.2.0."
fi

if [ -f ~/.gdbinit ]
then
  echo cat ~/.gdbinit
  cat ~/.gdbinit
else
  echo "No .gdbinit, creating one."
  touch ~/.gdbinit
fi
echo 'echo "set startup-with-shell off" >> ~/.gdbinit'
echo 'To codesign gdb: https://sourceware.org/gdb/wiki/BuildingOnDarwin'

# -----------------------------------------------------------------------------

# Warning: to use some of the tools with the usual names (like make instead
# of gmake) it is necessary to add extra folders to the PATH, like
# .../opt/make/libexec/gnubin

