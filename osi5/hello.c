#include <stdio.h>

int main(int argc, char **argv) {
  (void)argc; (void)argv;
  /* Using fputs(...) instead of puts(...) so that we can ensure that "\r"
   * is printed.
   */
  fputs("Hello, World!\r\n", stdout);
  return 0;
}
