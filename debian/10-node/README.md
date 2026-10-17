
# 10-node

## Node,js

- <https://nodejs.org/en/>

Node 18 & 20 requires GLIBC 2.28 (Debian 10).

The build script is based on the official nodejs Docker build scripts
available from the separate project:

- https://github.com/nodejs/docker-node


Download the 24 Debian file with:

```sh
curl -L https://github.com/nodejs/docker-node/raw/refs/heads/main/24/bookworm/Dockerfile -o Dockerfile-v24.22.0
```

Compare with existing files and perform some updates:

- at the beginning, change it to `FROM buildpack-deps:buster`
- at the end update it to invoke bash:

```
ENV NODE_ENV=production
CMD ["/bin/bash"]
```

## Build Docker images

There are several scripts, with respective node LTS versions.
The latest is:

- `build-v24.22.0.sh`

```sh
bash ~/Work/xpack-build-box.git/debian/10-node/build-v24.22.0.sh
```

## Publish

To publish, use:

```sh
docker push "ilegeul/debian:amd64-10-node-v24.22.0"
docker push "ilegeul/debian:arm64v8-10-node-v24.22.0"
```

## Test

The following tests were performed on a Debian
running on an Intel Linux.

```sh
docker run --interactive --tty ilegeul/debian:amd64-10-node-v24.22.0
```

The following tests were performed on Ubuntu
running on ampere:

```sh
docker run --interactive --tty ilegeul/debian:arm64v8-10-node-v24.22.0
```

## Notes

There is no arm 32-bit image.
