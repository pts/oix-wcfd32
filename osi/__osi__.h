/*
 * __osi__: tiny, incomplete libc for the __OSI__ target
 * by pts@fazekas.hu at Sat Apr 27 02:30:40 CEST 2024
 */

#ifndef ___OSI___H
#define ___OSI___H 1
#define ___OSI___H_INCLUDED 1

#ifndef __WATCOMC__
#  error Only Watcom C compiler is supported.
#endif
#ifndef __386__
#  error i386 CPU target is required.
#endif

#if defined(_IO_H_INCLUDED) || defined(_STDIO_H_INCLUDED) || defined(_STDLIB_H_INCLUDED) || defined(_STDDEF_H_INCLUDED) || defined(_STDARG_H_INCLUDED) || defined(_STDBOOL_H_INCLUDED) || \
    defined(_STDEXCEPT_H_INCLUDED) || defined(_STDINT_H_INCLUDED) || defined(_STDIOBUF_H_INCLUDED) || defined(_UNISTD_H_INCLUDED) || defined(_LIMITS_H_INCLUDED) || defined(_FLOAT_H_INCLUDED) || \
    defined(_MATH_H_INCLUDED) || defined(_CTYPE_H_INCLUDED) || defined(_STRING_H_INCLUDED) || defined(_STRINGS_H_INCLUDED) || defined(_SYS_TYPES_H_INCLUDED) || defined(_SYS_TIME_H_INCLUDED) || \
    defined(_SYS_UTIME_H_INCLUDED) || defined(_SYS_SELECT_H_INCLUDED) || defined(_SYS_MMAN_H_INCLUDED) || defined(_SYS_IOCTL_H_INCLUDED) || defined(_SYS_WAIT_H_INCLUDED) || \
    defined(_FCNTL_H_INCLUDED) || defined(_ERRNO_H_INCLUDED)
#  error Do not include Watcom C headers.  /* TODO(pts): Do more. */  /* TODO(pts): Do it later. */
#endif
#define _IO_H_INCLUDED 1
#define _STDIO_H_INCLUDED 1
#define _STDLIB_H_INCLUDED 1
#define _STDDEF_H_INCLUDED 1
#define _STDARG_H_INCLUDED 1
#define _STDBOOL_H_INCLUDED 1
#define _STDEXCEPT_H_INCLUDED 1
#define _STDINT_H_INCLUDED 1
#define _STDIOBUF_H_INCLUDED 1
#define _UNISTD_H_INCLUDED 1
#define _LIMITS_H_INCLUDED 1
#define _FLOAT_H_INCLUDED 1
#define _MATH_H_INCLUDED 1
#define _CTYPE_H_INCLUDED 1
#define _STRING_H_INCLUDED 1
#define _STRINGS_H_INCLUDED 1
#define _FCNTL_H_INCLUDED 1
#define _ERRNO_H_INCLUDED 1
#define _SYS_TYPES_H_INCLUDED 1
#define _SYS_TIME_H_INCLUDED 1
#define _SYS_UTIME_H_INCLUDED 1
#define _SYS_SELECT_H_INCLUDED 1
#define _SYS_MMAN_H_INCLUDED 1
#define _SYS_IOCTL_H_INCLUDED 1
#define _SYS_WAIT_H_INCLUDED 1

#define __OSI__ 1
#define i386 1
#define __i386 1
#define __i386__ 1
#undef MSDOS
#undef _WIN32
#undef __NETWARE__
#undef __WINDOWS__  /* ? */
#undef __NT__
#undef __OS2__
#undef __WINDOWS_386__
#undef __DOS__
#undef __LINUX__
#undef __linux
#undef __linux__
#undef __gnu_linux__
#undef linux

typedef char assert_int_size[sizeof(int) == 4 ? 1 : -1];
typedef char assert_long_long_size[sizeof(long long) == 8 ? 1 : -1];
/* <stdarg.h> */
typedef char *va_list;
#define va_start(ap, last) ((ap) = (char*)&(last) + ((sizeof(last)+3)&~3), (void)0)  /* i386 only. */
#define va_arg(ap, type) ((ap) += (sizeof(type)+3)&~3, *(type*)((ap) - ((sizeof(type)+3)&~3)))  /* i386 only. */
#define va_copy(dest, src) ((dest) = (src), (void)0)  /* i386 only. */
#define va_end(ap) /*((ap) = 0, (void)0)*/  /* i386 only. Adding the `= 0' back doesn't make a difference. */

/* <stddef.h> */
#define NULL ((void*)0)  /* Defined in multiple .h files: https://en.cppreference.com/w/c/types/NULL */
#undef offsetof
#define offsetof(type,member) ((size_t) &((type*)0)->member)

/* Defined in osi_start.c */
extern void (__far *_INT21ADDR)(void);
extern void *_STACKTOP;
extern unsigned *_BreakFlagPtr;
extern char __OS;
extern char **_EnvPtr;
extern char **environ;
extern char *_LpPgmName;

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned char int8_t;
typedef short int16_t;
typedef int int32_t;
typedef long long int64_t;
typedef int ssize_t;
typedef unsigned size_t;
typedef long off_t;  /* The __OSI__ ABI doesn't support 64-bit seek offsets, thus the largest file size correctly supported is 2 GiB - 1 byte. */
typedef unsigned mode_t;

/* Higher values are not portable. */
#define O_RDONLY 0  /* flags bitfield value below. */
#define O_WRONLY 1
#define O_RDWR   2

#define O_BINARY 0  /* All I/O is binary by default with __OSI__. */

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

/* --- __OSI__ functions. */

#define _INT_21 "call fword ptr _INT21ADDR"

/* There are no cleanups. A regular libc would flush the stdio streams before calling _exit(). */
__declspec(noreturn) void __watcall exit(int exit_code);
#pragma aux exit = "mov esp, _STACKTOP" "retf" __parm [__eax]

__declspec(noreturn) void __watcall _exit(int exit_code);
#pragma aux _exit = "mov esp, _STACKTOP" "retf" __parm [__eax]

ssize_t read(int fd, void *buf, size_t count);
#pragma aux read = "mov ah, 3fh" _INT_21 "rcl eax, 1" "ror eax,1" __parm [ebx] [edx] [ecx] __value [eax]

ssize_t __watcall write(int fd, const void *buf, size_t count);
/* We need to check for ECX == 0 to prevent truncation. */
#pragma aux write = "test ecx, ecx" "xchg eax, ecx" "jz skip" "xchg eax, ecx" "mov ah, 40h" _INT_21 "skip: rcl eax, 1" "ror eax, 1" __parm [__ebx] [__edx] [__ecx] __value [__eax]

#define CONFIG_USE_FTRUNCATE_HERE 1

/* Same as: ftruncate(fd, lseek(fd, 0, SEEK_CUR)); */
int __watcall ftruncate_here(int fd);
#pragma aux ftruncate_here = "xor ecx, ecx" "mov ah, 40h" _INT_21 "sbb eax, eax" __parm [__ebx] __value [__eax] __modify __exact [__ecx]

off_t __watcall lseek(int fd, off_t offset, int whence);
#pragma aux lseek = "mov ah, 42h" "mov ecx, edx" "shr ecx, 16" _INT_21 "rcl dx, 1" "ror dx, 1" "shl edx, 16" "mov dx, ax" __parm [__ebx] [__edx] [__al] __value [__edx] __modify [__eax __ebx __ecx __edx];

int creat(const char *pathname, mode_t mode);
#pragma aux creat = "mov ah, 3ch" _INT_21 "rcl eax, 1" "ror eax, 1" __parm [__edx] [__ecx] __value [eax];

#define CONFIG_USE_OPEN2 1

/* A 2-argument open(...) which is not able to create files. */
#pragma aux open2 = "and eax, 3" "mov ah, 3dh" _INT_21 "rcl eax, 1" "ror eax, 1" __parm [__edx] [__al] __value [__eax];
int open2(const char *pathname, int flags);

/* mode is ignored, because this open(...) doesn't support file creation. For that, use creat(...) instead. */
int open(const char *pathname, int flags, mode_t mode);
#pragma aux open = "and eax, 3" "mov ah, 3dh" _INT_21 "rcl eax, 1" "ror eax, 1" __parm [__edx] [__al] __value [__eax];

int __watcall close(int fd);
#pragma aux close = "mov ah, 3eh" _INT_21 "sbb eax, eax" __parm [__ebx] __value [__eax]

void * __watcall malloc(size_t size);
#pragma aux malloc = "mov ah, 48h" _INT_21 "sbb ebx, ebx" "not ebx" "and eax, ebx" __parm [__ebx] __value [__eax] __modify __exact [__eax __ebx]

int __watcall unlink(const char *pathname);
int __watcall remove(const char *pathname);
#pragma aux unlink = "mov ah, 41h" _INT_21 "sbb eax, eax" __parm [__edx] __value [__eax]
/*#pragma alias(remove, unlink)*/  /* Creates an invalid object file. */
#pragma aux remove = "mov ah, 41h" _INT_21 "sbb eax, eax" __parm [__edx] __value [__eax]  /* Same as unlink(). */

static __inline int setmode(int fd, mode_t mode) { (void)fd; (void)mode; return 0; }  /* All I/O is binary, no need for setmode9fd, O_BINARY). */

/* --- <ctype.h> */

static int __watcall isalpha_inline(int c);
static int __watcall isalpha(int c) { return isalpha_inline(c); }
#pragma aux isalpha_inline = "or al, 32"  "sub al, 97"  "cmp al, 26"  "sbb eax, eax"  "neg eax"  __value [__eax] __parm [__eax]

static int __watcall isspace_inline(int c);
static int __watcall isspace(int c) { return isspace_inline(c); }
#pragma aux isspace_inline = "sub al, 9"  "cmp al, 13-9+1"  "jc short @$1"  "sub al, 32-9"  "cmp al, 1"  "@$1: sbb eax, eax"  "neg eax"  __value [__eax] __parm [__eax]

static int __watcall isdigit_inline(int c);
static int __watcall isdigit(int c) { return isdigit_inline(c); }
#pragma aux isdigit_inline = "sub al, 48"  "cmp al, 10"  "sbb eax, eax"  "neg eax"  __value [__eax] __parm [__eax]

static int __watcall isxdigit_inline(int c);
static int __watcall isxdigit(int c) { return isxdigit_inline(c); }
#pragma aux isxdigit_inline = "sub al, 48"  "cmp al, 10"  "jc short @$1"  "or al, 32"  "sub al, 49"  "cmp al, 6"  "@$1: sbb eax, eax"  "neg eax"  __value [__eax] __parm [__eax]

/* --- <string.h> */

static size_t strlen_inline(const char *s);
static size_t strlen_inline2(const char *s);  /* Unused. Maybe shorter for inlining. */
static size_t strlen(const char *s) { return strlen_inline(s); }
#pragma aux strlen_inline = "xchg esi, eax"  "xor eax, eax"  "dec eax"  "again: cmp byte ptr [esi], 1"  "inc esi"  "inc eax"  "jnc short again"  __value [__eax] __parm [__eax] __modify [__esi]
#pragma aux strlen_inline2 = "xor eax, eax"  "dec eax"  "again: cmp byte ptr [esi], 1"  "inc esi"  "inc eax"  "jnc short again"  __value [__eax] __parm [__esi] __modify [__esi]

static char *strcpy_inline(char *dest, const char *src);
static char *strcpy(char *dest, const char *src) { return strcpy_inline(dest, src); }
#pragma aux strcpy_inline = "xchg esi, edx"  "xchg edi, eax"  "push edi"  "again: lodsb"  "stosb"  "cmp al, 0"  "jne short again"  "pop eax"  "xchg esi, edx"  __value [__eax] __parm [__eax] [__edx] __modify [__edi]

static void memcpy_void_inline(void *dest, const void *src, size_t n);
#pragma aux memcpy_void_inline = "rep movsb"  __parm [__edi] [__esi] [__ecx] __modify [__esi __edi __ecx]

/* Returns dest + n. */
static void *memcpy_newdest_inline(void *dest, const void *src, size_t n);
#pragma aux memcpy_newdest_inline = "rep movsb"  __value [__edi] __parm [__edi] [__esi] [__ecx] __modify [__esi __ecx]

#define CONFIG_USE_MEMCPY_INLINE 1

static int strcmp_inline(const char *s1, const char *s2);
static int strcmp(const char *s1, const char *s2) { return strcmp_inline(s1, s2); }
/* This is much shorter than in OpenWatcom libc and shorter than QLIB 2.12.1 and Zortech C++. */
#pragma aux strcmp_inline = "xchg esi, eax"  "xor eax, eax"  "xchg edi, edx"  "next: lodsb"  "scasb"  "jne short diff"  "cmp al, 0"  "jne short next"  "jmp short done"  "diff: mov al, 1"  "jnc short done"  "neg eax"  "done: xchg edi, edx" __value [__eax] __parm [__eax] [__edx] __modify [__esi]

static int memcmp_inline(const void *s1, const void *s2, size_t n);
static int memcmp(const void *s1, const void *s2, size_t n) { return memcmp_inline(s1, s2, n); }
#pragma aux memcmp_inline = "xor eax, eax" "jecxz done" "repz cmpsb" "je done" "inc eax" "jnc done" "neg eax" "done:" __value [__eax] __parm [__esi] [__edi] [__ecx] __modify [__esi __edi __ecx]

static void *memset_inline(void *s, int c, size_t n);
static void *memset(void *s, int c, size_t n) { return memset_inline(s, c, n); }
#pragma aux memset_inline = "push edi" "rep stosb" "pop eax" __value [__eax] __parm [__edi] [__eax] [__ecx] __modify [__edi __ecx]

#endif  /* _OSI_H */
