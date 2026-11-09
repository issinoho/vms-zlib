$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the ZLIB kit, verify it,
$! compile and link a program against the installed library, run minigzip
$! from it, then remove it.  Changes the system while it runs (PCSI database,
$! SYS$COMMON:[ZLIB], system logical ZLIB$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ if arch .eqs. "ALPHA" then base = "AXPVMS"
$ if arch .eqs. "VAX" then base = "VMS"
$ here = f$environment("DEFAULT")
$ tree = here - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$! A ZLIB$ROOT left in the process table (from a build) would hide the system one.
$ if f$trnlnm("ZLIB$ROOT", "LNM$PROCESS_TABLE") .nes. "" then deassign/process ZLIB$ROOT
$ write sys$output "=== INSTALL from ", kitdir
$ if arch .eqs. "VAX" then goto install_vax
$ product install ZLIB /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ goto installed
$! PCSI on OpenVMS VAX V7.3 has no /OPTIONS=NOCONFIRM: its questions are
$! answered from the lines below (continue, default options, no review);
$! DCL skips any it does not ask.
$install_vax:
$ define/user_mode sys$command sys$input
$ product install ZLIB /producer=ISSINOHO /base_system='base' /source='kitdir' /log
YES
YES
NO
$installed:
$ write sys$output "=== install status ", $status
$ product show product ZLIB /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:ZLIB$STARTUP.COM"), "]"
$ show logical ZLIB$ROOT
$ directory/nohead/notrail ZLIB$ROOT:[000000...]*.*
$ write sys$output "=== BUILD A PROGRAM AGAINST THE INSTALLED KIT"
$ test_src = tree - "]" + ".VMSPORT.KIT]KIT_TEST.C"
$ cc /include=ZLIB$ROOT:[INCLUDE] /object=kit_test.obj 'test_src'
$ link /executable=kit_test.exe kit_test.obj, ZLIB$ROOT:[LIB]LIBZ.OLB/library
$ run kit_test.exe
$ delete/nolog kit_test.obj;*, kit_test.exe;*
$ write sys$output "=== MINIGZIP FROM THE INSTALLED KIT"
$ minigzip = "$ZLIB$ROOT:[BIN]MINIGZIP.EXE"
$! FDL from a file: an inline /FDL="..." string needs VMS V7.3-1 or later.
$ create mg_stmlf.fdl
RECORD
        FORMAT  STREAM_LF
$ create/fdl=mg_stmlf.fdl mg_test.txt
$ delete/nolog mg_stmlf.fdl;*
$ open/append f mg_test.txt
$ write f "zlib on OpenVMS, compressed and expanded again"
$ close f
$ copy/nolog mg_test.txt mg_orig.txt
$! Each step must succeed: if minigzip were missing, the file would stay
$! unchanged and compare equal.
$ minigzip mg_test.txt
$ mg_ok = $status .and. f$search("mg_test.txt-gz") .nes. ""
$ minigzip "-d" mg_test.txt-gz
$ mg_ok = mg_ok .and. $status
$ differences/nooutput mg_orig.txt mg_test.txt
$ mg_sev = $severity
$ if .not. mg_ok then mg_sev = 2
$ if mg_sev .eq. 1 then write sys$output "MINIGZIP: PASS"
$ if mg_sev .ne. 1 then write sys$output "MINIGZIP: FAIL"
$ delete/nolog mg_orig.txt;*, mg_test.txt;*
$ write sys$output "=== REMOVE"
$ if arch .eqs. "VAX" then goto remove_vax
$ product remove ZLIB /producer=ISSINOHO /options=noconfirm /log
$ goto removed
$remove_vax:
$ define/user_mode sys$command sys$input
$ product remove ZLIB /producer=ISSINOHO /log
YES
$removed:
$ write sys$output "=== remove status ", $status
$ write sys$output "ZLIB$ROOT after removal: [", f$trnlnm("ZLIB$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[ZLIB...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:ZLIB$STARTUP.COM"), "]"
$ product show product ZLIB /producer=ISSINOHO
