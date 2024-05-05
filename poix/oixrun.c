/*
 * oixrun.c: OIX program runner reference implementation in C, for POSIX and Win32, for i386 only
 * by pts@fazekas.hu at Sat May  4 01:51:30 CEST 2024
 *
 * Compile with GCC for any Unix: gcc -m32 -march=i386 -s -Os -W -Wall -ansi -pedantic -o oixrun oixrun.c
 * Compile with Clang for any Unix: clang -m32 -march=i386 -s -Os -W -Wall -ansi -pedantic -o oixrun oixrun.c
 * Compile with TinyCC for Linux: tcc -s -Os -W -Wall -o oixrun oixrun.c
 * Compile with minicc (https://github.com/pts/minilibc686) for Linux i386: minicc -ansi -pedantic -o oixrun oixrun.c
 # Compile with OpenWatcom v2 C compiler for Win32: owcc -bwin32 -march=i386 -s -Os -W -Wall -Wno-n201 -std=c89 -o oixrun.exe oixrun.c
 * Compile with Digital Mars C compiler for Win32: dmc -v0 -3 -w2 -o+space oixrun.c
 *
 * Pass -DUSE_SBRK if your system has sbrk(2), but not mmap(2).
 *
 * TODO(pts): Check for i386, little-endian, 32-bit mode etc. system. Start with C #ifdef()s.
 * !! TODO(pts): Do some extra sanity checks that we are compiling for i386. Even at runtime: try to disassemble a simple function: void tryf(void) { return 0x12345678; }
 * !! TODO(pts): How to pass the pointer to the bottom of the stack? Document it.
 */

#if !defined(_WIN32) && defined(__NT__)  /* __NT__ is Watcom C, but it also defines _WIN32 with `owcc -bwin32'. */
#  define _WIN32 1
#endif

/* Make functions like sbrk(2) available with GCC. */
#define _DEFAULT_SOURCE
#define _XOPEN_SOURCE 500
#define _SVID_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>  /* rename(...). */
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#  include <io.h>  /* chsize(...). */
#  if defined(__WATCOMC__) || defined(__SC__)  /* Maybe h/nt (for __WATCOMC__) is not on the include path. */
    void* __stdcall VirtualAlloc(void *lpAddress, unsigned dwSize, unsigned flAllocationType, unsigned flProtect);
#  else
#    include <windows.h>
#  endif
#else
#  include <unistd.h>  /* sbrk(...), ftruncate(...). */
#endif
#if !defined(USE_SBRK) && !defined(_WIN32)
#  include <sys/mman.h>  /* mmap(...). */
#endif

#ifndef   O_BINARY  /* Mostly on _WIN32. */
#  define O_BINARY 0
#endif

#if !defined(__GNUC__) && !defined(__extension__)
#  define __extension__
#endif

#if defined(__i386) || defined(__i386__) || defined(i386) || defined(__386) || defined(_M_I386) || defined(_M_I86) || defined(_M_IX86) || defined(__386__) || defined(__X86__)
#else
#  if defined(__amd64__) || defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64) || defined(__X86_64__) || defined(_M_X64) || defined(_M_AMD64) || \
    defined(__X86__) || defined(__I86__) || defined(_M_I86) || defined(_M_I8086) || defined(_M_I286) || \
    defined(__BIG_ENDIAN__) || (defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__) && __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__) || \
    defined(__ARMEB__) || defined(__THUMBEB__) || defined(__AARCH64EB__) || defined(_MIPSEB) || defined(__MIPSEB) || defined(__MIPSEB__) || \
    defined(__powerpc__) || defined(_M_PPC) || defined(__m68k__) || defined(_ARCH_PPC) || defined(__PPC__) || defined(__PPC) || defined(PPC) || \
    defined(__powerpc) || defined(powerpc) || (defined(__BIG_ENDIAN) && (!defined(__BYTE_ORDER) || __BYTE_ORDER == __BIG_ENDIAN +0)) || \
    defined(_BIG_ENDIAN) || \
    defined(__ARMEL__) || defined(__THUMBEL__) || defined(__AARCH64EL__) || defined(_MIPSEL) || defined (__MIPSEL) || defined(__MIPSEL__) || \
    defined(__ia64__) || defined(__LITTLE_ENDIAN) || defined(_LITTLE_ENDIAN)
#    error Unsupported CPU architecture detected. If you are sure, then recompile with -D__386
#  else  /* TODO(pts): Add some runtime (disassembly) checks. */
#    error CPU architecture not detected. If you are sure you have i386, then recompile with -D__386
#  endif
#endif

#if defined(_WIN32) && defined(__WATCOMC__)
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

#if defined(_WIN32) && defined(__SC__)  /* Digital Mars C compiler. */
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

typedef char assert_sizeof_short[sizeof(short) == 2 ? 1 : -1];
typedef char assert_sizeof_int[sizeof(int) == 4 ? 1 : -1];
typedef char assert_sizeof_ptr[sizeof(void*) == 4 ? 1 : -1];  /* Prevent accidental compilation on __amd64__. */
typedef char assert_sizeof_function_ptr[sizeof(void(*)(void)) == 4 ? 1 : -1];  /* TODO(pts): Support far calls. */

struct pushad_regs {  /* i386 CPU registers, as pushed by pushfd, then pushad. */
  unsigned edi, esi, ebp, esp, ebx, edx, ecx, eax, eflags;
};
#define STC(r) ((r)->eflags |= 1)  /* Set CF=1 (carry flag). */
#define CLC(r) ((r)->eflags &= ~1)  /* Set CF=0 (carry flag). */
typedef char assert_sizeof_pushad_regs[sizeof(struct pushad_regs) == 0x24 ? 1 : -1];

struct tramp_args {
  void (*c_handler)(struct pushad_regs *r);
  char *program_entry;  /* Will be jumped to. */
  char *stack_low;  /* Can be set to NULL to indicate that the stack low limit is unknown. */
  unsigned operating_system;  /* Only the low byte is relevant. Will be saved to AH. */
  /* Order of elements from here matter, same as in the OIX param struct (struct pgmparms). */
  char *program_filename;
  char *command_line;
  char *env_strings;
  unsigned *break_flag_ptr;
  char *copyright;
  unsigned is_japanese;
  unsigned max_handle_for_os2;
};

#if defined(__GNUC__) || defined(__TINYC__)
#  define NORETURN __attribute__((noreturn))
#else
#  ifdef __WATCOMC__
#    define NORETURN __declspec(noreturn)
#  else
#    define NORETURN
#  endif
#endif

/* Use this NORETURN to pacify GCC 4.1 warning about a possibly
 * uninitialized variable after find_cf_header(...) returns.
 */
static NORETURN void fatal(char const *msg) {
  (void)!write(2, msg, strlen(msg));
  exit(125);
}
#ifdef __SC__
#  pragma noreturn (fatal)
#endif

#ifdef USE_SBRK
static void bad_sbrk(void) {
  fatal("fatal: sbrk failure\r\n");  /* Not an out-of-memory error. */
}
#endif

static char *brk0, *brk1;

#define IS_BRK_ERROR(x) ((unsigned)(x) + 1 <= 1U)  /* 0 and -1 are errors. */

/* Allocate a read-write-execute memory block size. This happens to
 * zero-initialize the bytes because sbrk(2), mmap and VirtualAlloc
 * zero-initialize.
 */
static void *alloc(unsigned size) {
#ifndef USE_SBRK
  unsigned psize;
#endif
  void *result;
  size = (size + 3) & ~3;  /* 4-byte alignment. */
  if (size == 0) return NULL;
  while ((unsigned)(brk1 - brk0) < size) {
#ifdef USE_SBRK  /* Typically sbrk(2) doesn't allocate read-write-execute memory (which we need), not even with `gcc -static -Wl,-N. But it succeds with `minicc --diet'. */
    if (IS_BRK_ERROR(brk1 = sbrk(0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
    if (!brk0) brk0 = brk1;  /* Initialization at first call. */
    if ((unsigned)(brk1 - brk0) >= size) break;
    /* TODO(pts): Allocate more than necessary, to save on system call round-trip time. */
    if (IS_BRK_ERROR(sbrk(size - (brk1 - brk0)))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
    if (IS_BRK_ERROR(brk1 = sbrk(0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
    if ((unsigned)(brk1 - brk0) < size) return NULL;  /* Not enough memory. */
    break;
#else  /* Use mmap(2) or VirtualAlloc(2). */
    /* TODO(pts): Write a more efficient memory allocator, and write one
     * which tries to allocate less if more is not available.
     */
    psize = (size + 0xfff) & ~0xfff;  /* Round up to page boundary. */
    if (!psize) return NULL;  /* Not enough memory. */
    if (!(psize >> 18)) psize = 1 << 18;  /* Round up less than 256 KiB to 256 KiB. */
#ifdef _WIN32  /* Use VirtualAlloc(...). */
#ifndef   PAGE_EXECUTE_READWRITE
#  define PAGE_EXECUTE_READWRITE 0x40
#endif
#ifndef   MEM_COMMIT
#  define MEM_COMMIT 0x1000
#endif
#ifndef   MEM_RESERVE
#  define MEM_RESERVE 0x2000
#endif
    if (!(brk0 = VirtualAlloc(NULL, psize, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE))) return NULL;  /* Not enough memory. */
#else  /* Use mmap(2). */
    if (!(brk0 = mmap(NULL, psize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0))) return NULL;  /* Not enough memory. */
#endif
    /* TODO(pts): Use the rest of the previous brk0...brk1 for smaller amounts. */
    brk1 = brk0 + psize;
    break;
#endif
  }
  result = brk0;
  brk0 += size;
  return result;
}

enum os_t {
  OS_DOS = 0,
  OS_OS2 = 1,
  OS_WIN32 = 2,
  OS_WIN16 = 3,
  OS_UNKNOWN = 4  /* Anything above 3 is unknown. */
};

enum oix_error_t {  /* Same as DOS and OS/2 error codes. */
  ERR_OK = 0,
  ERR_INVALID_FUNCTION,
  ERR_FILE_NOT_FOUND,
  ERR_PATH_NOT_FOUND,
  ERR_TOO_MANY_OPEN_FILES,
  ERR_ACCESS_DENIED,
  ERR_INVALID_HANDLE,
  ERR_ARENA_TRASHED,
  ERR_NOT_ENOUGH_MEMORY,
  ERR_INVALID_BLOCK,
  ERR_BAD_ENVIRONMENT,
  ERR_BAD_FORMAT,
  ERR_INVALID_ACCESS,
  ERR_INVALID_DATA,
  ERR_RESERVED,
  ERR_INVALID_DRIVE,
  ERR_CURRENT_DIRECTORY,
  ERR_NOT_SAME_DEVICE,
  ERR_NO_MORE_FILES,
  ERR_WRITE_PROTECT,
  ERR_BAD_UNIT,
  ERR_NOT_READY,
  ERR_BAD_COMMAND,
  ERR_CRC,
  ERR_BAD_LENGTH,
  ERR_SEEK,
  ERR_NOT_DOS_DISK,
  ERR_SECTOR_NOT_FOUND,
  ERR_OUT_OF_PAPER,
  ERR_WRITE_FAULT,
  ERR_READ_FAULT,
  ERR_GEN_FAILURE,
  ERR_SHARING_VIOLATION,
  ERR_LOCK_VIOLATION,
  ERR_WRONG_DISK,
  ERR_FCB_UNAVAILABLE,
  ERR_SHARING_BUFFER_EXCEEDED
  /* https://stanislavs.org/helppc/dos_error_codes.html has more, but OS/2 has different ones. */
};

enum oix_syscall_t {
  INT21H_FUNC_06H_DIRECT_CONSOLE_IO = 0x6,
  INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO = 0x8,
  INT21H_FUNC_19H_GET_CURRENT_DRIVE = 0x19,
  INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS = 0x1a,
  INT21H_FUNC_2AH_GET_DATE = 0x2a,
  INT21H_FUNC_2CH_GET_TIME = 0x2c,
  INT21H_FUNC_3BH_CHDIR = 0x3b,
  INT21H_FUNC_3CH_CREATE_FILE = 0x3c,
  INT21H_FUNC_3DH_OPEN_FILE = 0x3d,
  INT21H_FUNC_3EH_CLOSE_FILE = 0x3e,
  INT21H_FUNC_3FH_READ_FROM_FILE = 0x3f,
  INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE = 0x40,
  INT21H_FUNC_41H_DELETE_NAMED_FILE = 0x41,
  INT21H_FUNC_42H_SEEK_IN_FILE = 0x42,
  INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES = 0x43,
  INT21H_FUNC_44H_IOCTL_IN_FILE = 0x44,
  INT21H_FUNC_47H_GET_CURRENT_DIR = 0x47,
  INT21H_FUNC_48H_ALLOCATE_MEMORY = 0x48,
  INT21H_FUNC_4CH_EXIT_PROCESS = 0x4c,
  INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE = 0x4e,
  INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE = 0x4f,
  INT21H_FUNC_56H_RENAME_FILE = 0x56,
  INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME = 0x57,
  INT21H_FUNC_60H_GET_FULL_FILENAME = 0x60
};

/* The program calls this callback to do I/O and other system functions.
 *
 * For comparison, see the function __Int21C in bld/w32loadr/int21nt.c in
 * the OpenWatcom 1.0 sources
 * (https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip), which
 * implements the OIX syscall ABI using the Win32 API.
 */
static void handle_syscall(struct pushad_regs *r) {
  const unsigned char ah = r->eax >> 8;
  const unsigned bx = (unsigned short)r->ebx;
  int pos, fd;
  CLC(r); /* Success. TODO(pts): Some calls don't chage CF. */
  if (ah == INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE) {
    if (r->ecx != 0) {
      r->eax = write(bx, (const void*)r->edx, r->ecx);
      if ((int)r->eax < 0) { r->eax = ERR_WRITE_FAULT; goto do_error; }  /* TODO(pts): Better. */
    } else {  /* Truncate. */
      if ((pos = lseek(bx, 0, SEEK_CUR)) == -1) { r->eax = ERR_SEEK; goto do_error; }
#ifdef _WIN32
      if (chsize(bx, pos) != 0) { r->eax = ERR_GEN_FAILURE; goto do_error; }
#else
      if (ftruncate(bx, pos) != 0) { r->eax = ERR_GEN_FAILURE; goto do_error; }
#endif
      r->eax = 0;
    }
  } else if (ah == INT21H_FUNC_3FH_READ_FROM_FILE) {
    r->eax = read(bx, (void*)r->edx, r->ecx);
    if ((int)r->eax < 0) { r->eax = ERR_READ_FAULT; goto do_error; }  /* TODO(pts): Better. */
  } else if (ah == INT21H_FUNC_48H_ALLOCATE_MEMORY) {  /* This OIX-specific API function differs from the typical DOS extender API. */
    r->eax = (unsigned)alloc(r->ebx);
    if (!r->eax) { r->eax = ERR_NOT_ENOUGH_MEMORY; goto do_error; }
  } else if (ah == INT21H_FUNC_4CH_EXIT_PROCESS) {
    exit((unsigned char)r->eax);
  } else if (ah == INT21H_FUNC_3CH_CREATE_FILE) {
    /* Ignore attributes in CX. */
    fd = O_RDWR | O_CREAT | O_TRUNC;
   do_open:
    if ((fd = open((void*)r->edx, fd | O_BINARY, 0666)) < 0) {
     do_ferr:
      r->eax = (errno == ENOENT || errno == ENOTDIR) ? ERR_FILE_NOT_FOUND : (errno == EACCES) ? ERR_ACCESS_DENIED : ERR_BAD_FORMAT;
      goto do_error;
    }
    /* The ABI only allows 16-bit filehandles. So we fail of the POSIX
     * system gives us larger ones (extremely rare, it gives out filehandles
     * from 0, increasing 1 by 1).
     */
    if ((unsigned)fd > 0xffff) { close(fd); r->eax = ERR_TOO_MANY_OPEN_FILES; goto do_error; }
    r->eax = fd;  /* We set the entire EAX (not only AX), just like int21nt.c does it. The PMODE/W DOS extender also sets the entire EAX. */
  } else if (ah == INT21H_FUNC_3DH_OPEN_FILE) {
    fd = r->eax & 3;  /* O_RDONLY == 0, O_WRONLY == 1, O_RDWR == 2. */
    goto do_open;
  } else if (ah == INT21H_FUNC_3EH_CLOSE_FILE) {
    if (close(bx) != 0) { r->eax = ERR_INVALID_HANDLE; goto do_error; }
  } else if (ah == INT21H_FUNC_42H_SEEK_IN_FILE) {
    if ((pos = lseek(bx, r->ecx << 16 | (unsigned short)r->edx, (unsigned char)r->eax)) == -1) { r->eax = ERR_SEEK; goto do_error; }
    r->edx = (unsigned)pos >> 16;  /* Zero-extend. */
    r->eax = pos;  /* Don't clobber to 16 bits, int21nt.c doesn't do it either. */
  } else if (ah == INT21H_FUNC_44H_IOCTL_IN_FILE) {
    if ((r->eax & 0xff) != 0) goto do_invalid;
    /* Get device information. */
    r->edx = isatty(bx) ? 0x80 : 0;  /* 0x80 indicates character device. */  /* We set the entire EDX (not only DX), just like int21nt.c does it. The PMODE/W DOS extender sets only DX. */
  } else if (ah == INT21H_FUNC_41H_DELETE_NAMED_FILE) {
    if (unlink((const char*)r->edx) != 0) goto do_ferr;
  } else if (ah == INT21H_FUNC_56H_RENAME_FILE) {
    if (rename((const char*)r->edx, (const char*)r->edi) != 0) goto do_ferr;
  } else { do_invalid:
    /* TODO(pts): Implement more of the API. */
    r->eax = ERR_INVALID_FUNCTION;  /* TODO(pts): What does DOS do? */
   do_error:
    STC(r);
  }
}

/* Returns the number of bytes needed by append_arg_quoted(arg).
 * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
 */
static size_t get_arg_quoted_size(const char *arg) {
  const char *p;
  size_t size = 1;  /* It starts with space even if it's the first argument. */
  size_t bsc;  /* Backslash count. */
  for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\v' && *p != '"'; ++p) {}
  if (p != arg && *p == '\0') return size + (p - arg);  /* No need to quote. */
  size += 2;  /* Two '"' quotes, one on each side. */
  for (p = arg; ; ++p) {
    for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
    if (*p == '\0') {
      size += bsc << 1;
      break;
    }
    if (*p == '"') bsc = (bsc << 1) + 1;
    size += bsc + 1;
  }
  return size;
}

/* Appends the quoted (escaped) arg to pout, always starting with a space, and returns the new pout.
 * Implements the inverse of parts of CommandLineToArgvW(...).
 * Implementation corresponds to get_arg_quoted_size(arg).
 * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
 */
static char *append_arg_quoted(const char *arg, char *pout) {
  const char *p;
  size_t bsc;  /* Backslash count. */
  *pout++ = ' ';  /* It starts with space even if it's the first argument. */
  for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\v' && *p != '"'; ++p) {}
  if (p != arg && *p == '\0') {  /* No need to quote. */
    for (p = arg; *p != '\0'; *pout++ = *p++) {}
    return pout;
  }
  *pout++ = '"';
  for (p = arg; ; *pout++ = *p++) {
    for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
    if (*p == '\0') {
      for (bsc <<= 1; bsc != 0; --bsc, *pout++ = '\\') {}
      break;
    }
    if (*p == '"') bsc = (bsc << 1) + 1;
    for (; bsc != 0; --bsc, *pout++ = '\\') {}
  }
  *pout++ = '"';
  return pout;
}

static char *concatenate_args(char **args) {
  char **argp, *result, *pout;
  size_t size = 1;  /* Trailing '\0'. */
  for (argp = args; *argp; size += get_arg_quoted_size(*argp++)) {}
  ++size;
  result = alloc(size);  /* Will never be freed. */
  if (result) {
    pout = result;
    for (pout = result, argp = args; *argp; pout = append_arg_quoted(*argp++, pout)) {}
    *pout = '\0';
  }
  return result;
}

static char *concatenate_env(char **env) {
  size_t size = 4;  /* Trailing \0\0 (for extra count) and \0 (empty NUL-terminated program name). +1 for extra safety. */
  char **envp, *p, *pout;
  char *result;
  for (envp = env; (p = *envp); ++envp) {
    if (*p == '\0') continue;  /* Skip empty env var. Usually there is none. */
    while (*p++ != '\0') {}
    size += p - *envp;
  }
  result = alloc(size);  /* Will never be freed. */
  if (result) {
    pout = result;
    for (envp = env; (p = *envp); ++envp) {
      if (*p == '\0') continue;  /* Skip empty env var. Usually there is none. */
      while ((*pout++ = *p++) != '\0') {}
    }
    *pout++ = '\0';  /* Low byte of extra count. */
    *pout++ = '\0';  /* High byte of extra count. */
    *pout++ = '\0';  /* Empty NUL-terminated program name. */
    *pout = '\0';  /* Extra safety. */
  }
  return result;
}

static void apply_relocations(char *image_base, const unsigned short *rp) {
  unsigned count;
  char *at;
  while ((count = *rp++)) {
    at = image_base + (*rp++ << 16);
    do {
      at += *rp++;  /* !! Apply this optimization to other implementations. */
      *(unsigned*)at += (unsigned)image_base;  /* Apply single relocation. */
    } while (--count);
  }
}

struct cf_header {
  unsigned signature;  /* "CF\0\0"; 'C'|'F'<<8. CF_SIGNATURE. */
  unsigned load_fofs;  /* Start reading the image at this file offset. */
  unsigned load_size;  /* Load that many image bytes. */
  unsigned reloc_rva;  /* Apply relocations starting in the file at load_fofs+reloc_rva. */
  unsigned mem_size;   /* Preallocate this many bytes of memory for the image. Fill the bytes between load_size and mem_size with NUL (0 byte). */
  unsigned entry_rva;  /* To start the program, do a far call to this many bytes after the allocated memory region. */
};
typedef char assert_sizeof_cf_header[sizeof(struct cf_header) == 0x18 ? 1 : -1];
#define CF_SIGNATURE ((unsigned)('C'|'F'<<8))
#define ELF_SIGNATURE ((unsigned)(0x7f|'E'<<8|'L'<<16|'F'<<24))

static void find_cf_header(int fd, struct cf_header *hdr) {
  char buf[0x200], *p;  /* Same size as oixrun.nasm. */
  unsigned u;
  int got;
  if ((got = read(fd, buf, sizeof(buf))) < 0x18) fatal("fatal: error reading program header\r\n");
  got -= 0x18;
  /* TODO(pts): Find CF_SIGNATURE elsewhere as well. */
  if (*(const unsigned*)(p = buf) == CF_SIGNATURE) {
   found:
    *hdr = *(struct cf_header*)p;
    return;
  }
  if ((unsigned)got >= 0x54 && *(const unsigned*)buf == ELF_SIGNATURE && *(const unsigned*)(p = buf + 54) == CF_SIGNATURE) goto found;
  if ((unsigned)got >= 0x20 && *(const unsigned*)(p = buf + 0x20) == CF_SIGNATURE) goto found;
  if ((unsigned)got >= 0xa && (u = *(const unsigned short*)(buf + 8) << 4) <= (unsigned)got && *(const unsigned*)(p = buf + u) == CF_SIGNATURE) goto found;
  fatal("fatal: CF signature not found\r\n");
}

extern char **environ;

static unsigned break_flag;

#ifdef USE_TRAMP_H
#  include "tramp.h"  /* Defines const char tramp386[] = {...}; */
#else  /* NASM source code precompiled. */
/* ; All function pointers are 32-bit near (i.e. no segment part). But this trampoline can take both near and far calls:
 * ;
 * ; * tramp works when called as either near or far call.
 * ; * tramp calls `program_entry' so that it works if program_entry expects a near or far call.
 * ; * handle_far_syscall expects to be called as a far call. This is part of the OIX ABI, and can't be reliably autodetected.
 * ; * handle_far_syscall calls c_handler is called as a near call. TODO(pts): Make it work as either.
 *
 * bits 32
 * cpu 386
 * tramp:  ; Only works as a near call.
 * 		jmp strict short tramp2
 *
 * handle_far_syscall:  ; We assume far call (`retf'), we can't autodetect without active cooperation (stack pushing) from the program.
 * 		pushfd
 * 		pushad
 * 		mov eax, esp  ; EAX := (address of struct pushad_regs).
 * 		push eax  ; For the cdecl calling convention.
 * 		mov ebx, eax  ; Make it work with any calling convention by making EAX, EBX, ECX and EDX the same. https://en.wikipedia.org/wiki/X86_calling_conventions
 * 		mov ecx, eax
 * 		mov edx, eax
 * 		db 0xbe  ; mov esi, ...
 * .c_handler:	dd 0  ; Will be populated by tramp.
 * 		call esi
 * 		pop eax  ; Clean up the argument of c_handler from the stack.
 * 		popad
 * 		popfd
 * 		retf
 *
 * tramp2:  ; Only works as a near call.
 * 		pushad
 * 		lea esi, [esp+0x24]  ; ESI := address of the struct tramp_args pointer, or return CS in a far call.
 * 		call .me
 * .me:		pop ebp  ; For position-independent code with ebp-.me+
 * 		lodsd
 * 		test eax, eax
 * 		jz strict short .skip  ; It was a near call, `ret' below will suffice.
 * 		mov byte [ebp-.me+.ret], 0xcb  ; Replace ret with retf, to support return from far call.
 * .skip:		lodsd
 * 		test eax, eax
 * 		jz strict short .skip
 * .got_args:	xchg esi, eax ; ESI := address of c_handler; EAX := junk. Previously it was address of struct tramp_args
 * 		lodsd  ; EAX := c_handler.
 * 		lea edx, [ebp-.me+handle_far_syscall]
 * 		mov [ebp-.me+handle_far_syscall.c_handler], eax  ; This needs read-write-execute memory.
 * 		lodsd  ; EAX := program_entry.
 * 		xchg edi, eax  ; EDI := EAX (program entry point); EAX := junk.
 * 		lodsd  ; EAX := stack_low.
 * 		xchg ecx, eax  ; ECX := EAX (stack low); EAX := junk.
 * 		lodsd  ; EAX := operating_system.
 * 		movzx eax, al  ; Make sure to use only the low byte.
 * 		shl eax, 8  ; AH := operating_system.
 * 		xchg edi, esi  ; EDI := ESI (OIX param_struct); ESI := EDI (program entry point).
 * 		mov ebx, cs  ; Segment of handle_far_syscall.
 * 		push byte 0  ; Sentinel in case the function does a retf (far return). OIX entry points do.
 * 		push ebx  ; CS, assuming nonzero.
 * 		sub ebp, ebp  ; Not needed by the ABI, just make it deterministic. Also initializes many flags in EFLAGS.
 * 		call esi  ; Far or near call to the program entry point. Return value in EAX.
 * .pop_again:	pop ebx  ; Find sentinel.
 * 		test ebx, ebx
 * 		jnz .pop_again
 * 		mov [esp+0x1c], eax  ; Overwrite the EAX saved by pushad.
 * 		popad
 * .ret:		ret
 */
  static const char tramp386[] =
      /*@0x00*/  "\xEB\x16"              /* jmp short 0x18 */
      /*@0x02*/  "\x9C"                  /* pushf */
      /*@0x03*/  "\x60"                  /* pusha */
      /*@0x04*/  "\x89\xE0"              /* mov eax, esp */
      /*@0x06*/  "\x50"                  /* push eax */
      /*@0x07*/  "\x89\xC3"              /* mov ebx, eax */
      /*@0x09*/  "\x89\xC1"              /* mov ecx, eax */
      /*@0x0B*/  "\x89\xC2"              /* mov edx, eax */
      /*@0x0D*/  "\xBE\x00\x00\x00\x00"  /* mov esi, 0x0 */
      /*@0x12*/  "\xFF\xD6"              /* call esi */
      /*@0x14*/  "\x58"                  /* pop eax */
      /*@0x15*/  "\x61"                  /* popa */
      /*@0x16*/  "\x9D"                  /* popf */
      /*@0x17*/  "\xCB"                  /* retf */
      /*@0x18*/  "\x60"                  /* pusha */
      /*@0x19*/  "\x8D\x74\x24\x24"      /* lea esi, [esp+0x24] */
      /*@0x1D*/  "\xE8\x00\x00\x00\x00"  /* call 0x22 */
      /*@0x22*/  "\x5D"                  /* pop ebp */
      /*@0x23*/  "\xAD"                  /* lodsd */
      /*@0x24*/  "\x85\xC0"              /* test eax, eax */
      /*@0x26*/  "\x74\x04"              /* jz 0x2c */
      /*@0x28*/  "\xC6\x45\x37\xCB"      /* mov byte [ebp+0x37], 0xcb */
      /*@0x2C*/  "\xAD"                  /* lodsd */
      /*@0x2D*/  "\x85\xC0"              /* test eax, eax */
      /*@0x2F*/  "\x74\xFB"              /* jz 0x2c */
      /*@0x31*/  "\x96"                  /* xchg eax, esi */
      /*@0x32*/  "\xAD"                  /* lodsd */
      /*@0x33*/  "\x8D\x55\xE0"          /* lea edx, [ebp-0x20] */
      /*@0x36*/  "\x89\x45\xEC"          /* mov [ebp-0x14], eax */
      /*@0x39*/  "\xAD"                  /* lodsd */
      /*@0x3A*/  "\x97"                  /* xchg eax, edi */
      /*@0x3B*/  "\xAD"                  /* lodsd */
      /*@0x3C*/  "\x91"                  /* xchg eax, ecx */
      /*@0x3D*/  "\xAD"                  /* lodsd */
      /*@0x3E*/  "\x0F\xB6\xC0"          /* movzx eax, al */
      /*@0x41*/  "\xC1\xE0\x08"          /* shl eax, 0x8 */
      /*@0x44*/  "\x87\xFE"              /* xchg edi, esi */
      /*@0x46*/  "\x8C\xCB"              /* mov ebx, cs */
      /*@0x48*/  "\x6A\x00"              /* push byte +0x0 */
      /*@0x4A*/  "\x53"                  /* push ebx */
      /*@0x4B*/  "\x31\xED"              /* xor ebp, ebp */
      /*@0x4D*/  "\xFF\xD6"              /* call esi */
      /*@0x4F*/  "\x5B"                  /* pop ebx */
      /*@0x50*/  "\x85\xDB"              /* test ebx, ebx */
      /*@0x52*/  "\x75\xFB"              /* jnz 0x4f */
      /*@0x54*/  "\x89\x44\x24\x1C"      /* mov [esp+0x1c], eax */
      /*@0x58*/  "\x61"                  /* popa */
      /*@0x59*/  "\xC3"                  /* ret */
    ;
#endif

int main(int argc, char **argv) {
  struct tramp_args ta;
  char *tramp386_copy;
  int fd;
  struct cf_header hdr;
  char *image;
  (void)argc; (void)argv;
#if defined(_WIN32) && O_BINARY
  setmode(0, O_BINARY);
  setmode(1, O_BINARY);
  setmode(2, O_BINARY);
#endif
  if (!argv[0] || !argv[1]) fatal("Usage: oixrun <prog.oix> [<arg> ...]\r\n");
  /* TODO(pts): binmode(...) etc. On POSIX it's not needed. */
  if (!(tramp386_copy = alloc(sizeof(tramp386)))) fatal("fatal: initial alloc failed\r\n");
  memcpy(tramp386_copy, tramp386, sizeof(tramp386));
  if ((fd = open(argv[1], O_RDONLY | O_BINARY)) < 0) fatal("fatal: error opening OIX program\r\n");
  find_cf_header(fd, &hdr);
  /* TODO(pts): Do some bounds-checking on the cf_header fields. */
  if (!(image = alloc(hdr.mem_size))) fatal("fatal: not enough memory for program image\r\n");
  if (!(ta.command_line = concatenate_args(argv + 2))) fatal("fatal: not enough memory for argv\r\n");
  if (!(ta.env_strings = concatenate_env(environ))) fatal("fatal: not enough memory for environ\r\n");
  if (lseek(fd, hdr.load_fofs, SEEK_SET) + 0U != hdr.load_fofs) fatal("fatal: error seeking to program image\r\n");
  if (read(fd, image, hdr.load_size) + 0U != hdr.load_size) fatal("fatal: error reading program image\r\n");
  close(fd);
#if !defined(__TINYCC__) && !defined(__WATCOMC__)  /* TCC doesn't optimize, __WATCOMC__ complains about unreachable code. */
  /* This zero-initialization of OIX program BSS is not needed, because alloc(...) already zero-initializes memory. */
  if (0) memset(image + hdr.load_size, '\0', hdr.mem_size - hdr.load_size);
#endif
  apply_relocations(image, (const unsigned short*)(image + hdr.reloc_rva));
  ta.c_handler = handle_syscall;
  ta.program_entry = image + hdr.entry_rva;
  ta.operating_system = OS_WIN32;  /* A plausible lie. */
  ta.stack_low = NULL;
  ta.program_filename = argv[1];
  ta.break_flag_ptr = &break_flag;  /* break_flag is always zero. WLIB relies on non-NULL pointer. */
  ta.copyright = NULL;
  ta.is_japanese = 0;
  ta.max_handle_for_os2 = 0;
  /* We use varargs (`...') to force caller-pops calling convention (Watcom
   * default __watcall isn't one if not all arguments fit in registers. We push
   * two NULL pointers so that at least one ends up on the stack, and tramp can
   * use it to detect a far call.
   *
   * https://en.wikipedia.org/wiki/X86_calling_conventions
   */
  /* Without __extension__, `gcc -ansi -pedantic' reports: warning: ISO C forbids conversion of object pointer to function pointer type */
  return (__extension__ (int(*)(void*, ...))tramp386_copy)(NULL, NULL, &ta);
}
