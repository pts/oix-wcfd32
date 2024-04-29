#include <stdio.h>
#ifdef __TURBOC__
#  include <io.h>  /* isatty(...). */
#else
#  include <unistd.h>  /* isatty(...). */
#endif

int empty_count;
int nonempty_count;

/* Defined in other.c. Compile with: osicc global.c other.c */
extern int other(void);

int main(int argc, char **argv) {
  char const *crlf;
  char **ep;
  (void)argc;
  for (ep = argv + 1; *ep; ++ep) {
    if (**ep == '\0') {
      /* A local variable would also work. */
      ++empty_count;
    } else {
      ++nonempty_count;
    }
  }
  /* In DOS, "\n" alone doesn't do a proper newle, "\r\n" is needed. */
  crlf = isatty(fileno(stdout)) ? "\r\n" : "\n";
  printf("Argument count: empty=%d nonempty=%d%s",
         empty_count, nonempty_count, crlf);
  return other();  /* Exit code. */
}
