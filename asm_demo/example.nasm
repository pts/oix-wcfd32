;
; example.nasm: command-line and environment printer demo program for IOX, written in NASM
; by pts@fazekas.hu at Fri Apr 26 22:24:38 CEST 2024
;
; Compile with: nasm -O999999999 -w+orphan-labels -f bin -o example.oix example.nasm
;
; It has the same functionality as example.c. It doesn't split the
; command-line arguments to argv.
;

bits 32
cpu 386

cf_header:  ; The 32-bit DOS loader finds it at mz_header.hdrsize. Must be aligned to 0x10.
.signature:	dd 'CF'                ; +0x00. Signature.
.load_fofs:	dd text-$$             ; +0x04. load_fofs.
.load_size:	dd prebss-text         ; +0x08. load_size.
.reloc_rva:	dd relocations-text    ; +0x0c. reloc_rva.
.mem_size:	dd program_end-bss+prebss-text  ; +0x10. mem_size.
.entry_rva:	dd _start-text         ; +0x14. entry_rva.
		; End.                 ; +0x18. Size.
text:
relocations:	dw 0  ; End of relocations. It would be hard to generate them from NASM.

; WCFD32 ABI constants.
INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE equ 0x40
STDOUT_FILENO equ 1
EXIT_SUCCESS equ 0

_start:		call .vcont
.vcont:
org $$-.vcont  ; Position independent code (PIC): from now all global variables will be accessed through EBP.
		pop ebp  ; EBP := vaddr of .vcont.
		mov [ebp+wcfd32_far_syscall_offset], edx
		mov [ebp+wcfd32_far_syscall_segment], bx
		lea eax, [ebp+hello_msg]
		call print_str
		lea eax, [ebp+program_name_msg]
		call print_str
		mov eax, [edi]  ; Program pathname received from the OIX loader.
		call print_str
		lea eax, [ebp+crlf_msg]
		call print_str
		lea eax, [ebp+argv_msg]
		call print_str
		mov eax, [edi+4]  ; Command line received from the OIX loader.
		call print_str
		lea eax, [ebp+cparen_crlf_msg]
		call print_str
		lea eax, [ebp+env_vars_msg]
		call print_str
		mov ebx, [edi+8]  ; Environment variables received from the OIX loader.
.next_env_var:	cmp byte [ebx], 0
		je .done_env  ; Stop at the firt empty entry. Each entry looks like `<name>=<value>'.
		lea eax, [ebp+spsp_msg]
		call print_str
		mov eax, ebx
		call print_str
		lea eax, [ebp+crlf_msg]
		call print_str
.next_byte:	inc ebx
		cmp byte [ebx-1], 0
		jne .next_byte
		jmp .next_env_var
.done_env:	lea eax, [ebp+bye_msg]
		call print_str
		xor eax, eax  ; EXIT_SUCCESS.
		retf

print_str:  ; Prints the NUL-terminated string in EAX to stdout.
		push ebx
		push ecx
		push edx
		push eax
		xchg edx, eax  ; EDX := EAX (data pointer); EAX := junk.
		or ecx, -1
.next:		inc ecx
		cmp byte [edx+ecx], 0  ; TODO(pts): rep scasb.
		jne .next
		jecxz .after_write  ; Don't truncate.
		push STDOUT_FILENO
		pop ebx
		mov ah, INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE
		call far [ebp+wcfd32_far_syscall_offset]
.after_write:	pop eax
		pop edx
		pop ecx
		pop ebx

		xor eax, eax  ; EXIT_SUCCESS.
		ret

print_crlf:  ; Prints a CRLF ("\r", "\n") to stdout.
		push eax
		push 13|10<<8  ; String.
		mov eax, esp
		call print_str
		pop eax  ; String. Value ingored.
		pop eax
		ret

;section .rodata align=1  ; No separate section in OIX.

hello_msg:	db 'Hello, World from NASM!', 13, 10, 0
program_name_msg: db 'Program name: ', 0
cparen_crlf_msg: db ')'  ; Falls through to crlf.
crlf_msg:	db 13, 10, 0
argv_msg:	db 'Command-line arguments: (', 0
env_vars_msg:	db 'Environment variables:', 13, 10, 0
spsp_msg:	db '  ', 0
bye_msg:	db 'Bye!', 13, 10, 0

prebss:
bss_align equ (text-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
bss:		resb bss_align  ; Uninitialized data follows.

wcfd32_far_syscall_offset: resd 1
wcfd32_far_syscall_segment: resd 1  ; Only word size, but using dword for alignment.

program_end:
