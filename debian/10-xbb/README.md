
# 10-xbb

## Build Docker images

There are several scripts. The latest is:

- `build-v6.0.0.sh`

To run it, use:

```sh
bash ~/Work/xpack-build-box.git/debian/10-xbb/build-v6.0.0.sh

docker images
```

## Test

The following test was performed on a Debian 11
running on an GIGABYTE motherboard with AMD 5600G.

```sh
docker run --interactive --tty ilegeul/debian:amd64-10-xbb-v6.0.0
```

The following test was performed on Ubuntu
running on ampere:

```sh
docker run --interactive --tty ilegeul/debian:arm64v8-10-xbb-v6.0.0
```

## Publish

To publish, use:

```sh
docker push "ilegeul/debian:amd64-10-xbb-v6.0.0"
```

and

```sh
docker push "ilegeul/debian:arm64v8-10-xbb-v6.0.0"
```

## Notes

There is no arm 32-bit image.
