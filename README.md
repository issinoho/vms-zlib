<p align="center">
  <img src="docs/images/banner.svg" alt="zlib for OpenVMS: a DECterm window running zlib's example and minigzip, with a zlib mark" width="100%">
</p>

# zlib for OpenVMS

The [zlib](https://zlib.net) compression library (**1.3.2**) built natively for OpenVMS on
**IA64** and **x86-64**, following zlib's own releases rather than any vendor's release
cycle. Its first user is [curl for OpenVMS](https://github.com/issinoho/vms-curl), which
links it statically for compressed transfers. It belongs to the same family as
[GNU grep](https://github.com/issinoho/vms-grep), [PCRE2](https://github.com/issinoho/vms-pcre2),
[GNU sed](https://github.com/issinoho/vms-sed) and [GNU awk](https://github.com/issinoho/vms-awk)
for OpenVMS.

zlib ships its own OpenVMS build procedure (`make_vms.com`) in the release tarball. This
repository builds with it and holds **only our changes**: every build starts from the signed
release tarball (Mark Adler's key, pinned in `keys/`), applies our patches and adds our VMS
files in `vmsport/`.

## Status

| | IA64 (OpenVMS V8.4-2L3, VSI C 7.4) | x86-64 (OpenVMS E9.2-4, VSI C 7.7) |
|---|---|---|
| Builds with upstream's `make_vms.com` | yes | yes |
| Smoke test (zlib's `example` self-test, `minigzip` round trip) | 2/2 | 2/2 |
| PCSI kit (`ISSINOHO-<base>-ZLIB-V0103-2E1-1.PCSI`) | in progress | in progress |

## What gets built

- **`LIBZ.OLB`:** the library as an object library, for static linking.
- **An install tree** `[.INSTALL_<arch>]` with `[.INCLUDE]ZLIB.H, ZCONF.H` and
  `[.LIB]LIBZ.OLB`. Define the rooted logical name `ZLIB$ROOT` for it, then compile with
  `/INCLUDE=ZLIB$ROOT:[INCLUDE]` and link with `ZLIB$ROOT:[LIB]LIBZ.OLB/LIBRARY`.
- `EXAMPLE.EXE` and `MINIGZIP.EXE`, zlib's test programs, and upstream's shared image
  `LIBZSHR.EXE`.

## Patches

| Patch | Purpose |
|---|---|
| 0001 | `gzguts.h`: don't define `_POSIX_C_SOURCE` on VMS. Defined after `<stdio.h>`, it makes the CRTL's `<fcntl.h>` redeclare `creat()` incompatibly, and the `gz*.c` files did not compile. |
| 0002 | `make_vms.com`: recognise OpenVMS x86-64. It took the architecture from `HW_MODEL`, which put x86-64 in the VAX range: objects were compiled without `/NAMES=AS_IS` and the shared image options file was rejected. |

Both apply to upstream's VMS support and could go back to zlib.

## How to build

```sh
git clone https://github.com/issinoho/vms-zlib.git
cd vms-zlib
tools/prepare.sh            # fetch + verify the release, apply patches, add vmsport/
tools/build.sh ia64         # upload, then @[.VMSPORT]BUILD on the node (upstream's make_vms.com)
tools/test.sh ia64          # smoke test
```

By hand on VMS: copy the top-level files of `staging/zlib-1.3.2/` and its `vmsport/` and
`test/` directories, then `@[.VMSPORT]BUILD` and `@[.VMSPORT]TEST_SMOKE`. Set up
`tools/nodes.conf` as described in
[vms-grep's README](https://github.com/issinoho/vms-grep#2b-build-on-vms-from-the-host-over-ssh).

## Roadmap

1. curl for OpenVMS links this library statically ([vms-curl](https://github.com/issinoho/vms-curl)).
2. A PCSI kit for zlib itself, and patches 0001-0002 offered upstream.
3. A port to OpenVMS **Alpha**.

## Artwork

`docs/images/banner.svg` and `docs/images/icon.svg` were made for this project in the style
of classic DECwindows and VT terminals, like those of its sibling ports. The "zlib" mark in
them is our own drawing, not an official zlib logo.

## Licence

zlib is distributed under the zlib licence; see `COPYING`, a copy of upstream's `LICENSE`.
Our patches and VMS build files are distributed under the same terms.

OpenVMS is a trademark of VMS Software, Inc. This project is not affiliated with VMS
Software, Inc. or with the zlib project.
