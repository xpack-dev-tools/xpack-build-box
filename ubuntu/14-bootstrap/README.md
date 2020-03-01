
## Build Docker images

There are two scripts:

- `arm64-build-v3.1.sh` -> `ilegeul/ubuntu:arm64-14.04-bootstrap-v3.1`
- `armhf-build-v3.1.sh` -> `ilegeul/ubuntu:armhf-14.04-bootstrap-v3.1`

```console
$ bash ~/Downloads/xpack-build-box.git/ubuntu/14-bootstrap/arm64-build-v3.1.sh
$ bash ~/Downloads/xpack-build-box.git/ubuntu/14-bootstrap/armhf-build-v3.1.sh

$ docker images
```

As a shortcut, macOS users can double click the `.command` files in Finder.

## Test

The test was performed on a macOS.

```console
$ docker run --interactive --tty ilegeul/ubuntu:arm64-14.04-bootstrap-v3.1
$ docker run --interactive --tty ilegeul/ubuntu:armhf-14.04-bootstrap-v3.1
```

## Publish

To publish, use:

```console
$ docker push "ilegeul/ubuntu:arm64-14.04-bootstrap-v3.1"
$ docker push "ilegeul/ubuntu:armhf-14.04-bootstrap-v3.1"
```