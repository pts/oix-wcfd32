#ifndef __OSI__  /* Not __OSI__ v3. */
#  define S(ptr) (ptr)
#  define GSTRUCT(struct_name) (struct_name)
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

/* To use global variables (other than environ), put them into global
 * structs and define a macro with GSTRUCT for them (see in the example
 * below). The struct name and the global variable name must be the same.
 * You can define as many structs as you wish.
 */

struct g1 {
  int empty_count;
  int nonempty_count;
} g1;
#define g1 GSTRUCT(g1)

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

#define FORMAT_DEC_BUF_SIZE (sizeof(int) * 3 + 2)
/* Formats an int as a decimal string into buf. */
void format_dec(int i, char *buf) {
  char *s, c;
  if (i < 0) { *buf++ = '-'; i = -i; }
  s = buf;
  do {
    *s++ = i % 10 + '0';
    i /= 10;
  } while (i != 0);
  *s-- = '\0';
  while (s > buf) {
    c = *s;
    *s-- = *buf;
    *buf++ = c;
  }
}

/* Defined in other.c. Compile with: osicc global.c other.c */
extern int other(void);

int main(int argc, char **argv) {
  char const *crlf;
  char **ep;
  char empty_count_buf[FORMAT_DEC_BUF_SIZE];
  char nonempty_count_buf[FORMAT_DEC_BUF_SIZE];
  (void)argc;
  for (ep = argv + 1; *ep; ++ep) {
    if (**ep == '\0') {
      /* A local variable would also work. */
      ++g1.empty_count;
    } else {
      ++g1.nonempty_count;
    }
  }
  format_dec(g1.empty_count, empty_count_buf);
  format_dec(g1.nonempty_count, nonempty_count_buf);
  /* In DOS, "\n" alone doesn't do a proper newle, "\r\n" is needed. */
  crlf = S(isatty(STDOUT_FILENO) ? "\r\n" : "\n");
  print_strs(S("Argument count: empty="), empty_count_buf,
             S(" nonempty="), nonempty_count_buf, crlf, NULL);
  return other();  /* Exit code. */
}
