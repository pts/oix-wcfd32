#ifndef __OSI__  /* Not __OSI__ v3. */
#  define S(ptr) (ptr)
#  include <fcntl.h>
#  include <stdarg.h>
#  include <stdlib.h>
#  include <string.h>
#  ifdef __TURBOC__
#    include <io.h>
#  else
#    include <unistd.h>
#  endif
#  ifndef STDOUT_FILENO
#    define STDOUT_FILENO 1
#  endif
  extern char **environ;
#endif

/* You must wrap string literals ("...") within G(...) upon each use.
 * Otherwise your program will crash.
 *
 * If you want to use global variables other than environ, see GSTRUCT in
 * global.c for how. Without that, your program will crash.
 */

void print_str(const char *str) {
  (void)!write(STDOUT_FILENO, str, strlen(str));
}

void print_strs(const char *str, ...) {
  va_list ap;
  va_start(ap, str);
  do {
    print_str(str);
  } while ((str = va_arg(ap, const char *)) != NULL);
}

int main(int argc, char **argv) {
  char **ep;
  (void)argc;
  print_strs(S("Hello, World from __OSI__ v3!\r\n"),
             S("Program name: "), argv[0], S("\r\n"),
             S("Command-line arguments:\r\n"), NULL);
  for (ep = argv + 1; *ep; ++ep) {
    print_strs(S("  "), *ep, S("\r\n"), NULL);
  }
  print_str(S("Environment variables:\r\n"));
  for (ep = environ; *ep; ++ep) {
    print_strs(S("  "), *ep, S("\r\n"), NULL);
  }
  return 42;  /* Exit code. */
}
