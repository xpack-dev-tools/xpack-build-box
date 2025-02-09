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

uname_arch="$(uname -m)"
case "${uname_arch}" in
  x86_64 ) arch="amd64";;
  aarch64 ) arch="arm64v8";;
  armv7l | armv8l ) arch='arm32v7';;
  * ) echo "unsupported architecture ${uname_arch}"; exit 1;;
esac

debian_version="10"
node_version="20.18.2"

cd "${script_folder_path}"

docker build --tag ilegeul/debian:${arch}-${debian_version}-node-v${node_version} --file Dockerfile-v${node_version} --no-cache --progress plain .

echo
echo "Done."

# -----------------------------------------------------------------------------
