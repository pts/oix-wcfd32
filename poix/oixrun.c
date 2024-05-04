/*
 * oixrun.c: an OIX program runner reference implementation in (mostly) POSIX C, for i386 only
 * by pts@fazekas.hu at Sat May  4 01:51:30 CEST 2024
 *
 * Pass -DUSE_SBRK if your system has sbrk(2), but not mmap(2).
 *
 * TODO(pts): Check for i386, little-endian, 32-bit mode etc. system. Start with C #ifdef()s.
 * !! TODO(pts): Do some extra snity checks that we are compiling for i386. Even at runtime: try to disassemble a simple function: void tryf(void) { return 0x12345678; }
 * !! TODO(pts): Make it work with minicc.
 */

/* Make functions like sbrk(2) available. */
#define _DEFAULT_SOURCE
#define _XOPEN_SOURCE 500
#define _SVID_SOURCE

#include "tramp.h"
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>  /* rename(...). */
#include <stdlib.h>
#include <string.h>
#include <unistd.h>  /* sbrk(...). */
#ifndef USE_SBRK
#  include <sys/mman.h>  /* mmap(...). */
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
  char *program_entry;
  unsigned operating_system;
  /* Order of elements from here matter, same as in the OIX param struct. */
  char *program_filename;
  char *command_line;
  char *env_strings;
  unsigned *break_flag_ptr;
  char *copyright;
  unsigned is_japanese;
  unsigned max_handle_for_os2;
};

static void fatal(char const *msg) {
  (void)!write(2, msg, strlen(msg));
  exit(125);
}

#ifdef USE_SBRK
static void bad_sbrk(void) {
  fatal("fatal: sbrk failure\r\n");  /* Not an out-of-memory error. */
}
#endif

static char *brk0, *brk1;

/* Allocate a read-write-execute memory block size. */
static void *alloc(unsigned size) {
#ifndef USE_SBRK
  unsigned psize;
#endif
  void *result;
  size = (size + 3) & ~3;  /* 4-byte alignment. */
  if (size == 0) return NULL;
  while ((unsigned)(brk1 - brk0) < size) {
#ifdef USE_SBRK  /* Typically sbrk(2) doesn't allocate read-write-execute memory (which we need), not even with `gcc -static -Wl,-N. But it succeds with `minicc --diet'. */
    if (!(brk1 = sbrk(0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
    if (!brk0) brk0 = brk1;  /* Initialization at first call. */
    if ((unsigned)(brk1 - brk0) >= size) break;
    /* TODO(pts): Allocate more than necessary, to save on system call round-trip time. */
    if (!sbrk(size - (brk1 - brk0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
    if (!(brk1 = sbrk(0))) bad_sbrk();  /* This is fatal, it shouldn't be NULL. */
    if ((unsigned)(brk1 - brk0) < size) return NULL;  /* Not enough memory. */
    break;
#else  /* Use mmap(2). */
    /* TODO(pts): Write a more efficient memory allocator, and write one
     * which tries to allocate less if more is not available.
     */
    psize = (size + 0xfff) & ~0xfff;  /* Round up to page boundary. */
    if (!psize) return NULL;  /* Not enough memory. */
    if (!(psize >> 18)) psize = 1 << 18;  /* Round up less than 256 KiB to 256 KiB. */
    if (!(brk0 = mmap(NULL, psize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0))) return NULL;  /* Not enough memory. */
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

/* The program calls this callback to do I/O and other system functions. */
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
      if (ftruncate(bx, pos) != 0) { r->eax = ERR_GEN_FAILURE; goto do_error; }
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
    if ((fd = open((void*)r->edx, fd, 0666)) < 0) {
     do_ferr:
      r->eax = (errno == ENOENT || errno == ENOTDIR) ? ERR_FILE_NOT_FOUND : (errno == EACCES) ? ERR_ACCESS_DENIED : ERR_BAD_FORMAT;
      goto do_error;
    }
    if ((unsigned)fd > 0xffff) { r->eax = ERR_TOO_MANY_OPEN_FILES; goto do_error; }
    r->eax = fd;
  } else if (ah == INT21H_FUNC_3DH_OPEN_FILE) {
    fd = r->eax & 3;  /* O_RDONLY == 0, O_WRONLY == 1, O_RDWR == 2. */
    goto do_open;
  } else if (ah == INT21H_FUNC_3EH_CLOSE_FILE) {
    if (close(bx) != 0) { r->eax = ERR_INVALID_HANDLE; goto do_error; }
  } else if (ah == INT21H_FUNC_42H_SEEK_IN_FILE) {
    if ((pos = lseek(bx, r->ecx << 16 | (unsigned short)r->edx, (unsigned char)r->eax)) == -1) { r->eax = ERR_SEEK; goto do_error; }
    r->edx = (unsigned)pos >> 16;  /* Zero-extend. */
    r->eax = (unsigned short)pos;
  } else if (ah == INT21H_FUNC_44H_IOCTL_IN_FILE) {
    if ((r->eax & 0xff) != 0) goto do_invalid;
    /* Get device information. */
    r->edx = isatty(bx) ? 0x80 : 0;  /* 0x80 indicates character device. */
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

int main(int argc, char **argv) {
  struct tramp_args ta;
  typedef struct tramp_args *t;
  char *tramp386_copy;
  int fd;
  struct cf_header hdr;
  char *image;
  (void)argc; (void)argv;
  if (!argv[0] || !argv[1]) fatal("Usage: oixrun <prog.oix> [<arg> ...]\r\n");
  /* TODO(pts): binmode(...) etc. On POSIX it's not needed. */
  if (!(tramp386_copy = alloc(sizeof(tramp386)))) fatal("fatal: initial alloc failed\r\n");
  memcpy(tramp386_copy, tramp386, sizeof(tramp386));
  if ((fd = open(argv[1], O_RDONLY)) < 0) fatal("fatal: error opening OIX program\r\n");
  find_cf_header(fd, &hdr);
  /* TODO(pts): Do some bounds-checking on the cf_header fields. */
  if (!(image = alloc(hdr.mem_size))) fatal("fatal: not enough memory for program image\r\n");
  if (!(ta.command_line = concatenate_args(argv + 2))) fatal("fatal: not enough memory for argv\r\n");
  if (!(ta.env_strings = concatenate_env(environ))) fatal("fatal: not enough memory for environ\r\n");
  if (lseek(fd, hdr.load_fofs, SEEK_SET) + 0U != hdr.load_fofs) fatal("fatal: error seeking to program image\r\n");
  if (read(fd, image, hdr.load_size) + 0U != hdr.load_size) fatal("fatal: error reading program image\r\n");
  close(fd);
  apply_relocations(image, (const unsigned short*)(image + hdr.reloc_rva));
  ta.c_handler = handle_syscall;
  /* TODO(pts): Apply relocations. */
  ta.program_entry = image + hdr.entry_rva;
  ta.operating_system = OS_WIN32;  /* A plausible lie. */
  ta.program_filename = argv[1];
  ta.break_flag_ptr = &break_flag;  /* break_flag is always zero. WLIB relies on non-NULL pointer. */
  ta.copyright = NULL;
  ta.is_japanese = 0;
  ta.max_handle_for_os2 = 0;
  /* Pass it 5 times in case the active C calling convention passes some arguments in registers EAX, EBX, ECX and EDX. https://en.wikipedia.org/wiki/X86_calling_conventions */
  /* Without __extension__, `gcc -ansi -pedantic' reports: warning: ISO C forbids conversion of object pointer to function pointer type */
  return (__extension__ (int(*)(t, t, t, t, t))tramp386_copy)(&ta, &ta, &ta, &ta, &ta);
}
