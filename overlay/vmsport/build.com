$! BUILD.COM - build zlib for OpenVMS with upstream's MAKE_VMS.COM
$!
$! Usage:  @[.VMSPORT]BUILD [target] [CLANG]
$!         target defaults to ALL; CLEAN deletes the build products.
$!         CLANG (x86-64 only) also compiles the library with VSI's clang into
$!         [.OBJ_X86_64_CLANG] and [.INSTALL_X86_64_CLANG], for programs built
$!         with clang: it is LP64 (long and pointers 64-bit) where VSI C is
$!         ILP32, so the two kinds of object cannot be mixed (vms-php, as
$!         vms-pcre2's clang variant serves vms-mariadb).
$!
$! zlib ships its OpenVMS build (MAKE_VMS.COM) in the release tarball; this
$! procedure runs it from the top of the tree, then lays out the install tree
$! that other ports build against:
$!     [.INSTALL_<arch>.INCLUDE]ZLIB.H, ZCONF.H
$!     [.INSTALL_<arch>.LIB]LIBZ.OLB
$! Point ZLIB$ROOT (a rooted logical) at [.INSTALL_<arch>.] to use it.
$!
$ status = 44
$ on control_y then goto done
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ target = f$edit(p1, "UPCASE")
$ if target .eqs. "" then target = "ALL"
$ variant = f$edit(p2, "UPCASE")
$ if variant .eqs. "CLANG" .and. arch .nes. "X86_64"
$ then
$   write sys$error "BUILD: CLANG needs x86-64"
$   goto done
$ endif
$ write sys$output "BUILD: ''target' for ''arch' ''variant' in ''f$environment("DEFAULT")'"
$ if target .eqs. "CLEAN"
$ then
$   if f$search("*.OBJ;*") .nes. "" then delete/nolog *.OBJ;*
$   if f$search("*.EXE;*") .nes. "" then delete/nolog *.EXE;*
$   if f$search("LIBZ.OLB;*") .nes. "" then delete/nolog LIBZ.OLB;*
$   if f$search("*.OPT;*") .nes. "" then delete/nolog *.OPT;*
$   if f$search("[.INSTALL_''arch'...]*.*;*") .nes. "" then -
        delete/nolog [.INSTALL_'arch'...]*.*;*
$   if f$search("[.OBJ_X86_64_CLANG]*.*;*") .nes. "" then delete/nolog [.OBJ_X86_64_CLANG]*.*;*
$   if f$search("[.INSTALL_X86_64_CLANG...]*.*;*") .nes. "" then -
        delete/nolog [.INSTALL_X86_64_CLANG...]*.*;*
$   status = 1
$   goto finish
$ endif
$! Upstream's procedure; P1 selects the builder.
$ @make_vms.com MMS
$ status = $status
$ if f$search("LIBZ.OLB") .eqs. ""
$ then
$   write sys$error "BUILD: MAKE_VMS.COM did not produce LIBZ.OLB"
$   status = 44
$   goto done
$ endif
$ inst = "[.INSTALL_''arch'"
$ if f$search("INSTALL_''arch'.DIR") .eqs. "" then create/directory 'inst']
$ if f$search("''inst']INCLUDE.DIR") .eqs. "" then create/directory 'inst'.INCLUDE]
$ if f$search("''inst']LIB.DIR") .eqs. "" then create/directory 'inst'.LIB]
$ copy/nolog zlib.h,zconf.h 'inst'.INCLUDE]
$ copy/nolog LIBZ.OLB 'inst'.LIB]
$ purge/nolog 'inst'...]
$ status = 1
$ if variant .eqs. "CLANG" then gosub clang_build
$finish:
$ write sys$output "BUILD: done"
$done:
$ set default 'saved_default'
$ exit status
$!
$! The same library sources with clang, against the zconf.h MAKE_VMS.COM
$! configured above; the header's types follow the compiler, so the result is
$! LP64 throughout.  Also links example and minigzip for TEST_SMOKE CLANG.
$clang_build:
$ clang :== $sys$system:clang.exe
$! keep the case of clang's arguments (-D...) and show its diagnostics
$ set process/parse_style=extended
$ define/process decc$argv_parse_style enable
$ define/user sys$error sys$output
$ cflags = "-std=gnu99 -O2 -pointer-size=argv64 -D_LARGEFILE -D_USE_STD_STAT -I."
$ obj = "[.OBJ_X86_64_CLANG]"
$ if f$search("OBJ_X86_64_CLANG.DIR") .eqs. "" then create/directory 'obj'
$ if f$search("''obj'LIBZ.OLB") .nes. "" then delete/nolog 'obj'LIBZ.OLB;*
$ library/create/object 'obj'LIBZ.OLB
$ srcs = "adler32,compress,crc32,deflate,gzclose,gzlib,gzread,gzwrite,infback,inffast,inflate,inftrees,trees,uncompr,zutil"
$ i = 0
$clang_loop:
$ s = f$element(i, ",", srcs)
$ if s .eqs. "," then goto clang_lib_done
$ define/user sys$error sys$output
$ clang 'cflags' -c 's'.c -o 'obj''s'.obj
$ if .not. $status
$ then
$   write sys$error "BUILD: clang failed on ''s'.c"
$   status = 44
$   return
$ endif
$ library/insert/object 'obj'LIBZ.OLB 'obj''s'.obj
$ i = i + 1
$ goto clang_loop
$clang_lib_done:
$ define/user sys$error sys$output
$ clang 'cflags' -c [.test]example.c -o 'obj'example.obj
$ link/executable='obj'EXAMPLE.EXE 'obj'example.obj,'obj'LIBZ.OLB/library
$ define/user sys$error sys$output
$ clang 'cflags' -c [.test]minigzip.c -o 'obj'minigzip.obj
$ link/executable='obj'MINIGZIP.EXE 'obj'minigzip.obj,'obj'LIBZ.OLB/library
$ cinst = "[.INSTALL_X86_64_CLANG"
$ if f$search("INSTALL_X86_64_CLANG.DIR") .eqs. "" then create/directory 'cinst']
$ if f$search("''cinst']INCLUDE.DIR") .eqs. "" then create/directory 'cinst'.INCLUDE]
$ if f$search("''cinst']LIB.DIR") .eqs. "" then create/directory 'cinst'.LIB]
$ copy/nolog zlib.h,zconf.h 'cinst'.INCLUDE]
$ copy/nolog 'obj'LIBZ.OLB 'cinst'.LIB]
$ purge/nolog 'cinst'...],'obj'
$ write sys$output "BUILD: clang library ''obj'LIBZ.OLB, install tree ''cinst']"
$ return
