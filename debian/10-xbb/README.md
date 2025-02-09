
# 10-xbb

## Build Docker images

There are several scripts:

- `build-v6.0.0.sh`
- `build-v5.1.1.sh`

```sh
bash ~/Work/xpack-build-box.git/debian/10-xbb/build-v6.0.0.sh

docker images
```

## Test

The following tests were performed on a Debian 11
running on an GIGABYTE motherboard with AMD 5600G.

```sh
docker run --interactive --tty ilegeul/debian:amd64-10-xbb-v6.0.0
```

The following tests were performed on Ubuntu
running on ampere:

```sh
docker run --interactive --tty ilegeul/debian:arm64v8-10-xbb-v6.0.0
```

## Publish

To publish, use:

```sh
docker push "ilegeul/debian:amd64-10-xbb-v6.0.0"

docker push "ilegeul/debian:arm64v8-10-xbb-v6.0.0"
```

## Notes

There is no arm 32-bit image.
