
# 10-node

## Node,js

- <https://nodejs.org/en/>

Node 18 & 20 requires GLIBC 2.28 (Debian 10).

The build script is based on:

- <https://github.com/nodejs/docker-node/blob/60f46a13212d389fa2cc9ceecdb33ea4456a5217/20/buster/Dockerfile>

Download it with:

```sh
curl -L https://github.com/nodejs/docker-node/raw/60f46a13212d389fa2cc9ceecdb33ea4456a5217/20/buster/Dockerfile -o Dockerfile-v20.18.2
```

Compare with existing files and update it at the end, to invoke bash.

## Build Docker images

There are several scripts, with respective node LTS versions.
The latest is:

- `build-v20.18.2.sh`

```sh
bash ~/Work/xpack-build-box.git/debian/10-node/build-v20.18.2.sh
```

The images are based on the official `buildpack-deps` images.

## Test

The following tests were performed on a Debian
running on an Intel Linux.

```sh
docker run --interactive --tty ilegeul/debian:amd64-10-node-v20.18.2
```

The following tests were performed on Ubuntu
running on ampere:

```sh
docker run --interactive --tty ilegeul/debian:arm64v8-10-node-v20.18.2
```

## Publish

To publish, use:

```sh
docker push "ilegeul/debian:amd64-10-node-v20.18.2"
docker push "ilegeul/debian:arm64v8-10-node-v20.18.2"
```

## Notes

There is no arm 32-bit image.
