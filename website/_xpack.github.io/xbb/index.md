---
title: The xPack Build Box
permalink: /xbb/

summary: A reproducible environment for building binary xPacks.

comments: true

date: 2016-03-09 12:04:00 +0300

---

The **xPack Build Box** (XBB) is an elaborated build environment focused on
obtaining **reproducible** runs while building **cross-platform standalone
binaries** for GNU/Linux, macOS and Windows.

## How it works?

XBB achieves repeatability and consistency by:

- controlling the versions of the tools used during the build
- compiling most dependencies (libraries) from sources.

By strictly controlling the versions of the compiled sources and tools, it is
possible to create build environments that use about the same tools
on both GNU/Linux (Intel and Arm) and macOS, helping to obtain
consistent results.

On GNU/Linux, to allow the builds to be performed on any distribution,
the actual builds run inside Docker containers
(Intel/Arm, 32/64-bit).

On macOS, the builds run on standard systems, without the need for
custom tools, but expecting to be pristine, without additional tools
installed via alternate package managers (like HomeBrew or MacPorts).

## XBB v5.0.0

The v5.0.0 release from early 2023 represents a major milestone
for the xPack project, since it is the first self-sustained release,
which allows to build new binary xPacks using previous xPacks,
without requiring any custom Docker images, or other compiled tools.

## XBB v5.1.1

The latest release, v5.1.1 from mid 2023 updates Python 3 and adds C++
support.

## `xpm run`

For convenience, the new build scripts are xPacks, with
multiple build configurations, for all supported platforms,
and all actions are defined uniformly as **xPack actions**.

xPack actions are named sequences of shell commands, that are executed
in order when the action is invoked.

For example:

```json
    "actions": {
      "deep-clean": [
        "rm -rf build xpacks node_modules package-lock.json",
        "rm -rf ${HOME}/Work/{{ properties.appLcName }}-[0-9]*-*"
      ],
      "install": [
        "npm install",
        "xpm install"
      ],
      "link-deps": [
        "xpm link @xpack-dev-tools/xbb-helper"
      ],
      "git-pull-helper": [
        "git -C ${HOME}/Work/xpacks/xbb-helper-xpack.git pull"
      ],
      "git-log": "git log --pretty='%cd * %h %s' --date=short",
      "test-xpm": "bash {{ properties.dbg }} scripts/test.sh --xpm",
      "build-native": "bash {{ properties.dbg }} scripts/build.sh",
      "build-native-develop": "bash {{ properties.dbg }} scripts/build.sh --develop",
      "build-native-win": "bash {{ properties.dbg }} scripts/build.sh --windows",
      "build-native-win-develop": "bash {{ properties.dbg }} scripts/build.sh --develop --windows"
    },
```

To invoke these actions, the `xpm run` command is used.

## The helper project

Since there are lots of common files between projects, they were collected
into a helper project.

The helper project is a
source xPack (`@xpack-dev-tools/xbb-helper`), which can be installed
as a dependency with:

```sh
cd ~/Work/xpacks/<project>-xpack.git
xpm install --save-dev @xpack-dev-tools/xbb-helper@latest
```

The result is a folder like:

```console
$ tree -l -L 2 xpacks/
xpacks/
└── xpack-dev-tools-xbb-helper -> /home/ilg/.local/xPacks/@xpack-dev-tools/xbb-helper/1.4.7
    ├── CHANGELOG.md
    ├── config
    ├── dependencies
    ├── developer
    ├── extras
    ├── github-actions
    ├── LICENSE
    ├── maintainer
    ├── package.json
    ├── patches
    ├── pkgconfig
    ├── README.md
    ├── scripts
    ├── templates
    ├── tests
    └── travis

13 directories, 4 files
```

There are many files in the helper, for various use cases. The build scripts
directly include files from the `scripts` and `dependencies` folders.

## Types of builds

From the point of view of the desired result, there are two types of builds:

- local/native builds, intended for development and running on the local
  machine
- distribution builds, intended for xPack binary distributions and running
  on most modern machines

The main use cases of XBBs are distribution builds, but they can be used
for native builds as well.

### Native builds with all tools from the host machine

In this case all build tools are expected to be available on the
host machine. The list of these dependency depends on the distribution
and is outside the scope of this project, which recommends the next
use Docker use case, presented below.

```sh
xpm run install
xpm run build-native
```

The first command is used to install the helper project;
the second command runs the build.

These commands run the same on both GNU/Linux and macOS.

To generate the Windows binaries on GNU/Linux, there is a
separate build action:

```sh
xpm run install
xpm run build-native-win
```

### Native builds with the major tools coming from xPacks

Sometimes the native tools available on the host machine may be too old
for building modern packages.

A simple solution is to install the main tools as binary xPacks. The
selection of tools depends on the target platform.

The existing projects include separate build configurations for
multiple platforms (darwin-x64, darwin-arm64, linux-x64, linux-arm64,
linux-arm, win32-x64).

For example, to build the Intel GNU/Linux binaries, use:

```sh
xpm run install
xpm run install --config linux-x64
xpm run build --config linux-x64
```

### Docker builds with tools coming from xPacks

An even more reproducible configuration can be achieved by using
Docker containers, with the base system tools.

```sh
xpm run install
xpm run docker-prepare --config linux-x64
xpm run docker-build --config linux-x64
```

### Writable helper scripts

For normal builds, the helper project, which is a source xPack,
is downloaded and marked as read-only, to prevent damaging it.

For development purposes it might be necessary to update it; the
xPack solution (inspired by the npm solution) is to download the
helper repository into a separate location, and link it to the
current project.

This is done in two steps, first a link from the central store to the
helper repo is created. This ensures that multiple projects can
conveniently use the writable helper.

```sh
rm -rf ~/Work/xpacks/xbb-helper-xpack.git && \
mkdir -p ~/Work/xpacks && \
git clone \
  --branch xpack-develop \
  https://github.com/xpack-dev-tools/xbb-helper-xpack.git \
  ~/Work/xpacks/xbb-helper-xpack.git && \
xpm link -C ~/Work/xpacks/xbb-helper-xpack.git
```

The result is a link like:

```console
$ ls -lA ~/.local/xPacks/@xpack-dev-tools/xbb-helper
total 4
dr-xr-xr-x 14 ilg ilg 4096 Mar 24 17:38 1.4.7
lrwxrwxrwx  1 ilg ilg   42 Mar 27 17:16 .link -> /home/ilg/Work/xpacks/xbb-helper-xpack.git
```

In other words, in the folder where versioned releases are installed,
a special hidden symbolic link is created, pointing to the location where
the repo was cloned.

In the second step, a link from the build project to the central store
is created.

```sh
xpm link @xpack-dev-tools/xbb-helper -C ~/Work/xpacks/<project>-xpack.git
```

The result is a link like:

```console
$ cd ~/Work/xpacks/<project>-xpack.git
$ ls -l xpacks/
total 0
lrwxrwxrwx 1 ilg ilg 57 Mar 27 17:21 xpack-dev-tools-xbb-helper -> /home/ilg/.local/xPacks/@xpack-dev-tools/xbb-helper/.link
```

In other words, the `xpack-dev-tools-xbb-helper` link, instead of pointing
to a version, like `/home/ilg/.local/xPacks/@xpack-dev-tools/xbb-helper/1.4.7`,
now points to the `.link`, which points to the cloned repo.

This double link mechanism allows multiple projects to refer to the writable
folder, and allow this folder to be easily moved to another location
without having to update all projects that reference it.

For details on the actual usage, please check the
build projects.

## Supported platforms

Generally, xPack binaries are available for the following platforms:

- Windows Intel 64-bit
- GNU/Linux Intel 64-bit
- GNU/Linux Arm 32-bit
- GNU/Linux Arm 64-bit
- macOS Intel 64-bit
- macOS Apple Silicon 64-bit

{% include note.html content="Starting with 2022, support for
macOS Apple Silicon was added; 32-bit support for Windows and
GNU/Linux Intel was discontinued." %}

XBB supports creating binaries for all these platforms.

For the detailed supported versions, please check the specific
[release]({{ site.baseurl }}/xbb/releases/) page.

### GNU/Linux Arm binaries

Support for Arm binaries was added in v3.1, in early 2020.

The supported architectures are:

- `arm64v8` - the ARMv8 64-bit architecture Aarch64
- `arm32v7` - the ARMv7 32-bit architecture with hardware float (armhf)

### macOS Apple Silicon

Support for Apple Silicon was added in v3.4, in late 2021.

## Docker specifics

As with any Docker builds, the XBB builds run completely inside Docker
containers, which start afresh each time they are instantiated.

To pass the folder with the build scripts in and the results out,
it is usual to use a `Work` folder, for example:

```console
$ docker run -it --volume "${HOME}/Work:/Host/Work" ilegeul/ubuntu:amd64-18.04-xbb-v5.0.0
root@bc7071f2c78a:/# ls -l Host/Work/xpacks
total 8
drwxrwxr-x 11 node node 4096 Mar 24 15:39 openocd-xpack.git
drwxrwxr-x 17 node node 4096 Mar 27 14:15 xbb-helper-xpack.git
```

In this simple configuration, the builds run with root permissions; with
more elaborate configurations it is possible to start the Docker containers
with user rights, but they are beyond the scope of this document.

## How to use the XBB tools

Both on GNU/Linux and macOS, the XBB tools are installed as binary
xPack dependencies in `xpacks/.bin` and are fully distinct from
the system tools.

To access them, the application should update the `PATH` to prefer
the `xpacks/.bin` path.

### Common scripts

For consistency between projects, common scripts were grouped in the
helper project.

After installing it with `xpm install`, the scripts are available
from `xpacks/xpack-dev-tools-xbb-helper`.

There are many scripts in this location; the main ones are in the
`scripts` folder. The scripts to build various dependencies are in
the `dependencies` folder.

### The `pkg-config-verbose` script

While running the configuration step, it is sometimes useful to trace
how `pkg-config` identifies resources to be used during the build.

The standard `pkg-config` does not have an option to increase verbosity.

The workaround is to use a separate script that displays the received command
and the response on the stderr stream.

This script is not specific to XBB, and can be used with any build.

For this, copy the file into `.../xbb/bin` or any other folder present
in the PATH and pass the script name via the environment.

```sh
chmod +x /opt/xbb/bin/pkg-config-verbose
export PKG_CONFIG=pkg-config-verbose
```

## No more TeX

Starting with v3.4, support for building the manuals was dropped,
and the TeX tools are no longer needed.

## Maintainer info

- [README-MAINTAINER](https://github.com/xpack/xpack-build-box/blob/master/README-MAINTAINER.md)

## End of support for Linux distributions

To help decide what base version to use, and how long to keep support for it,
a list of main Linux distributions was compiled, with the GLIBC versions:

- [end of support]({{ site.baseurl }}/xbb/end-of-support/)

## Upgrade plans

RedHat maintenance support 1 for RHEL 7 ended in Aug. 2020, with
maintenance support 2 to last until June. 2024. However XBB support
for RHEL 7 is a tough requirement, and was discontinued starting with 2022.

Compatibility was moved up to
**Ubuntu 18 LTS** (**GLIBC 2.27**), which also provides compatibility with
RedHat 8 / Debian 10, which both use GLIBC 2.28.

The next upgrade step will be taken when the minimum Node.js becomes 18.x,
which requires GLIBC 2.28, when the base system will be
**Debian 10** (planned for mid-2024).

## Credits

The xPack Build Box is inspired by the
[Holy Build Box](https://github.com/phusion/holy-build-box).

## Links

- [prerequisites]({{ site.baseurl }}/xbb/prerequisites/) for using XBB
- [releases]({{ site.baseurl }}/xbb/releases/)
- [GitHub](https://github.com/xpack/xpack-build-box/)
