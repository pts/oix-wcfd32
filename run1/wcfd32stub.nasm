; by pts@fazekas.hu at Mon Apr 22 17:44:31 CEST 2024

%macro assert_at 1
  times  (%1)-($-$$) times 0 db 0
  times -(%1)+($-$$) times 0 db 0
%endm

%ifdef LINUXPROG
; Usage for .exe output: wcfd32stub <input.cf.exe> <output.exe>
; Usage for ELF executable output: wcfd32stub <input.cf.exe> <output>
; !! Remove the ELF output file and chmod +x it.
; !! Port this stub to OIX, making it multiplatform.
; !! Port rex2oix to OIX, making it multiplatform.
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

; All specific to Linux i386.
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
O_CREAT  equ 100q   ; Linux-specific (not the same on FreeBSD).
O_TRUNC  equ 1000q  ; Linux-specific (not the same on FreeBSD).

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
		; Now find the CF header in read_buf[:]. This logic is duplicated in wcfd32load.inc.nasm.
		sub eax, 0x18
		jnb .s1
		mov eax, fatal_too_short
		jmp fatal
.s1:		mov edx, 'CF'  ; "CF\0\0". CF header signature.
		mov esi, read_buf
		cmp dword [esi], edx
		je .cf_found
		cmp dword [esi], 0x7f|'ELF'<<8
		jne .not_elf
		cmp eax, 0x54
		jb .not_elf
		cmp dword [esi+0x54], edx
		jne .not_elf
		add esi, 0x54
		jmp .cf_found
.not_elf:	cmp eax, 0x20
		jb .s3
		add esi, 0x20
		cmp dword [esi], edx
		je .cf_found
.s3:		movzx esi, word [read_buf+8]  ; mz_haader.hdrsize field.
		shl esi, 4
		cmp eax, esi
		jb .s2
		add esi, read_buf
		cmp dword [esi], edx
		je .cf_found
.s2:
.cf_not_found:	mov eax, fatal_cf_not_found
		jmp fatal
.cf_found:	; CF header found at file offset ESI-ESP, at [esi].
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
		pop ebp  ; argv[3].
		push ebx  ; Save input filehandle.
		xchg ebx, eax  ; EBX := EAX; EAX := junk.
		mov ecx, O_WRONLY|O_CREAT|O_TRUNC
		mov edx, 666q  ; Permission bits (mode_t) for file creation.
		mov al, SYS_open
		call check_syscall_al
		test ebp, ebp  ; argv[3].
		xchg ebp, eax  ; EBP := EAX (fd); EAX := junk.
		jz .exe_output
.elf_output:	; ---
		mov eax, [cf_header.entry_rva]
		;add eax, [elf_org]
		;add eax, elf_stub_end-elf_header
		;mov [elf_cf_entry_vaddr], eax
		mov edi, [elf_cf_entry_vaddr]  ; bss.
		add [elf_cf_entry_vaddr], eax
		mov eax, [cf_header.load_size]
		add [elf_text_filesiz], eax
		mov eax, [cf_header.mem_size]
		add [elf_text_memsiz], eax
		; Now we read the entire image, and write it at once.
		push SYS_brk
		pop eax
		xor ebx, ebx
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		jns .brk1_ok
.bad_alloc:	mov eax, fatal_alloc
		jmp fatal
.brk1_ok:	xchg ebx, eax  ; EBX := EAX; EAX := junk.
		mov ecx, ebx  ; ECX := EBX (image base vaddr).
		add ebx, [cf_header.load_size]
		push SYS_brk
		pop eax
		int 0x80  ; Linux i386 syscall.
		test eax, eax
		js .bad_alloc
		cmp eax, ebx
		jb .bad_alloc
		mov edx, [cf_header.load_size]
		pop ebx  ; Input filehandle.
		push ebx
		push SYS_read
		pop eax
		call check_syscall_al
		cmp eax, edx
		je .readall_ok
		mov eax, fatal_read
		jmp fatal
.readall_ok:
		mov edx, ecx  ; image_base in the stub-allocated buffer.
		mov esi, [cf_header.reloc_rva]
.apply_relocations_and_clear:
		; Apply relocations and clear (set-to-zero) relocation data bytes.
		; Input: EDX, EDI: image_base; ESI: reloc_rva.
		; Spoils: EAX, EBX, ECX, ESI.
		add esi, edx  ; ESI := stub-allocated image_base + cf_header.reloc_rva.
		jmp strict short .next_block
.next_reloc:	lodsw
		and word [esi-2], 0  ; Clear.
		add ebx, eax
.first_reloc:	add [ebx], edi
		loop .next_reloc
.next_block:	lodsw
		and word [esi-2], 0  ; Clear.
		movzx ecx, ax
		jecxz .rdone
		lodsd
		and dword [esi-4], 0  ; Clear.
		xchg ebx, eax  ; EBX := EAX; EAX := junk.
		ror ebx, 16
		add ebx, edx
		xor eax, eax
		jmp strict short .first_reloc
.rdone:		; Now: EDX: image_base; EAX, EBX, ECX, ESI: spoiled.
		mov ecx, edx  ; stub-allocated image_base.
		mov edx, [cf_header.load_size]
		mov edi, edx
		; Strip trailing NULs (0 bytes) from the image.
.strip0:	test edx, edx
		jz .done_strip0
		cmp byte [ecx+edx-1], 0
		jne .done_strip0
		dec edx
		jmp .strip0
.done_strip0:	mov ebx, ebp  ; Output filehandle.
		sub edi, edx
		sub [elf_text_filesiz], edi
		push ecx
		push edx
		mov ecx, elf_stub
		mov edx, elf_stub_end-elf_stub
		push SYS_write
		pop eax
		call check_syscall_al
		pop edx
		pop ecx
		push SYS_write
		pop eax
		call check_syscall_al
		jmp .pop_read_next  ; Read resources after the image.
		; ---
.exe_output:	mov ecx, stub
		mov edx, stub_end-stub
		mov ebx, ebp
		push SYS_write
		pop eax
		call check_syscall_al
		; !! Also strip trailing NULs here (needs big rewrite).
.pop_read_next:	pop ebx  ; Input filehandle.
.read_next:	call read_to_buf
		test eax, eax
		jz .rw_done
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
.rw_done:	xor eax, eax
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
fatal_alloc:	db 'fatal: error allocating memory', 10, 0
%endif  ; LINUXPROG

; This is independent of `bits 16' or `bits 32'.
stub:
mz_header:
incbin 'wcfd32dos.exe', 0, 6  ; 'MZ' signature and image size.
incbin 'wcfd32dosp.exe', 6, 0x20-6  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
cf_header:  ; The 32-bit DOS loader finds it at mz_header.hdrsize. Must be aligned to 0x10.
		db 'CF', 0, 0          ; +0x00. Signature.
.load_fofs:	;dd wcfd32_load_fofs  ; +0x04. load_fofs.
;.load_size:	;dd wcfd32_load_size  ; +0x08. load_size.
;.reloc_rva:	;dd wcfd32_reloc_rva  ; +0x0c. reloc_rva.
;.mem_size:	;dd wcfd32_mem_size   ; +0x10. mem_size.
;.entry_rva:	;dd wcfd32_entry_rva  ; +0x14. entry_rva.
.load_size equ cf_header+8
.reloc_rva equ cf_header+0xc
.mem_size equ cf_header+0x10
.entry_rva equ cf_header+0x14
		incbin 'wcfd32dos.exe', 0x24, 0x14
		; End.                 ; +0x18. Size.
incbin 'wcfd32dosp.exe', 0x3c, 4  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
		dd pe_header-mz_header  ;incbin 'wcfd32win32.exe', 0x3c, 4  ; !! TODO(pts): Check that this dword == pe_header.
;incbin 'wcfd32dosp.exe', 0x40, 0xe  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
; PMODE/W config (struct cfg). The /... flags are for pmwsetup.exe.
pmodew_config:

%if 0  ; PMODE/W 1.33 defaults.
.pagetables	db 4		; /V number of page tables under VCPI; Number of VCPI page tables to allocate. Each page table needs 4 KiB, and gives 4 MiB of memory for VCPI. These are allocated only for VCPI.
.selectors	dw 0x100	; /S max selectors under VCPI/XMS/raw; VCPI/XMS/Raw maximum selectors.
.rmstacklen	dw 0x40		; /R real mode stack length, in para; Real mode stack length (in paragraphs).
.pmstacklen	dw 0x80		; /P protected mode stack length, in para; Protected mode stack length (in paragraphs).
.rmstacks	db 8		; /N real mode stack nesting; Real mode stack nesting.
.pmstacks	db 8		; /E protected mode stack nesting; Protected mode stack nesting.
.callbacks	db 0x20		; /C number of real mode callbacks; Number of real mode callbacks.
.mode		db 1		; /M mode bits; VCPI/DPMI detection mode (0=DPMI first, 1=VCPI first).
.pamapping	db 1		; /A physical address mappings; Number of physical address mapping page tables.
.crap		dw 0		; Unused.
.options	db 1		; /B option flags; Display copyright message at startup (0=No, 1=Yes).
.extmax		dd 0x7fffffff	; /X maximum extended memory to allocate; Maximum extended memory to allocate (in bytes).
.lowmin		dw 0		; /L amount of low memory to try and save; Low memory to reserve (in paragraphs)
%elif 0  ; PMODE/W 1.33 defaults, but hide the copyright message.
.pagetables	db 4
.selectors	dw 0x100
.rmstacklen	dw 0x40
.pmstacklen	dw 0x80
.rmstacks	db 8
.pmstacks	db 8
.callbacks	db 0x20
.mode		db 1
.pamapping	db 1
.crap		dw 0
.options	db 0
.extmax		dd 0x7fffffff
.lowmin		dw 0
%else  ; Settings optimized to save conventional memory for WCFD32.
; We tweak these settings to get some extra free conventional memory. By
; default, DOSBox has 40546 paragraphs (~633 KiB) free, kvikdos has 40688
; paragraphs (~635 KiB) free. Out of this, PMODE/W and the runner
; wcfd32dos.nasm (including 4 KiB of stack for the program) uses 1943
; paragraphs (~30 KiB) with these tweaks, and 3735 paragraphs (~58 KiB) with
; the PMODE/W defaults. Thus these tweaks save about ~28 KiB of conventional
; memory.
.pagetables	db 0x10  ; Not a problem, only allocated for VCPI and if high memory (above 1 MiB) is available.
.selectors	dw 0x10  ; Doesn't save much.
.rmstacklen	dw 0x40
.pmstacklen	dw 0x40
.rmstacks	db 1
.pmstacks	db 1
.callbacks	db 0
.mode		db 0  ; DPMI first. It gives more memory.
.pamapping	db 0
.crap		dw 0
.options	db 0
.extmax		dd 0x7fffffff
.lowmin		dw 0
%endif
.end: assert_at (pmodew_config-$$)+0x15
;db 'PMODE/W v1.'...
incbin 'wcfd32dosp.exe', 0x55, 0x1f03-0x55  ; wcfd32dos.exe and wcfd32dosp.exe are identical here.
; Replace the 0x3c byte so that the PMODE/W DOS stub will find the LE image offset at fofs 0x38 instead of 0x3c.
; !! TODO(pts): Check that an actual 0x3c byte was replaced.
; TODO(pts): Check that decompression is still successful.
		db 0x38
incbin 'wcfd32dosp.exe', 0x1f03+1  ; We use wcfd32dosp.exe here, because wcfd32dos.exe doesn't have the alignment of the PE header to 4.
pe_header:
; TODO(pts): Build the PE manually (with relocations!). Merge .idata and .reloc to .data. Exclude trailing NUL bytes from .data. Overlap .text and .data.
incbin 'wcfd32win32.exe', pe_header-mz_header, 8
TimeDateStamp:	dd 0  ; Make the build reproducible by specifying a constant timestamp.
incbin 'wcfd32win32.exe', pe_header-mz_header+0xc, 0xf8-0xc
db '.text', 0, 0, 0  ; Overwrite 'AUTO' PE section name.
incbin 'wcfd32win32.exe', pe_header-mz_header+0xf8+8, 0x50-8
db '.data', 0, 0, 0  ; Overwrite 'DGROUP' PE section name.
incbin 'wcfd32win32.exe', pe_header-mz_header+0xf8+0x50+8

stub_end:

%ifdef LINUXPROG
elf_stub:
elf_header:
incbin 'wcfd32linux.bin'
elf_stub_end:
elf_entry equ elf_header+0x54
elf_cf_entry_vaddr equ elf_entry+1  ; Will be modified in place. The argument of the `mov esi, ...' instruction in wcfd32linux.nasm.
elf_org equ elf_header+0x54-0x14
elf_text_filesiz equ elf_header+0x54-0x10  ; Will be modified in place.
elf_text_memsiz  equ elf_header+0x54-0xc   ; Will be modified in place.
prebss:
		bss_align equ ($$-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
		bss resb bss_align  ; Uninitialized data follows.
read_buf:	resb 0x8000
.end:
program_end:
%endif  ; LINUXPROG
