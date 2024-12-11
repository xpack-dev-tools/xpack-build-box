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

# =============================================================================

helper_folder_path="${script_folder_path}/helper"

source "${helper_folder_path}/common-functions-source.sh"
source "${helper_folder_path}/common-docker-functions-source.sh"

# -----------------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

echo
env | sort
unset TERM

# -----------------------------------------------------------------------------

if is_intel
then
  docker_replace_source_list "http://archive.ubuntu.com/ubuntu/" "bionic"
elif is_arm
then
  docker_replace_source_list "http://ports.ubuntu.com/ubuntu-ports/" "bionic"
fi

# -----------------------------------------------------------------------------

if is_aarch64
then
  run_verbose dpkg --add-architecture armhf
fi

run_verbose apt-get update

# -----------------------------------------------------------------------------

# https://www.thomas-krenn.com/en/wiki/Configure_Locales_in_Ubuntu
run_verbose apt-get install --yes locales
run_verbose locale-gen en_US.UTF-8
run_verbose update-locale LANG=en_US.UTF-8

# Must be passed as `ENV TZ=UTC` in Dockerfile.
# export TZ=UTC
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

run_verbose apt-get --yes install tzdata

# -----------------------------------------------------------------------------

# Replaced by source build.
# python3 \
# python3-pip \

# Keep it to a minimum.
run_verbose apt-get -qq install -y \
\
autoconf \
automake \
bison \
bzip2 \
build-essential \
ca-certificates \
coreutils \
cpio \
curl \
diffutils \
dos2unix \
file \
flex \
gawk \
gettext \
git \
gzip \
help2man \
libatomic1 \
libc6-dev \
libtool \
linux-headers-generic \
lsb-release \
m4 \
make \
patch \
perl \
pkg-config \
python \
re2c \
rhash \
rsync \
systemd \
tar \
tcl \
texinfo \
time \
unzip \
wget \
xz-utils \
zip \
zlib1g-dev

if is_intel
then
  run_verbose apt-get install --yes g++-multilib
elif is_aarch64
then
  run_verbose apt-get install --yes \
    crossbuild-essential-armhf \
    libc6:armhf \
    libstdc++6:armhf
fi

# For QEMU
run_verbose apt-get install --yes \
libx11-dev \
libxext-dev \
mesa-common-dev

# For QEMU & OpenOCD
run_verbose apt-get install --yes \
libudev-dev

# -----------------------------------------------------------------------------
# Build Python3 from sources.

# build-essential wget pkg-config - already installed

run_verbose apt-get install --yes zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev

mkdir -pv ~/Work/python3
cd ~/Work/python3

# Keep in sync with the version installed on macOS.
PYTHON_VERSION="3.11.4"

run_verbose curl -L https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz -o Python-${PYTHON_VERSION}.tgz
run_verbose tar -xf Python-${PYTHON_VERSION}.tgz

cd Python-${PYTHON_VERSION}/
run_verbose ./configure --enable-optimizations

run_verbose make -j $(nproc)
run_verbose make install

hash -r

run_verbose python3 --version

echo "[curl -sS https://bootstrap.pypa.io/get-pip.py | python3]"
curl -sS https://bootstrap.pypa.io/get-pip.py | python3

run_verbose pip3 --version
run_verbose pip3 list

# Cleanups.
rm -rf ~/Work/python3

# Try to avoid leaking development packages into the final image.
run_verbose apt-get remove --yes build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev

run_verbose apt-get autoremove --yes

# -----------------------------------------------------------------------------

echo
echo "Container done."

# -----------------------------------------------------------------------------
