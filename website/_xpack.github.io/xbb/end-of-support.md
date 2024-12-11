---
title: End-of-support schedule
permalink: /xbb/end-of-support/

comments: true

date: 2021-10-13 15:15:00 +0300

---

## GNU/Linux distro versions

To better decide which versions to support, below is a list of existing
versions.

The names are in fact docker image names, and can be used directly to query
the `ldd --version`:

```sh
docker run -it <image> ldd --version
```

### [Debian](https://en.wikipedia.org/wiki/Debian_version_history)

- `debian:6` - squeeze - 2011-2016, GLIBC 2.11.3, kernel 2.6.32
- `debian:7` - wheezy - 2013-2016, GLIBC 2.13, kernel 3.2
- `debian:8` - jessie - 2015-2018, GLIBC 2.19, kernel 3.16
- `debian:9` - stretch - 2017-2020, GLIBC 2.24, kernel 4.9.0-6 (first with arm64)
- `debian:10` - buster - 2019-2022, GLIBC **2.28**, kernel 4.19.0-6 <-- **next, since mid-2024**
- `debian:11` - bullseye - 2021-2026, GLIBC 2.31, kernel 5.10
- `debian:12` - bookworm - ?

Debian 10 [LTS](https://wiki.debian.org/LTS) ends in **June 30th, 2024**.

### [Ubuntu](https://en.wikipedia.org/wiki/Ubuntu_version_history)

- `ubuntu:10.04` - lucy - 2010-2015, GLIBC 2.11.1
- `ubuntu:12.04` - precise - 2012-2019, GLIBC 2.15, kernel **3.2** <--- XBB v3.3 Intel Linux choice
- `ubuntu:14.04` - trusty - 2014-2022, GLIBC 2.19, kernel 3.16
- `ubuntu:16.04` - xenial - 2016-2024, GLIBC 2.23, kernel 4.4 <--- XBB v3.3 Arm Linux choice
- `ubuntu:18.04` - bionic - 2018-2028, GLIBC **2.27**, kernel 4.15 <-- **XBB v3.4 - v5.1.1** Intel & Arm Linux choice
- `ubuntu:20.04` - focal - 2020-2230, GLIBC 2.31, kernel 5.4
- `ubuntu:22.04` - jammy - 2022-2232, GLIBC 2.35, kernel 5.15

### [RHEL](https://access.redhat.com/support/policy/updates/errata/#Life_Cycle_Dates)

- `registry.access.redhat.com/rhel6` - GLIBC 2.12 (no longer supported)
- `registry.access.redhat.com/rhel7` - GLIBC 2.17, kernel 3.10 <-- XBB v3.3
- `registry.access.redhat.com/ubi8` - GLIBC 2.28, kernel 5.10 <-- XBB v3.4 - v5.1.1

Red Hat Enterprise
[Extended Update Support](https://access.redhat.com/support/policy/updates/errata#RHEL8_Planning_Guide)
for 8.8 ends in **May 31, 2025**.

### [CentOS](https://en.wikipedia.org/wiki/CentOS)

- `centos:6` - 2011-2020, GLIBC 2.12 (no longer supported)
- `centos:7` - 2014-2024, GLIBC 2.17, kernel 3.10 <-- XBB v3.3
- `centos:8` - 2019-2029, GLIBC 2.28, kernel 4.18 <-- XBB v3.4 - v5.1.1

Last version was 8.4; discontinued by the end of 2021; see Rocky Linux.

### [Fedora](https://en.wikipedia.org/wiki/Fedora_version_history)

- `fedora:20` - 2013-12, GLIBC 2.18, kernel 3.11 <-- XBB v3.3 Intel
- `fedora:21` - 2014-12, GLIBC 2.20, kernel 3.17
- `fedora:22` - 2015-05, GLIBC 2.21, kernel 4.0
- `fedora:23` - 2015-11, GLIBC 2.22, kernel 4.2
- `fedora:24` - 2016-06, GLIBC 2.23, kernel 4.5 <-- XBB v3.3 Arm
- `fedora:25` - 2016-11, GLIBC 2.24, kernel 4.8
- `fedora:26` - 2017-07, GLIBC 2.25, kernel 4.11
- `fedora:27` - 2017-11, GLIBC 2.26, kernel 4.13
- `fedora:28` - 2018-05, GLIBC 2.27, kernel 4.16 <-- XBB v3.4 - v5.1.1
- `fedora:29` - 2018-10, GLIBC **2.28**, kernel 4.18
- `fedora:30` - 2019-05, GLIBC 2.29, kernel 5.0
- `fedora:31` - 2019-10, GLIBC 2.30, kernel 5.3
- `fedora:32` - 2020-04, GLIBC 2.31, kernel 5.6
- `fedora:33` - 2020-10, GLIBC 2.32, kernel 5.8
- `fedora:34` - 2021-04 - 2022-05, GLIBC 2.33, kernel 5.11
- `fedora:35` - 2021-11 - 2022-12, GLIBC 2.34, kernel 5.15
- `fedora:36` - 2021-11 - 2023-05, GLIBC 2.35, kernel 5.17
- `fedora:37` - 2022-11 - 2023-11, GLIBC ?, kernel 6.0
- `fedora:38` - 2023-04 - 2024-05, GLIBC ?, kernel ?

### Raspberry Pi

- `raspbian/stretch` - (Raspbian 9.4 stretch) - GLIBC 2.24
- `balenalib/raspberrypi3:buster` - (Debian 10) - GLIBC 2.28 (armv7l)
- `balenalib/raspberrypi3:bullseye` - (Debian 11) - GLIBC 2.31 (armv7l)
- `balenalib/raspberrypi4-64-debian:bullseye` (Debian 11) - GLIBC 2.31 (aarch64)

## 32-bit support

Existing support for 32-bit Windows and GNU/Linux Intel builds was dropped.
Support for 32-bit GNU/Linux Arm (`armv7l`) will be preserved for the moment,
since there are still many 32-bit Raspberry Pi machines,
but might be dropped in one of the future version.

## armv6

`armv6` is currently not supported, so the resulting binaries do not
run on Raspberry Pi 1, Raspberry Pi Zero
and Compute Module 1.

## Discontinued versions

### CentOS 6

According to the
[CentOS schedule](https://en.wikipedia.org/wiki/CentOS#End-of-support_schedule),
version 6 was supported up to Nov. 2020.

Starting with XBB v3.1, support for CentOS/RHEL 6 was discontinued.

### RedHat 7

RHEL releases have a longer
[life cycle](https://access.redhat.com/support/policy/updates/errata/#Life_Cycle_Dates)
and RHEL 7 end of extended life-cycle support is 2024.

Starting with XBB v3.4, support for RHEL 7 was discontinued

## Current base version

For GNU/Linux, to preserve support for older distributions,
the **Ubuntu 18 LTS (bionic)** distribution was selected;
the resulting binaries depend on **GLIBC 2.27** and should
also run on RHEL 8 or newer, Debian 10, Fedora 29 or newer.

For Arm binaries, the resulting binaries should run on all
Raspberry Pi class machines, or larger/newer.

## Pre-deprecation notice for Ubuntu 18.04

Ubuntu 18.04 LTS _Bionic Beaver_ reached the end of the standard five-year
maintenance window for Long-Term Support (LTS) release on 31 May 2023.

As a courtesy, the xPack GNU/Linux releases will continue to be based on
Ubuntu 18.04 for another year.

From 2025 onwards, the GNU/Linux binaries will be built on **Debian 10**,
(**GLIBC 2.28**), and are also expected to run on RedHat 8.

Users are urged to update their build and test infrastructure to
ensure a smooth transition to the next xPack releases.
