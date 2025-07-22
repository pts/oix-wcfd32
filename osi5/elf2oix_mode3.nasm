;
; elf2oix_mode3.nasm: build an OIX program which manually applies its relocations, packed differently
; by pts@fazekas.hu at Tue Jul  8 17:10:45 CEST 2025
;
; Compile with: nasm-0.98.39 -O0 -w+orphan-labels -f bin -DINOIXFN="'../run1/nasm.oix'" -o nasmrel3.oix elf2oix_mode3.nasm
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
.reloc_rva:	dd oix_image_end-oix_image  ; By pointing to word [0], simulate to the OIX runner that there are no relocations.
.mem_size:	dd oix_mem_end-oix_image
.entry_rva:	dd wrapper_entry-oix_image

oix_image:
wrapper_entry:	pusha  ; Save.
		call .here  ; For position-independent code (PIC) in wrapper_entry.
.here:		pop edi  ; EDI := loaded memory offset of .here.
		lea edi, [byte edi-(.here-.done)]  ; EDI := prog_textdata == loaded memory offset of prog_textdata.
		lea esi, [dword edi+oix_reloc-oix_image-(.done-oix_image)]  ; The constants has to be patched here.
		push esi  ; Save, will be restored by `pop edi'.
.apply_relocations:
		; Apply relocations.
		; Input: EDI: image_base; ESI: image_base + .reloc_rva == image_base + oix_reloc-oix_image.
		; Ruins: EAX, EBX, ECX, ESI.
		mov ebx, edi
.clr_next_byte:	xor eax, eax  ; Clear the 3 highest bytes of EAX.
.next_byte:	lodsb  ; AL := first_byte.
		sub al, 1
		jc short .skip  ; Jumps if AL was 0.
		add ebx, eax  ; Adds any of 0..0xfe.
		add [ebx], edi
		add ebx, byte 4
		jmp short .next_byte
.skip:		mul byte [esi]  ; EAX := AX := AL * second_byte == 0xff * second_byte.
		inc esi
		add ebx, eax  ; EBX += skip_size.
		test eax, eax
		jnz short .clr_next_byte  ; Jumps iff second_byte wasn't 0.
.rdone:		; We reach this iff first_byte == 0 && second_byte == 0, i.e. after two NUL bytes.
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
.done:		assert_at 0x18+0x3c
prog_textdata:	;incbin INOIXFN, 0x18+RELOC_BLOCK1_SIZE+6, TEXTDATA_SIZE
		incbin 'nasmrel.bin', 0, TEXTDATA_SIZE  ; Created by: perl -0777 -wn nasmrel.pl <../run1/nasm.oix >nasmrel.bin
		times (file_header-$)&1 db 0
oix_reloc:	incbin 'nasm.relmode3.bin'  ; Not generated.
.end:
oix_image_end:
oix_mem_end0: equ prog_textdata+TEXTDATA_SIZE+BSS_SIZE
%if oix_reloc.end-oix_image>oix_mem_end0-oix_image
  oix_mem_end: equ oix_reloc.end
%else
  oix_mem_end: equ oix_mem_end0
%endif
