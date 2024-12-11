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

# https://www.thomas-krenn.com/en/wiki/Configure_Locales_in_Ubuntu
run_verbose apt-get install --yes locales
run_verbose locale-gen en_US.UTF-8
run_verbose update-locale LANG=en_US.UTF-8

# Must be passed as `ENV TZ=UTC` in Dockerfile.
# export TZ=UTC
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

run_verbose apt-get --yes install tzdata

# -----------------------------------------------------------------------------

# Keep it to a minimum, mainly to allow scripts to
# download/uncompress archives.
# The test is to instantiate and build an xpm hello template.
run_verbose apt-get -qq install -y \
bzip2 \
ca-certificates \
coreutils \
curl \
file \
git \
gzip \
libatomic1 \
libc6-dev \
linux-headers-generic \
lsb-release \
patch \
systemd \
tar \
time \
unzip \
wget \
xz-utils \
zip \
zlib1g-dev \

# -----------------------------------------------------------------------------

# https://nodejs.org/dist/v16.17.1/node-v16.17.1-linux-x64.tar.xz
# https://nodejs.org/dist/v16.17.1/node-v16.17.1-linux-arm64.tar.xz
# https://nodejs.org/dist/v16.17.1/node-v16.17.1-linux-armv7l.tar.xz

case "$(uname -m)" in
 "x86_64" )
    DISTRO=linux-x64
    ;;

  "aarch64" )
    DISTRO=linux-arm64
    ;;

  "armv7l" )
    DISTRO=linux-armv7l
    ;;

  * )
    echo "Unsupported machine $(uname -m)"
    exit 1
    ;;
esac

if [ "${XBB_VERSION}" == "4.0" ]
then
  VERSION=v16.17.1
else
  echo "Version ${XBB_VERSION} not supported."
  exit 1
fi

# https://github.com/nodejs/help/wiki/Installation
mkdir -pv /usr/local/lib/nodejs
curl -L https://nodejs.org/dist/$VERSION/node-$VERSION-$DISTRO.tar.xz | tar -xJv -C /usr/local/lib/nodejs

# The path where npm installs other binaries must be somehow
# added to the system PATH. It is not clear exactly how the docker
# image is invoked, so add it in multiple places.

# .bashrc is used by interractive shells (like `docker run -it`).
echo "export PATH=\"/usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin:$PATH\"" >>/etc/bash.bashrc

# profile is used by login shells.
echo "export PATH=\"/usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin:$PATH\"" >/etc/profile.d/00-path.sh

# Probably not used.
run_verbose sed -i -e "s|PATH=\"|PATH=\"/usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin:|" /etc/environment

# Explicit links that work regardless the PATH.
ln -sv /usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin/node /usr/bin/node
ln -sv /usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin/npm /usr/bin/npm
ln -sv /usr/local/lib/nodejs/node-$VERSION-$DISTRO/bin/npx /usr/bin/npx

run_verbose node -v
run_verbose npm version
run_verbose npx -v

# -----------------------------------------------------------------------------

echo
echo "Container done."

# -----------------------------------------------------------------------------
