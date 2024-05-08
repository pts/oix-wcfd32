/*
 * poix1.h: thin compatibility layer for writing extremely portable command-line C programs, version 1
 * by pts@fazekas.hu at Mon May  6 10:14:29 CEST 2024
 *
 * See the documentation in poix1.md.
 */

#ifndef _POIX1_H
#define _POIX1_H 1

#ifndef _FILE_OFFSET_BITS
#  define _FILE_OFFSET_BITS 64  /* Glibc sys/types.h and <unistd.h> respect it. */
#endif

#ifndef __extension__
#  if defined(__GNUC__)
#    define __extension__ __extension__
#  else
#    define __extension__
#  endif
#endif

#ifndef __inline__
#  if defined(__GNUC__) || defined(__TINYC__)
#    define __inline__ __inline__
#  else
#    if defined(__WATCOMC__) || defined(__SC__)
#      define __inline__ __inline
#    else
#      define __inline__
#    endif
#  endif
#endif

#ifndef NORETURN
#  if defined(__GNUC__) || defined(__TINYC__)
#    define NORETURN __attribute__((__noreturn__))
#  else
#    ifdef __WATCOMC__
#      define NORETURN __declspec(noreturn)
#    else
#      define NORETURN
#    endif
#  endif
#endif

#if !defined(POIX_INLINE)
#  define POIX_INLINE  /* Recommended value for inlining: static __inline__ */
#endif

#if defined(__LINUX__) && !defined(__linux__)  /* __WATCOMC__ may have it. */
#  define __linux__ 1
#endif

#if defined(__NT__) && !defined(_WIN32)  /* __WATCOMC__ may have it. */
#  define _WIN32
#endif

#if !defined(MSDOS) && (defined(__DOS__) || defined(__DOS32__) || defined(__MSDOS__))  /* __WATCOMC__ may have either. */
#  ifndef MSDOS
#    define MSDOS
#  endif
#endif

#if !defined(__DOS16__) && defined(MSDOS) && !defined(__DOS32__) && (defined(__TINY__) || defined(__SMALL__) || defined(__MEDIUM__) || defined(__COMPACT__) || defined(__LARGE__) || defined(__HUGE__))
#  define __DOS16__  /* Not a standard macro. */
#endif

#ifdef MSDOS
#  define POIX_CEALLOC_MALLOC
#endif

#if defined(_WIN32) || defined(MSDOS) || defined(__OS2__) || defined(POIX_CEALLOC_MALLOC)
#  undef POIX_CEALLOC_SBRK  /* These systems don't have a working sbrk(2). */
#endif

#ifndef __i386__
#  if (defined(__i386) || defined(i386) || defined(__386) || defined(_M_I386) || defined(__386__)) || (defined(__SC__) && __INTSIZE == 4 && !_M_AMD64)
#    define __i386__ 1
#  endif
#endif

#if !defined(__WATCOMC_LIBC__) && defined(__WATCOMC__) && !defined(__OSI__) && !defined(__MINILIBC686__)  /* Please note that __MINILIBC686__ has to be defined manually. */
#  define __WATCOMC_LIBC__ 1
#endif

#ifdef POIX_NO_INCLUDE
#  ifdef POIX_INCLUDE
#    undef POIX_NO_INCLUDE
#  endif
#else
#  ifndef POIX_INCLUDE
#    if defined(__TINYC__) && defined(__i386__) && defined(__linux__)  /* Typically _WIN32, __linux__ or __FreeBSD__. */
#      define POIX_NO_INCLUDE
#    else
#      define POIX_INCLUDE
#    endif
#  endif
#endif

#if !defined(__SIZEOF_LONG_LONG__) && (defined(__i386__) || defined(__x86_64__)) && (defined(__GNUC__) || defined(__TINYC__) || defined(__WATCOMC__) || defined(__SC__))
#  define __SIZEOF_LONG_LONG__ 8
#endif
#if !defined(__SIZEOF_INT__) && (defined(__i386__) || (defined(__SC__) && __INTSIZE == 4)) || defined(__DOS32__)
#  define __SIZEOF_INT__ 4
#endif
#if !defined(__SIZEOF_INT__) && (defined(__WATCOMC__) && defined(_M_I86)) || defined(__DOS16__)   /* _M_I86 is used in <stdint.h> of __WATCOMC_LIBC__. */
#  define __SIZEOF_INT__ 2
#endif

#ifndef POIX_NO_INCLUDE
  /* Make functions like sbrk(2) available with GCC. */
  #define _DEFAULT_SOURCE  /* For sbrk(2) on Linux with glibc. */
  #define _XOPEN_SOURCE 500  /* For sbrk(2) on Linux with glibc. */
  #define _SVID_SOURCE  /* For sbrk(2) on Linux with glibc. */
  #define _DARWIN_C_SOURCE  /* For MAP_ANON in MacOSX10.10.sdk/usr/include/sys/mman.h . */
  #define _LINUX_SOURCE  /* For _lseeki64 on Linux i386 with __WATCOMC__. */
  #define _POSIX_SOURCE  /* For OpenWatcom to define _exit with -std=c99. */
#endif

#if defined(POIX_NO_INCLUDE) || (defined(__TURBOC__) && defined(__DOS16__))  /* No <stdint.h> for Turbo C. */
  typedef unsigned char uint8_t;
  typedef unsigned short uint16_t;
  typedef signed char int8_t;
  typedef short int16_t;
#  if __SIZEOF_INT__ == 4 || __SIZEOF_LONG__ > 4
    typedef unsigned int uint32_t;
    typedef int int32_t;
#  else
    typedef unsigned long uint32_t;
    typedef long int32_t;
#  endif
#  if __SIZEOF_LONG_LONG__ == 8
#    define UINT64_MAX 9223372036854775807ULL
    __extension__ typedef unsigned long long uint64_t;
    __extension__ typedef long long int64_t;
#  else
#    define UINT64_MAX 9223372036854775807UL
      __extension__ typedef unsigned long uint64_t;
      __extension__ typedef long int64_t;
#  endif
#else
#  include <stdint.h>
#endif

#if _FILE_OFFSET_BITS == 64 && (!defined(UINT64_MAX) || defined(__SC__) || defined(MSDOS))  /* DMC 8.57c doesn't have a 64-bit seek function. TODO(pts): Use the SetFileSize(...) Win32 API call with get_osfhandle(...). Also DosSetFileSizeL(...) for OS/2. */
#  undef  _FILE_OFFSET_BITS
#  define _FILE_OFFSET_BITS 32
#endif

#ifdef POIX_NO_INCLUDE
#  ifdef __TURBOC__
#    define O_RDONLY 1
#    define O_WRONLY 2
#    define O_RDWR 4
#    define O_ACCMODE 7
#  else
#    define O_RDONLY 0
#    define O_WRONLY 1
#    define O_RDWR 2
#    define O_ACCMODE 3
#  endif
#  if defined(__linux__) || defined(__OSI__)  /* Just to make sure <fcntl.h> doesn't define other values. */
#    define O_CREAT 0100  /* Non-Linux systems have different values. */
#    define O_TRUNC 01000
#    define O_BINARY 0  /* Incorrect include path for __WATCOMC_LIBC__ has a different value. */
#  endif
#  if defined(__FreeBSD__) || defined(__APPLE__)  /* Just to make sure <fcntl.h> doesn't define other values. */
#    define O_CREAT 0x0200  /* Non-Linux systems have different values. */
#    define O_TRUNC 0x0400
#    define O_BINARY 0  /* Incorrect include path for __WATCOMC_LIBC__ has a different value. */
#  endif
#  if defined(__WATCOMC_LIBC__) && !defined(__linux__) && !defined(__FreeBSD__) && !defined(__APPLE__) && !defined(__OSI__)
#    define O_CREAT 0x0020  /* create new file */
#    define O_TRUNC 0x0040  /* truncate existing file */
#    define O_BINARY 0x0200  /* binary file */
#  endif
#  if !defined(__WATCOMC_LIBC__) && (defined(_WIN32) || defined(MSDOS))  /* __TINYCC_, mingw-w64, __SC__ targeting Win32; Turbo C 1.01 targeting DOS. */
#    define O_CREAT 0x0100
#    define O_TRUNC 0x0200
#    define O_BINARY 0x8000
#  endif
#  ifdef __OSI__
    int open2(const char *pathname, int flags);
    int open3(const char *pathname, int flags, unsigned mode);
#  endif
#else
#  include <fcntl.h>  /* O_... constants and open(2). */
#endif
#ifndef __OSI__
#  define open2(pathname, flags) open(pathname, flags)
#  define open3(pathname, flags, mode) open(pathname, flags)
#endif
#ifndef O_ACCMODE
#  ifdef __TURBOC__
#    define O_ACCMODE 7
#  else 
#    define O_ACCMODE 3
#  endif
#endif
#if (!defined(__TURBOC__) && (O_RDONLY != 0 || O_WRONLY != 1 || O_RDWR != 2 || O_ACCMODE != 3)) || (defined(__TURBOC__) && (O_RDONLY != 1 || O_WRONLY != 2 || O_RDWR != 4 || O_ACCMODE != 7))
#  error Bad O_* constants.
#endif
#if !defined(O_LARGEFILE)
#  if defined(__linux__)
#    define O_LARGEFILE 0100000
#    undef  O_RDONLY
#    define O_RDONLY (O_LARGEFILE|0)
#    undef  O_WRONLY
#    define O_WRONLY (O_LARGEFILE|1)
#    undef  O_RDWR
#    define O_RDWR   (O_LARGEFILE|2)
#  else
#    define O_LARGEFILE 0
#  endif
#endif
#if _FILE_OFFSET_BITS < 64
#  undef  O_LARGEFILE
#  define O_LARGEFILE 0
#endif
#ifndef   O_BINARY
#  define O_BINARY 0
#endif

#ifdef POIX_NO_INCLUDE
#  if defined(__WATCOMC_LIBC__) && !defined(__linux__) && !defined(__FreeBSD__) && !defined(__OSI__)
#    define ENOENT 1
#    define ENOTDIR 23
#    define EACCES 6
#    define ENXIO 27
#    define ERANGE 14
#  else  /* Typical values, including Linux and FreeBSD. */
#    ifdef __TURBOC__
#      define ENOENT 2
#      define ENOTDIR 120  /* Fake. */
#      define EACCES 5
#      define ENXIO 121  /* Fake. */
#      define ERANGE 34
#    else  /* Linux, FreeBSD, macOS, iBCS2, Win32 MSVCRT.DLL. */
#      define ENOENT 2
#      define ENOTDIR 20
#      define EACCES 13
#      define ENXIO 6
#      define ERANGE 34
#    endif
#  endif
#  if defined(__WATCOMC_LIBC__) && !defined(errno)
    int *__get_errno_ptr(void);
#    define errno (*__get_errno_ptr())
#  else
    extern int errno;  /* In glibc it's the __errno_location() function, but we can't know without an `#include'. */
#  endif
#else
#  include <errno.h>  /* The errno variable and the E... constants. `extern int errno;' doesn't work everywhere, because errno may be thread-local. */
#  if !defined(POIX_ANY_E) && (defined(__linux__) || defined(__FreeBSD__) || (defined(_WIN32) && !defined(__WATCOMC__))) && (ENOENT != 2 || ENOTDIR != 20 || EACCES != 13 || ENXIO != 6 || ERANGE != 34)
#    error Bad E* constants.  /* Typically with __WATCOMC_LIBC__ and bad -I"$WATCOM/lh" not specified, so the incorrect -I"$WATCOM/h" is used. */
#  endif
#  if defined(__TURBOC__) && ENOTDIR<0
#    undef  ENOTDIR
#    define ENOTDIR 120
#  endif
#  if defined(__TURBOC__) && ENXIO<0
#    undef  ENOTDIR
#    define ENOTDIR 121
#    undef  ENXIO
#    define ENXIO 121
#  endif
#endif

#ifdef USE_POSIX_CONSTANTS  /* Just for debugging, dump the values with `gcc -E' */
/* Linux (GCC, OpenWatcom v2 Linux i386): const int posix_constants[] = {0100, 01000, 2, 20, 13};
 * Linux in hex: const int posix_constants[] = {0x40, 0x200, 2, 20, 13};
 * OpenWatcom v2 Win32, 32-bit DOS, OS/2 2.0+: const int posix_constants[] = {0x0020, 0x0040, 1, 23, 6};
 * Digital Mars C compiler, mingw-w64, TinyCC i386-win-tcc for Win32: const int posix_constants[] = {0x100, 0x200, 2, 20, 13};
 * FreeBSD 9.3 and 3.0: int posix_constants[] = {0x0200, 0x0400, 2, 20, 13};
 * IBCS2: int posix_constants[] = {0x100, 0x200, 2, 20, 13};
 * Turbo C 1.01: int posix_constants[] = {0x100, 0x200, 2, -1, 5};
 */
const int posix_constants[] = {O_CREAT, O_TRUNC, ENOENT, ENOTDIR, EACCES};
#endif

#ifdef POIX_NO_INCLUDE
#  ifdef __SIZE_TYPE__  /* GCC 4.8 already has it. */
    typedef __SIZE_TYPE__ size_t;
#    ifdef __clang__
#      pragma clang diagnostic push
#      pragma clang diagnostic ignored "-Wkeyword-macro"
#      define unsigned signed
#      pragma clang diagnostic pop
#    else
#      define unsigned signed
#    endif
    typedef __SIZE_TYPE__ ssize_t;
#    undef unsigned
#  else
#    if defined(__i386__) || defined(__DOS16__)  /* Even with the __HUGE__ model, __WATCOMC__ and __TURBOC__ defines size_t to be the same as int. */
#      define __SIZE_TYPE__ int
      typedef unsigned size_t;
      typedef int ssize_t;
#    else
#      if defined(__SC__) && _M_AMD64  /* Taken from its include/stddef.h */
#      define __SIZE_TYPE__ long long
        typedef unsigned long long size_t;
        typedef long long size_t;
#      else
#      define __SIZE_TYPE__ long
        typedef unsigned long size_t;
        typedef long ssize_t;
#      endif
#    endif
#  endif
#  define NULL ((void*)0)
#  if _FILE_OFFSET_BITS == 64
#    define __REDEFINE_OFF_T_TO_INT64_T  /* Later, after we've defined mmap(...). */
#  endif
  typedef long off_t;
#else
#  include <stddef.h>  /* NULL, size_t, ssize_t. */
#  if defined(__SC__) || defined(__TURBOC__)  /* __SC__ and __TURBOC__ don't define ssize_t. */
#    if _M_AMD64
      typedef long long ssize_t;
#    else
      typedef int ssize_t;
#    endif
#  endif
#endif

#ifdef POIX_NO_INCLUDE
#  if _FILE_OFFSET_BITS == 64 && !(defined(__FreeBSD__) || defined(__APPLE__))  /* lseek(...) and ftruncate(...) are already 64 bits, there are no ...64(...) functions. */
#    if defined(__WATCOMC_LIBC__) || defined(_WIN32)
      long long  _lseeki64(int fd, int64_t offset, int whence);
#      define lseek(fd, offset, whence) _lseeki64(fd, offset, whence)
#    else
      int64_t lseek64(int fildes, int64_t offset, int whence);
#      define lseek(fd, offset, whence) lseek64(fd, offset, whence)
#    endif
#    if defined(__OS2__) || defined(_WIN32) || defined(MSDOS)
      int chsize(int fd, long length);  /* There is no 64-bit chsize in __WATCOMC_LIBC__ libc or in MSVCRT.DLL. */
#      define ftruncate(fd, size) chsize(fd, size)
#    else
      int ftruncate64(int fd, int64_t length);
#      define ftruncate(fd, size) ftruncate64(fd, size)
#    endif
#  else
    off_t lseek(int fd, off_t offset, int whence);
#    if defined(__OS2__) || defined(_WIN32) || defined(MSDOS)
      int chsize(int fd, long length);
#      define ftruncate(fd, size) chsize(fd, size)
#    else
      int ftruncate(int fd, off_t length);
#    endif
#  endif
  int open(const char *pathname, int flags, ...);  /* `...' is either `mode_t mode' or missing, may be ignored, good value: 0666. */
  int creat(const char *pathname, unsigned mode);  /* mode may be ignored, good value: 0666. */
  int close(int fd);
  ssize_t write(int fd, const void *buf, size_t count);
  ssize_t read(int fd, void *buf, size_t count);
  int isatty(int fd);
  int unlink(const char *pathname);  /* Same as remove(pathname). */
  int rename(const char *oldpath, const char *newpath);
  NORETURN void _exit(int exit_code);  /* At least 8 bits of exit_code is propagated to the caller. Never returns. */
#  ifdef __SC__
#    pragma noreturn (_exit)
#  endif
#  define remove(pathname) unlink(pathname)  /* TODO(pts): Create inline functions instead of these #defines, for better namespacing. */
#  ifdef __OSI__
    int ftruncate_here(int fd);
#  endif
#  if defined(_WIN32) || defined(MSDOS)
    int setmode(int fd, int mode);
#  endif
#else
#  if defined(__OS2__) || defined(_WIN32) || defined(MSDOS)
#    include <io.h>
#    define ftruncate(fd, size) chsize(fd, size)  /* There is no 64-bit chsize in __WATCOMC_LIBC__ libc or in MSVCRT.DLL. */
#    if _FILE_OFFSET_BITS == 64
#      define __REDEFINE_OFF_T_TO_INT64_T  /* Later, after we've defined mmap(...). */
#      if defined(__WATCOMC_LIBC__)
#        define lseek(fd, offset, whence) _lseeki64(fd, offset, whence)
#      else
#        define lseek(fd, offset, whence) lseek64(fd, offset, whence)
#      endif
#    endif
#    if defined(__SC__) || defined(__TURBOC__)  /* __SC__ for Win32 doesn't define off_t. */
      typedef long off_t;
#    endif
#  else
#    include <unistd.h>  /* FreeBSD lseek and off_t are always 64-bit, even if _FILE_OFFSET_BITS == 32. */
#    if _FILE_OFFSET_BITS == 64 && defined(__WATCOMC_LIBC__)
#      define __REDEFINE_OFF_T_TO_INT64_T  /* Later, after we've defined mmap(...). */
#      define lseek(fd, offset, whence) _lseeki64(fd, offset, whence)
#    endif
#  endif
#endif
#ifdef __TURBOC__
#  define isatty(fd) (isatty(fd) ? 1 : 0)  /* The nonzero return value of the isatty(...) function is 0x80 with __TURBOC__. */
#endif

#if O_BINARY && (defined(__OS2__) || defined(_WIN32) || defined(MSDOS))
#  define set_binmode(fd) setmode(fd, O_BINARY)  /* Good for STDIN_FILENO, STDOUT_FILENO and STDERR_FILENO. */
#else
#  define set_binmode(fd) do {} while (0)
#endif

#ifdef POIX_NO_INCLUDE
  NORETURN void exit(int exit_code);  /* Same as _exit(...), there is nothing to autoflush. */
#  ifdef __SC__
#    pragma noreturn (exit)
#  endif
#  ifdef POIX_CEALLOC_SBRK
    POIX_INLINE void *cemalloc(size_t size);
#    define malloc(size) cealloc(size)  /* Don't let them compete for the same heap. */
#  else
    /* Returned pointer is aligned to C long size. Memory is read-write (it
     * may also be read-write-execute), initial contents not defined. There is
     * no way to free memory (except for exiting the process) in POIX.
     */
    void *malloc(size_t size);
#  endif
#else
#  include <stdio.h>
#  include <stdlib.h>  /* exit(...), malloc(...). */
#  ifdef POIX_CEALLOC_SBRK
#    define malloc(size) cealloc(size)  /* Don't let them compete for the same heap. */
#  endif
#endif

#ifndef   STDIN_FILENO
#  define STDIN_FILENO  0
#endif
#ifndef   STDOUT_FILENO
#  define STDOUT_FILENO 1
#endif
#ifndef   STDERR_FILENO
#  define STDERR_FILENO 2
#endif

#undef  EXIT_SUCCESS
#define EXIT_SUCCESS 0
#undef  EXIT_FAILURE  /* OpenWatcom defines it to 0xFF. */
#define EXIT_FAILURE 1

#ifndef   SEEK_SET
#  define SEEK_SET 0
#endif
#ifndef   SEEK_CUR
#  define SEEK_CUR 1
#endif
#ifndef   SEEK_END
#  define SEEK_END 2
#endif

#ifdef __SC__  /* Most other libcs don't have a header containing it. */
  #ifdef POIX_NO_INCLUDE
    extern char **_environ;
#    define environ _environ
  #endif
#else
  extern char **environ;
#endif

#ifdef POIX_NO_INCLUDE
  size_t strlen(const char *s);
  void *memcpy(void *dest, const void *src, size_t n);
  void *memset(void *s, int c, size_t n);
#else
#  include <string.h>
#endif

#if defined(__GNUC__) || defined(__TINYC__) && !defined(__stdcall)
  #define __stdcall __attribute__((__stdcall__))
#endif

#if defined(POIX_NO_IMPL)
#  ifdef __GNUC__  /* This generates a few dozen bytes more code than the pointer arithmetics below, but it works only with __attrbiute__((noinline))) functions. TODO(pts): Find cheaper alternatives */
    typedef __builtin_va_list va_list;
#    define va_start(v,l)  __builtin_va_start(v,l)
#    define va_end(v)      __builtin_va_end(v)
#    define va_arg(v,l)	   __builtin_va_arg(v,l)
#    define va_copy(d,s)   __builtin_va_copy(d,s)
#  else
#    ifdef __i386__
      typedef char *va_list;
#      define va_start(ap, last) ((ap) = (char*)&(last) + ((sizeof(last)+3)&~3), (void)0)  /* i386 only. */
#      define va_arg(ap, type) ((ap) += (sizeof(type)+3)&~3, *(type*)((ap) - ((sizeof(type)+3)&~3)))  /* i386 only. */
#      define va_copy(dest, src) ((dest) = (src), (void)0)  /* i386 only. */
#      define va_end(ap) /*((ap) = 0, (void)0)*/  /* i386 only. Adding the `= 0' back doesn't make a difference. */
#    endif
#  endif
#else
#  include <stdarg.h>
#endif

#ifndef __OSI__  /* __OSI__ already defines cealloc(...). */
#  if !defined(POIX_NO_IMPL)
#    if !defined(POIX_CEALLOC_MALLOC) && !defined(POIX_CEALLOC_SBRK)
#      ifdef _WIN32
#        if defined(POIX_NO_INCLUDE) || defined(__WATCOMC__) || defined(__SC__) || defined(__TINYC__) || defined(__GNUC__)  /* Maybe h/nt (for __WATCOMC__) is not on the include path. */
#          ifndef   PAGE_EXECUTE_READWRITE
#            define PAGE_EXECUTE_READWRITE 0x40
#          endif
#          ifndef   MEM_COMMIT
#            define MEM_COMMIT 0x1000
#          endif
#          ifndef   MEM_RESERVE
#            define MEM_RESERVE 0x2000
#          endif
          void* __stdcall VirtualAlloc(void *lpAddress, unsigned dwSize, unsigned flAllocationType, unsigned flProtect);
#        else
#          include <windows.h>
#        endif
#      endif
#      ifdef __OS2__
#        if defined(POIX_NO_INCLUDE) || defined(__WATCOMC__)  /* Maybe h/os2 (for __WATCOMC__) is not on the include path. */
          /* __WATCOMC__ os2/bsememf.h */
#          define PAG_READ      0x00000001
#          define PAG_WRITE     0x00000002
#          define PAG_EXECUTE   0x00000004
#          define PAG_COMMIT    0x00000010
          /* os2/bsedos.h */
          unsigned long _System DosAllocMem(void **pBaseAdress, unsigned long ulObjectSize, unsigned long ulAllocationFlags);  /* http://www.edm2.com/index.php/DosAllocMem */
#        else
#          include <bsememf.h>  /* #defines()s above. */
#          include <bsedos.h>  /* DosAllocMem(...), DosSetRelMaxFH(...). */
#        endif
#      endif
#      if !defined(_WIN32) && !defined(__OS2__)  /* Use mmap(2). */
#        if defined(POIX_NO_INCLUDE)
#          define PROT_READ 0x1
#          define PROT_WRITE 0x2
#          define PROT_EXEC 0x4
#          ifdef __linux__
#            define MAP_PRIVATE 0x02
#            define MAP_ANON 0x20
#          endif
#          if defined(__FreeBSD__) || defined(__APPLE__)  /* __APPLE__ stands for macOS and iOS. */
#            define MAP_PRIVATE 0x02
#            define MAP_ANON 0x1000
#          endif
          void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
#        else
#          include <sys/mman.h>  /* POSIX mmap(...). */
#          include <unistd.h>  /* sysconf(...). */
#        endif
#        if defined(MAP_ANON) && !defined(MAP_ANONYMOUS)  /* macOS: MacOSX10.10.sdk/usr/include/sys/mman.h */
#          define MAP_ANONYMOUS MAP_ANON
#        endif
#      endif
#      ifndef PAGE_SIZE
#        if defined(__i386__) || defined(_M_IX86) || defined(__X86__) || defined(__amd64__) || defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64) || defined(__X86_64__) || defined(_M_X64) || defined(_M_AMD64) || defined(__X86__)
#          define PAGE_SIZE 0x1000
#        endif
#      endif
#    endif
    /* Returned pointer is aligned to C long size. Memory is read-write-execute and zero-initialized. */
    POIX_INLINE void *cealloc(size_t size) {
#    ifndef POIX_CEALLOC_MALLOC
      size_t psize;
#      ifndef PAGE_SIZE
        static size_t page_size;
#      endif
      static char *brk0, *brk1;
#    endif
      void *result;
      if (size == 0) ++size;
      size = (size + sizeof(long) - 1) & ~(sizeof(long) - 1);
      if (size == 0) return NULL;
#    ifdef POIX_CEALLOC_MALLOC
      result = malloc(size);
      if (result) memset(result, '\0', size);  /* TODO(pts): Do it with fast `rep stosd' with __WATCOMC__ on i386. */
#    else
#      define IS_BRK_ERROR(x) ((unsigned)(x) + 1 <= 1U)  /* 0 and -1 are errors. */
      while ((unsigned)(brk1 - brk0) < size) {
#      ifdef USE_SBRK  /* Typically sbrk(2) doesn't allocate read-write-execute memory (which we need), not even with `gcc -static -Wl,-N. But it succeds with `minicc --diet'. */
        if (IS_BRK_ERROR(brk1 = sbrk(0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
        if (!brk0) brk0 = brk1;  /* Initialization at first call. */
        if ((unsigned)(brk1 - brk0) >= size) break;
        /* TODO(pts): Allocate more than necessary, to save on system call round-trip time. */
        if (IS_BRK_ERROR(sbrk(size - (brk1 - brk0)))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
        if (IS_BRK_ERROR(brk1 = sbrk(0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
        if ((unsigned)(brk1 - brk0) < size) return NULL;  /* Not enough memory. */
        break;
#      else  /* Use mmap(2) or VirtualAlloc(2). */
        /* TODO(pts): Write a more efficient memory allocator, and write one
         * which tries to allocate less if more is not available.
         */
#        ifdef PAGE_SIZE
          psize = (size + (PAGE_SIZE - 1)) & -PAGE_SIZE;  /* Round up to page boundary. */
#        else
          if (!page_size) page_size = sysconf(_SC_PAGESIZE);
          psize = (size + (page_size - 1)) & -page_size;  /* Round up to page boundary. */
#        endif
        if (!psize) return NULL;  /* Not enough memory. */
        if (!(psize >> 18)) psize = 1 << 18;  /* Round up less than 256 KiB to 256 KiB. */
#        ifdef _WIN32  /* Use VirtualAlloc(...). */
          if ((brk0 = (char*)VirtualAlloc(NULL, psize, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE)) == NULL) return NULL;  /* Not enough memory. */
#        endif
#        ifdef __OS2__  /* Use DosAllocMem(...) */
          if (DosAllocMem((void**)&brk0, psize, PAG_COMMIT | PAG_READ | PAG_WRITE | PAG_EXECUTE)) return  NULL;  /* Not enough memory. */
#        endif
#        if !defined(_WIN32) && !defined(__OS2__)  /* Use mmap(2). */
          if (!(brk0 = (char*)mmap(NULL, psize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0))) return NULL;  /* Not enough memory. */
#        endif
        /* TODO(pts): Use the rest of the previous brk0...brk1 for smaller amounts. */
        brk1 = brk0 + psize;
        break;
#      endif
      }
      result = brk0;
      brk0 += size;
#    endif
      return result;
    }
#  else
    POIX_INLINE void *cealloc(size_t size);
#  endif
#endif

#ifdef __REDEFINE_OFF_T_TO_INT64_T
#  define off_t int64_t
#endif

#ifndef __OSI__  /* __OSI__ already defines ftruncate_here(...). */
#  if !defined(POIX_NO_IMPL)
    POIX_INLINE int ftruncate_here(int fd) {
      const off_t off = lseek(fd, 0, SEEK_CUR);
      if (off == (off_t)-1) return -1;
      return ftruncate(fd, off);
    }
#  else
    POIX_INLINE int ftruncate_here(int fd);
#  endif
#endif

#if !defined(POIX_NO_IMPL) && defined(_WIN32) && defined(__WATCOMC__)
  /* Overrides lib386/nt/clib3r.lib / mbcupper.o
   * Source: https://github.com/open-watcom/open-watcom-v2/blob/master/bld/clib/mbyte/c/mbcupper.c
   * Overridden implementation calls CharUpperA in USER32.DLL:
   * https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-charuppera
   *
   * This function is a transitive dependency of _cstart() with main() in
   * OpenWatcom. By overridding it, we remove the transitive dependency of all
   * .exe files compiled with `owcc -bwin32' on USER32.DLL.
   *
   * This is a simplified implementation, it keeps non-ASCII characters intact.
   */
  unsigned int _mbctoupper(unsigned int c) {
    return (c - 'a' + 0U <= 'z' - 'a' + 0U)  ? c + 'A' - 'a' : c;
  }
#endif

#if !defined(POIX_NO_IMPL) && defined(_WIN32) && defined(__SC__)  /* Digital Mars C compiler. */
  /* Overrides win32/w32fater.o. The _win32_faterr(...) function is a
   * transitive dependency of the DMC libc (dm/lib/snn.lib). It calls
   * MessageBoxA, which we don't want to call, to avoid the dependency on
   * USER32.DLL. So we just call write(2) from here.
   * TODO(pts): Call GetStdHandle and WriteConsole instead. Is it needed?
   */
  void _win32_faterr(const char *msg) {
    (void)!write(2, msg, strlen(msg));
    exit(1);
  }
#endif

#if defined(__TURBOC__) && defined(__DOS16__)
#  define __near near
#endif
#if !defined(__WATCOMC__) && !defined(__near)
#  define __near
#endif

#endif  /* _POIX1_H. */
