#include <stdarg.h>  /* va_arg etc. */
#include <stddef.h>  /* NULL. */
#include "tinyio.h"  /* TinyWrite(...) */

char _DOSseg__;
void __declspec(noreturn) __watcall __exit(int exit_code);
void __declspec(noreturn) __watcall exit(int exit_code) { __exit(exit_code); }
void __cdecl _InitRtns(void) {}
void __cdecl _FiniRtns(void) {}
extern char const *_LpPgmName;
extern char const *_LpCmdLine;
#define STDOUT_FILENO 1
extern char **environ;
/* Use TinyWrite etc. */
/* Use _TinyMemAlloc to allocate memory. For many, do it in >=64 KiB chunks. */

void write_string(const char *str) {
  const char *str0 = str;
  for (; *str != '\0'; ++str) {}  /* Poor man's strlen(...). */
  TinyWrite(STDOUT_FILENO, str0, str - str0);
}

void write_strings(const char *str, ...) {
  va_list ap;
  va_start(ap, str);
  do {
    write_string(str);
  } while ((str = va_arg(ap, const char *)) != NULL);
}

int __cdecl _CMain(void) {  /* __OSI__ entry point. */
  char **ep;
  write_strings("Hello, World!\r\n",
                "Program name: ", _LpPgmName, "\r\n",
                "Command-line arguments: (", _LpCmdLine, ")\r\n",
                "Environment variables:\r\n", NULL);
  for (ep = environ; *ep; ++ep) {
    write_strings("  ", *ep, "\r\n", NULL);
  }
  write_string("Bye!\r\n");
  return 42;  /* Exit code. */
}
