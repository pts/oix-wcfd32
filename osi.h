/* This file contains a formal descriptions on the POSIX C functions that
 * can be built on top of the OIX syscall API.
 */

typedef int ssize_t;
typedef long off_t;  /* 32 bits. */
typedef unsigned long size_t;
typedef unsigned mode_t;

typedef char assert_osi_sizeof_int[sizeof(int) == 4 ? 1 : -1];
typedef char assert_osi_sizeof_long[sizeof(long) == 4 ? 1 : -1];

/* fd constants. */
#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

/* exit(2) exit_code constants. */
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1

/* lseek(2) whence constants. */
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

/* open(2) flags cnstants. */
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR   2
#define O_CREAT  0100   /* Not all systems have this value, using this breaks binary compatibility. */
#define O_TRUNC  01000  /* Not all systems have this value, using this breaks binary compatibility. */

void *malloc(size_t size);  /* Returned pointer is aligned to 4. Returns read-write-execute memory. There is no way to free memory (except for exiting the process). */

extern int errno; /* Has with DOS--OS/2 error codes. */
extern char **environ;

/* POSIX functions. */
void exit(int exit_code);  /* Same as _exit(...), there is nothing to autoflush. */
void _exit(int exit_code);
ssize_t write(int fd, const void *buf, size_t count);
ssize_t read(int fd, void *buf, size_t count);
off_t lseek(int fd, off_t offset, int whence);
int ftruncate(int fd, off_t length);
int creat(const char *pathname, mode_t mode);
int open(const char *pathname, int flags, ...);
int close(int fd);
int remove(const char *pathname);
int unlink(const char *pathname);  /* Same as remove(pathname). */
int rename(const char *oldpath, const char *newpath);
int isatty(int fd);

/* Non-POSIX functions. */
int open2(const char *pathname, int flags);  /* Same functionality as the 2-argument open(2). */
int open3(const char *pathname, int flags, mode_t mode);  /* Same functionality as the 2-argument open(2). */
int ftruncate_here(int fd, off_t length);  /* Same as (but with error handling): ftruncate(fd, lseek(fd, 0, SEEK_CUR)). */
