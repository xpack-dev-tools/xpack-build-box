## 6-xbb

### Overview

Dockerfile to create a Docker image based on the latest CentOS 6 32/64-bits development image, plus selected new tools.

### Changes

Using the bootstrap development tools, build final, most recent, versions of the tools from sources. 

This step installs the newly created tools in `/opt/xbb`, using several temporary folders.

To use the new tools, add `/opt/xpp/bin` to the path and adjust the include and library search paths.

To simplify things, use the functions provided by the `xbb.sh` bash script:

```console
$ source /opt/xbb/xbb.sh
$ xbb_activate
xPack Build Box activated! CentOS 6.9, gcc (GCC) 7.2.0, ldd (GNU libc) 2.12

PATH=/opt/xbb/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CFLAGS=-g -O2 -ffunction-sections -fdata-sections
CXXFLAGS=-g -O2 -ffunction-sections -fdata-sections
LDFLAGS=-L"/opt/xbb/lib" -Wl,--gc-sections

STATICLIB_CFLAGS=-g -O2 -ffunction-sections -fdata-sections
STATICLIB_CXXFLAGS=-g -O2 -ffunction-sections -fdata-sections

SHLIB_CFLAGS=-g -O2 -fPIC
SHLIB_CXXFLAGS=-g -O2 -fPIC
SHLIB_LDFLAGS=-L"/opt/xbb/lib"

LD_LIBRARY_PATH=/opt/xbb/lib
PKG_CONFIG_PATH=/opt/xbb/lib/pkgconfig:/usr/lib/pkgconfig
```

or 

```console
$ source /opt/xbb/xbb.sh
$ xbb_activate_static
```

or 

```console
$ source /opt/xbb/xbb.sh
$ xbb_activate_shared
```

### Developer

#### Create

To create the Docker image locally, use:

```console
$ cd ...
$ docker build --squash --tag "ilegeul/centos:6-xbb-v1" -f Dockerfile-v1 .
$ docker build --squash --tag "ilegeul/centos32:6-xbb-v1" -f Dockerfile32-v1 .
```

On macOS, to prevent entering sleep, use:

```console
$ caffeinate docker build --squash --tag "ilegeul/centos:6-xbb-v1" -f Dockerfile-v1 .
$ caffeinate docker build --squash --tag "ilegeul/centos32:6-xbb-v1" -f Dockerfile32-v1 .
```

To create a second, third, etc version:

```console
$ caffeinate docker build --squash --tag "ilegeul/centos:6-xbb-v2" -f Dockerfile-v2 .
$ caffeinate docker build --squash --tag "ilegeul/centos:6-xbb-v3" -f Dockerfile-v3 .
$ caffeinate docker build --squash --tag "ilegeul/centos32:6-xbb-v2" -f Dockerfile32-v2 .
$ caffeinate docker build --squash --tag "ilegeul/centos32:6-xbb-v3" -f Dockerfile32-v3 .
```

#### Test

To test the image:

```console
$ docker run --interactive --tty ilegeul/centos:6-xbb-v1
$ docker run --interactive --tty ilegeul/centos:6-xbb-v2
$ docker run --interactive --tty ilegeul/centos32:6-xbb-v1
$ docker run --interactive --tty ilegeul/centos32:6-xbb-v2
```

#### Publish

To publish, use:

```console
$ docker push "ilegeul/centos:6-xbb-v1"
$ docker push "ilegeul/centos32:6-xbb-v1"
```

#### Copy & Paste

```bash
caffeinate docker build --squash --tag "ilegeul/centos:6-xbb-v1" -f Dockerfile-v1 .
docker push "ilegeul/centos:6-xbb-v1"
caffeinate docker build --squash --tag "ilegeul/centos32:6-xbb-v1" -f Dockerfile32-v1 .
docker push "ilegeul/centos32:6-xbb-v1"

```

### Credits

The design was heavily inspired by [Holy Build Box](http://phusion.github.io/holy-build-box/), available from [GitHub](https://github.com/phusion/holy-build-box).
