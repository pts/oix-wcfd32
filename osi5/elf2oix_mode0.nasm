;
; elf2oix_mode0.nasm: build an OIX program which manually applies its relocations
; by pts@fazekas.hu at Tue Jul  8 17:10:45 CEST 2025
;
; Compile with: nasm-0.98.39 -O0 -w+orphan-labels -f bin -DINOIXFN="'../run1/nasm.oix'" -o nasmrel.oix elf2oix_mode0.nasm
;

%macro assert_at 1
  times  (%1)-($-$$) times 0 db 0
  times -(%1)+($-$$) times 0 db 0
%endm

bits 32
cpu 386

%ifndef INOIXFN
  %error ERROR_MISSING_INOIXFN
  db 1/0
  ;%define INOIXFN  '../run1/nasm.oix'
%endif

; Based on binary analysis of INOIXFN.
TEXTDATA_SIZE equ 0x35a84
BSS_SIZE equ 0x16910
RELOC_BLOCK1_SIZE equ 0x3aa6  ; Excludes the block header word before it and the terminating block header word after it.
ENTRY_IN_TEXTDATA equ 0x1c9dd

file_header:
cf_header:
.signature:	db 'CF', 0, 0
.load_fofs:	dd oix_image-file_header
.load_size:	dd oix_reloc.end-oix_image
.reloc_rva:	dd oix_reloc.header2-oix_image  ; By pointing to word [0], simulate to the OIX runner that there are no relocations.
.mem_size:	dd oix_mem_end-oix_image
.entry_rva:	dd wrapper_entry-oix_image

oix_image:
wrapper_entry:	pusha  ; Save.
		call .here  ; For position-independent code (PIC) in wrapper_entry.
.here:		pop edi  ; EDI := loaded memory offset of .here.
		lea edi, [byte edi-(.here-oix_image)]  ; EDI := image_base == loaded memory offset of oix_image.
		lea esi, [dword edi+oix_reloc-oix_image]  ; The constants has to be patched here.
.apply_relocations:
		; Apply relocations. !! Do better compression of relocations.
		; Input: EDI: image_base; ESI: image_base + .reloc_rva == image_base + oix_reloc-oix_image.
		; Spoils: EAX, EBX, ECX, ESI.
		push esi  ; Save, will be restored by `pop edi'.
		xor eax, eax  ; The high word of EAX will remain 0 until .rdone.
.next_block:	lodsw
		mov ecx, eax
		jecxz .rdone
		lodsw
		mov ebx, eax
		shl ebx, 16
		add ebx, edi
.next_reloc:	lodsw
		add ebx, eax
		add [ebx], edi
		loop .next_reloc
		jmp strict short .next_block
.rdone:
.clear_relocations:  ; Clear oix_reloc with NUL bytes. This is needed, because relocations overlap with BSS, and the program expects BSS bytes to be NUL.
		pop edi  ; EDI := image_base + .reloc_rva == image_base + oix_reloc-oix_image.
%if 0  ; This is 1 byte shorter than a direct mov, but a direct mov is more flexible: the constant can be changed later.
		mov ecx, esi
		sub ecx, edi  ; ECX := oix_reloc.end-oix_reloc.
%else
		mov ecx, oix_reloc.end-oix_reloc  ; The constant has to be patched here.
%endif
		rep stosb  ; Clear relocation data. EAX == 0 here, see `jecxz .rdone' above.
		popa  ; Restore.
		jmp strict near prog_textdata+ENTRY_IN_TEXTDATA  ; The constant has to be patched here.
		times (file_header-$)&3 nop
		assert_at 0x18+0x3c
prog_textdata:	;incbin INOIXFN, 0x18+RELOC_BLOCK1_SIZE+6, TEXTDATA_SIZE
		incbin 'nasmrel.bin', 0, TEXTDATA_SIZE  ; Created by: perl -0777 -wn nasmrel.pl <../run1/nasm.oix >nasmrel.bin
		times (file_header-$)&1 db 0
oix_reloc:
.header1:	dw (.header2-.header1-4)>>1
.block1:	dw 0, prog_textdata+0x41-oix_image  ; RVA of first relocation. The first word is the high word.
		incbin INOIXFN, 0x18+2+4, RELOC_BLOCK1_SIZE-4 ; After the swapped-dword RVA, each entry is a 2-byte little-endian word.
.header2:	dw 0  ; End of relocations.
.end:
;oix_image_end:
oix_mem_end0: equ prog_textdata+TEXTDATA_SIZE+BSS_SIZE
%if oix_reloc.end-oix_image>oix_mem_end0-oix_image
  oix_mem_end: equ oix_reloc.end
%else
  oix_mem_end: equ oix_mem_end0
%endif
