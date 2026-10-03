$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the ZLIB kit, verify it,
$! compile and link a program against the installed library, run minigzip
$! from it, then remove it.  Changes the system while it runs (PCSI database,
$! SYS$COMMON:[ZLIB], system logical ZLIB$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ here = f$environment("DEFAULT")
$ tree = here - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$! A ZLIB$ROOT left in the process table (from a build) would hide the system one.
$ if f$trnlnm("ZLIB$ROOT", "LNM$PROCESS_TABLE") .nes. "" then deassign/process ZLIB$ROOT
$ write sys$output "=== INSTALL from ", kitdir
$ product install ZLIB /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
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
$ create/fdl="RECORD; FORMAT STREAM_LF;" mg_test.txt
$ open/append f mg_test.txt
$ write f "zlib on OpenVMS, compressed and expanded again"
$ close f
$ copy/nolog mg_test.txt mg_orig.txt
$ minigzip mg_test.txt
$ minigzip "-d" mg_test.txt-gz
$ differences/nooutput mg_orig.txt mg_test.txt
$ mg_sev = $severity
$ if mg_sev .eq. 1 then write sys$output "MINIGZIP: PASS"
$ if mg_sev .ne. 1 then write sys$output "MINIGZIP: FAIL"
$ delete/nolog mg_orig.txt;*, mg_test.txt;*
$ write sys$output "=== REMOVE"
$ product remove ZLIB /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "ZLIB$ROOT after removal: [", f$trnlnm("ZLIB$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[ZLIB...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:ZLIB$STARTUP.COM"), "]"
$ product show product ZLIB /producer=ISSINOHO
