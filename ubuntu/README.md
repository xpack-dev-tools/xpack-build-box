# The Ubuntu XBB - production Docker images

Note: This page is dedicated to the production version of the
Ubuntu XBB, used for building distribution packages.
The Ubuntu XBB used for native builds is documented in the
separate [README-NATIVE](README-NATIVE.md) page.

The production Ubuntu XBB consists of multiple Docker images,
in pairs of 32/64-bit, for each platform and version.

The images are published on
[Docker Hub](https://hub.docker.com/repository/docker/ilegeul/ubuntu)
(pulling can be done anonymously, pushing requires login).

Intel Ubuntu

- `ilegeul/ubuntu:amd64-18.04-xbb-v5.2.1`

Arm Ubuntu

- `ilegeul/ubuntu:arm64v8-18.04-xbb-v5.2.1`
- `ilegeul/ubuntu:arm32v7-18.04-xbb-v5.2.1`

Each of these images are built upon multiple layers,
starting from a base archive,
updating it, installing development tools, tex, the bootstrap and
finally the XBB itself.

To be sure Docker will not run out of space while building the images,
before each build step it is recommended
to clean possible dangling images:

```bash
docker system prune -f
```

## Intel Linux

The following sequences of commands were used on a Debian 10 Intel
Linux (x86_64):

### Ubuntu 12 Intel (precise)

No longer maintained (since 2022).

### Ubuntu 14 Intel (trusty)

No longer maintained.

### Ubuntu 16 Intel (xenial)

No longer maintained.

### Ubuntu 18 Intel (bionic)

```sh
set -o errexit
docker system prune -f

time ( bash ${HOME}/Work/xpack-build-box.git/ubuntu/18-node/build-v16.20.2.sh && \
bash ${HOME}/Work/xpack-build-box.git/ubuntu/18-xbb/build-v5.2.1.sh && \
docker images )

docker push "ilegeul/ubuntu:amd64-18.04-node-v16.20.2" && \
docker push "ilegeul/ubuntu:amd64-18.04-xbb-v5.2.1"
```

The build takes about 5 minutes on the GIGABYTE motherboard with AMD 5600G.

```console
REPOSITORY            TAG                         IMAGE ID       CREATED         SIZE
ilegeul/ubuntu        amd64-18.04-xbb-v5.2.1      19690b6c1041   3 minutes ago   1.21GB
ilegeul/ubuntu        amd64-18.04-xbb-v5.1.0      d891971595b5   8 days ago      1.21GB
ilegeul/ubuntu        amd64-18.04-node-v16.20.2   b2377a77e168   8 days ago      173MB
ilegeul/ubuntu        amd64-18.04-xbb-v5.0.0      5974fda9979c   10 months ago   908MB
ilegeul/ubuntu        amd64-18.04-node-v16.18.0   1c0643ba6a91   10 months ago   173MB
ilegeul/ubuntu        amd64-18.04-xbb-v4.0        801333c614c6   11 months ago   506MB
ubuntu                18.04                       71cb16d32be4   11 months ago   63.1MB
```

## Arm Linux

The following sequences of commands were used on a Raspberry Pi OS
Linux (AArch64):

### Ubuntu 16 Arm (xenial)

No longer maintained (since 2022).

### Ubuntu 18 Arm (bionic)

### 64-bit

It is recommended to run the entire build on a Raspberry Pi OS 64-bit machine.

```sh
set -o errexit
docker system prune -f

time ( bash ${HOME}/Work/xpack-build-box.git/ubuntu/18-node/build-v16.20.2.sh && \
bash ${HOME}/Work/xpack-build-box.git/ubuntu/18-xbb/build-v5.2.1.sh && \
docker images )

docker push "ilegeul/ubuntu:arm64v8-18.04-node-v16.20.2" && \
docker push "ilegeul/ubuntu:arm64v8-18.04-xbb-v5.2.1"
```

The build takes about 30 minutes on a Raspberry Pi CM4 at 2 GHz.

```console
REPOSITORY            TAG                           IMAGE ID       CREATED         SIZE
ilegeul/ubuntu        arm64v8-18.04-xbb-v5.2.1      29d8d82a475d   4 hours ago     1.19GB
ilegeul/ubuntu        arm64v8-18.04-xbb-v5.1.0      8463ef17d171   8 days ago      1.16GB
ilegeul/ubuntu        arm64v8-18.04-node-v16.20.2   4dff11135c01   8 days ago      166MB
ubuntu                18.04                         d1a528908992   3 months ago    56.7MB
ilegeul/ubuntu        arm64v8-18.04-node-v16.18.0   fccbc2567073   7 months ago    166MB
ilegeul/ubuntu        arm64v8-18.04-xbb-v5.0.0      baa7d6c9797e   10 months ago   758MB
ilegeul/ubuntu        arm64v8-18.04-xbb-v4.0        c87b49337906   11 months ago   472MB
```

#### 32-bit

It is recommended to run the entire build on a Raspberry Pi OS 32-bit machine.

Note: the 32-bit `18-node` build **must** be performed on a 32-bit machine,
otherwise `nvm` will try to incorectly install the 64-bit node/npm.

```bash
set -o errexit
docker system prune -f

time ( bash ${HOME}/Work/xpack-build-box.git/ubuntu/18-node/build-v16.20.2.sh && \
bash ${HOME}/Work/xpack-build-box.git/ubuntu/18-xbb/build-v5.2.1.sh && \
docker images )

docker push "ilegeul/ubuntu:arm32v7-18.04-node-v16.20.2" && \
docker push "ilegeul/ubuntu:arm32v7-18.04-xbb-v5.2.1"
```

The build takes about 30 minutes on a Raspberry Pi4.

```console
REPOSITORY         TAG                           IMAGE ID       CREATED         SIZE
ilegeul/ubuntu     arm32v7-18.04-xbb-v5.2.1      6c31512719d1   3 hours ago     892MB
ilegeul/ubuntu     arm32v7-18.04-xbb-v5.1.0      e925c617ffae   8 days ago      862MB
ilegeul/ubuntu     arm32v7-18.04-node-v16.20.2   11bdc6e25d12   8 days ago      147MB
ilegeul/ubuntu     arm32v7-18.04-xbb-v5.0.0      b071935af982   10 months ago   657MB
ilegeul/ubuntu     arm32v7-18.04-node-v16.18.0   4aee7f964002   10 months ago   147MB
ilegeul/ubuntu     arm32v7-18.04-xbb-v4.0        7c1c3f724109   11 months ago   420MB
ubuntu             18.04                         bfbba71facee   11 months ago   45.8MB
```

## Testing

For such a complex project, which brings together multiple separate
projects, testing is quite a challenge, and was addressed at several
levels.

First, the project tests were executed. Unfortunately some projects
were not ready to run in a custom environment like XBB, and some of
the tests had to be disabled.

Then, a quick test to check that the executables start properly was
performed right during the build.

At the end of the script, those tests were executed again, to check
that adding more libraries and binaries did not damage anything.

For Linux, all binaries using dynamically linked libraries were
checked for all dependencies to be in the hardcoded RPATH.

As a final functional step, a separate XBB test image was built
with the actual XBB Docker image. In other words, XBB can build
itself, which is quite a tough functional test.
