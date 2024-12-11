# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2020 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# Common functions used for building the XBB environments.

# =============================================================================

function host_init_docker_env()
{
  WORK_FOLDER_PATH="${HOME}/Work"
  CACHE_FOLDER_PATH="${WORK_FOLDER_PATH}/cache"

  docker system prune -f

  if [ "$(uname)" == "Linux" ]
  then
    NPROC=$(nproc)
  elif [ "$(uname)" == "Darwin" ]
  then
    NPROC=$(sysctl hw.ncpu | sed 's/hw.ncpu: //')
  fi

  export NPROC

  cd "${script_folder_path}"
}

function host_init_docker_input()
{
  local input_folder_name="input-${distro}-${release}-${arch}"
  rm -rf "${script_folder_path}/${input_folder_name}"
  mkdir -pv "${script_folder_path}/${input_folder_name}/helper/patches"

  if [ -d "${script_folder_path}/container-scripts" ]
  then
    ln -v "${script_folder_path}/container-scripts"/*.sh "${script_folder_path}/${input_folder_name}"
  fi

  # Using hard links simplifies development, since edits will no longer
  # need to be propagated back.

  # Hard link the entire content of the helper folder.
  ln -v "${helper_folder_path}"/*.sh "${script_folder_path}/${input_folder_name}/helper"
  ln -v "${helper_folder_path}"/pkg-config-verbose "${script_folder_path}/${input_folder_name}/helper"

  ln -v "${helper_folder_path}/patches"/*.patch "${script_folder_path}/${input_folder_name}/helper/patches"

  # Possibly hard link additional files.
  while [ $# -gt 0 ]
  do
    if [ -f "$1" ]
    then
      ln -v "$1" "${script_folder_path}/${input_folder_name}/helper"
    elif [ -d "$1" ]
    then
      local subfolder=$(basename "$1")
      mkdir -pv "${script_folder_path}/${input_folder_name}/helper/${subfolder}"
      ln -v "$1"/* "${script_folder_path}/${input_folder_name}/helper/${subfolder}"
    fi

    shift
  done
}

function host_clean_docker_input()
{
  rm -rf "${script_folder_path}/input"
}

function host_run_docker_it_with_volume()
{
  # Warning: do not use HOST_MACHINE!
  local input_folder_name="input-${distro}-${release}-${arch}"
  local output_folder_name="${HOME}/opt/${layer}-${distro}-${release}-${arch}"
  mkdir -pv "${output_folder_name}"

  echo
  echo "Running parent Docker image ${from}..."

  if [[ "${layer}" == "xbb-bootstrap" ]]
  then
    run_verbose docker run \
      --interactive \
      --tty \
      --hostname "${layer}-${arch}" \
      --workdir="/root" \
      --env DEBUG="${DEBUG}" \
      --env JOBS="${JOBS:-${NPROC}}" \
      --env XBB_VERSION="${version}" \
      --env XBB_LAYER="${layer}" \
      --env RUN_LONG_TESTS="${RUN_LONG_TESTS:-""}" \
      --volume="${WORK_FOLDER_PATH}:/root/Work" \
      --volume="${script_folder_path}/${input_folder_name}:/input" \
      --volume="${output_folder_name}:/opt/${layer}" \
      ${from}
  elif [[ "${layer}" == "xbb" ]]
  then
    bootstrap_path="${HOME}/opt/${layer}-bootstrap-${distro}-${release}-${arch}"
    if [ ! -d "${bootstrap_path}" ]
    then
      echo "Missing bootstrap folder ${bootstrap_path}."
      exit 1
    fi

    run_verbose docker run \
      --interactive \
      --tty \
      --hostname "${layer}-${arch}" \
      --workdir="/root" \
      --env DEBUG="${DEBUG}" \
      --env JOBS="${JOBS:-${NPROC}}" \
      --env XBB_VERSION="${version}" \
      --env XBB_LAYER="${layer}" \
      --env RUN_LONG_TESTS="${RUN_LONG_TESTS:-""}" \
      --volume="${WORK_FOLDER_PATH}:/root/Work" \
      --volume="${script_folder_path}/${input_folder_name}:/input" \
      --volume="${output_folder_name}:/opt/${layer}" \
      --volume="${bootstrap_path}:/opt/${layer}-bootstrap" \
      ${from}
  fi
}

function host_run_docker_it_with_image()
{
  # Warning: do not use HOST_MACHINE!
  local output_folder_name="${HOME}/opt/${layer}-${distro}-${release}-${arch}"
  mkdir -pv "${output_folder_name}"

  local input_folder_name="input-${distro}-${release}-${arch}"

  echo
  echo "Running parent Docker image ${from}..."

  run_verbose docker run \
    --interactive \
    --tty \
    --hostname "${layer}-${arch}" \
    --workdir="/root" \
    --env DEBUG="${DEBUG}" \
    --env JOBS="${JOBS:-${NPROC}}" \
    --env XBB_VERSION="${version}" \
    --env XBB_LAYER="${layer}" \
    --env RUN_LONG_TESTS="${RUN_LONG_TESTS:-""}" \
    --volume="${WORK_FOLDER_PATH}:/root/Work" \
    --volume="${script_folder_path}/${input_folder_name}:/input" \
    --volume="${output_folder_name}:/opt/${layer}" \
    ${from}
}

function host_run_docker_build()
{
  local version="$1"
  local tag="$2"
  local dockerfile="$3"
  local layer="$4"

  set +e
  run_verbose docker rmi "${tag}"
  set -e

  echo
  echo "Building Docker image ${tag}..."
  run_verbose docker build \
    --build-arg DEBUG="${DEBUG}" \
    --build-arg JOBS="${JOBS:-${NPROC}}" \
    --build-arg XBB_VERSION="${version}" \
    --build-arg XBB_LAYER="${layer}" \
    --build-arg RUN_LONG_TESTS="${RUN_LONG_TESTS:-""}" \
    --no-cache \
    --progress plain \
    --tag "${tag}" \
    --file "${dockerfile}" \
    .
}

# =============================================================================

function xbb_activate()
{
  :
}

# =============================================================================

# Used in tex images.
function docker_prepare_env()
{
  if [ ! -d "${WORK_FOLDER_PATH}" ]
  then
    mkdir -pv "${WORK_FOLDER_PATH}"
    touch "${WORK_FOLDER_PATH}/.dockerenv"
  fi

  # The place where files are downloaded.
  CACHE_FOLDER_PATH="${WORK_FOLDER_PATH}/cache"

  # ---------------------------------------------------------------------------

  # Make all tools choose gcc, not the old cc.
  # Redefined more elaborately.
  export CC=gcc
  export CXX=g++

  export CACHE_FOLDER_PATH

  echo
  echo "docker env..."
  env | sort
}

function docker_download_rootfs()
{
  local archive_name="$1"

  # No trailing slash.
  download "https://github.com/xpack/xpack-build-box/releases/download/rootfs/${archive_name}" "${archive_name}"
}

# =============================================================================

function docker_build_from_archive()
{
  if [ $# -lt 5 ]
  then
    echo "docker_build_from_archive needs 5 params"
    exit 1
  fi

  arch="$1"
  distro="$2"
  release="$3"
  archive_name="$4"
  tag="$5"

  local input_folder_name="input-${distro}-${release}-${arch}"

  docker_download_rootfs "${archive_name}"

  # Assume "input" was created by init_input().
  cp -v "${CACHE_FOLDER_PATH}/${archive_name}" "${input_folder_name}"

  echo
  echo "Building Docker image ${tag}..."
  docker build --tag "${tag}" -f "${arch}-Dockerfile" --no-cache --progress plain .
}

function docker_build_from_hub()
{
  if [ $# -lt 2 ]
  then
    echo "docker_build_from_hub needs 2 params"
    exit 1
  fi

  arch="$1"
  tag="$2"

  echo
  echo "Building Docker image ${tag}..."
  docker build --tag "${tag}" -f "${arch}-Dockerfile" --no-cache --progress plain .
}

# =============================================================================

function docker_replace_source_list()
{
  local url=$1
  local name=$2

  echo
  echo "The orginal /etc/apt/sources.list"
  cat "/etc/apt/sources.list"
  echo "---"

  # -----------------------------------------------------------------------------

  echo "Creating new sources.list..."

# Note: __EOF__ is not quoted to allow substitutions here.
cat <<__EOF__  >"/etc/apt/sources.list"
# https://help.ubuntu.com/community/Repositories/Ubuntu
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.

deb ${url} ${name} main restricted
# deb-src ${url} ${name} main restricted
deb ${url} ${name}-security main restricted
# deb-src ${url} ${name}-security main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb ${url} ${name}-updates main restricted
# deb-src ${url} ${name}-updates main restricted

deb ${url} ${name}-backports main restricted
# deb-src ${url} ${name}-backports main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb ${url} ${name} universe
# deb-src ${url} ${name} universe
deb ${url} ${name}-security universe
# deb-src ${url} ${name}-security universe

deb ${url} ${name}-updates universe
# deb-src ${url} ${name}-updates universe

deb ${url} ${name}-backports universe
# deb-src ${url} ${name}-backports universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb ${url} ${name} multiverse
# deb-src ${url} ${name} multiverse
deb ${url} ${name}-security multiverse
# deb-src ${url} ${name}-security multiverse

deb ${url} ${name}-updates multiverse
# deb-src ${url} ${name}-updates multiverse

deb ${url} ${name}-backports multiverse
# deb-src ${url} ${name}-backports multiverse
__EOF__

  echo
  echo "The resulting /etc/apt/sources.list"
  cat "/etc/apt/sources.list" | egrep '^deb '
  echo "---"

  apt-get update
  apt-get upgrade --yes

  apt-get install --yes lsb-release

  # ---------------------------------------------------------------------------

  apt-get clean
  apt-get autoclean
  apt-get autoremove

  # ---------------------------------------------------------------------------

  echo
  uname -a
  lsb_release -a
}


function ubuntu_install_develop()
{
  # lsb_release must be present from upgrade.
  local release="$(lsb_release -r | sed 's/Release:[^0-9]*//')"
  local release_major=$(echo ${release} | sed -e 's|\([0-9][0-9]*\)\.[0-9].*|\1|')

  local machine="$(uname -m)"

  # ---------------------------------------------------------------------------

  echo "docker env..."
  env | sort
  # Be sure no tool will senter a curses mode.
  unset TERM

  # These tools should be enough to build the bootstrap tools.

  run_verbose apt-get update

  run_verbose apt-get install --yes \
    \
    autoconf \
    automake \
    bison \
    bzip2 \
    ca-certificates \
    cmake \
    cpio \
    curl \
    diffutils \
    file \
    flex \
    gawk \
    gcc g++ \
    gcc-8 g++-8 \
    gettext \
    git \
    libc6-dev \
    libtool \
    m4 \
    make \
    patch \
    perl \
    pkg-config \
    python \
    python3 \
    python3-pip \
    re2c \
    rhash \
    rsync \
    tcl \
    time \
    unzip \
    wget \
    xz-utils \
    zip \
    zlib1g-dev \

  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8

  # Without it, building GCC on Arm 32-bit fails.
  # https://askubuntu.com/questions/1202249/c-compilng-failed
  if [ "${machine}" == "armv8l" -o "${machine}" == "armv7l" ]
  then
    run_verbose apt-get install --yes g++-multilib g++-8-multilib
  fi

  # libtool-bin - not present in precise

  # For QEMU
  run_verbose apt-get install --yes \
    libx11-dev \
    libxext-dev \
    mesa-common-dev \

  # For QEMU & OpenOCD
  run_verbose apt-get install --yes \
    libudev-dev

  # From  (universe)
  run_verbose apt-get install --yes \
    texinfo \
    help2man \

  # Not available on Ubuntu 16.
  run_verbose apt-get install --yes dos2unix

  # ---------------------------------------------------------------------------

  # For add-apt-repository
  run_verbose apt-get install --yes software-properties-common

  # run_verbose add-apt-repository --yes ppa:ubuntu-toolchain-r/test
  run_verbose add-apt-repository --yes ppa:openjdk-r/ppa

  run_verbose apt-get update

  # 7.5.0
  run_verbose gcc --version

  run_verbose apt-get install --yes gdb

  if [ "${machine}" == "x86_64" ]
  then
    run_verbose apt-get install --yes mingw-w64 wine64
  fi

  # ---------------------------------------------------------------------------

  run_verbose apt-get install --yes openjdk-11-jdk

  run_verbose apt-get install --yes ant

  # maven not available in Ubuntu 14, and not needed so far.
  # apt-get install --yes maven

  # ---------------------------------------------------------------------------

  run_verbose apt-get install --yes texlive

  # ---------------------------------------------------------------------------

  echo
  uname -a
  lsb_release -a

  ant -version
  autoconf --version
  bison --version
  cmake --version
  curl --version
  flex --version
  g++ --version
  gawk --version
  gdb --version
  git --version
  java -version
  m4 --version
  # mvn -version
  make --version
  patch --version
  perl --version
  pkg-config --version
  python --version
  python3 --version

}

function ubuntu_clean()
{
  apt-get clean --yes
  apt-get autoclean --yes
  apt-get autoremove --yes
}

# =============================================================================


function debian_install_develop()
{
  # lsb_release must be present from upgrade.
  local release="$(lsb_release -r | sed 's/Release:[^0-9]*//')"
  local release_major=$(echo ${release} | sed -e 's|\([0-9][0-9]*\)\.[0-9].*|\1|')

  local machine="$(uname -m)"

  # ---------------------------------------------------------------------------

  echo "docker env..."
  env | sort
  # Be sure no tool will senter a curses mode.
  unset TERM

  # These tools should be enough to build the bootstrap tools.

  run_verbose apt-get update

  run_verbose apt-get install --yes \
    \
    autoconf \
    automake \
    bison \
    bzip2 \
    ca-certificates \
    cmake \
    cpio \
    curl \
    diffutils \
    file \
    flex \
    gawk \
    gcc g++ \
    gcc-8 g++-8 \
    gettext \
    git \
    libc6-dev \
    libtool \
    m4 \
    make \
    patch \
    perl \
    pkg-config \
    python \
    python3 \
    python3-pip \
    re2c \
    rhash \
    rsync \
    tcl \
    time \
    unzip \
    wget \
    xz-utils \
    zip \
    zlib1g-dev \

  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8

  # Without it, building GCC on Arm 32-bit fails.
  # https://askubuntu.com/questions/1202249/c-compilng-failed
  if [ "${machine}" == "armv8l" -o "${machine}" == "armv7l" ]
  then
    run_verbose apt-get install --yes g++-multilib g++-8-multilib
  fi

  # libtool-bin - not present in precise

  # For QEMU
  run_verbose apt-get install --yes \
    libx11-dev \
    libxext-dev \
    mesa-common-dev \

  # For QEMU & OpenOCD
  run_verbose apt-get install --yes \
    libudev-dev

  # From  (universe)
  run_verbose apt-get install --yes \
    texinfo \
    help2man \

  # Not available on Ubuntu 16.
  run_verbose apt-get install --yes dos2unix

  # ---------------------------------------------------------------------------

  # For add-apt-repository
  run_verbose apt-get install --yes software-properties-common

  # run_verbose add-apt-repository --yes ppa:ubuntu-toolchain-r/test
  run_verbose add-apt-repository --yes ppa:openjdk-r/ppa

  run_verbose apt-get update

  # 7.5.0
  run_verbose gcc --version

  run_verbose apt-get install --yes gdb

  if [ "${machine}" == "x86_64" ]
  then
    run_verbose apt-get install --yes mingw-w64 wine64
  fi

  # ---------------------------------------------------------------------------

  run_verbose apt-get install --yes openjdk-11-jdk

  run_verbose apt-get install --yes ant

  # maven not available in Ubuntu 14, and not needed so far.
  # apt-get install --yes maven

  # ---------------------------------------------------------------------------

  run_verbose apt-get install --yes texlive

  # ---------------------------------------------------------------------------

  echo
  uname -a
  lsb_release -a

  ant -version
  autoconf --version
  bison --version
  cmake --version
  curl --version
  flex --version
  g++ --version
  gawk --version
  gdb --version
  git --version
  java -version
  m4 --version
  # mvn -version
  make --version
  patch --version
  perl --version
  pkg-config --version
  python --version
  python3 --version

}

function debian_clean()
{
  apt-get clean --yes
  apt-get autoclean --yes
  apt-get autoremove --yes
}

# =============================================================================

# yum search packpattern
# yum provides file
# repoquery -l <packname>

function centos_install_develop()
{
  run_verbose yum -y install \
  \
  autoconf \
  automake \
  bison \
  bzip2 \
  ca-certificates \
  cmake \
  coreutils \
  cpio \
  curl \
  diffutils \
  dos2unix \
  file \
  flex \
  gawk \
  gcc \
  gcc-c++ \
  gcc-gfortran \
  gdb \
  gettext \
  git \
  libtool \
  redhat-lsb-core \
  m4 \
  make \
  patch \
  perl \
  pkg-config \
  python \
  python3 \
  rsync \
  tcl \
  time \
  unzip \
  which \
  wget \
  xz \
  zip \
  zlib-devel \

  # For QEMU
  run_verbose yum -y install \
  libX11-devel \
  libXext-devel \
  mesa-libGL-devel \

  # For QEMU & OpenOCD (libudev-dev)
  run_verbose yum -y install systemd-devel

  run_verbose yum -y install \
  texinfo \
  help2man \

  # Java
  run_verbose yum -y install \
  java-1.8.0-openjdk \
  java-11-openjdk-devel \
  ant \
  maven \

  # Configure Java 11 as default.
  echo 2 | update-alternatives --config java
  echo 2 | update-alternatives --config javac

  # Without it, building GCC on Arm 32-bit fails.
  # https://askubuntu.com/questions/1202249/c-compilng-failed
  if [ "${machine}" == "armv8l" -o "${machine}" == "armv7l" ]
  then
    : # yum -y install glibc-devel.aarch64 libstdc++-devel.aarch64
  fi

  # Ubuntu packages not available on CentOS.
  # libc6-dev re2c rhash g++-multilib
  # locales
  # gcc-6

  # Not usable.
  # /opt/rh/devtoolset-8/root/bin/
  # run_verbose yum -y install centos-release-scl
  # run_verbose yum -y install devtoolset-8

  # ---------------------------------------------------------------------------

  echo
  run_verbose uname -a
  run_verbose lsb_release -a

  run_verbose ant -version
  run_verbose autoconf --version
  run_verbose bison --version
  run_verbose cmake --version
  run_verbose curl --version
  run_verbose flex --version
  run_verbose g++ --version
  run_verbose gawk --version
  run_verbose gdb --version
  run_verbose git --version
  run_verbose java -version
  run_verbose javac -version
  run_verbose m4 --version
  run_verbose mvn -version
  run_verbose make --version
  run_verbose patch --version
  run_verbose perl --version
  run_verbose pkg-config --version
  run_verbose python --version
  run_verbose python3 --version

}

function centos_clean()
{
  run_verbose yum clean all
}

# =============================================================================
