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

/* Global variables also work. */
int empty_count;
int nonempty_count;

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
      ++empty_count;
    } else {
      ++nonempty_count;
    }
  }
  format_dec(empty_count, empty_count_buf);
  format_dec(nonempty_count, nonempty_count_buf);
  /* In DOS, "\n" alone doesn't do a proper newle, "\r\n" is needed. */
  crlf = isatty(STDOUT_FILENO) ? "\r\n" : "\n";
  print_strs("Argument count: empty=", empty_count_buf,
             " nonempty=", nonempty_count_buf, crlf, NULL);
  return other();  /* Exit code. */
}
