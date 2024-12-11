
# 18-xbb

## Prerequisites

The `ubuntu-18.04-node-*` docker image.

## Build Docker images

There are several scripts:

- `build-v5.2.2.sh`

```sh
bash ~/Work/xpack-build-box.git/ubuntu/18-xbb/build-v5.2.2.sh

docker images
```

## Test

The following tests were performed on a Debian 11
running on an GIGABYTE motherboard with AMD 5600G.

```sh
docker run --interactive --tty ilegeul/ubuntu:amd64-18.04-xbb-v5.2.2
```

The following tests were performed on a Raspberry Pi OS
running on a Raspberry CM4 with 8 GB RAM.

```sh
docker run --interactive --tty ilegeul/ubuntu:arm64v8-18.04-xbb-v5.2.2
docker run --interactive --tty ilegeul/ubuntu:arm32v7-18.04-xbb-v5.2.2
```

## Publish

To publish, use:

```sh
docker push "ilegeul/ubuntu:amd64-18.04-xbb-v5.2.2"

docker push "ilegeul/ubuntu:arm64v8-18.04-xbb-v5.2.2"
docker push "ilegeul/ubuntu:arm32v7-18.04-xbb-v5.2.2"
```

## Notes

The unpublished 3.4.1 version, directly derived from 3.4,
was a failed attempt to fix the GCC tests by updating wine to 7.15.

## Changes

- v5.2.2 - add `dc` (used by binutils tests)
