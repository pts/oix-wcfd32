/* by pts@fazekas.hy at Sun Apr 28 23:53:15 CEST 2024 */
#ifndef _OSI_H
#define _OSI_H 1

#ifndef __WATCOMC__
#  error Only Watcom C compiler is supported.
#endif
#ifndef __386__
#  error i386 CPU target is required.
#endif
#ifndef __OSI__  /* Just specify: owcc -D__OSI__ */
#  error Watcom OS-independent target is required.
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

/* <stdint.h> */
typedef char assert_int_size[sizeof(int) == 4 ? 1 : -1];
typedef char assert_long_long_size[sizeof(long long) == 8 ? 1 : -1];
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned char int8_t;
typedef short int16_t;
typedef int int32_t;
typedef long long int64_t;

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

enum OSI_OS {
  OSI_OS_DOS = 0,
  OSI_OS_OS2 = 1,
  OSI_OS_WIN32 = 2,
  OSI_OS_WIN16 = 3,
  OSI_OS_UNKNOWN = 4  /* Anything above 3 is unknown. */
};

extern void (__far *_INT21ADDR)(void);
extern void *_STACKTOP;
extern unsigned *_BreakFlagPtr;
extern char __OS;  /* enum OSI_OS. It's mostly useless, because most loaders set it incorrectly on purpose. */
extern char **__environ;

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

/* --- __OSI__ syscall functions. */

void * __watcall __int21h_call(void);

void * __watcall __osi_reloc(const void *p);
#if 0
static __declspec(naked) void * __watcall __osi_reloc(const void *p) { (void*)p; __asm {
		push ebp  ; Save. */
		call Lhere
  Lhere:	pop ebp
		sub ebp, 6  /* 6 is the length of `push ebp' + `call Lhere'. */
		sub ebp, __osi_reloc
		add eax, ebp
		pop ebp  ; Restore. */
		ret
} }
#endif

void __watcall __osi_reloc_get_ebp(void);
#if 0
static __declspec(naked) void __watcall __osi_reloc_get_ebp(void) { __asm {
		call Lhere
  Lhere:	pop ebp
		sub ebp, __osi_reloc_get_ebp  ; 5 is the length of `call Lhere'. */
		sub ebp, 5
		ret
} }
#endif

#define _INT_21  "call __int21h_call"
#define _INT_21_A call __int21h_call


/* There are no cleanups. A regular libc would flush the stdio streams before calling _exit(). */
__declspec(noreturn) void __watcall exit(int exit_code);
#pragma aux exit  = "call __osi_reloc_get_ebp" "mov esp, _STACKTOP[ebp]" "retf" __parm [__eax]

__declspec(noreturn) void __watcall _exit(int exit_code);
#pragma aux _exit = "call __osi_reloc_get_ebp" "mov esp, _STACKTOP[ebp]" "retf" __parm [__eax]

ssize_t read(int fd, void *buf, size_t count);
#pragma aux read = "mov ah, 3fh" _INT_21 "rcl eax, 1" "ror eax,1" __parm [ebx] [edx] [ecx] __value [eax]

ssize_t __watcall write(int fd, const void *buf, size_t count);
/* We need to check for ECX == 0 to prevent truncation. */
#pragma aux write = "test ecx, ecx" "xchg eax, ecx" "jz skip" "xchg eax, ecx" "mov ah, 40h" _INT_21 "skip: rcl eax, 1" "ror eax, 1" __parm [__ebx] [__edx] [__ecx] __value [__eax]

#define CONFIG_USE_FTRUNCATE_HERE 1

/* Same as: ftruncate(fd, lseek(fd, 0, SEEK_CUR));
 * This is not a standard C or POSIX function.
 */
int __watcall ftruncate_here(int fd);
#pragma aux ftruncate_here = "xor ecx, ecx" "mov ah, 40h" _INT_21 "sbb eax, eax" __parm [__ebx] __value [__eax] __modify __exact [__ecx]

static __declspec(naked) int __watcall ftruncate(int fd, off_t size) { (void)fd; (void)size; __asm {
		push ebx
		push ecx
		push esi
		mov esi, edx  /* Save argument size. */
		xchg ebx, eax  /* EBX := EAX (filehandle); EBX := junk. */
		mov ax, 4201h  /* SEEK_CUR. */
		xor ecx, ecx
		xor edx, edx
		_INT_21_A
		jc Ldone
		xchg edx, eax  /* DX := AX (low word); AX := (high word). */
		xchg ecx, eax  /* CX := AX (high word); AX := junk. */
		push ecx
		push edx
		mov edx, esi
		mov ecx, esi
		shr ecx, 16
		mov ax, 4200h  /* SEEK_SET to ESI. */
		_INT_21_A
		jc Ldone
		mov ah, 40h
		xor ecx, ecx
		_INT_21_A  /* Truncate. */
		jc Ldone
		pop edx
		pop ecx
		mov ax, 4200h  /* SEEK_SET back. */
		_INT_21_A
  Ldone:	sbb eax, eax
		pop esi
		pop ecx
		pop ebx
		ret
} }

off_t __watcall lseek(int fd, off_t offset, int whence);
#pragma aux lseek = "mov ah, 42h" "mov ecx, edx" "shr ecx, 16" _INT_21 "rcl dx, 1" "ror dx, 1" "shl edx, 16" "mov dx, ax" __parm [__ebx] [__edx] [__al] __value [__edx] __modify [__eax __ebx __ecx __edx]

/* If unsure, pass 0666 as mode. It will be ignored by __OSI__. */
int creat(const char *pathname, mode_t mode);
#pragma aux creat = "mov ah, 3ch" "xor ecx, ecx" _INT_21 "rcl eax, 1" "ror eax, 1" __parm [__edx] [__ecx] __value [eax];

#define CONFIG_USE_OPEN2 1

/* A 2-argument open(...) which is not able to create files.
 * This is not a standard C or POSIX function.
 */
#pragma aux open2 = "and eax, 3" "mov ah, 3dh" _INT_21 "rcl eax, 1" "ror eax, 1" __parm [__edx] [__al] __value [__eax];
int open2(const char *pathname, int flags);

/* mode is ignored, because this open(...) doesn't support file creation. For that, use creat(...) instead. */
int open(const char *pathname, int flags, mode_t mode);
#pragma aux open = "and eax, 3" "mov ah, 3dh" _INT_21 "rcl eax, 1" "ror eax, 1" __parm [__edx] [__al] __value [__eax];

int __watcall close(int fd);
#pragma aux close = "mov ah, 3eh" _INT_21 "sbb eax, eax" __parm [__ebx] __value [__eax]

int __watcall isatty(int fd);
#pragma aux isatty = "mov ax, 4400h" _INT_21 "mov eax, 0" "jc done" "test dl, 80h" "jz done" "inc eax" "done:" __parm [__ebx] __value [__eax] __modify [__edx]

void * __watcall malloc(size_t size);
#pragma aux malloc = "mov ah, 48h" _INT_21 "sbb ebx, ebx" "not ebx" "and eax, ebx" __parm [__ebx] __value [__eax] __modify __exact [__eax __ebx]

#define CONFIG_NO_FREE 1  /* free(3) is not implemented in the libc. */

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

/* Not a standard C function, but useful. */
static void memswap_inline(void *a, void *b, size_t size);
static void memswap(void *a, void *b, size_t size) { memswap_inline(a, b, size); }
#pragma aux memswap_inline = "jecxz done" "again: mov al, [edi]" "xchg al, [edx]" "stosb" "inc edx" "loop again" "done:" __parm [__edi] [__edx] [__ecx] __modify _exact [__al __edi __edx __ecx]

/* Same signature as qsort(3), but it implements the fast-in-worst-case
 * heapsort. It is not stable. For a stable but very slow
 * qsort(3) implementation, see fyi/c_qsort.c.
 *
 * Worst case execution time: O(n*log(n)): less than 3*n*log_2(n)
 * comparisons and swaps. (The number of swaps is usually a bit smaller than
 * the number of comparisons.) The average number of comparisons is
 * 2*n*log_2(n)-O(n). It is very fast if all values are the same (but still
 * does lots of comparisons and swaps). It is not especially faster than
 * average if the input is already ascending or descending (with unique
 * values),
 *
 * Uses a constant amount of memory in addition to the input/output array.
 *
 * Based on heapsort algorithm H from Knuth TAOCP 5.2.3. The original uses a
 * temporary variable (of `size' bytes) and copies elements between it and
 * the array. That code was changed to swaps within the original array.
 */
static void qsort(void *base, size_t n, size_t size,
                  int __watcall (*cmp)(const void*, const void*)) {
  char *ap = (char*)base, *lp = ap + size * (n >> 1);
  char *rp = ap + size * (n - 1), *tp, *ip, *jp;
  if (n < 2) return;
  for (;;) {
    if (lp != ap) {
      tp = lp -= size;
    } else {
      memswap(ap, rp, size);
      if ((rp -= size) == ap) break;
      tp = ap;
    }
    jp = lp;
    for (;;) {
      ip = jp;
      jp += (jp - ap) + size;
      if (jp > rp) break;
      if (jp < rp && cmp(jp, jp + size) < 0) jp += size;
      if (!(cmp(tp, jp) < 0)) break;
      memswap(ip, jp, size);
      tp = jp;
    }
    memswap(ip, tp, size);
  }
}

/* --- start implementation. */

#if 0
/* Reverses the elements in a NULL-terminated array of (void*)s. */
/* static __declspec(naked) void __watcall reverse_ptrs(void **p) { (void)p; __asm { */
#endif

/* Parses the first argument of the Windows command-line (specified in EAX)
 * in place. Returns (in EAX) the pointer to the rest of the command-line.
 * The parsed argument will be available as NUL-terminated string at the
 * same location as the input.
 *
 * Similar to CommandLineToArgvW(...) in SHELL32.DLL, but doesn't aim for
 * 100% accuracy, especially that it doesn't support non-ASCII characters
 * beyond ANSI well, and that other implementations are also buggy (in
 * different ways).
 *
 * It treats only space and tab and a few others as whitespece. (The Wine
 * version of CommandLineToArgvA.c treats only space and tab as whitespace).
 *
 * This is based on the incorrect and incomplete description in:
 *  https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw
 *
 * See https://nullprogram.com/blog/2022/02/18/ for a more detailed writeup
 * and a better installation.
 *
 * https://github.com/futurist/CommandLineToArgvA/blob/master/CommandLineToArgvA.c
 * has the 3*n rule, which Wine 1.6.2 doesn't seem to have. It also has special
 * parsing rules for argv[0] (the program name).
 *
 * There is the CommandLineToArgvW function in SHELL32.DLL available since
 * Windows NT 3.5 (not in Windows NT 3.1). For alternative implementations,
 * see:
 *
 * * https://github.com/futurist/CommandLineToArgvA
 *   (including a copy from Wine sources).
 * * http://alter.org.ua/en/docs/win/args/
 * * http://alter.org.ua/en/docs/win/args_port/
 */
#if 0  /* Long reference implementation. */
static char * __watcall parse_first_arg(char *pw) {
  const char *p;
  const char *q;
  char c;
  char is_quote = 0;
  for (p = pw; c = *p, c == ' ' || c == '\t' || c == '\n' || c == '\v'; ++p) {}
  if (*p == '\0') { *pw = '\0'; return pw; }
  for (;;) {
    if ((c = *p) == '\0') goto after_arg;
    ++p;
    if (c == '\\') {
      for (q = p; c = *q, c == '\\'; ++q) {}
      if (c == '"') {
        for (; p < q; p += 2) {
          *pw++ = '\\';
        }
        if (p != q) {
          is_quote ^= 1;
        } else {
          *pw++ = '"';
          ++p;  /* Skip over the '"'. */
        }
      } else {
        *pw++ = '\\';
        for (; p != q; ++p) {
          *pw++ = '\\';
        }
      }
    } else if (c == '"') {
      is_quote ^= 1;
    } else if (!is_quote && (c == ' ' || c == '\t' || c == '\n' || c == '\v')) {
     got_space:
      if (p - 1 != pw) --p;  /* Don't clobber the rest with '\0' below. */
     after_arg:
      *pw = '\0';
      return (char*)p;
    } else {
      *pw++ = c;  /* Overwrite in-place. */
    }
  }
}
#else  /* Short assembly implementation. */
/* static __declspec(naked) char * __watcall parse_first_arg(char *pw) { (void)pw; __asm { */
#endif

int __watcall __osi_main();
extern char _edata[], _end[];  /* Populated by WLINK. */

/* __OSI__ program entry point. */
static __declspec(naked) int __watcall __osi_start_helper(void) { __asm {
		call __osi_reloc_get_ebp
                mov  word ptr __int21h_call[ebp+5], bx   /* Segment. */
                mov dword ptr __int21h_call[ebp+1], edx  /* Offset. */
		/* Zero-initialize BSS. !! TODO(pts): The WCFD32 loader has done it. */
		push edx
		push edi
		push eax
		mov ecx, offset _end	/* end of _BSS segment (start of free) */
		add ecx, ebp
		mov edi, offset _edata	/* start of _BSS segment */
		add edi, ebp
		sub ecx, edi		/* calc # of bytes in _BSS segment */
		xor eax, eax		/* zero the _BSS segment */
		mov dl, cl		/* copy the lower bits of size */
		shr ecx, 2		/* get number of dwords */
		rep stosd		/* copy them */
		mov cl, dl		/* get lower bits */
		and cl, 3		/* get number of bytes left (modulo 4) */
		rep stosb		/* copy remaining few bytes */
		pop eax
		pop edi
		pop edx
		/* Initialize variables in BSS. */
		mov _STACKTOP[ebp], esp
		mov __OS[ebp], ah	/* save OS ID */
		mov eax, [edi+12]	/* get address of break flag */
		mov _BreakFlagPtr[ebp], eax	/* save it */
		mov eax, [edi]		/* get program name */
		push 0			/* NULL marks end of argv array. */
		/*mov _LpPgmName[ebp], eax*/
		push eax		/* Push argv[0]. */
		mov eax, [edi+4]	/* Get command line. */
		/*mov _LpCmdLine[ebp], eax*/	/* Don't save it, parse_first_arg has overwritten it. */
		xor ecx, ecx
		inc ecx			/* ECX := 1 (current argc). */
  Largv_next:	mov edx, eax		/* Save EAX (remaining command line). */
		call parse_first_arg
		cmp eax, edx
		je Largv_end		/* No more arguments in argv. */
		inc ecx			/* argc += 1. */
		push edx		/* Push argv[i]. */
		jmp Largv_next
  Largv_end:	mov eax, esp
		call reverse_ptrs
		mov esi, [edi+8]	/* get environment pointer */
		mov edi, esp		/* Save argv to EDI. */
		/* Initialize environ. */
		/* TODO(pts): Allocate pointers on the heap, not on the stack. */
		/*mov _EnvPtr, esi*/	/* save environment pointer */
		push 0			/* NULL marks end of env array */
  L2:		push esi		/* push ptr to next string */
  L3:		lodsb			/* get character */
		cmp al, 0		/* check for null char */
		jne L3			/* until end of string */
		cmp byte ptr [esi], 0   /* check for double null char */
		jne L2			/* until end of environment strings */
		mov eax, esp
		call reverse_ptrs
		mov __environ[ebp], esp	/* set pointer to array of ptrs */
		/* Call main. */
		xchg eax, ecx		/* EAX := ECX (argc). ECX := junk. */
		mov edx, edi		/* EDX := ESI (saved argv). */
		mov ebx, esp		/* EBX := ESP (environ pointer). */
		call __osi_main
		/* We cannot just retf here, we have many variables on the stack. */
		call __osi_reloc_get_ebp
		mov esp, _STACKTOP[ebp]
		retf  /* exit(). */
		/* Not reached. */
  parse_first_arg:  /* char * __watcall parse_first_arg(char *pw); */
		push ebx
		push ecx
		push edx
		push esi
		xor bh, bh  /* is_quote. */
		mov edx, eax
  LP1:		mov bl, [edx]
		cmp bl, ' '
		je short LP2  /* The inline assembler is not smart enough with forward references, we need these shorts. */
		cmp bl, 0x9
		jb short LP3
		cmp bl, 0xb
		ja short LP3
  LP2:		inc edx
		jmp short LP1
  LP3:		test bl, bl
		jne short LP8
		mov [eax], bl
		jmp short LPret
  LP4:		cmp bl, '"'
		jne short LP11
  LP5:		lea esi, [eax+0x1]
		cmp edx, ecx
		jae short LP6
		mov byte ptr [eax], 0x5c  /* "\\" */
		mov eax, esi
		inc edx
		inc edx
		jmp short LP5
  LP6:		je short LP10
  LP7:		not bh
  LP8:		mov bl, [edx]
		test bl, bl
		je short LP16
		inc edx
		cmp bl, 0x5c  /* "\\" */
		jne short LP13
		mov ecx, edx
  LP9:		mov bl, [ecx]
		cmp bl, 0x5c  /* "\\" */
		jne short LP4
		inc ecx
		jmp short LP9
  LP10:		mov byte ptr [eax], '"'
		mov eax, esi
		lea edx, [ecx+0x1]
		jmp short LP8
  LP11:		mov byte ptr [eax], 0x5c  /* "\\" */
		inc eax
  LP12:		cmp edx, ecx
		je short LP8
		mov byte ptr [eax], 0x5c  /* "\\" */
		inc eax
		inc edx
		jmp short LP12
  LP13:		cmp bl, '"'
		je short LP7
		test bh, bh
		jne short LP15
		cmp bl, ' '
		je short LP14
		cmp bl, 0x9
		jb short LP15
		cmp bl, 0xb
		jna short LP14
  LP15:		mov [eax], bl
		inc eax
		jmp short LP8
  LP14:		dec edx
		cmp eax, edx
		jne LP16
		inc edx
  LP16:		mov byte ptr [eax], 0x0
		xchg eax, edx  /* EAX := EDX: EDX := junk. */
  LPret:	pop esi
		pop edx
		pop ecx
		pop ebx
		ret
		/* Not reached. */
  reverse_ptrs:  /* void __watcall reverse_ptrs(void **p); */
		push ecx
		push edx
		lea edx, [eax-4]
  LRnext1:	add edx, 4
		cmp dword ptr [edx], 0
		jne short LRnext1
		cmp edx, eax
		je short LRnothing
		sub edx, 4
		jmp short LRcmp2
  LRnext2:	mov ecx, [eax]
		xchg ecx, [edx]
		mov [eax], ecx
		add eax, 4
		sub edx, 4
  LRcmp2:	cmp eax, edx
		jb short LRnext2
  LRnothing:	pop edx
		pop ecx
  LRret:	ret
} }

/* --- main() and global variable magic */

#define __osi_impl \
    void (__far *_INT21ADDR)(void); \
    void *_STACKTOP; \
    unsigned *_BreakFlagPtr; \
    char __OS; \
    char **__environ; \
    /* We can't have newlines in a macro body, so we need single-line assembly functions. We accomplish that mostly with `dd' and `db'. */ \
    __declspec(naked) void * __watcall __int21h_call(void) { __asm { db 0x9a, 0, 0, 0, 0, 0, 0  /* call far (6 bytes hardcoded). */  , 0xc3  /* ret. */ } } \
    __declspec(naked) void * __watcall __osi_reloc(const void *p) { (void*)p; __asm { dd 0xe855, 0x835d0000, 0xed8106ed, offset __osi_reloc, 0xc35de801 } } \
    __declspec(naked) void __watcall __osi_reloc_get_ebp(void) { __asm { dd 0xe8, 0xed815d00, offset __osi_reloc_get_ebp, 0xc305ed83 } } \
    /* __OSI__ program entry point. */ \
    __declspec(naked) int __watcall __far _cstart(void) { __asm { jmp __osi_start_helper } } \
    /* !!! Also add an MZ header. */ \
    uint32_t __based(__segname("HDR")) cf_header[8 + 6] = {  /* It only matters that the HDR segment has class=FAR_DATA (default by the C compiler), and `wlink order clname FAR_DATA' has been specified. */ \
      'M'|'Z'<<8, 0, 2, 0, 0, 0, 0, 0,  /* mz_header. These bytes are not needed by oixrun, but w32run.exe needs them. We aim for maximum compatibility here. */ \
      'C'|'F'<<8,  /* signature. */ \
      0,  /* load_fofs. */ \
      (uint32_t)_edata - 3,  /* load_size. Unfortunately rounds up size to a multiple of 4, so we use last.c. */ \
      4,  /* reloc_rva: points to (uint16_t)0). */ \
      (uint32_t)_end,  /* mem_size. */ \
      (uint32_t)_cstart,  /* entry_rva. */ \
    };

#define __END__ char __osi__lastc[3] = "\0\0\0";  /* "END" to make it visible. */
#define __MAIN_END__ __END__

#define S(ptr) __osi_reloc(ptr)
#define GSTRUCT(g) (*(struct g*)S(&g))
#define environ (*(char***)S(&__environ))

#define main extern __dummy_int_var; __MAIN_END__ __osi_impl int __osi_main

#endif  /* _OSI_H */
