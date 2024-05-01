; by pts@fazekas.hu at Fri Apr 26 08:48:19 CEST 2024

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
;INT21H_FUNC_4CH_EXIT_PROCESS equ 0x4C
STDOUT_FILENO equ 1
EXIT_SUCCESS equ 0

_start:		push bx  ; Segment of the wcfd32_far_syscall syscall.
		push edx  ; Offset of the wcfd32_far_syscall syscall.
		call .get_msg
.msg:		db 'Hello, World!', 13, 10
.msg_end:
.get_msg:	pop edx  ; EDX := vaddr of .msg, in a position-independent way.
		mov ecx, .msg_end-.msg
		push STDOUT_FILENO
		pop ebx
		mov ah, INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE
		call far [esp]  ; Call wcfd32_far_syscall.
%if 0  ;  This also works.
		mov ax, INT21H_FUNC_4CH_EXIT_PROCESS<<8 | EXIT_SUCCESS
		call far [esp]  ; Call wcfd32_far_syscall.
		; Not reached.
%else
		add esp, 6  ; Pop offset and segment of the wcfd32_far_syscall syscall.
		xor eax, eax  ; EXIT_SUCCESS.
		retf
%endif

prebss:
bss_align equ (text-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
bss:		resb bss_align  ; Uninitialized data follows.

program_end:
