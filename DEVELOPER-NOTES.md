# Developer notes

## `rpath`

The workaround to the Linux shared libraries hell is to hardcode the
library search path in each ELF, as `rpath` which has the greatest
priority for the loader. (not `runpath`!)

The easy way is to use `LD_RUN_PATH` an let the linker set it to
this path.

However, the linker uses `LD_RUN_PATH` only if it is not given any
explicit `-Wl,-rpath,<path>`.

Ensuring this is easier said than done, since some tools always add
some path as `-rpath`.

The most notable example is `libtool`, which does an extensive path
processing.

Fortunately this behaviour can be disabled with a short sequence
of `sed` regular expressions applied to the resulting `libtool` files.

Other cases were also fixed with similar `sed` regular expressions,
applied directly to `make` files, and possibly other scripts.

## install / check order

The usual order is to run check before install, to prevent install if
check fails, but some packages, especially those that required libtool
patches, are no longer able to run if their libraries are not installed
in the final location.

The workaround is simple, run install first, and then check.

Thus, for consistency reasons, all packages are first installed then checked.

For packets that use test specific shared libraries, not installed in the
final folders, the workaround is a bit more elaborated, and requires
skipping patching in the test folders. (for example in the `gc` package).
