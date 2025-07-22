;
; elf2oix_mode1.nasm: build 0x1c-byte setup code an OIX program which has do relocations and its entry point is not at the beginning
; by pts@fazekas.hu at Tue Jul  8 17:10:45 CEST 2025
;
; Compile with: nasm-0.98.39 -O0 -w+orphan-labels -f bin -o elf2oix_mode1.bin elf2oix_mode1.nasm

%macro assert_at 1
  times  (%1)-($-$$) times 0 db 0
  times -(%1)+($-$$) times 0 db 0
%endm

bits 32
cpu 386

file_header:
oix_image:
wrapper_entry:	pusha  ; Save.
		call .here  ; For position-independent code (PIC) in wrapper_entry.
.here:		pop edi  ; EDI := loaded memory offset of .here.
		;lea edi, [byte edi-(.here-oix_image)]  ; EDI := image_base == loaded memory offset of oix_image. lea edi, [edi+6].
		lea edi, [dword edi+oix_reloc-oix_image-(.here-oix_image)]  ; The constants has to be patched here.
		; Now EDI is image_base + .reloc_rva == image_base + oix_reloc-oix_image.
		mov ecx, oix_reloc.end-oix_reloc  ; The constant has to be patched here.
		xor eax, eax
		rep stosb  ; Clear relocation data. EAX == 0 here, see `jecxz .rdone' above.
		popa  ; Restore.
		jmp strict near prog_textdata  ; The constant has to be patched here.
		times (file_header-$)&3 nop
prog_textdata:	hlt
oix_reloc:
.header2:	dw 0  ; End of relocations.
.end:
