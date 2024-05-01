;
; answer42.nasm: example NASM source code for an OIX program which just does exit(42)
; by pts@fazekas.hu at Wed May  1 04:34:36 CEST 2024
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

; OIX program entry point.
_start:		mov al, 42  ; Set process exit code.
		retf  ; Return to caller, it will make the process exit with exit code in AL.

prebss:
bss_align equ (text-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
bss:		resb bss_align  ; Uninitialized data follows.

program_end:
