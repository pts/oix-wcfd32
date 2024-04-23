; by pts@fazekas.hu at Mon Apr 22 17:44:31 CEST 2024

%ifdef LINUXPROG
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

SEEK_SET equ 0

O_RDONLY equ 0
O_WRONLY equ 1
O_RDWR   equ 2
O_CREAT  equ 100q
O_TRUNC  equ 1000q

_start:		pop eax  ; Skip argc.
		pop eax  ; Skip argv[0].
		pop eax  ; argv[1]: input filename.
		call check_filename
		xchg ebx, eax  ; EBX := EAX; EAX := junk.
		xor ecx, ecx  ; O_RDONLY.
		mov al, SYS_open
		call check_syscall_al
		xchg ebx, eax  ; EBX := EAX (fd); EAX := junk.
		call read_to_buf
		cmp eax, 0x38
		jnb .s1
		mov eax, fatal_too_short
		jmp fatal
.s1:		lea ecx, [eax-0x18]
		mov edx, 'CF'
		mov eax, read_buf+0x20
		cmp dword [eax], edx
		je .cf_found
		movzx eax, word [read_buf+8]  ; mz_haader.hdrsize field.
		shl eax, 4
		cmp eax, ecx
		jna .s2
.cf_not_found:	mov eax, fatal_cf_not_found
		jmp fatal
.s2:		add eax, read_buf
		cmp dword [eax], edx
		jne .cf_not_found
.cf_found:	; CF header found at file offset EAX, at [esp+eax].
		xchg esi, eax  ; ESI := EAX (CF header offset); EAX := junk.
		mov edi, cf_header
		movsd  ; Signature.
		mov ecx, [esi]  ; wcfd32_load_fofs.
		mov dword [esi], stub_end-stub  ; New load_fofs.
		times 5 movsd
		;mov edi, [eax+8]  ; wcfd32_load_size.  No need to save this, we copy until EOF, to include the Watcom resources after the image.
		mov al, SYS_lseek
		xor edx, edx  ; SEEK_SET.
		call check_syscall_al
		pop eax  ; argv[2]: output filename.
		call check_filename
		push ebx
		xchg ebx, eax  ; EBX := EAX; EAX := junk.
		mov ecx, O_WRONLY|O_CREAT|O_TRUNC
		mov edx, 666q  ; Permission bits (mode_t) for file creation.
		mov al, SYS_open
		call check_syscall_al
		xchg ebx, eax  ; EBX := EAX (fd); EAX := junk.
		mov ecx, stub
		mov edx, stub_end-stub
		mov al, SYS_write
		call check_syscall_al
		mov ebp, ebx  ; Save output filehandle to EBP.
		pop ebx  ; Input filehandle.
.read_next:	call read_to_buf
		test eax, eax
		jz .read_done
		xchg edx, eax  ; EDX := EAX (size); EAX := junk.
		xchg ebp, ebx
		mov al, SYS_write
		call check_syscall_al
		cmp eax, edx
		je .write_ok
		mov eax, fatal_write
		jmp fatal
.write_ok:	xchg ebp, ebx
		jmp .read_next
.read_done:	xor eax, eax
		inc eax  ; SYS_exit.
		xor ebx, ebx  ; EXIT_SUCCESS.
		int 0x80  ; Linux i386 syscall.
		; Not reached.

read_to_buf:	mov al, SYS_read
		mov ecx, read_buf
		mov edx, read_buf.end-read_buf
		;jmp check_syscall_al  ; Fall through to check_syscall_al.

check_syscall_al:  ; Input: AL: syscall number.
		movzx eax, al
		push eax
		int 0x80
		test eax, eax
		js .bad
		add esp, 4
		ret
.bad:		pop ebx  ; Syscall number.
		mov eax, fatal_open
		cmp ebx, SYS_open
		je .fatal
		mov eax, fatal_read
		cmp ebx, SYS_read
		je .fatal
		mov eax, fatal_write
		cmp ebx, SYS_write
		je .fatal
		mov eax, fatal_lseek
		cmp ebx, SYS_lseek
		je .fatal
		mov eax, fatal_syscall
.fatal:		;jmp fatal  ; Fall through to fatal.

fatal:  ; Writes message at EAX to stderr, and exits with EXIT_FAILURE.
		xchg eax, ecx  ; ECX := EAX; EAX := junk.
		xor edx, edx
		dec edx
.again:		inc edx
		cmp byte [ecx+edx], 0
		jne .again
		xor eax, eax
		mov al, SYS_write
		xor ebx, ebx
		mov bl, 2  ; STDERR_FILENO.
		int 0x80  ; Linux o386 syscall. ECX is data, EDX is size.
		xor eax, eax
		inc eax  ; SYS_exit.
		mov ebx, eax  ; EXIT_FAILURE
		int 0x80  ; Linux i386 syscall.
		; Not reached.

check_filename:  ; Checks filename in EAX.
		test eax, eax
		jz .bad
		cmp byte [eax], 0
		je .bad
		ret
.bad:		mov eax, fatal_filename
		jmp fatal

fatal_filename:	db 'fatal: filename expected', 10, 0
fatal_open:	db 'fatal: error opening', 10, 0
fatal_read:	db 'fatal: error reading', 10, 0
fatal_write:	db 'fatal: error writing', 10, 0
fatal_lseek:	db 'fatal: error seeking', 10, 0
fatal_syscall:	db 'fatal: error in syscall', 10, 0
fatal_too_short: db 'fatal: file too short for CF header', 10, 0
fatal_cf_not_found: db 'fatal: CF header not found', 10, 0
%endif  ; LINUXPROG

; This is independent of `bits 16' or `bits 32'.
stub:
mz_header:
incbin 'wcfd32dos.exe', 0, 6  ; 'MZ' signature and image size.
incbin 'wcfd32dosp.exe', 6, 0x20-6  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
cf_header:  ; The 32-bit DOS loader finds it at mz_header.hdrsize. Must be aligned to 0x10.
		db 'CF', 0, 0          ; +0x00. Signature.
		dd 0;wcfd32_load       ; +0x04. load_fofs.
		dd 0;wcfd32_load_size  ; +0x08. load_size.
		dd 0;wcfd32_reloc_rva  ; +0x0c. reloc_rva.
		dd 0;wcfd32_mem_size   ; +0x10. mem_size.
		dd 0;wcfd32_entry_rva  ; +0x14. entry_rva.
		; End.                 ; +0x18. Size.
incbin 'wcfd32dosp.exe', 0x3c, 4  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
		dd pe_header-mz_header  ;incbin 'wcfd32win32.exe', 0x3c, 4  ; !! TODO(pts): Check that this dword == pe_header.
incbin 'wcfd32dosp.exe', 0x40, 0xe  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
		db 0  ; Disable displaying the PMODE/W copyright message.
incbin 'wcfd32dosp.exe', 0x4f, 0x1f03-0x4f  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
; Replace the 0x3c byte so that the PMODE/W DOS stub will find the LE image offset at fofs 0x38 instead of 0x3c.
; !! TODO(pts): Check that an actual 0x3c byte was replaced.
; TODO(pts): Check that decompression is still successful.
		db 0x38
incbin 'wcfd32dosp.exe', 0x1f03+1  ; We use wcfd32dosp.exe here, because wcfd32dos.exe doesn't have the alignment of the PE header to 4.
pe_header:
incbin 'wcfd32win32.exe', pe_header-mz_header, 8
TimeDateStamp:	dd 0  ; Make the build reproducible by specifying a constant timestamp.
incbin 'wcfd32win32.exe', pe_header-mz_header+0xc
stub_end:

%ifdef LINUXPROG
prebss:
		bss_align equ ($$-$)&3
section .bss  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
		bss resb bss_align  ; Uninitialized data follows.
read_buf:	resb 0x8000
.end:
program_end:
%endif  ; LINUXPROG
