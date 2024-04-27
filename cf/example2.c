#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

void write_string(const char *str) {
  (void)!write(STDOUT_FILENO, str, strlen(str));
}

void write_strings(const char *str, ...) {
  va_list ap;
  va_start(ap, str);
  do {
    write_string(str);
  } while ((str = va_arg(ap, const char *)) != NULL);
}

int main(int argc, char **argv) {
  char **ep;
  (void)argc; (void)argv;
  write_strings("Hello, World from __OSI__!\r\n",
                "Program name: ", argv[0], "\r\n",
                "Command-line arguments:\r\n", NULL);
  for (ep = argv + 1; *ep; ++ep) {
    write_strings("  ", *ep, "\r\n", NULL);
  }
  write_string("Environment variables:\r\n");
  for (ep = environ; *ep; ++ep) {
    write_strings("  ", *ep, "\r\n", NULL);
  }
  write_string("Bye!\r\n");
  /* exit(15); */
  return 42;  /* Exit code. */
}
