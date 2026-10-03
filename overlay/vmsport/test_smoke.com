$! TEST_SMOKE.COM - check zlib with upstream's test programs
$!
$! Usage:  @[.VMSPORT]TEST_SMOKE
$! Runs EXAMPLE.EXE (zlib's own self-test: compress, gz* file I/O, deflate,
$! inflate, dictionaries) and a MINIGZIP.EXE compress/decompress round trip.
$! Exits with SS$_NORMAL if every check passes.
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ top = f$environment("DEFAULT")
$ pass = 0
$ fail = 0
$ if f$search("SMOKE_TMP.DIR") .eqs. "" then create/directory [.SMOKE_TMP]
$ set default [.SMOKE_TMP]
$ if f$search("*.*;*") .nes. "" then delete/nolog *.*;*
$!
$! 1. example: every step prints its result on stdout; any error goes to
$!    stderr and the program exits with a failure status.
$ example = "$" + top - "]" + "]EXAMPLE.EXE"
$ define/user sys$output example.out
$ define/user sys$error example.err
$ example
$ st = $status
$ errs = 0
$ if f$search("example.err") .nes. "" then errs = f$file_attributes("example.err", "EOF")
$ search/nooutput example.out "uncompress(): hello, hello!"
$ found = $severity .eq. 1
$ if st .and. found .and. errs .eq. 0
$ then
$   write sys$output "PASS EXAMPLE"
$   pass = pass + 1
$ else
$   write sys$output "FAIL EXAMPLE: status ''st', stderr blocks ''errs'"
$   type example.err
$   fail = fail + 1
$ endif
$!
$! 2. minigzip round trip of a multi-record text file.
$ minigzip = "$" + top - "]" + "]MINIGZIP.EXE"
$! minigzip reads and writes raw bytes, so use a Stream_LF file: a VFC file
$! (the default for OPEN/WRITE) would carry its record headers through.
$ create/fdl="RECORD; FORMAT STREAM_LF;" data.txt
$ open/append f data.txt
$ i = 0
$loop:
$ write f "line ''i': the quick brown fox jumps over the lazy dog ''i'"
$ i = i + 1
$ if i .lt. 500 then goto loop
$ close f
$ copy/nolog data.txt orig.txt
$ minigzip data.txt
$! On VMS minigzip names the compressed file with "-gz" (DATA.TXT-GZ).
$ minigzip "-d" data.txt-gz
$ differences/nooutput orig.txt data.txt
$ if $severity .eq. 1
$ then
$   write sys$output "PASS MINIGZIP"
$   pass = pass + 1
$ else
$   write sys$output "FAIL MINIGZIP: round trip differs"
$   fail = fail + 1
$ endif
$!
$ set default 'top'
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ set default 'saved_default'
$ if fail .eq. 0 .and. pass .gt. 0 then exit 1
$ exit 44
