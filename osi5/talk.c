#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

int main(int argc, char **argv) {
  char **ep;
  (void)argc; (void)argv;
  printf("Hello, World from __OSI__ v5 libc!\r\nProgram name: %s\r\nCommand-line arguments:\r\n", argv[0]);
  for (ep = argv + 1; *ep; ++ep) {
    printf("  %s\r\n", *ep);
  }
  printf("Environment variables:\r\n");
  for (ep = environ; *ep; ++ep) {
    printf("  %s\r\n", *ep);
  }
  printf("Bye!\r\n");
  return 42;
}
