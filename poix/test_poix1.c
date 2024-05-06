/* This doesn't test everything, but at least checks that each function, constant and variable is defined. */

#include "poix1.h"

static void fdputs(const char *msg, int fd) {
  (void)!write(fd, (void*)msg, strlen(msg));
}

/* Use this NORETURN to pacify GCC 4.1 warning about a possibly
 * uninitialized variable after find_cf_header(...) returns.
 */
NORETURN void fatal(char const *msg) {
  fdputs(msg, STDERR_FILENO);
  exit(125);
}
#ifdef __SC__
#  pragma noreturn (fatal)
#endif

int main(int argc, char **argv) {
  static char buf[10];
  struct a {
    size_t s;
    ssize_t ss;
    off_t o;
    uint8_t u8;
    uint16_t u16;
    uint32_t u32;
    /* TODO(pts): Also test uin64_t with a feature test macro. */
    int8_t i8;
    int16_t i16;
    int32_t i32;
  } a = {__extension__ 0, 0, 0, 0, 0, 0, 0, 0, 0};  /* No need for __extension__ here, just demo it. */
  size_t s;
  char *p;
  
  (void)argc; (void)argv; (void)a;
  set_binmode(STDERR_FILENO);
  if (NULL) return 9;
  if (sizeof(a.s) != sizeof(void __near*)) return 10;
  if (sizeof(a.s) < sizeof(int)) return 11;
  if (sizeof(a.s) != sizeof(a.ss)) return 12;
  if (sizeof(a.o) < sizeof(long)) return 13;
  if ((off_t)-1 > 0) return 14;
  if (sizeof(a.u8) != 1) return 15;
  if (sizeof(a.u16) != 2) return 16;
  if (sizeof(a.u32) != 4) return 17;
  if ((uint8_t)-1 < 1) return 18;
  if ((uint16_t)-1 < (long)1) return 19;
  if ((uint32_t)-1 < 1) return 20;
  if (sizeof(a.i8) != 1) return 21;
  if (sizeof(a.i16) != 2) return 22;
  if (sizeof(a.i32) != 4) return 23;
  if ((int8_t)-1 > 0) return 24;
  if ((int16_t)-1 > 0) return 25;
  if ((int32_t)-1 > 0) return 26;
  if (STDIN_FILENO  != 0) return 30;
  if (STDOUT_FILENO != 1) return 31;
  if (STDERR_FILENO != 2) return 32;
  if (EXIT_SUCCESS != 0) return 33;
  if (EXIT_FAILURE != 1) return 34;
  if (SEEK_SET != 0) return 35;
  if (SEEK_CUR != 1) return 36;
  if (SEEK_END != 2) return 37;
#ifdef __TURBOC__
  if (O_RDONLY != 1) return 38;
  if (O_WRONLY != 2) return 39;
  if (O_RDWR   != 4) return 40;
#else
  if ((O_RDONLY & ~O_LARGEFILE) != 0) return 38;
  if ((O_WRONLY & ~O_LARGEFILE) != 1) return 39;
  if ((O_RDWR   & ~O_LARGEFILE) != 2) return 40;
  if (((O_RDONLY | O_WRONLY | O_RDWR)  & ~(O_ACCMODE | O_LARGEFILE)) != 0) return 68;
#endif
  if (O_CREAT <= 0 || (O_CREAT & 3) != 0) return 41;
  if (O_TRUNC <= 0 || (O_TRUNC & 3) != 0) return 42;
  if (O_BINARY < 0) return 43;
  if (O_LARGEFILE < 0) return 43;
  if (argc < 1) return 50;
  for (; *argv; ++argv) {}
  for (argv = environ; *argv; ++argv) {}
  if (argc < - 1) {
    if (open("file", O_RDONLY|O_LARGEFILE)) return -1;
    if (open("file", O_RDONLY|O_LARGEFILE, 0666)) return -1;
  }
  memset(buf, 'x', sizeof(buf) - 1);
  memcpy(buf, "hello", strlen("hello") + 1);
  if (buf[0] != 'h' || buf[1] != 'e' || buf[2] != 'l' || buf[3] != 'l' || buf[4] != 'o' || buf[5] != '\0' || buf[6] != 'x' || buf[7] != 'x' || buf[8] != 'x' || buf[9] != '\0') return 51;
  errno = 0;
  if (errno >= ENOENT || errno >= ENOTDIR || errno >= EACCES || errno >= ENXIO) return 52;
  set_binmode(STDIN_FILENO);
  if (argc < -1) {
    if (open("file", O_RDONLY | O_LARGEFILE) < 0) return -1;
    if (open("file", O_RDONLY | O_LARGEFILE | O_CREAT, 0666) < 0) return -1;
    if (open2("file", O_RDONLY | O_LARGEFILE) < 0) return -1;
    if (open3("file", O_RDONLY | O_LARGEFILE | O_CREAT, 0666) < 0) return -1;
    if (creat("file", 0666) < 0) return -1;
  }
  if (close(-1) != -1) return 53;
#ifdef __TURBOC__  /* -1 would be correct here, __TURBOC__ is mistaken. */
  if (read(-1, buf, sizeof(buf)) > 0) return 54;
  if (write(-1, buf, sizeof(buf)) > 0) return 55;
#else
  if (read(-1, buf, sizeof(buf)) != -1) return 54;
  if (write(-1, buf, sizeof(buf)) != -1) return 55;
#endif
  if (lseek(-1, 0, SEEK_CUR) != (off_t)-1) return 56;
  if (ftruncate(-1, 0) != -1) return 57;
  if (ftruncate_here(-1) != -1) return 58;
  if (isatty(0) & ~1) return 59;
  if (remove("") != -1) return 60;
  if (unlink("") != -1) return 61;
  if (rename("a", "/") != -1) return 62;
  if (argc < 1) fatal("no go\r\n");
  if (argc < 1) exit(9);
  if (argc < 1) _exit(8);
  if ((p = (char*)malloc(42)) == NULL) return 64;
  for (s = 0; s < 42; ++s) {
    p[s] = 'u';
  }
  if (cealloc(0) == NULL) return 65;
  if ((p = (char*)cealloc(43)) == NULL) return 66;
  if ((p = (char*)cealloc(47)) == NULL) return 67;
  for (s = 0; s < 47; ++s) {
    if (p[s] != '\0') return 68;
  }
  for (s = 0; s < 47; ++s) {
    p[s] = 'u';
  }
  fdputs("test_poix1 OK.\r\n", STDERR_FILENO);
  return 0;
}
