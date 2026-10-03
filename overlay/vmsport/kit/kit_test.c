/* kit_test.c - compiled and linked against an installed zlib kit by
   tools/vms_installcheck.com, to check that the headers and object library
   in ZLIB$ROOT work for a program built the documented way.  */
#include <stdio.h>
#include <string.h>
#include <zlib.h>

int
main (void)
{
  static const char text[] =
    "OpenVMS OpenVMS OpenVMS OpenVMS OpenVMS OpenVMS OpenVMS OpenVMS";
  unsigned char packed[256], unpacked[256];
  uLongf plen = sizeof packed, ulen = sizeof unpacked;
  int rc1 = compress2 (packed, &plen, (const Bytef *) text, sizeof text, 9);
  int rc2 = uncompress (unpacked, &ulen, packed, plen);
  int ok = rc1 == Z_OK && rc2 == Z_OK && ulen == sizeof text
           && memcmp (text, unpacked, ulen) == 0 && plen < sizeof text;
  printf ("KIT_TEST: %s (zlib %s, %d -> %lu -> %lu bytes)\n",
          ok ? "PASS" : "FAIL", zlibVersion (), (int) sizeof text,
          (unsigned long) plen, (unsigned long) ulen);
  return ok ? 0 : 1;
}
