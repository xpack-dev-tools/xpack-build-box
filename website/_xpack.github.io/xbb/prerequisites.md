---
title: Prerequisites for building xPack binaries
permalink: /xbb/prerequisites/

comments: true
toc: false

date: 2017-07-06 20:55:00 +0300

---

The scripts used to build the
[xPack 3rd Party Development Tools](https://github.com/xpack-dev-tools/)
are based on the
[xPack Build Box (XBB)](https://github.com/xpack/xpack-build-box) v5.1.0.

The build scripts run on **GNU/Linux** and **macOS**.

The **Windows** binaries are generated on Intel GNU/Linux,
using [mingw-w64](https://mingw-w64.org).

{% capture npm_xpm_tldr %}

## npm/xpm

### Quick instructions

If you know what you're doing and prefer a shortcut, copy/paste the following
[script](https://github.com/xpack/assets/blob/master/scripts/install-nvm-node-npm-xpm.sh)
into a terminal (otherwise perform the steps one by one).

{% include warning.html content="For security reasons, conscientious users
should first check the content of the file before executing it." %}

```sh
mkdir -pv "${HOME}/Downloads/"
curl --output "${HOME}/Downloads/install-nvm-node-npm-xpm.sh" https://raw.githubusercontent.com/xpack/assets/master/scripts/install-nvm-node-npm-xpm.sh
cat "${HOME}/Downloads/install-nvm-node-npm-xpm.sh"

bash "${HOME}/Downloads/install-nvm-node-npm-xpm.sh"

exit
```

This script will install `nvm` (the Node Version Manager), `node`,
`npm` and `xpm`.

{% include note.html content="To activate `nvm` automatically,
the script adds several lines
to the shell initialisation script." %}

{% endcapture %}

{% capture npm_xpm_details %}

### node/npm

`npm` is shipped with Node.js, and is required to install `xpm`.

For full details on installing Node.js, please see the
[xPack prerequisites]({{ site.baseurl }}/install/) page.

{% include warning.html content="Be sure you **do not** install npm
with administrative rights, like via a system package manager;
use `nvm` instead, as instructed, otherwise you will run into
troubles caused by permissions." %}

### xpm

[`xpm`](https://xpack.github.io/xpm/) is a portable
[Node.js](https://nodejs.org/) command line application.

If you followed the _Quick instructions_, it is already installed.

Otherwise, to install it, follow the steps in the
[xpm install]({{ site.baseurl }}/xpm/install/) page.

If you know what you're doing and prefer a shortcut,
issue the following command:

```sh
npm install --global xpm@latest
```

{% endcapture %}

{% capture macos %}

The macOS builds run natively on Intel and Apple Silicon
machines, and, apart from the usual **Command Line Tools** (provided by
Apple) and `xpm`, the host machine has no other special
requirements.

The prerequisites are:

- `npm` (shipped with Node.js; installed via nvm)
- `xpm` (installed via `npm`)
- the **Command Line Tools** from Apple

Some build scripts may require **Python 3**. If not already available in the
standard Apple distribution, install it from Python
[downloads](https://www.python.org/downloads/macos/).

For development builds, the procedure can be executed on a recent macOS
version (currently tested up to 12.6).

For production builds it is recommended to use a slightly older version,
for example **macOS 10.13** is a good compromise.

It is not mandatory to have a physical macOS 10.13 machine, a virtual
machine is also perfectly fine. Both Parallels and VirtualBox were
checked and were functional (although VirtualBox was not as stable
as Parallels).

The build scripts were tested on:

- macOS 12.6.8, running on an Intel MacMini
- macOS 10.14, running on a Intel NUC NUC8i7BEH
- macOS 10.13, running inside a Parallels virtual machine
- macOS 11.7.4, running on an Apple Silicon MacMini

{{ npm_xpm_tldr }}

{% include note.html content="When running on macOS this script also installs
the Command Line Tools." %}

{{ npm_xpm_details }}

## The Command Line Tools

The macOS compiler and other development tools are packed in a
separate Xcode add-on. The best place to get it is from the
[Developer](https://developer.apple.com/xcode/downloads/) site,
although this might require enrolling to the developer program
(free of charge).

If you followed the _Quick instructions_, it is already installed.

Otherwise, the recommended way is to install the Command Line Tools separately
via a command line:

```console
$ xcode-select --install
$ xcode-select -p
/Library/Developer/CommandLineTools
$ gcc --version
Configured with: --prefix=/Library/Developer/CommandLineTools/usr --with-gxx-include-dir=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/4.2.1
Apple clang version 13.0.0 (clang-1300.0.29.3)
Target: x86_64-apple-darwin20.6.0
Thread model: posix
InstalledDir: /Library/Developer/CommandLineTools/usr/bin
```

{% include note.html content="Xcode alone includes the compiler
in the Xcode.app folder, which may vary in different versions;
for a stable configuration it is
required to install the CommandLineTools package." %}

## No macOS Docker

Due to the specifics of macOS, Docker cannot run natively; instead,
it uses a GNU/Linux virtual machine running in Apple HyperKit
(Apple's virtualization framework), and a file system compatibility
layer.

The end result is that Docker runs slowly, consumes a lot of memory,
and is not reliable, so it is not recommended to run the
Linux/Windows builds on macOS.

{% endcapture %}

{% capture linux %}

The GNU/Linux build scripts use a set
of [Docker](https://www.docker.com)
images based on older
and more conservative distributions, to avoid problems when
attempting to run the executables on older systems.

**Any x86_64/aarch64/armhf GNU/Linux distribution that is
able to run Docker should be fine**; it
is not necessary to have a physical machine, virtual machines are
perfectly fine. For better results, dedicate 3-4 cores and 8-12 GB of RAM.

The XBB v5.0.0 Docker images are built on top of **Ubuntu 18 LTS** for both
Intel and Arm GNU/Linux, which should allow the resulting binaries to
run on any system based on **GLIBC >= 2.27**.

{% include note.html content="Building Arm binaries requires
an Arm machine. A Raspberry Pi 4 8GB equipped with a Samsung Portable T7
USB 3 SSD is a good solution." %}

{% include note.html content="Although Arm 32 binaries can be build
inside Docker containers running on AArch64 machines,
it is still recommended to use a 32-bit OS, to avoid issues caused
by the differences between armv7 and armv8." %}

The prerequisites are:

- `curl` (installed via the system package manager)
- `git` (installed via the system package manager)
- `docker` (preferably a recent one, installed from **docker.com**)
- `npm` (shipped with Node.js; installed via **nvm**,
  **not** the system package manager)
- `xpm` (installed via `npm`)

The build scripts do most of the actual work in a Docker container, and,
apart from `curl`, `git` `docker` and `xpm`, the host machine has no other
special requirements.

The build scripts were tested on:

- Ubuntu 18.04 LTS, running on an Intel NUC NUC8i7BEH (i7) with 32 GB of RAM
- Debian 10 (buster), running on an AMD Ryzen 5600G with 32 GB of RAM
- Raspberry Pi OS 64-bit, running on a Raspberry Pi 4 with 8 GB of RAM
- Raspberry Pi OS 32-bit, running on a Raspberry Pi 4 with 4 GB of RAM

## curl & git

Install `curl` & `git` using the system package manager.

For example on Ubuntu and Debian derived distributions, use:

```sh
sudo apt-get install --yes curl git
```

## Docker

A **recent Docker** is necessary. If your distribution has one,
probably it can be used,
but generally it is recommended to update to the latest stable available
directly from docker.com.

For **any GNU/Linux** distribution, follow the
[specific instructions](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-repository).

For example, the steps to install Docker on a modern **Ubuntu** system
are basically:

```sh
sudo apt-get update && \
\
sudo apt-get install ca-certificates curl gnupg && \
\
sudo mkdir -m 0755 -p /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
\
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
\
sudo apt-get update && \
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

To check if the install is functional, run the _Hello World_ image,
for the moment as `sudo`:

```console
$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
b04784fba78d: Pull complete
Digest: sha256:f3b3b28a45160805bb16542c9531888519430e9e6d6ffc09d72261b0d26ff74f
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
...
```

### Configure Docker to run as a regular user

To allow Docker to run as a regular user, you need to be a member of
the `docker` group.

```sh
sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo service docker restart
```

The above script are for Ubuntu and the Debian family. For other
distributions, the last line may differ, for example for Arch Linux use:

```sh
systemctl restart docker
```

To make these changes effective, preferably **reboot** the machine.

To check if the configuration change is functional, run the same
_Hello World_ image without sudo:

```console
$ docker run hello-world

Hello from Docker!
...
```

### Docker images

The Docker images are available from
[Docker Hub](https://hub.docker.com/u/ilegeul/). They were build using
the Dockerfiles available from
[XBB (xPack Build Box)](https://github.com/xpack/xpack-build-box/tree/master/).

If not already loaded, Docker will load the images at first usage.
The images are reasonably large, currently below 1 GB.

More details in each script documentation page.

{{ npm_xpm_tldr }}

{{ npm_xpm_details }}

{% endcapture %}

{% include platform-tabs-unix.html %}

## Visual Studio Code

Although not mandatory, VS Code is a nice addition to the development
environment, and with the
[xPack extension](https://marketplace.visualstudio.com/items?itemName=ilg-vscode.xpack),
some of the actions are only a mouse click away.
