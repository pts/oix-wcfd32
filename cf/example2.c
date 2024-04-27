#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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
  print_strs("Hello, World from __OSI__!\r\n",
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
