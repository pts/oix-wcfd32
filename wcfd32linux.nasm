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

; Linux i386 syscall numbers.
SYS_exit equ 1
SYS_read equ 3
SYS_write equ 4
SYS_open equ 5
SYS_close equ 6
SYS_unlink equ 10
SYS_lseek equ 19
SYS_brk equ 45
SYS_ioctl equ 54
SYS_ftruncate equ 93

SEEK_SET equ 0
SEEK_CUR equ 1
SEEK_END equ 2

O_RDONLY equ 0
O_WRONLY equ 1
O_RDWR   equ 2
O_CREAT  equ 100q  ; Linux-specific.
O_TRUNC  equ 1000q  ; Linux-specific.

; Linux errno error codes.
ENOENT equ 2	; No such file or directory.
EACCES equ 13	; Permission denied.
ENOTDIR equ 20	; Not a directory.
ENOTTY equ 25  ; Not a typewriter.

INT21H_FUNC_06H_DIRECT_CONSOLE_IO equ 0x6
INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO equ 0x8
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

WCFD32_OS_DOS equ 0
WCFD32_OS_OS2 equ 1
WCFD32_OS_WIN32 equ 2
WCFD32_OS_WIN16 equ 3
WCFD32_OS_UNKNOWN equ 4  ; Anything above 3 is unknown.

NULL equ 0

EXIT_SUCCESS equ 0
EXIT_FAILURE equ 1


_start:  ; Program entry point.
		pop edx  ; argc.
%ifdef RUNPROG
		pop eax  ; Ignore argv[0].
		dec edx
		jnz .have_argv1
		mov eax, msg_usage
		call print_str  ; !! Print to stderr.
		mov al, EXIT_FAILURE
		jmp handle_INT21H_FUNC_4CH_EXIT_PROCESS

.have_argv1:
%endif
		pop edi  ; argv[0]: program invocation name. !! Replace it with "/proc/self/exe" in open, if it doesn't contain a slash, but on macOS in Docker: https://github.com/pts/staticpython/blob/1bc021851823cbbc38c0dbd0790a252b760e9beb/calculate_path.2.7.c#L71-L75
		mov eax, esp  ; argv.
		lea ecx, [eax+edx*4]  ; envp.
		call concatenate_args
		xchg ebp, eax  ; EBP := EAX (command-line arguments terimated by NUL); EAX := junk.
		xchg eax, ecx  ; EAX := ECX (env); ECX := junk.
		call concatenate_env
		xchg ecx, eax  ; ECX := EAX (DOS environment variable strings); EAX := junk.
		; Now: EBP: command-line arguments terminated by NUL; ECX: DOS environment variable strings; EDI: full program pathname terminated by NUL.
%if 0  ; Debug: print program pathname and environment variables.
		mov eax, edi
		call print_str
		mov al, ':'
		call print_chr
		call print_crlf
		mov eax, ebp
		call print_str
		mov al, '<'
		call print_chr
		call print_crlf
%endif
%if 0  ; Debug: print environment variables.
		mov eax, ecx
.next_envvar:	call print_str
		call print_crlf
.skip:		inc eax
		cmp byte [eax-1], 0
		jne .skip
		cmp byte [eax], 0
		jne .next_envvar
%endif
		mov eax, edi
		call load_wcfd32_program_image
		cmp eax, -10
		jb .load_ok
		neg eax  ; EAX := load_error_code.
		push eax
		mov eax, [load_errors+4*eax]
		call print_str  ; !! Report filename etc. on file open error.
		pop eax
		jmp .exit ; exit(load_error_code).
.load_ok:	; Now we call the entry point.
		;
		; Input: AH: operating system (WCFD32_OS_OS2 or WCFD32_OS_WIN32).
		; Input: BX: segment of the wcfd32_far_syscall syscall.
		; Input: EDX: offset of the wcfd32_far_syscall syscall.
		; Input: ECX: must be 0 (unknown parameter).
		; Input: EDI: wcfd32_param_struct
		; Input: dword [wcfd32_param_struct]: program filename (ASCIIZ)
		; Input: dword [wcfd32_param_struct+4]: command-line (ASCIIZ)
		; Input: dword [wcfd32_param_struct+8]: environment variables (each ASCIIZ, terminated by a final NUL)
		; Input: dword [wcfd32_param_struct+0xc]: 0 (wcfd32_break_flag_ptr)
		; Input: dword [wcfd32_param_struct+0x10]: 0 (wcfd32_copyright)
		; Input: dword [wcfd32_param_struct+0x14]: 0 (wcfd32_is_japanese)
		; Input: dword [wcfd32_param_struct+0x18]: 0 (wcfd32_max_handle_for_os2)
		; Call: far call.
		; Output: EAX: exit code (0 for EXIT_SUCCESS).
		mov [wcfd32_program_filename], edi
		mov [wcfd32_command_line], ebp
		mov [wcfd32_env_strings], ecx
		xor ebx, ebx  ; Not needed by the ABI, just make it deterministic.
		xor esi, esi  ; Not needed by the ABI, just make it deterministic.
		xor ebp, ebp  ; Not needed by the ABI, just make it deterministic.
		sub ecx, ecx  ; Stack limit, which we always set to 0.
		mov edx, wcfd32_far_syscall
		mov edi, wcfd32_param_struct
		mov bx, cs  ; Segment of wcfd32_far_syscall for the far call.
		xchg eax, esi  ; ESI := (entry point address); EAX := junk.
		mov ah, WCFD32_OS_WIN32  ; !! TODO(pts): Is there an OS_LINUX constant to use?
		push cs  ; For the `retf' of the far call.
		call esi
.exit:		jmp handle_INT21H_FUNC_4CH_EXIT_PROCESS  ; Exit with exit code in AL.
		; Not reached.

%undef  CONFIG_LOAD_TRY_CF_AT_HDRSIZE
%ifdef RUNPROG
  %define CONFIG_LOAD_TRY_CF_AT_HDRSIZE
%endif
%define CONFIG_LOAD_SINGLE_READ
%define CONFIG_LOAD_INT21H call wcfd32_near_syscall
%define CONFIG_LOAD_MALLOC_EAX call malloc
%undef  CONFIG_LOAD_MALLOC_EBX
%include "wcfd32load.inc.nasm"

wcfd32_near_syscall:
		push cs
		call wcfd32_far_syscall
		ret

; !! It differs from the DOS syscall API in some register sizes (e.g. uses
; EDX instead of DX), and it may change some flags not in the documentation.
wcfd32_far_syscall: ; proc far
		;call debug_syscall  ; !!
		push esi
		mov esi, handle_INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO
		cmp ah, INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO
		je .do_handle
		mov esi, handle_unimplemented
		cmp ah, 0x3c
		jb .do_handle
		cmp ah, 0x3c + ((handlers_3CH.end-handlers_3CH)>>2)
		jnb .do_handle
		movzx esi, ah
		mov esi, [handlers_3CH-4*0x3c+4*esi]
.do_handle:	call esi
		pop esi
		retf

handle_INT21H_FUNC_3DH_OPEN_FILE:  ; Open file. AL is access mode (0, 1 or 2). EDX points to the filename. Returns: CF indicating failure; EAX (if CF=0) is the filehandle (high word is 0). EAX (if CF=1) is DOS error code (high word is 0).
		push ebx
		push ecx
		push edx
		xchg ecx, eax  ; ECX := EAX; EAX := junk.
		and ecx, 3
		jmp strict short handle_common.both
		; Not reached.

handle_INT21H_FUNC_3EH_CLOSE_FILE:  ; Close file. EBX is the file descriptor to close. Returns: CF=1 indicating failure, and on failure sets the DOS error code in EAX (high word is 0).
		push eax  ; Save EAX.
		push SYS_close
		pop eax
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		pop eax  ; Restore EAX.
		jmp strict short handle_common.xret  ; Treat any negative values as error. This effectively limits the usable file size to <2 GiB (7fffffffh bytes). That's fine, Linux won't give us more without O_LARGEFILE anyway.

handle_INT21H_FUNC_3FH_READ_FROM_FILE:  ; Read from file. EBX is the file descriptor. ECX is the number of bytes to read. EDX is the data pointer. Returns: CF indicating failure; EAX (if CF=0) is the filehandle (high word is 0). EAX (if CF=1) is DOS error code (high word is 0).
		push ebx
		push ecx
		push edx
		push SYS_read
.do:		xchg edx, ecx
		jmp strict short handle_common.cax
		; Not reached.

handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE:  ; Write to or truncate file. EBX is the file descriptor. ECX is the number of bytes to read. EDX is the data pointer. Returns: CF indicating failure; EAX (if CF=0) is the filehandle (high word is 0). EAX (if CF=1) is DOS error code (high word is 0).
		push ebx
		push ecx
		push edx
		jecxz .truncate
.write:		push SYS_write
		jmp strict short handle_INT21H_FUNC_3FH_READ_FROM_FILE.do
		; Not reached.
.truncate:	push SYS_lseek
		pop eax
		xor ecx, ecx  ; Seek to offset 0, relative to SEEK_CUR.
		push SEEK_CUR
		pop edx
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		js strict short handle_common.pop_xret
		xchg ecx, eax  ; ECX := EAX (file position); EAX := junk.
		push SYS_ftruncate
		jmp strict short handle_common.cax  ; Returns 0 in EAX on error.
		; Not reached.

handle_INT21H_FUNC_3CH_CREATE_FILE:  ; Create file. CX is file attribute (ignored), EDX points to the filename. Returns: CF indicating failure; EAX (if CF=0) is the filehandle (high word is 0). EAX (if CF=1) is DOS error code (high word is 0).
		push ebx
		push ecx
		push edx
		mov ecx, O_RDWR|O_CREAT|O_TRUNC
handle_common:
.both:		mov ebx, edx
		mov edx, 666q
		push SYS_open  ; This push-pop technique works as long as 0 <= SYS_* < 0x80.
.cax:		pop eax
		int 0x80  ; Linux i386 syscall.
.test_pop_xret:	test eax, eax
.pop_xret:	pop edx
		pop ecx
		pop ebx
.xret:		js .badret  ; Treat any negative values as error. This effectively limits the usable file size to <2 GiB (7fffffffh bytes). That's fine, Linux won't give us more without O_LARGEFILE anyway.
		clc
		ret
.badret:	mov ah, 2  ; DOS error: File not found. https://stanislavs.org/helppc/dos_error_codes.html TODO(pts): Add better error mapping.
		cmp eax, -ENOENT
		je .err_found
		cmp eax, -ENOTDIR
		je .err_found
		mov ah, 5  ; DOS error: Access denied.
		cmp eax, -EACCES
		je .err_found
		mov ah, 0xb ; Fallback DOS error: Invalid format.
.err_found:	shr eax, 8
		stc
		ret

handle_INT21H_FUNC_41H_DELETE_NAMED_FILE:  ; Open file. EDX points to the filename. Returns: CF indicating failure; EAX (if CF=1) is DOS error code (high word is 0).
		push eax  ; Save.
		push SYS_unlink
		pop eax
		xchg ebx, edx
		int 0x80  ; Linux i386 syscall.
		xchg ebx, edx  ; Restore EBX and EDX.
		test eax, eax
		pop eax  ; Restore.
		jmp strict short handle_common.xret
		; Not reached.

handle_INT21H_FUNC_42H_SEEK_IN_FILE:  ; Seek in file. EBX is the file descriptor. AL is whence (0 for SEEK_SET, 1 for SEEK_CUR, 2 for SEEK_END). CX is the high word of the offset. DX is the low word of the offset. Returns: CF indicating failure; EAX (if CF=0) is the low word of the position (high word is 0); EDX (if CF=0) is the high word of the position (high word of EDX is 0). EAX (if CF=1) is DOS error code (high word is 0).
		push ebx
		push ecx
		push edx
		shl ecx, 16
		mov cx, dx
		movzx edx, al
		;call handle_unimplemented
		push SYS_lseek  ; Only 32-bit offsets.
		pop eax
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		js strict short handle_common.pop_xret
		ror eax, 16
		movzx edx, ax
		shr eax, 16
		clc
		pop ecx  ; Just pop it, but don't overwrite EDX.
		pop ecx
		pop ebx
		ret

handle_INT21H_FUNC_44H_IOCTL_IN_FILE:  ; EBX is the file descriptor. AL is the ioctl number (we support only 0). Returns: CF indicating failure; EDX (if CF=0) contains the device information bits (high word is 0). EAX (if CF=1) is DOS error code (high word is 0).
		cmp al, 0  ; Get device information.
		jne strict short handle_unimplemented
		; In EDX, we return 0x80 for TTY, 0 for anything else.
		; !! TODO(pts): Should we return 0x80 for character devices other than a TTY?
		; https://stanislavs.org/helppc/int_21-44-0.html
		push ebx
		push ecx
		push edx
		push eax  ; Save.
		sub esp, strict byte 0x24  ; Output buffer of tcgets.
		push SYS_ioctl
		pop eax
		mov ecx, 0x5401  ; TCGETS.
		mov edx, esp  ; 3rd argument (data) of ioctl TCGETS.
		int 0x80  ; Linux i386 syscall.
		add esp, strict byte 0x24  ; Clean up output buffer of tcgets.
		xor edx, edx
		cmp eax, -ENOTTY
		jne .not_enotty
		pop eax
		mov dl, 0  ; Indicated disk file to DOS.
		jmp .ret_edx
.not_enotty:	test eax, eax
		pop eax
		js strict short handle_common.pop_xret
		mov dl, 0x80  ; Indicate character device to DOS.
.ret_edx:	pop ecx  ; Ignore saved EDX.
		pop ecx
		pop ebx
		ret

handle_unimplemented:
		mov al, ah
		aam 0x10  ; AH := high nibble; AL := low nibble
		cmp ah, 10
		jb .ah
		add ah, 'a'-'0'-10
.ah:		cmp al, 10
		jb .al
		add al, 'a'-'0'-10
.al		add ax, '0'<<8|'0'
		xchg al, ah
		mov ebp, msg_unimplemented
		mov word [ebp+msg_unimplemented.hexdigits-msg_unimplemented], ax
		xchg eax, ebp  ; EAX := EBP; EBP := junk.
		call print_str  ; !! Print to stderr.
		mov al, 120  ; Exit code.
		jmp strict short handle_INT21H_FUNC_4CH_EXIT_PROCESS
		; Not reached.

handle_INT21H_FUNC_48H_ALLOCATE_MEMORY:
		mov eax, ebx
		call malloc
		cmp eax, 1
		jnc .done  ; Success with CF=0.
		mov al, 8  ; DOS error: Insufficient memory. https://stanislavs.org/helppc/dos_error_codes.html
		; Keep CF=1 for indicating error.
.done:		ret

handle_INT21H_FUNC_4CH_EXIT_PROCESS:
		movzx ebx, al
		xor eax, eax
		inc eax  ; SYS_exit.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

handle_INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO:
		; !! TODO(pts): Disable line buffering and echo; tio.c_lflag &= ~(ICANON | ECHO);
		; However, the default behavior is good enough, WASM only waits for <Enter>.
		push ebx
		push ecx
		push edx
		push eax  ; Just leave room for 1 byte on the stack.
		push SYS_read
		pop eax
		xor ebx, ebx  ; STDIN_FILENO.
		mov ecx, esp
		xor edx, edx
		inc edx
		int 0x80  ; Linux i386 syscall.
		pop eax  ; AL contains the byte read.
		pop edx
		pop ecx
		pop ebx
		ret

handlers_3CH:
		dd handle_INT21H_FUNC_3CH_CREATE_FILE
		dd handle_INT21H_FUNC_3DH_OPEN_FILE
		dd handle_INT21H_FUNC_3EH_CLOSE_FILE
		dd handle_INT21H_FUNC_3FH_READ_FROM_FILE
		dd handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE
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
; !! Implement these, but only if needed by WASM or WLIB.
; !! WLIB does a segmentation fault on Linux at startup, with a NULL pointer dereference. Why? Does it fail in Wine?
; !! WASM by default needs: 3C, 3D, 3E, 3F, 40, 41, 42, 44, 48, 4C, also the help needs 08  ; !! Check WASM and WLIB code, all versions.
;INT21H_FUNC_06H_DIRECT_CONSOLE_IO equ 0x6
;INT21H_FUNC_19H_GET_CURRENT_DRIVE equ 0x19
;INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS equ 0x1A
;INT21H_FUNC_2AH_GET_DATE        equ 0x2A
;INT21H_FUNC_2CH_GET_TIME        equ 0x2C
;INT21H_FUNC_3BH_CHDIR           equ 0x3B
;INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE equ 0x4E
;INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE equ 0x4F
;INT21H_FUNC_56H_RENAME_FILE     equ 0x56
;INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME equ 0x57
;INT21H_FUNC_60H_GET_FULL_FILENAME equ 0x60
.end:

debug_syscall:  ; !!
		push eax
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
		push SYS_write
		pop eax
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
                push SYS_write
                pop eax
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
		push ecx
		push edx
		add eax,  3  ; Part of the align fix to dword.
		and eax, ~3  ; Part of the align fix to dword.
		test eax, eax
		jle .18  ; If allocating zero bytes, return NULL.
		mov ebx, eax
		cmp dword [_malloc_simple_base], byte 0
		jne .7
		xor eax, eax
		push ebx  ; Save.
		xchg ebx, eax ; EBX := EAX (argument of sys_brk(2)); EAX := junk.
		push SYS_brk
		pop eax
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
		push SYS_brk  ; __NR_brk.
		pop eax
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
.17:		pop edx
		pop ecx
		pop ebx
		ret

xmalloc:  ; !!
		call malloc
		test eax, eax
		jz .oom
		ret
.oom:		mov eax, msg_oom
		call print_str
		mov al, 121  ; Exit code.
		jmp handle_INT21H_FUNC_4CH_EXIT_PROCESS
		; Not reached.


; /* Returns the number of bytes needed by append_arg_quoted(arg).
;  * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
;  */
; static size_t __watcall get_arg_quoted_size(const char *arg) {
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
get_arg_quoted_size:
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
;  * Implementation corresponds to get_arg_quoted_size(arg).
;  * Based on https://learn.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
;  */
; static char * __watcall append_arg_quoted(const char *arg, char *pout) {
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
append_arg_quoted:
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

; char * __watcall concatenate_args(char **args) {
;   char **argp, *result, *pout;
;   size_t size = 1;  /* Trailing '\0'. */
;   for (argp = args; *argp; size += get_arg_quoted_size(*argp++)) {}
;   ++size;
;   result = malloc(size);  /* Will never be freed. */
;   if (result) {
;     pout = result;
;     for (pout = result, argp = args; *argp; pout = append_arg_quoted(*argp++, pout)) {}
;     *pout = '\0';
;   }
;   return result;
; }
concatenate_args:
		push ebx
		push ecx
		push edx
		mov ebx, eax
		mov edx, 1
		mov ecx, eax
.22:		mov eax, [ecx]
		test eax, eax
		je .23
		add ecx, 0x4
		call get_arg_quoted_size
		add edx, eax
		jmp .22
.23:		xchg eax, edx  ; EAX := EDX; EDX := junk.
		inc eax
		call malloc
		test eax, eax
		jz pop_edx_ecx_ebx_ret
		push eax  ; Save return value.
		mov ecx, ebx
.24:		cmp dword [ecx], 0x0
		je .25
		mov ebx, [ecx]
		add ecx, 0x4
		mov edx, eax
		mov eax, ebx
		call append_arg_quoted
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
		push 4
		pop eax
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
.30:		call malloc
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

msg_oom:	db 'fatal: out of memory', 13, 10, 0
%ifdef RUNPROG
msg_usage:	db 'Usage: wcfd32linux <wcfd32-prog-file> [<arg> ...]', 13, 10, 0
%endif

;section .data

msg_unimplemented: db 'fatal: unimplemented syscall 0x',
.hexdigits:	db '??', 13, 10, 0  ; The '??' part is read-write.

emit_load_errors

prebss:
		bss_align equ ($$-$)&3
section .bss  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
		bss resb bss_align  ; Uninitialized data follows.

_malloc_simple_base	resd 1  ; char *base;
_malloc_simple_free	resd 1  ; char *free;
_malloc_simple_end	resd 1  ; char *end;
wcfd32_param_struct:  ; Contains 7 dd fields, see below.
  wcfd32_program_filename resd 1  ; dd empty_str  ; ""
  wcfd32_command_line resd 1  ; dd empty_str  ; ""
  wcfd32_env_strings resd 1  ; dd empty_env
  wcfd32_break_flag_ptr resd 1  ; !! Set.
  wcfd32_copyright resd 1
  wcfd32_is_japanese resd 1
  wcfd32_max_handle_for_os2 resd 1

program_end:
