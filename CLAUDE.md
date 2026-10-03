# CLAUDE.md

zlib for OpenVMS (IA64, x86-64), built with zlib's own `make_vms.com`, wrapped by the same
tooling as `~/projects/vms-grep`, `vms-pcre2`, `vms-sed` and `vms-awk` (read vms-grep's
`CLAUDE.md` for the ground rules and VMS/ssh pitfalls; they all apply). In short:

- **Never edit `staging/`, `cache/` or `out/`.** Upstream files change only through
  `patches/` (listed in `patches/series`); our files live in `overlay/vmsport/`.
- **Use `tools/vms.sh`** for remote work; never raw `ssh host cmd`, never `WAIT` over ssh.
- **Committed files must not contain real node details** (they live in `tools/nodes.conf`).
- `make_vms.com` reads `Makefile.in` for its module list (push.sh uploads it).
- The install tree `[.INSTALL_<arch>]` (`ZLIB$ROOT`) is what vms-curl links statically.
- `minigzip` reads/writes raw bytes: test it with Stream_LF files, not VFC.

```sh
tools/prepare.sh
tools/build.sh <ia64|x86> [ALL|CLEAN]
tools/test.sh <node>
```

Don't push without the user asking; the remote is `origin` (github.com/issinoho/vms-zlib),
branch `main`.
