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
SYS_unlink equ 10
SYS_lseek equ 19
SYS_brk equ 45
SYS_fchmod equ 94
SYS_fstat equ 108  ; Supported by Linux 1.0.

SEEK_SET equ 0

O_RDONLY equ 0
O_WRONLY equ 1
O_RDWR   equ 2
O_CREAT  equ 100q   ; Linux-specific (not the same on FreeBSD).
O_TRUNC  equ 1000q  ; Linux-specific (not the same on FreeBSD).

_start:		pop eax  ; Skip argc.
		pop eax  ; Skip argv[0].
		pop eax  ; argv[1]: input filename.
		test eax, eax
		jz short .usage
		pop ebx  ; argv[2]: output filename.
		test ebx, ebx
		jz short .usage
		mov [output_filename], ebx
		pop ecx  ; argv[3]: output format or NULL. Default is 'exe'.
		test ecx, ecx
		jz short .no_argv3
		pop ebx  ; argv[4]: must be NULL.
		test ebx, ebx
		jz short .have_ofmt
.usage:		mov eax, fatal_usage
.j_fatal:	jmp strict near fatal
.no_argv3:	xor ecx, ecx  ; ZF := 0, `je' below will jump.
		jmp short .have_ofmt_ecx
.have_ofmt:	mov ecx, [ecx]
		cmp ecx, 'exe'  ; Default.
.have_ofmt_ecx: mov ebx, output_exe
		je short found_ofmt
		cmp ecx, 'oix'
		mov ebx, output_oix
		je short found_ofmt
		inc byte [do_add_executable_bit]  ; For 'elf' and 'epl' below.
		cmp ecx, 'elf'  ; ELF-32. 84 bytes (+ the number of trailing NULs) longer than 'epl' because of 24 bytes of CF header, 48 bytes of .apply_relocations, 12 bytes of extra .clear_last_page_of_bss. Also a bit slower to start up because of .apply_relocations.
		mov ebx, output_elf
		je short found_ofmt
		cmp ecx, 'epl'  ; ELF-32 pre-relocated.
		mov ebx, output_epl
		je short found_ofmt
		mov eax, fatal_ofmt
		jmp short _start.j_fatal
found_ofmt:	mov [output_code_ptr], ebx
		xchg ebx, eax  ; EBX := EAX (input_filename); EAX := junk.
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
		lodsd  ; cf_header.load_fofs.
		xchg ecx, eax  ; ECX := cf_header.load_fofs; EAX := junk.
		mov eax, stub_end-stub  ; Output cf_header.load_fofs.
		stosd  ; Output cf_header.load_fofs.
		times 4 movsd  ; Copy 4 more cf_header fields to cf_header.
		;mov edi, [eax+8]  ; cf_header.load_size.  No need to save this, we copy until EOF, to include the Watcom resources after the image.
		mov al, SYS_lseek
		xor edx, edx  ; SEEK_SET. ECX == cf_header.load_fofs.
		call check_syscall_al
		mov eax, [output_filename]

		push ebx  ; Save input filehandle.
		xchg ebx, eax  ; EBX := EAX (output_filename); EAX := junk.
		push byte SYS_unlink
		pop eax
		int 0x80  ; Linux i386 syscall. Ignore error returned in EAX (e.g. because the file was not found).
		mov ecx, O_WRONLY|O_CREAT|O_TRUNC
		mov edx, 666q  ; Permission bits (mode_t) for file creation.
		mov al, SYS_open
		call check_syscall_al
		xchg ebp, eax  ; EBP := EAX (output_filehandle); EAX := junk.
		jmp dword [output_code_ptr]

output_epl:
.update_elf_headers:
		mov edi, [epl_cf_entry_vaddr]  ; oix_image, i.e. image_base in the output executable program.
		mov eax, [cf_header.entry_rva]
		add [epl_cf_entry_vaddr], eax
		mov eax, [cf_header.load_size]
		add [epl_text_filesiz], eax
		mov eax, [cf_header.mem_size]
		add [epl_text_memsiz], eax
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
		mov ecx, ebx  ; ECX := EBX (image_base vaddr).
		add ebx, [cf_header.load_size]
		add ebx, byte 8  ; Allocate a few more NUL bytes in case the last few relocation bytes end in BSS.
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
		mov edx, ecx  ; EDX := image_base in the stub-allocated buffer.
		mov esi, [cf_header.reloc_rva]
.apply_relocations_and_clear:
		; Apply relocations and clear (set-to-zero) relocation data bytes.
		; Input: EDX: image_base in the stub-allocated buffer, EDI: image_base in the output executable program; ESI: reloc_rva.
		; Spoils: EAX, EBX, ECX, ESI.
		add esi, edx  ; ESI := image_base in the stub-allocated buffer + cf_header.reloc_rva.
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
		mov ebx, edx
		; Strip trailing NULs (0 bytes) from the image.
.strip0:	test edx, edx
		jz .done_strip0
		cmp byte [ecx+edx-1], 0
		jne .done_strip0
		dec edx
		jmp .strip0
.done_strip0:	sub ebx, edx
		sub [epl_text_filesiz], ebx  ; Subtract the number of bytes saved at the end.
		mov esi, [cf_header.mem_size]
		add esi, edi  ; ESI += image_base in the output executable program.
		add edi, [cf_header.load_size]
		sub edi, ebx  ; Subtract the number of bytes saved at the end.
.precompute_bss_clear_edi_and_ecx:  ; Ruins EBX, ESI, EDI.
		mov ebx, edi
		add ebx, 0xfff
		and ebx, ~0xfff  ; Round up to i386 page boundary. EBX := end of first page of BSS.
		cmp ebx, esi
		jna short .done_ebx  ; Jump iff the end of the first page of BSS is not later than the end of BSS.
		mov ebx, esi  ; Start filling from the end of load (.text and .data).
.done_ebx:	sub ebx, edi
		mov [epl_clear_bss_ecx], ebx
		mov [epl_clear_bss_edi], edi
.write_epl_stub:
		mov ebx, ebp  ; Output filehandle.
		push ecx  ; Save.
		push edx  ; Save.
		mov ecx, epl_stub
		mov edx, epl_stub_end-epl_stub
		push SYS_write
		pop eax
		call check_syscall_al
		pop edx  ; Restore.
		pop ecx  ; Restore.
		jmp short write_and_copy_rest  ; Writes EDX bytes starting at address ECX.

output_elf:	lea esi, [edi-6*4+cf_header.load_size-cf_header]  ; ESI := cf_header.load_size.
		mov edi, elf_cf_header.load_size
		lodsd  ; EAX := .load_size.
		stosd  ; Copy .load_size.
		movsd  ; Copy .reloc_rva.
		mov edx, [esi]  ; .mem_size.
		times 2 movsd  ; Copy .mem_size and .entry_rva from cf_header to elf_cf_header.
		lea ecx, [edi-6*4-elf_cf_header+elf_header]  ; ECX := elf_header.
		add [byte ecx-elf_header+elf_text_filesiz], eax  ; EAX == .load_size.
		add [byte ecx-elf_header+elf_text_memsiz ], edx  ; EDX == .mem_size.
		mov edx, elf_stub_end-elf_header
		; TODO(pts): Write shorter stub if there are no relocations.
		jmp short output_exe.after_ecdx

output_oix:	push byte 6*4  ; 6*4  ; OIX image starts right after the CF header.
		pop edx
		mov [byte edi-6*4+cf_header.load_fofs-cf_header], edx
		lea ecx, [edi-6*4]  ; cf_header.
		jmp short output_exe.after_ecdx

output_exe:	mov edx, stub_end-stub  ; MZ stub (DOS and Win32).
		mov ecx, stub
.after_ecdx:	mov ebx, ebp  ; Output filehandle.
		; Falls through to write_and_copy_rest

write_and_copy_rest:  ; Also copies resources (i.e. overlay) after the image.
		push SYS_write
		pop eax  ; Output filehandle.
		call check_syscall_al
		; !! Also strip trailing NULs from EOF here (needs big rewrite).
		; Falls through to copy_rest.
.copy_rest:	pop ebx  ; Input filehandle.
.read_next:	call read_to_buf
		test eax, eax
		jz .rw_done
		xchg edx, eax  ; EDX := EAX (size); EAX := junk.
		xchg ebp, ebx  ; EBX := output filehandle.
		mov al, SYS_write
		call check_syscall_al
		cmp eax, edx
		je .write_ok
		mov eax, fatal_write
		jmp fatal
.write_ok:	xchg ebp, ebx  ; EBX := input filehandle.
		jmp .read_next
.rw_done:	cmp [do_add_executable_bit], al  ; AL == 0.
		je short .after_add_executable_bit
.add_executable_bit:
		mov al, SYS_fstat  ; On Linux i386, this fails with EOVERFLOW == 75 if the file size is at least 1<<31 bytes (2 GiB).
		mov ebx, ebp  ; EBX := output filehandle.
		sub esp, byte 64  ; sizeof(struct stat) on Linux i386.
		mov ecx, esp
		call check_syscall_al
		movzx ecx, word [ecx+8]  ; .st_mode.
		add esp, byte 64  ; sizeof(struct stat) on Linux i386.
		mov edx, ecx
		and edx, 444q
		shr edx, 2  ; Convert subset of 0444 (readable) to 0111 (executable).
		or ecx, edx
		cmp ecx, edx
		je short .after_add_executable_bit  ; Jump if no change in permission bits.
		mov al, SYS_fchmod
		;mov ebx, ...  ; EBX == output filehandle.
		;mov ecx, ...  ; ECX == mode, including permission bits.
		call check_syscall_al
.after_add_executable_bit:
.exit_success:	xor eax, eax
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
.bad:		pop eax  ; Syscall number.
		cmp eax, SYS_open
		je short .bad_open
		mov eax, fatal_read
		cmp eax, SYS_read
		je short .fatal
		mov eax, fatal_write
		cmp eax, SYS_write
		je short .fatal
		mov eax, fatal_lseek
		cmp eax, SYS_lseek
		je short .fatal
		mov eax, fatal_fstat
		cmp eax, SYS_fstat
		je short .fatal
		mov eax, fatal_fchmod
		cmp eax, SYS_fchmod
		je short .fatal
		mov eax, fatal_syscall
		jmp short .fatal
.bad_open:	cmp ebx, [output_filename]
		mov eax, fatal_open_in
		jne short .fatal
		; Falls through.
		mov eax, fatal_open_out
.fatal:		;jmp fatal  ; Falls through to fatal.

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

fatal_usage:	db 'Usage: wcfd32stub <input.prog> <output.prog> [<output-format>]', 10, 0
fatal_ofmt:	db 'fatal: unknown output format', 10, 0
fatal_open_in:	db 'fatal: error opening input program file', 10, 0
fatal_open_out:	db 'fatal: error opening output program file', 10, 0
fatal_read:	db 'fatal: error reading', 10, 0
fatal_write:	db 'fatal: error writing', 10, 0
fatal_lseek:	db 'fatal: error seeking', 10, 0
fatal_fstat:	db 'fatal: error getting file attributes', 10, 0
fatal_fchmod:	db 'fatal: error adding executable bit to file', 10, 0
fatal_syscall:	db 'fatal: error in syscall', 10, 0
fatal_too_short: db 'fatal: file too short for CF header', 10, 0
fatal_cf_not_found: db 'fatal: CF header not found', 10, 0
fatal_alloc:	db 'fatal: error allocating memory', 10, 0
%endif  ; LINUXPROG

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
epl_stub:
epl_header:
incbin 'wcfd32linuxepl.bin'
epl_stub_end:
epl_cf_entry_vaddr equ epl_header+0x54+0*5+1  ; Will be modified in place. The argument of the `mov esi, ...' instruction in wcfd32linux.nasm.
epl_clear_bss_ecx  equ epl_header+0x54+1*5+1  ; Will be modified in place. The argument of the `mov ecx, ...' instruction in wcfd32linux.nasm.
epl_clear_bss_edi  equ epl_header+0x54+2*5+1  ; Will be modified in place. The argument of the `mov edi, ...' instruction in wcfd32linux.nasm.
epl_text_filesiz equ epl_header+0x54-0x10  ; Will be modified in place.
epl_text_memsiz  equ epl_header+0x54-0xc   ; Will be modified in place.

elf_stub:
elf_header:
incbin 'wcfd32linuxelf.bin'
elf_stub_end:
elf_cf_header equ elf_header+0x54
elf_cf_header.signature equ elf_cf_header+0  ; "CF\0\0". Correct when loaded.
elf_cf_header.load_fofs equ elf_cf_header+4  ; Correct when loaded.
elf_cf_header.load_size equ elf_cf_header+8  ; Will be modified in place, copied from cf_header.
elf_cf_header.reloc_rva equ elf_cf_header+0xc  ; Will be modified in place, copied from cf_header.
elf_cf_header.mem_size  equ elf_cf_header+0x10  ; Will be modified in place, copied from cf_header.
elf_cf_header.entry_rva equ elf_cf_header+0x14  ; Will be modified in place, copied from cf_header.
elf_text_filesiz equ elf_header+0x54-0x10  ; Will be modified in place.
elf_text_memsiz  equ elf_header+0x54-0xc   ; Will be modified in place.

prebss:
		bss_align equ ($$-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
		resb bss_align  ; Uninitialized data follows.
bss:
output_filename: resd 1
output_code_ptr: resd 1
;struct_stat:  ; Linux i386. 64 bytes.
;.st_dev: resd 1
;.st_ino: resd 1
;.st_mode: resw 1
;.st_nlink: resw 1
;.st_uid: resw 1  ; Special returned value 0xfffe means larger than 0xffff.
;.st_gid: resw 1  ; Special returned value 0xfffe means larger than 0xffff.
;.st_rdev: resd 1
;.st_size: resd 1  ; If file_size >= 0x80000000, then the syscall fails with EOVERFLOW == 75 == Value too large for defined data type.
;.st_blksize: resd 1  ; May be incorrect: 0x1000 reported here instead of 0x200 reported in struct stat64.
;.st_blocks: resd 1
;.st_atime: resd 1
;.st_atime_nsec: resd 1
;.st_mtime: resd 1
;.st_mtime_nsec: resd 1
;.st_ctime: resd 1
;.st_ctime_nsec: resd 1
;.__unused4: resd 1
;.__unused5: resd 1
read_buf:	resb 0x8000
.end:
do_add_executable_bit: resb 1
program_end:
%endif  ; LINUXPROG
