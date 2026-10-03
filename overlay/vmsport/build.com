$! BUILD.COM - build zlib for OpenVMS with upstream's MAKE_VMS.COM
$!
$! Usage:  @[.VMSPORT]BUILD [target]
$!         target defaults to ALL; CLEAN deletes the build products.
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
$ write sys$output "BUILD: ''target' for ''arch' in ''f$environment("DEFAULT")'"
$ if target .eqs. "CLEAN"
$ then
$   if f$search("*.OBJ;*") .nes. "" then delete/nolog *.OBJ;*
$   if f$search("*.EXE;*") .nes. "" then delete/nolog *.EXE;*
$   if f$search("LIBZ.OLB;*") .nes. "" then delete/nolog LIBZ.OLB;*
$   if f$search("*.OPT;*") .nes. "" then delete/nolog *.OPT;*
$   if f$search("[.INSTALL_''arch'...]*.*;*") .nes. "" then -
        delete/nolog [.INSTALL_'arch'...]*.*;*
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
$finish:
$ write sys$output "BUILD: done"
$done:
$ set default 'saved_default'
$ exit status
