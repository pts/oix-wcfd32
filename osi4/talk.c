#ifndef __OSI__  /* Not __OSI__ v3. */
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

extern char **environ;

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
  (void)argc; (void)argv;
  print_strs("Hello, World from __OSI__ v4!\r\n",
             "Program name: ", argv[0], "\r\n",
             "Command-line arguments:\r\n", NULL);
  for (ep = argv + 1; *ep; ++ep) {
    print_strs("  ", *ep, "\r\n", NULL);
  }
  print_str("Environment variables:\r\n");
  for (ep = environ; *ep; ++ep) {
    print_strs("  ", *ep, "\r\n", NULL);
  }
  print_str("Bye!\r\n");
  /* exit(15); */
  return 42;  /* Exit code. */
}
