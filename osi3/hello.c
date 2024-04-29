/* This block is not for __OSI__, but other targets and compilers. */
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
#endif

void print_str(const char *str) {
  (void)!write(STDOUT_FILENO, str, strlen(str));
}

int main(int argc, char **argv) {
  (void)argc; (void)argv;
  /* You must wrap string literals ("...") within S(...) before use,
   * otherwise your program will crash.
   */
  print_str(S("Hello, World!\r\n"));
  return 0;
}
