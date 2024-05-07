/*
 * oixrun.c: OIX program runner reference implementation in C, for POSIX and Win32 and OS/2 2.0+, for i386 only
 * by pts@fazekas.hu at Sat May  4 01:51:30 CEST 2024
 *
 * Compile with GCC for any Unix: gcc -m32 -march=i386 -s -Os -W -Wall -ansi -pedantic -o oixrun oixrun.c
 * Compile with Clang for any Unix: clang -m32 -march=i386 -s -Os -W -Wall -ansi -pedantic -o oixrun oixrun.c
 * Compile with TinyCC for Linux: tcc -s -Os -W -Wall -o oixrun oixrun.c
 * Compile with minicc (https://github.com/pts/minilibc686) for Linux i386: minicc -ansi -pedantic -o oixrun oixrun.c
 * Compile with Clang for macOS 10.14 Mojave or earlier on macOS: gcc -m32 -march=i386 -O2 -W -Wall -ansi -pedantic -o oixrun oixrun.c && strip oixrun
 * Compile with Clang for macOS 10.14 Mojave or earlier on Linux amd64 with pts-osxcross (https://github.com/pts/pts-osxcross): ~/Downloads/pts_osxcross_10.10/i386-apple-darwin14/bin/gcc -m32 -march=i386 -mmacosx-version-min=10.5 -nodefaultlibs -lSystem -O2 -W -Wall -ansi -pedantic -o oixrun.darwinc32 oixrun.c && ~/Downloads/pts_osxcross_10.10/i386-apple-darwin14/bin/strip oixrun.darwinc32
 * Compile with mingw-w64 GCC for Win32: i686-w64-mingw32-gcc -s -Os -W -Wall -o oixrun.exe oixrun.c
 * Compile with TinyCC for Win32: i386-win-tcc -s -Os -W -Wall -o oixrun.exe oixrun.c
 * Compile with the OpenWatcom v2 C compiler for Linux i386: owcc -blinux -I"$WATCOM/lh" -s -Os -W -Wall -std=c89 -o oixrun oixrun.c
 * Compile with the OpenWatcom v2 C compiler for 32-bit DOS (compiles but untested): owcc -bdos4g -Wc,-bt=dos32 -s -Os -W -Wall -std=c89 -o oixrun.exe oixrun.c
 * Compile with the OpenWatcom v2 C compiler for OS/2 2.0+: owcc -bos2v2 -march=i386 -s -Os -W -Wall -std=c89 -o oixrun.exe oixrun.c
 * Compile with the OpenWatcom v2 C compiler for Win32: owcc -bwin32 -march=i386 -s -Os -W -Wall -std=c89 -o oixrun.exe oixrun.c
 * Compile with the Digital Mars C compiler for Win32: dmc -v0 -3 -w2 -o+space oixrun.c
 *
 * This is the reference implementation, meaning that in case of ambiguity
 * this implementation (among the multiple implementations in WCFD32,
 * especially in run1/, run2/, run3/ etc.) is definitive.
 *
 * This implementation was written by pts from scratch, by looking at
 * OpenWatcom 1.0 sources only.
 *
 * Pass -DUSE_SBRK if your system has sbrk(2), but not mmap(2). On most
 * systems, sbrk(2) doesn't allocate read-write-execute memory, but oixrun
 * needs it, so we use mmap(2) by default instead.
 *
 * TODO(pts): Check for i386, little-endian, 32-bit mode etc. system. Start with C #ifdef()s.
 * !! TODO(pts): Do some extra sanity checks that we are compiling for i386. Even at runtime: try to disassemble a simple function: void tryf(void) { return 0x12345678; }
 */

#define _FILE_OFFSET_BITS 32  /* The OIX ABI doesn't support more. */
#include "poix1.h"

#ifdef __OS2__  /* Maybe h/os2 (for __WATCOMC__) is not on the include path. */
  /* os2/bsedos.h */
  unsigned long _System DosSetRelMaxFH(long *pcbReqCount, unsigned long *pcbCurMaxFH);  /* http://www.edm2.com/index.php/DosSetRelMaxFH */
#endif

#ifndef __i386__
#  if defined(__amd64__) || defined(__x86_64__) || defined(_M_X64) || defined(_M_AMD64) || defined(__X86_64__) || defined(_M_X64) || defined(_M_AMD64) || \
    defined(__X86__) || defined(__I86__) || defined(_M_I86) || defined(_M_I8086) || defined(_M_I286) || \
    defined(__BIG_ENDIAN__) || (defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__) && __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__) || \
    defined(__ARMEB__) || defined(__THUMBEB__) || defined(__AARCH64EB__) || defined(_MIPSEB) || defined(__MIPSEB) || defined(__MIPSEB__) || \
    defined(__powerpc__) || defined(_M_PPC) || defined(__m68k__) || defined(_ARCH_PPC) || defined(__PPC__) || defined(__PPC) || defined(PPC) || \
    defined(__powerpc) || defined(powerpc) || (defined(__BIG_ENDIAN) && (!defined(__BYTE_ORDER) || __BYTE_ORDER == __BIG_ENDIAN +0)) || \
    defined(_BIG_ENDIAN) || \
    defined(__ARMEL__) || defined(__THUMBEL__) || defined(__AARCH64EL__) || defined(_MIPSEL) || defined (__MIPSEL) || defined(__MIPSEL__) || \
    defined(__ia64__) || defined(__LITTLE_ENDIAN) || defined(_LITTLE_ENDIAN)
#    error Unsupported CPU architecture detected. This program requires i386. If you are sure, then recompile with -D__386
#  else  /* TODO(pts): Add some runtime (disassembly) checks. */
#    error CPU architecture not detected. If you are sure you have i386, then recompile with -D__386
#  endif
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
  long is_japanese;  /* Using the type `long' because for __OS2__ we reuse this for the req_count. */
  unsigned long max_handle_for_os2;
};

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

enum os_t {
  OS_DOS = 0,
  OS_OS2 = 1,
  OS_WIN32 = 2,
  OS_WIN16 = 3,
  OS_UNKNOWN = 4  /* Anything above 3 is unknown. */
};

/* Same as DOS, OS/2 and Win32 (ERROR_SUCCESS etc.) error codes (!), not the
 * same as POSIX errno E* numbers. The ERRH_* (above 0x12) error codes are
 * never returned by DOS except as extended error info with int 21h, AH ==
 * 0x59.
 */
enum oix_error_t {
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
  ERRH_WRITE_PROTECT,
  ERRH_BAD_UNIT,
  ERRH_NOT_READY,
  ERRH_BAD_COMMAND,
  ERRH_CRC,
  ERRH_BAD_LENGTH,
  ERRH_SEEK,
  ERRH_NOT_DOS_DISK,
  ERRH_SECTOR_NOT_FOUND,
  ERRH_OUT_OF_PAPER,
  ERRH_WRITE_FAULT,
  ERRH_READ_FAULT,
  ERRH_GEN_FAILURE,
  ERRH_SHARING_VIOLATION,
  ERRH_LOCK_VIOLATION,
  ERRH_WRONG_DISK,
  ERRH_FCB_UNAVAILABLE,
  ERRH_SHARING_BUFFER_EXCEEDED
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
  char c;
#ifdef DEBUG_MORE
    fprintf(stderr, "info: trying OIX function: 0x%02x\r\n", ah);
#endif
  if (ah == INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE) {
    if (r->ecx != 0) {
      r->eax = write(bx, (const void*)r->edx, r->ecx);
      if ((int)r->eax < 0) { r->eax = ERR_INVALID_DATA /* ERRH_WRITE_FAULT */; goto do_error; }  /* TODO(pts): Better. */
    } else {  /* Truncate. */
      if ((pos = lseek(bx, 0, SEEK_CUR)) == -1) { r->eax = ERR_INVALID_DATA /* ERRH_SEEK */; goto do_error; }
      if (ftruncate(bx, pos) != 0) { r->eax = ERR_INVALID_DATA  /* ERR_GEN_FAILURE */; goto do_error; }
      r->eax = 0;
    }
  } else if (ah == INT21H_FUNC_3FH_READ_FROM_FILE) {
    r->eax = read(bx, (void*)r->edx, r->ecx);
    if ((int)r->eax < 0) { r->eax = ERR_INVALID_DATA  /* ERRH_READ_FAULT */; goto do_error; }  /* TODO(pts): Better. */
  } else if (ah == INT21H_FUNC_48H_ALLOCATE_MEMORY) {  /* This OIX-specific API function differs from the typical DOS extender API. */
    r->eax = (unsigned)cealloc(r->ebx);
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
    if ((pos = lseek(bx, r->ecx << 16 | (unsigned short)r->edx, (unsigned char)r->eax)) == -1) { r->eax = ERR_INVALID_DATA /* ERRH_SEEK */; goto do_error; }
    r->edx = (unsigned)pos >> 16;  /* Zero-extend. The PMODE/W DOS extender doesn't zero-extend it, but WCFD32 fixes it. */
    r->eax = pos;  /* Don't clobber to 16 bits, int21nt.c doesn't do it either. The PMODE/W DOS extender clobbers it, but WCFD32 fixes it. */
  } else if (ah == INT21H_FUNC_44H_IOCTL_IN_FILE) {
    if ((r->eax & 0xff) != 0) { do_invalid:
      r->eax = ERR_INVALID_FUNCTION;
      goto do_error;
    }
    /* Get device information. */
    r->edx = isatty(bx) ? 0x80 : 0;  /* 0x80 indicates character device. */  /* We set the entire EDX (not only DX), just like int21nt.c does it. The PMODE/W DOS extender sets only DX, but WCFD32 fixes it. */
  } else if (ah == INT21H_FUNC_41H_DELETE_NAMED_FILE) {
    if (unlink((const char*)r->edx) != 0) goto do_ferr;
  } else if (ah == INT21H_FUNC_56H_RENAME_FILE) {
    if (rename((const char*)r->edx, (const char*)r->edi) != 0) goto do_ferr;
  } else if (ah == INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO) {
    /* This is a deprecated API, please don't call it from new software.
     * binw/wasm.exe and binw/wlib.exe in Watcom C/C++ 10.0a, 10.5, 10.6, 11.0b and 11.0c use it.
     * We do a good-enough fallback implementation: we read 1 byte from stdin, it will be echoed.
     */
    if (read(0, &c, 1) != 1) c = '\n';
    *(char*)&r->eax = c;  /* Only change AL. */
    return;  /* Don't change CF. */
  } else if (ah == INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME) {
    /* This is a deprecated API, please don't call it from new software.
     * binw/wlib.exe in Watcom C/C++ 10.5 and 10.6 use it for .lib file creation (default OMF LIBHEAD format), and only for getting the time.
     * We could use our own gmtime(2), but this syscall expects local time, but not all libcs have a working localtime(2).
     */
    if (*(const char*)r->eax != 0) goto do_invalid;
    r->ecx = 0;  /* Fake file time. */
    r->edx = 1 << 5 | 1;  /* Fake file date. */
  } else if (ah == INT21H_FUNC_60H_GET_FULL_FILENAME) {
    /* This is a deprecated API, please don't call it from new software.
     * This is different from https://stanislavs.org/helppc/int_21-60.html ,
     * see int21nt.c. This gives the input pathname in EDX.
     *
     * binw/wasm.exe in Watcom C/C++ 10.6, 11.0b and 11.0c call this when
     * assembling, and it puts the result to the THEADR header as the
     * filename.
     *
     * binw/wlib.exe in Watcom C/C++ 11.0b and 11.0c call these when
     * creating library.
     *
     * We just fake it by returning the input unmodified.
     */
    unsigned size = strlen((const char*)r->edx);
#ifdef DEBUG_MORE
    fprintf(stderr, "warning: trying to get full filename of: (%s)\r\n", (const char*)r->edx);
#endif
    if (r->ecx <= size) { r->eax = ERR_INVALID_ACCESS /* ERR_BAD_LENGTH */; goto do_error; }  /* No way to query the required size. */
    memcpy((char*)r->ebx, (char*)r->edx, size + 1);
  } else {
    /* binw/wlib.exe in Watcom C/C++ 11.0b and 11.0c call these when creating library:
     * INT21H_FUNC_19H_GET_CURRENT_DRIVE = 0x19,
     * INT21H_FUNC_2AH_GET_DATE = 0x2a,
     * INT21H_FUNC_2CH_GET_TIME = 0x2c,
     * INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES = 0x43,  !! Implement this, otherwise binw/wlib.exe recreates the file.
     * INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE = 0x4e,
     * INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE = 0x4f,
     * INT21H_FUNC_60H_GET_FULL_FILENAME = 0x60,
     * binw/wasm.exe in Watcom C/C++ 10.6, 11.0b and 11.0c call these when assembling:
     * INT21H_FUNC_60H_GET_FULL_FILENAME = 0x60,
     */
#ifdef DEBUG  /* !! Make this non-debugging. */
    fprintf(stderr, "warning: unknown OIX function: 0x%02x\r\n", ah);
#endif
    /* TODO(pts): Implement more of the API. */
    *(unsigned char*)&r->eax = 0;  /* Indicate function not supported. MS-DOS 2.0, MS-DOS 6.22, DOSBox 0.74 DOS_21Handler and kvikdos also set AL := 0, some of them also set CF := 1. */
   do_error:
    STC(r);
    return;
  }
  CLC(r); /* Success. */
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
  result = cealloc(size);  /* Will never be freed. */
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
  result = cealloc(size);  /* Will never be freed. */
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
    at = image_base + ((unsigned)*rp++ << 16);
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
  if ((unsigned)got >= 0x54 && *(const unsigned*)(p = buf) == ELF_SIGNATURE && *(const unsigned*)(p = buf + 54) == CF_SIGNATURE) goto found;
  if ((unsigned)got >= 0x20 && *(const unsigned*)(p = buf + 0x20) == CF_SIGNATURE) goto found;
  if ((unsigned)got >= 0xa && (u = *(const unsigned short*)(buf + 8) << 4) <= (unsigned)got && *(const unsigned*)(p = buf + u) == CF_SIGNATURE) goto found;
  fatal("fatal: CF signature not found\r\n");
}

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
 * 		push gs
 * 		pushfd
 * 		pushad
 * 		mov eax, esp  ; EAX := (address of struct pushad_regs).
 * 		push eax  ; For the cdecl calling convention.
 * 		mov ebx, eax  ; Make it work with any calling convention by making EAX, EBX, ECX and EDX the same. https://en.wikipedia.org/wiki/X86_calling_conventions
 * 		mov ecx, eax
 * 		mov edx, eax
 * 		db 0xbe  ; mov esi, ...
 * .c_gs:	dd 0  ; Will be populated by tramp.
 * 		mov gs, esi  ; Restore host libc GS, will be used by e.g. isatty(2) for stack smashing protection (gcc without -fno-stack-protector): https://www.labcorner.de/the-gs-segment-and-stack-smashing-protection/
 * 		db 0xbe  ; mov esi, ...
 * .c_handler:	dd 0  ; Will be populated by tramp.
 * 		call esi
 * 		pop eax  ; Clean up the argument of c_handler from the stack.
 * 		popad
 * 		popfd
 * 		pop gs
 * 		retf
 *
 * tramp2:  ; Only works as a near call.
 * 		pushad
 * 		lea esi, [esp+0x24]  ; ESI := address of the struct tramp_args pointer, or return CS in a far call.
 * 		call .me
 * .me:		pop ebp  ; For position-independent code with ebp-.me+
 * 		push gs  ; Save host libc GS.
 * 		lodsd
 * 		test eax, eax
 * 		jz strict short .skip  ; It was a near call, `ret' below will suffice.
 * 		mov byte [ebp-.me+.ret], 0xcb  ; Replace ret with retf, to support return from far call.
 * .skip:	lodsd
 * 		test eax, eax
 * 		jz strict short .skip
 * .got_args:	xchg esi, eax ; ESI := address of c_handler; EAX := junk. Previously it was address of struct tramp_args
 * 		lodsd  ; EAX := c_handler.
 * 		lea edx, [ebp-.me+handle_far_syscall]
 * 		mov [ebp-.me+handle_far_syscall.c_handler], eax  ; This needs read-write-execute memory.
 * 		mov [ebp-.me+handle_far_syscall.c_gs], gs
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
 * 		pop gs  ; Restore host libc GS.
 * 		mov [esp+0x1c], eax  ; Overwrite the EAX saved by pushad.
 * 		popad
 * .ret:	ret
 */
  static const char tramp386[] =
      /*@0x00*/  "\xEB\x21"              /* jmp short 0x23 */
      /*@0x02*/  "\x0F\xA8"              /* push gs */
      /*@0x04*/  "\x9C"                  /* pushf */
      /*@0x05*/  "\x60"                  /* pusha */
      /*@0x06*/  "\x89\xE0"              /* mov eax, esp */
      /*@0x08*/  "\x50"                  /* push eax */
      /*@0x09*/  "\x89\xC3"              /* mov ebx, eax */
      /*@0x0B*/  "\x89\xC1"              /* mov ecx, eax */
      /*@0x0D*/  "\x89\xC2"              /* mov edx, eax */
      /*@0x0F*/  "\xBE\x00\x00\x00\x00"  /* mov esi, 0x0 */
      /*@0x14*/  "\x8E\xEE"              /* mov gs, si */
      /*@0x16*/  "\xBE\x00\x00\x00\x00"  /* mov esi, 0x0 */
      /*@0x1B*/  "\xFF\xD6"              /* call esi */
      /*@0x1D*/  "\x58"                  /* pop eax */
      /*@0x1E*/  "\x61"                  /* popa */
      /*@0x1F*/  "\x9D"                  /* popf */
      /*@0x20*/  "\x0F\xA9"              /* pop gs */
      /*@0x22*/  "\xCB"                  /* retf */
      /*@0x23*/  "\x60"                  /* pusha */
      /*@0x24*/  "\x8D\x74\x24\x24"      /* lea esi, [esp+0x24] */
      /*@0x28*/  "\xE8\x00\x00\x00\x00"  /* call 0x2d */
      /*@0x2D*/  "\x5D"                  /* pop ebp */
      /*@0x2E*/  "\x0F\xA8"              /* push gs */
      /*@0x30*/  "\xAD"                  /* lodsd */
      /*@0x31*/  "\x85\xC0"              /* test eax, eax */
      /*@0x33*/  "\x74\x04"              /* jz 0x39 */
      /*@0x35*/  "\xC6\x45\x3E\xCB"      /* mov byte [ebp+0x3e], 0xcb */
      /*@0x39*/  "\xAD"                  /* lodsd */
      /*@0x3A*/  "\x85\xC0"              /* test eax, eax */
      /*@0x3C*/  "\x74\xFB"              /* jz 0x39 */
      /*@0x3E*/  "\x96"                  /* xchg eax, esi */
      /*@0x3F*/  "\xAD"                  /* lodsd */
      /*@0x40*/  "\x8D\x55\xD5"          /* lea edx, [ebp-0x2b] */
      /*@0x43*/  "\x89\x45\xEA"          /* mov [ebp-0x16], eax */
      /*@0x46*/  "\x8C\x6D\xE3"          /* mov [ebp-0x1d], gs */
      /*@0x49*/  "\xAD"                  /* lodsd */
      /*@0x4A*/  "\x97"                  /* xchg eax, edi */
      /*@0x4B*/  "\xAD"                  /* lodsd */
      /*@0x4C*/  "\x91"                  /* xchg eax, ecx */
      /*@0x4D*/  "\xAD"                  /* lodsd */
      /*@0x4E*/  "\x0F\xB6\xC0"          /* movzx eax, al */
      /*@0x51*/  "\xC1\xE0\x08"          /* shl eax, 0x8 */
      /*@0x54*/  "\x87\xFE"              /* xchg edi, esi */
      /*@0x56*/  "\x8C\xCB"              /* mov ebx, cs */
      /*@0x58*/  "\x6A\x00"              /* push byte +0x0 */
      /*@0x5A*/  "\x53"                  /* push ebx */
      /*@0x5B*/  "\x29\xED"              /* sub ebp, ebp */
      /*@0x5D*/  "\xFF\xD6"              /* call esi */
      /*@0x5F*/  "\x5B"                  /* pop ebx */
      /*@0x60*/  "\x85\xDB"              /* test ebx, ebx */
      /*@0x62*/  "\x75\xFB"              /* jnz 0x5f */
      /*@0x64*/  "\x0F\xA9"              /* pop gs */
      /*@0x66*/  "\x89\x44\x24\x1C"      /* mov [esp+0x1c], eax */
      /*@0x6A*/  "\x61"                  /* popa */
      /*@0x6B*/  "\xC3"                  /* ret */
      /*@0x6C*/;
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
  if (!(tramp386_copy = cealloc(sizeof(tramp386)))) fatal("fatal: initial alloc failed\r\n");
  memcpy(tramp386_copy, tramp386, sizeof(tramp386));
  if ((fd = open(argv[1], O_RDONLY | O_BINARY)) < 0) fatal("fatal: error opening OIX program\r\n");
  find_cf_header(fd, &hdr);
  /* TODO(pts): Do some bounds-checking on the cf_header fields. */
  if (!(image = cealloc(hdr.mem_size))) fatal("fatal: not enough memory for program image\r\n");
  if (!(ta.command_line = concatenate_args(argv + 2))) fatal("fatal: not enough memory for argv\r\n");
  if (!(ta.env_strings = concatenate_env(environ))) fatal("fatal: not enough memory for environ\r\n");
  if (lseek(fd, hdr.load_fofs, SEEK_SET) + 0U != hdr.load_fofs) fatal("fatal: error seeking to program image\r\n");
  if (read(fd, image, hdr.load_size) + 0U != hdr.load_size) fatal("fatal: error reading program image\r\n");
  close(fd);
#if !defined(__TINYCC__) && !defined(__WATCOMC__)  /* TCC doesn't optimize, __WATCOMC__ complains about unreachable code. */
  /* This zero-initialization of OIX program BSS is not needed, because cealloc(...) already zero-initializes memory. */
  if (0) memset(image + hdr.load_size, '\0', hdr.mem_size - hdr.load_size);
#endif
  apply_relocations(image, (const unsigned short*)(image + hdr.reloc_rva));
  ta.c_handler = handle_syscall;
  ta.program_entry = image + hdr.entry_rva;
  ta.operating_system = OS_WIN32;  /* A plausible lie. */
  ta.stack_low = NULL;
  ta.program_filename = argv[1];
  /* TODO(pts): On POSIX, catch SIGINT, set break_flag = 1. */
  /* TODO(pts): Add interrupt and exception handling for Win32 and OS/2 2.0+ as well. */
  ta.break_flag_ptr = &break_flag;  /* break_flag is always zero. WLIB relies on non-NULL pointer. */
  ta.copyright = NULL;
#ifdef __OS2__
  ta.is_japanese = 0;
  DosSetRelMaxFH(&ta.is_japanese, &ta.max_handle_for_os2);  /* ta_is_japanese is the req_count argument. */
#else
  ta.max_handle_for_os2 = 0;
#endif
  ta.is_japanese = 0;
  /* bld/w32loadr/loader.c a */
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
