# POIX: thin compatibility layer for writing extremely portable command-line C programs

POIX is a thin compatibility layer for writing extremely portable
command-line tools in C. POIX supports receiving command-line arguments,
receiving environment variables, doing file I/O, doing I/O with the standard
streams (stdin, stdout, stderr) either as line-based on the console or
redirected to a file, memory allocation (but not freeing), exiting with an
exit code. POIX programs are written in C, they do an `#include "poix1.h"`
in the beginning instead of doing other includes. The result is that the
same C source file is portable to various C compilers, operating systems and
CPU architectures, without having to use `#ifdef`.

POIX has several versions. This document describes version 1, corresponding
to `#include "poix1.h"`.

POIX doesn't contain a C compiler or a libc (C runtime library), but it can
work together with various C compilers and libcs, see the instructions below.

Limitations of POIX:

* POIX is not suitable for porting most existing programs or libraries
  (rather than writing new ones), because they tend to use way too many libc
  functions and they have system-specific `#ifdef`s.
* Only text-mode, noninteractive console programs are supported. (No GUI
  support, no cursor positioning or color support, no text line editing
  support.)
* No support for buffered I/O (e.g. fwrite(...)). But you can add your own.
* No support for formatted output (e.g. printf(...)). But you can add your
  own.
* No support for input format conversion (e.g. scanf(...)). But you can add
  your own.
* No support for signal handling (including Ctrl-*C* and Ctrl-*Break*) or
  CPU exception handling.
* It's not possible to return unused memory to the operating system, i.e.
  there is no free(...) function.
* On some systems it suppots only file seek offsets less than 2 GiB. It
  tries to autodetect 64-bit seek support though.
* Networking (e.g. BSD sockets) is not supported. You may `#include
  <sys/socket.h>`, and it may work, but POIX doesn't help you.
* Variable number of arguments (e.g. *stdarg.h*, va_start(...)) is not
  supported, but you can use your C compiler's `#include <stdarg.h>`.
* Multithreaded programs are not supported.
* Most Unix system calls (e.g. mkdir(...), getpid(...), chroot(..)) are not
  supported.
* POIX is not a program file size optimization tool. If you want to build
  tiny programs for Linux i386, use
  [minilibc686](https://github.com/pts/minilibc686) instead.
* Please note that the *char* type may be signed or unsigned depending on
  the compiler and its settings, POIX doesn't attempt to standardize it.

Program compilation instructions:

* Copy the file *poix.h* next to your C program source file (e.g. *prog.c*).
* Use `#include "poix1.h"` in your C program source file. If you already
  pass `-I.` (or similar) to your C compiler command line, `#include
  <poix1.h>` also works.
* If your program consists of multiple source files, do `#define
  POIX_NO_IMPL` in all of them except for the one containing your main(...)
  function.
* On Unix systems (including Linux, FreeBSD and macOS) with GCC, Clang,
  TinyCC or PCC as the C compiler, and libc installed as usual, you are all
  set, compile your program as usual, e.g. `gcc -s -O2 -W -Wall -o prog
  prog.c.
* You can target macOS x86 (i386 and amd64) on Linux using *osxcross*. The
  recommended easy way is using
  [pts-osxcross](https://github.com/pts/pts-osxcross). The simplest
  command is `pts_osxcross_10.10/i386-apple-darwin14/bin/gcc -O2 -W
  -Wall -o prog prog.c && pts_osxcross_10.10/i386-apple-darwin14/bin/strip
  prog`.
* When targeting Win32 (Windows i386, starting with Windows NT, also
  including Windows 11), use any of:
  * [MinGW](https://sourceforge.net/projects/mingw/files/Installer/) GCC (command `gcc -s -O2 -W -Wall -o prog.exe prog.c`)
  * [mingw-w64](https://www.mingw-w64.org/downloads/) GCC (command `i686-w64-mingw32-gcc -s -O2 -W -Wall -o prog.exe prog.c`)
  * the [OpenWatcom v2 C compiler](https://open-watcom.github.io/) (command `owcc -bwin32 -s -O2 -W -Wall -o prog.exe prog.c`)
  * the [Digital Mars C compiler](https://www.digitalmars.com/download/freecompiler.html) (command `dmc prog.c`)
  * [TinyCC](https://bellard.org/tcc/) (command `tcc -s -o prog.exe prog.c`)
  Other C compilers may also work, but they are untested.
* When targeting OS/2 2.0+, use
  the [OpenWatcom v2 C compiler](https://open-watcom.github.io/) (command `owcc -bos2v2 -s -O2 -W -Wall -o prog.exe prog.c`),
* When targeting 16-bit DOS, use
  the [OpenWatcom v2 C compiler](https://open-watcom.github.io/) (command `owcc -bdos -s -Os -W -Wall -o prog.exe prog.c`),
* When targeting 32-bit DOS, use
  the [OpenWatcom v2 C compiler](https://open-watcom.github.io/) (command `owcc -bdos4g -Wc,-bt=dos32 -s -Os -W -Wall -o prog.exe prog.c`),
  This method is untested, and it needs an additional DOS extender .exe file
  at runtime, or it needs additonal preparation (`-bpmodew` instead of
  `-bdos4g` etc.).

*poix1.h* provides something like this:

```C
/* Integer types. */
typedef ... size_t;  /* Unsigned. */
typedef ... ssize_t;  /* Signed. */
typedef ... off_t;  /* File position. Signed 32 or 64 bit. Size will match _FILE_OFFSET_BITS. */
/*typedef ... mode_t;*/  /* Unsigned. int or shorter. Not always defined. */
typedef unsigned long size_t;
typedef unsigned ... uint8_t;
typedef unsigned ... uint16_t;
typedef unsigned ... uint32_t;
typedef unsigned ... uint64_t;  /* Not always defined. */
typedef signed ... int8_t;
typedef signed ... int16_t;
typedef signed ... int32_t;
typedef signed ... int64_t;  /* Not always defined. */

/* Standard file descriptors (fd) constants. */
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

/* open(2) flags constants. */
#define O_RDONLY 0..  /* This is 1 for __TURBOC__, and 0 or (O_LARGEFILE|0) everywhere else. */
#define O_WRONLY 1..  /* This is 2 for __TURBOC__, and 1 or (O_LARGEFILE|1) everywhere else. */
#define O_RDWR   2..  /* This is 4 for __TURBOC__, and 2 or (O_LARGEFILE|2) everywhere else. */
#define O_CREAT  ...  /* System-specific value at least 4. */
#define O_TRUNC  ...  /* System-specific value at least 4. */
#define O_BINARY ...  /* System-specific value. On Unix, it's 0. */
#define O_LARGEFILE ...  /* System-specific value. Usually it's 0, except for Linux. Pass this to open flags if you want to work with files of >=2 GiB. */

/* File offset helper. */
#define _FILE_OFFSET_BITS ...  /* 32 or 64. You can also predefine it to your desired value. If possible, POIX will honor it. Its value is not reliable, better check sizeof(off_t). */

/* CPU architecture helper. */
#define __i386__  /* Only defined if generating code for the 32-bit protected mode of the Intel i386 CPU (ia32, x86 32-bit architecture). */

/* POSIX file I/O functions. */
int open(const char *pathname, int flags, ...);  /* `...' is either `mode_t mode' or missing, may be ignored, good value: 0666. */
int creat(const char *pathname, mode_t mode);  /* mode may be ignored, good value: 0666. */
int close(int fd);
ssize_t write(int fd, const void *buf, size_t count);
ssize_t read(int fd, void *buf, size_t count);
off_t lseek(int fd, off_t offset, int whence);
int ftruncate(int fd, off_t length);  /* Similar to chsize(...). */
int isatty(int fd);
int remove(const char *pathname);
int unlink(const char *pathname);  /* Same as remove(pathname). */
int rename(const char *oldpath, const char *newpath);

/* Compatibility file I/O functions. */
void set_binmode(int fd);  /* Puts fd to binary mode. Useful for STD*_FILENO. */
int open2(const char *pathname, int flags);  /* Same functionality as the 2-argument open(2). */
int open3(const char *pathname, int flags, mode_t mode);  /* Same functionality as the 2-argument open(2). */
int ftruncate_here(int fd);  /* Same as (but with error handling): ftruncate(fd, lseek(fd, 0, SEEK_CUR)). */

/* POSIX entry and exit functions. */
void exit(int exit_code);  /* Same as _exit(...), there is nothing to autoflush. */
void _exit(int exit_code);  /* At least 8 bits of exit_code is propagated to the caller. Never returns. */
extern int main(int argc, char **v);  /* Your program starts here. */
extern int main(void);  /* Alternative, if you don't need command-line arguments. */

/* POSIX environment. */
extern char **environ;  /* Read-only, NULL-terminated, `KEY=VALUE` pairs. */

/* POSIX file I/O error reporting. */
#define ENOENT  ...  /* Positive integer constant for No such file or directory. */
#define ENOTDIR ...  /* Positive integer constant for Not a directory. */
#define EACCES  ...  /* Positive integer constant for Permission denied. */
#define ENXIO   ...  /* Positive integer constant for No such device or address. Used by POIX as a generic errno value. */
extern into errno;  /* Only open(..) and create(...) are guranteed to set it on error; E... value. */

/* POSIX memory management functions. */
void *malloc(size_t size);  /* Returned pointer is aligned to C long size. Memory is read-write (it may also be read-write-execute), initial contents not defined. There is no way to free memory (except for exiting the process) in POIX. */

/* Compatibility memory management functions. */
void *cealloc(size_t size);  /* Returned pointer is aligned to C long size. Memory is read-write-execute and zero-initialized. */

/* POSIX string functions. */
size_t strlen(const char *s);
void *memcpy(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);

/* <stdarg.h> C89 and C99 variable number of arguments receivers. */
void va_start(va_list ap, last);
type va_arg(va_list ap, type);
void va_end(va_list ap);
void va_copy(va_list dest, va_list src);

/* Helpers. */
#define __extension__ ...  /* For using GCC extensions. */
#define NORETURN ...  /* For declaring that a function doesn't return. DMC (__SC__) uses #pragma instead. */
```

TODOs:

* Write a minilibc implementation of POIX.
* Write an OIX (OSI) implementation of POIX.
* Test all compilers and targets above.
* Check 64-bit seek support everywhere.
* Make O_LARGEFILE automatic on Linux with _FILE_OFFSET_BITS == 64. Neither __WATCOMC__ libc nor __MINILIBC686__ does it.
* Add ftruncate64 for Win32 (SetFileSize) and OS/2 ([DosSetFileSizeL](http://www.edm2.com/index.php/DosSetFileSizeL)).
* What does the UNIX2003 mean in the macOS symbol names \_close$UNIX2003 \_creat$UNIX2003 \_mmap$UNIX2003 \_open$UNIX2003 \_read$UNIX2003 \_write$UNIX2003?

TODOs for version POIX 2:

* A non-POSIX function for making a file executable.
* mkdir(2).
* rmdir(2).
* stat64(2).
* chmod(2).
* utime(2) and utimes(2).
* gettimeofday(2).
* The-related functions for GMT and local time.
