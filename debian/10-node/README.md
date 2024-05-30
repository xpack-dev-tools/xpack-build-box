
# 10-node

## Node,js

- <https://nodejs.org/en/>

Node 18 & 20 requires GLIBC 2.28 (Debian 10).

The build script is based on:

- <https://github.com/nodejs/docker-node/blob/main/18/buster/Dockerfile>
- <https://github.com/nodejs/docker-node/blob/main/20/buster/Dockerfile>

Download it with:

```sh
curl -L https://github.com/nodejs/docker-node/raw/main/18/buster/Dockerfile -o Dockerfile-v18.x.0
```

or

```sh
curl -L https://github.com/nodejs/docker-node/raw/main/20/buster/Dockerfile -o Dockerfile-v20.x.0
```

Compare with existing files and update it at the end, to invoke bash.

## Build Docker images

There are several scripts, with respective node LTS versions:

- `build-v18.17.0.sh`

```sh
bash ~/Work/xpack-build-box.git/debian/10-node/build-v18.17.0.sh
```

The images are based on the official `buildpack-deps` images.

Note: the arm32v7 script requires a 32-bit Arm machine.

## Test

The following tests were performed on a Debian
running on an Intel Linux.

```sh
docker run --interactive --tty ilegeul/debian:amd64-10-node-v18.17.0
```

The following tests were performed on two Raspberry Pi
running Raspberry Pi OS 64/32:

```sh
docker run --interactive --tty ilegeul/debian:arm64v8-10-node-v18.17.0
docker run --interactive --tty ilegeul/debian:arm32v7-10-node-v18.17.0
```

## Publish

To publish, use:

```sh
docker push "ilegeul/debian:amd64-10-node-v18.17.0"
docker push "ilegeul/debian:arm64v8-10-node-v18.17.0"
docker push "ilegeul/debian:arm32v7-10-node-v18.17.0"
```

## Notes

This is currently an experimental build, to prepare for the next
release that will require Node 18.

The images were not yet published on docker.hub.
