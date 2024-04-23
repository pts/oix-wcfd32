; by pts@fazekas.hu at Tue Apr 23 14:15:16 CEST 2024

org 0x8048000  ; Typical Linux i386 executable program.
bits 32
cpu 386
RX equ 5  ; It's segmentation fault unless FileSiz == MemSiz.
RWX equ 7  ; Section permission: read + write + execute.
OSABI_Linux equ 3
file_header:	db 0x7F,'ELF',1,1,1,OSABI_Linux,0,0,0,0,0,0,0,0,2,0,3,0
		dd 1, _start
		dd program_header-file_header, 0, 0
		dw program_header-file_header, 0x20, 1, 0, 0, 0
program_header:	dd 1, 0, file_header, file_header
		dd prebss-file_header, program_end-bss+prebss-file_header, RWX, 0x1000

SYS_exit equ 1
SYS_read equ 3
SYS_write equ 4
SYS_open equ 5
SYS_close equ 6
SYS_lseek equ 19
SYS_brk equ 45

SEEK_SET equ 0

O_RDONLY equ 0
O_WRONLY equ 1
O_RDWR   equ 2
O_CREAT  equ 100q
O_TRUNC  equ 1000q

INT21H_FUNC_06H_DIRECT_CONSOLE_IO equ 0x6
INT21H_FUNC_08H_WAIT_FOR_CONSOLE_INPUT equ 0x8
INT21H_FUNC_19H_GET_CURRENT_DRIVE equ 0x19
INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS equ 0x1A
INT21H_FUNC_2AH_GET_DATE        equ 0x2A
INT21H_FUNC_2CH_GET_TIME        equ 0x2C
INT21H_FUNC_3BH_CHDIR           equ 0x3B
INT21H_FUNC_3CH_CREATE_FILE     equ 0x3C
INT21H_FUNC_3DH_OPEN_FILE       equ 0x3D
INT21H_FUNC_3EH_CLOSE_FILE      equ 0x3E
INT21H_FUNC_3FH_READ_FROM_FILE  equ 0x3F
INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE equ 0x40
INT21H_FUNC_41H_DELETE_NAMED_FILE equ 0x41
INT21H_FUNC_42H_SEEK_IN_FILE    equ 0x42
INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES equ 0x43
INT21H_FUNC_44H_IOCTL_IN_FILE   equ 0x44
INT21H_FUNC_47H_GET_CURRENT_DIR equ 0x47
INT21H_FUNC_48H_ALLOCATE_MEMORY equ 0x48
INT21H_FUNC_4CH_EXIT_PROCESS    equ 0x4C
INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE equ 0x4E
INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE equ 0x4F
INT21H_FUNC_56H_RENAME_FILE     equ 0x56
INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME equ 0x57
INT21H_FUNC_60H_GET_FULL_FILENAME equ 0x60

LOAD_ERROR_SUCCESS       equ 0x0
LOAD_ERROR_OPEN_ERROR    equ 0x1
LOAD_ERROR_INVALID_EXE   equ 0x2
LOAD_ERROR_READ_ERROR    equ 0x3
LOAD_ERROR_OUT_OF_MEMORY equ 0x4

WCFD32_OS_DOS equ 1
WCFD32_OS_WIN32 equ 2

NULL equ 0

_start:		;mov eax, msg
		;call print_str
		;call print_crlf
		pop eax  ; argc.
		mov edx, esp  ; argv.
		lea ecx, [edx+eax*4+4]  ; envp.

		mov eax, ecx
		call concatenate_env  ; !! Segfault when printed.
.next_envvar:	call print_str
		call print_crlf
.skip:		inc eax
		cmp byte [eax-1], 0
		jne .skip
		cmp byte [eax], 0
		jne .next_envvar

%if 0
		mov eax, edx
		call concatenate_argv
		call print_str
		mov al, '<'
		call print_chr
		call print_crlf
%endif

		xor eax, eax
		inc eax  ; SYS_exit.
		xor ebx, ebx  ; EXIT_SUCCESS.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

wcfd32_near_syscall:
		push cs
		; Fall through to wcfd32_far_syscall.

wcfd32_far_syscall:  ; proc far
		;call debug_syscall  ; !!
		push esi
		mov esi, handle_unimplemented
		cmp ah, 0x3c
		jb .do_handle
		cmp ah, 0x3c + ((handlers_3CH.end-handlers_3CH)>>2)
		jnb .do_handle
		movzx esi, ah
		lea esi, [handlers_3CH-4*0x3c+4*esi]
.do_handle:	call esi
		pop esi
		retf
; !! WASM by default needs: 3C, 3D, 3E, 3F, 40, 41, 42, 44, 48, 4C  ; !! Check WASM and WLIB code, all versions.

handle_unimplemented:
		mov eax, msg_unimplemented
		call print_str  ; !! Print to stderr.
		xor eax, eax
		inc eax  ; SYS_exit.
		mov al, 120  ; Exit code.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

handle_INT21H_FUNC_3CH_CREATE_FILE:
handle_INT21H_FUNC_3DH_OPEN_FILE:
handle_INT21H_FUNC_3EH_CLOSE_FILE:
handle_INT21H_FUNC_3FH_READ_FROM_FILE:
handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE:
handle_INT21H_FUNC_41H_DELETE_NAMED_FILE:
handle_INT21H_FUNC_42H_SEEK_IN_FILE:
handle_INT21H_FUNC_44H_IOCTL_IN_FILE:
; !! Implement these.
		call debug_syscall  ; !!
		jmp handle_unimplemented

handle_INT21H_FUNC_48H_ALLOCATE_MEMORY:
		mov eax, ebx
		call malloc
		cmp eax, 1
		jnc .done  ; Success with CF=0.
		mov al, 8  ; DOS error: insufficient memory.
		jmp .done  ; Keep CF=1 for indicating error.
.done:		ret

handle_INT21H_FUNC_4CH_EXIT_PROCESS:
		and eax, 0xff
		xchg ebx, eax  ; EBX := (exit code); EAX := junk.
		xor eax, eax
		inc eax  ; SYS_exit.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

handlers_3CH:
		dd handle_INT21H_FUNC_3CH_CREATE_FILE
		dd handle_INT21H_FUNC_3DH_OPEN_FILE
		dd handle_INT21H_FUNC_3EH_CLOSE_FILE
		dd handle_INT21H_FUNC_3FH_READ_FROM_FILE
		dd handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE
		dd handle_unimplemented  ; 41H
		dd handle_INT21H_FUNC_41H_DELETE_NAMED_FILE
		dd handle_INT21H_FUNC_42H_SEEK_IN_FILE
		dd handle_unimplemented  ; dd handle_INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES  ; WASM doesn't need it.
		dd handle_INT21H_FUNC_44H_IOCTL_IN_FILE
		dd handle_unimplemented  ; 45H
		dd handle_unimplemented  ; 46H
		dd handle_unimplemented  ; dd handle_INT21H_FUNC_47H_GET_CURRENT_DIR  ; WASM doesn't need it.
		dd handle_INT21H_FUNC_48H_ALLOCATE_MEMORY
		dd handle_unimplemented  ; 49H
		dd handle_unimplemented  ; 4AH
		dd handle_unimplemented  ; 4BH
		dd handle_INT21H_FUNC_4CH_EXIT_PROCESS
.end:

debug_syscall:	push eax
		mov al, ah
		shr al, 4
		add al, '0'
		cmp al, '9'
		jna .d1
		add al, 'A'-'0'-10
.d1:		call print_chr
		mov al, ah
		and al, 0xf
		add al, '0'
		cmp al, '9'
		jna .d2
		add al, 'A'-'0'-10
.d2:		call print_chr
		call print_crlf
		pop eax
		ret


print_str:  ; !! Prints the ASCIIZ string (NUL-terminated) at EAX to stdout.
		push ebx
		push ecx
		push edx
		xchg ecx, eax  ; ECX := EAX (data pointer); EAX := junk.
		or edx, -1
.next:		inc edx
		cmp byte [ecx+edx], 0  ; TODO(pts): rep scasb.
		jne .next
		xor eax, eax
		mov al, SYS_write
		xor ebx, ebx
		inc ebx  ; STDOUT_FILENO.
		int 0x80  ; Linux i386 syscall.
		xchg eax, ecx  ; EAX := ECX (data pointer, restored); ECX := junk.
.pop_edx_ecx_ebx_ret:
		pop edx
		pop ecx
		pop ebx
		ret

print_chr:  ; !! Prints single byte in AL to stdout.
                push ebx
                push ecx
                push edx
                push eax
                xor eax, eax
                mov al, SYS_write
                xor ebx, ebx
                inc ebx  ; STDOUT_FILENO.
                mov ecx, esp
                xor edx, edx
                inc edx  ; EDX := 1 (number of bytes to print).
                int 0x80  ; Linux i386 syscall.
                pop eax
                jmp strict short print_str.pop_edx_ecx_ebx_ret

print_crlf:  ; !! Prints a CRLF ("\r", "\n") to stdout.
		push eax
		push 13|10<<8  ; String.
		mov eax, esp
		call print_str
		pop eax  ; String. Value ingored.
		pop eax
		ret

; Implemented using sys_brk(2). Equivalent to the following C code, but was
; size-optimized.
;
; A simplistic allocator which creates a heap of 64 KiB first, and then
; doubles it when necessary. It is implemented using Linux system call
; brk(2), exported by the libc as sys_brk(...). free(...)ing is not
; supported. Returns an unaligned address (which is OK on x86).
;
; #define NULL ((void*)0)
; typedef unsigned size_t;
;
; void * __watcall malloc(size_t size) {
;     static char *base, *free, *end;
;     ssize_t new_heap_size;
;     if ((ssize_t)size <= 0) return NULL;  /* Fail if size is too large (or 0). */
;     if (!base) {
;         if (!(base = free = (char*)sys_brk(NULL))) return NULL;  /* Error getting the initial data segment size for the very first time. */
;         new_heap_size = 64 << 10;  /* 64 KiB. */
;         goto grow_heap;  /* TODO(pts): Reset base to NULL if we overflow below. */
;     }
;     while (size > (size_t)(end - free)) {  /* Double the heap size until there is `size' bytes free. */
;         new_heap_size = (end - base) >= (1 << 20) ? (end - base) + (1 << 20) : (end - base) << 1;  /* Double it until 1 MiB. */
;       grow_heap:
;         if ((ssize_t)new_heap_size <= 0 || (size_t)base + new_heap_size < (size_t)base) return NULL;  /* Heap would be too large. */
;         if ((char*)sys_brk(base + new_heap_size) != base + new_heap_size) return NULL;  /* Out of memory. */
;         end = base + new_heap_size;
;     }
;     free += size;
;     return free - size;
; }
;
; !! TODO(pts): If allocating 1 MiB more fails, type 512 KiB etc, all the way down to 64 KiB.
; !! TODO(pts): Align to 4 bytes, all implementations. Then remove align fixes.
malloc:  ; Allocates EAX bytes of memory. On success, returns starting address. On failure, returns NULL.
		push ebx
		test eax, eax
		jle .18  ; If allocating zero bytes, return NULL.
		mov ebx, eax
		cmp dword [_malloc_simple_base], byte 0
		jne .7
		xor eax, eax
		push ebx  ; Save.
		xchg ebx, eax ; EBX := EAX (argument of sys_brk(2)); EAX := junk.
		xor eax, eax
		mov al, SYS_brk
		int 0x80  ; Linux i386 syscall.
		pop ebx  ; Restore.
		mov [_malloc_simple_free], eax
		mov [_malloc_simple_base], eax
		test eax, eax
		jz short .18
		mov eax, 0x10000  ; 64 KiB minimum allocation.
.9:		add eax, [_malloc_simple_base]
		jc .18
		push eax  ; Save, will be restored to EDX.
		push ebx  ; Save.
		xchg ebx, eax ; EBX := EAX (argument of sys_brk(2)); EAX := junk.
		xor eax, eax
		mov al, SYS_brk  ; __NR_brk.
		int 0x80  ; Linux i386 syscall.
		pop ebx  ; Restore.
		pop edx  ; This (and the next line) could be ECX instead.
		cmp eax, edx
		jne .18
		mov [_malloc_simple_end], eax
.7:		mov edx, [_malloc_simple_end]
		mov eax, [_malloc_simple_free]
		mov ecx, edx
		sub ecx, eax
		cmp ecx, ebx
		jb .21
		add ebx, eax
		mov [_malloc_simple_free], ebx
		jmp short .17
.21:		sub edx, [_malloc_simple_base]
		mov eax, 1<<20  ; 1 MiB.
		cmp edx, eax
		jnbe .22
		mov eax, edx
		;cmovbe eax, edx  ; i686 only.
.22:		add eax, edx
		test eax, eax  ; ZF=..., SF=..., OF=0.
		jg .9  ; Jump iff ZF=0 and SF=OF=0. Why is this correct?
.18:		xor eax, eax  ; NULL.
.17:		pop ebx
		ret

xmalloc:  ; !!
		call malloc
		test eax, eax
		jz .oom
		ret
.oom:		mov eax, oom_msg
		call print_str
		xor eax, eax
		inc eax  ; SYS_exit.
		mov ebx, eax  ; EXIT_FAILURE.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

oom_msg:	db 'fatal: out of memory', 13, 10, 0

; /* Returns the number of bytes needed by append_argv_quoted(arg).
;  * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
;  */
; static size_t __watcall get_argv_quoted_size(const char *arg) {
;   const char *p;
;   size_t size = 1;  /* It starts with space even if it's the first argument. */
;   size_t bsc;  /* Backslash count. */
;   for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\v' && *p != '"'; ++p) {}
;   if (p != arg && *p == '\0') return size + (p - arg);  /* No need to quote. */
;   size += 2;  /* Two '"' quotes, one on each side. */
;   for (p = arg; ; ++p) {
;     for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
;     if (*p == '\0') {
;       size += bsc << 1;
;       break;
;     }
;     if (*p == '"') bsc = (bsc << 1) + 1;
;     size += bsc + 1;
;   }
;   return size;
; }
get_argv_quoted_size:
		push ebx
		push ecx
		push edx
		mov ecx, eax
		mov eax, 0x1
		mov edx, ecx
.1:		cmp byte [edx], 0x0
		je .2
		cmp byte [edx], ' '
		je .2
		cmp byte [edx], 0x9
		je .2
		cmp byte [edx], 0xa
		je .2
		cmp byte [edx], 0xb
		je .2
		cmp byte [edx], '"'
		je .2
		inc edx
		jmp .1
.2:		cmp edx, ecx
		je .3
		cmp byte [edx], 0x0
		jne .3
		sub edx, ecx
		add eax, edx
		pop edx
		pop ecx
		pop ebx
		ret
.3:		mov edx, ecx
		inc eax
		inc eax
.4:		xor ecx, ecx
.5:		cmp byte [edx], 0x5c  ; "\"
		jne .6
		inc edx
		inc ecx
		jmp .5
.6:		lea ebx, [ecx+ecx]
		cmp byte [edx], 0x0
		je .8
		cmp byte [edx], '"'
		jne .7
		lea ecx, [ebx+0x1]
.7:		inc ecx
		add eax, ecx
		inc edx
		jmp .4
.8:		add eax, ebx
		pop edx
		pop ecx
		pop ebx
		ret

; /* Appends the quoted (escaped) arg to pout, always starting with a space, and returns the new pout.
;  * Implements the inverse of parts of CommandLineToArgvW(...).
;  * Implementation corresponds to get_argv_quoted_size(arg).
;  * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
;  */
; static char * __watcall append_argv_quoted(const char *arg, char *pout) {
;   const char *p;
;   size_t bsc;  /* Backslash count. */
;   *pout++ = ' ';  /* It starts with space even if it's the first argument. */
;   for (p = arg; *p != '\0' && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\v' && *p != '"'; ++p) {}
;   if (p != arg && *p == '\0') {  /* No need to quote. */
;     for (p = arg; *p != '\0'; *pout++ = *p++) {}
;     return pout;
;   }
;   *pout++ = '"';
;   for (p = arg; ; *pout++ = *p++) {
;     for (bsc = 0; *p == '\\'; ++p, ++bsc) {}
;     if (*p == '\0') {
;       for (bsc <<= 1; bsc != 0; --bsc, *pout++ = '\\') {}
;       break;
;     }
;     if (*p == '"') bsc = (bsc << 1) + 1;
;     for (; bsc != 0; --bsc, *pout++ = '\\') {}
;   }
;   *pout++ = '"';
;   return pout;
; }
append_argv_quoted:
		push ebx
		push ecx
		mov byte [edx], ' '
		mov ecx, eax
		inc edx
.9:		cmp byte [ecx], 0x0
		je .10
		cmp byte [ecx], ' '
		je .10
		cmp byte [ecx], 0x9
		je .10
		cmp byte [ecx], 0xa
		je .10
		cmp byte [ecx], 0xb
		je .10
		cmp byte [ecx], '"'
		je .10
		inc ecx
		jmp .9
.10:		cmp ecx, eax
		je .13
		cmp byte [ecx], 0x0
		jne .13
		mov ecx, eax
.11:		mov al, [ecx]
		test al, al
		je .12
		mov [edx], al
		inc ecx
		inc edx
		jmp .11
.12:		mov eax, edx
		pop ecx
		pop ebx
		ret
.13:		mov byte [edx], '"'
		mov ecx, eax
		inc edx
.14:		xor eax, eax
.15:		cmp byte [ecx], 0x5c  ; "\"
		jne .16
		inc ecx
		inc eax
		jmp .15
.16:		lea ebx, [eax+eax]
		cmp byte [ecx], 0x0
		jne .18
		mov eax, ebx
.17:		lea ecx, [edx+0x1]
		test eax, eax
		je .21
		mov byte [edx], 0x5c  ; "\"
		dec eax
		mov edx, ecx
		jmp .17
.18:		cmp byte [ecx], '"'
		jne .19
		lea eax, [ebx+0x1]
.19:		lea ebx, [edx+0x1]
		test eax, eax
		je .20
		mov byte [edx], 0x5c  ; "\\"
		dec eax
		mov edx, ebx
		jmp .19
.20:		mov al, [ecx]
		mov [edx], al
		inc ecx
		mov edx, ebx
		jmp .14
.21:		mov byte [edx], '"'
		mov eax, ecx
		pop ecx
		pop ebx
		ret

; char * __watcall concatenate_argv(char **argv) {
;   char **argp, *result, *pout;
;   size_t size = 1;  /* Trailing '\0'. */
;   for (argp = argv + 1; *argp; size += get_argv_quoted_size(*argp++)) {}
;   ++size;
;   result = malloc(size);  /* Will never be freed. */
;   if (result) {
;     pout = result;
;     for (pout = result, argp = argv + 1; *argp; pout = append_argv_quoted(*argp++, pout)) {}
;     *pout = '\0';
;   }
;   return result;
; }
concatenate_argv:
		push ebx
		push ecx
		push edx
		mov ebx, eax
		mov edx, 0x1
		lea ecx, [eax+0x4]
.22:		mov eax, [ecx]
		test eax, eax
		je .23
		add ecx, 0x4
		call get_argv_quoted_size
		add edx, eax
		jmp .22
.23:		xchg eax, edx  ; EAX := EDX; EDX := junk.
		inc eax
		add eax, 3  ; Part of the align fix to dword.
		and eax, ~3  ; Part of the align fix to dword.
		call malloc
		test eax, eax
		jz pop_edx_ecx_ebx_ret
		push eax  ; Save return value.
		lea ecx, [ebx+0x4]
.24:		cmp dword [ecx], 0x0
		je .25
		mov ebx, [ecx]
		add ecx, 0x4
		mov edx, eax
		mov eax, ebx
		call append_argv_quoted
		jmp .24
.25:		mov byte [eax], 0x0
pop_eax_edx_ecx_ebx_ret:
		pop eax  ; Restore return value.
pop_edx_ecx_ebx_ret:
		pop edx
		pop ecx
		pop ebx
		ret

; char * __watcall concatenate_env(char **env) {
;   size_t size = 4;  /* Trailing \0\0 (for extra count) and \0 (empty NUL-terminated program name). +1 for extra safety. */
;   char **envp, *p, *pout;
;   char *result;
;   for (envp = env; (p = *envp); ++envp) {
;     if (*p == '\0') continue;  /* Skip empty env var. Usually there is none. */
;     while (*p++ != '\0') {}
;     size += p - *envp;
;   }
;   result = malloc(size);  /* Will never be freed. */
;   if (result) {
;     pout = result;
;     for (envp = env; (p = *envp); ++envp) {
;       if (*p == '\0') continue;  /* Skip empty env var. Usually there is none. */
;       while ((*pout++ = *p++) != '\0') {}
;     }
;     *pout++ = '\0';  /* Low byte of extra count. */
;     *pout++ = '\0';  /* High byte of extra count. */
;     *pout++ = '\0';  /* Empty NUL-terminated program name. */
;     *pout = '\0';  /* Extra safety. */
;   }
;   return result;
; }
concatenate_env:
		push ebx
		push ecx
		push edx
		xchg ebx, eax  ; EBX := EAX; EAX := junk.
		xor eax, eax
		mov al, 4
		mov ecx, ebx
.27:		mov edx, [ecx]
		test edx, edx
		je .30
		cmp byte [edx], 0x0
		je .29
.28:		inc edx
		cmp byte [edx-1], 0x0
		jne .28
		sub edx, [ecx]
		add eax, edx
.29:		add ecx, 0x4
		jmp .27
.30:		add eax, 3  ; Part of the align fix to dword.
		and eax, ~3  ; Part of the align fix to dword.
		call malloc
		test eax, eax
		jz strict short pop_edx_ecx_ebx_ret  ; Returns.
		push eax  ; Save return value.
		mov ecx, ebx
.31:		mov edx, [ecx]
		test edx, edx
		je .34
		cmp byte [edx], 0x0
		je .33
.32:		mov bl, [edx]
		mov [eax], bl
		inc edx
		inc eax
		test bl, bl
		jne .32
.33:		add ecx, 0x4
		jmp .31
.34:		and dword [eax], 0
		jmp strict short pop_eax_edx_ecx_ebx_ret

msg_unimplemented: db 'fatal: unimplemented syscall', 13, 10, 0  ; !! Display which.

prebss:
		bss_align equ ($$-$)&3
section .bss  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
		bss resb bss_align  ; Uninitialized data follows.

_malloc_simple_base	resd 1  ; char *base;
_malloc_simple_free	resd 1  ; char *free;
_malloc_simple_end	resd 1  ; char *end;

program_end:
