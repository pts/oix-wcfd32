; by pts@fazekas.hu at Fri Apr 26 08:48:19 CEST 2024

bits 32
cpu 386

mz_header:  ; This is not valid DOS MZ header, but it's good enough for wcfd32stub and others to find the CF header.
		dw 'MZ', 0, 0, 0, (cf_header-mz_header)>>4, 0, 0, 0
		times 8 dw 0
cf_header:  ; The 32-bit DOS loader finds it at mz_header.hdrsize. Must be aligned to 0x10.
.signature:	dd 'CF'                ; +0x00. Signature.
.load:		dd text-mz_header      ; +0x04. load_fofs.
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
		push edx  ; Save.
		push eax  ; Save.
		mov [ebp+wcfd32_far_syscall_offset], edx
		mov [ebp+wcfd32_far_syscall_segment], bx
		mov eax, [edi+4]  ; dword [wcfd32_param_struct+4]: command-line (ASCIIZ).
		call parse_first_arg
		cmp eax, [edi+4]
		jne .found_arg
		push 1  ; Exit code.
		lea eax, [ebp+msg_usage]
		jmp .print_exit
.found_arg:	xchg eax, [edi+4]
		mov [edi], eax  ; dword [wcfd32_param_struct]: program filename (ASCIIZ).
		; Now: EAX: filename of the WCFD32 executable program to load.
		call load_wcfd32_program_image  ; Also modifies EDX.
		cmp eax, -10
		jb .load_ok
		neg eax  ; EAX := load_error_code.
		push eax
		mov eax, [ebp+load_errors+4*eax]
		add eax, ebp  ; For PIC.
.print_exit:	call print_str  ; !! Report filename etc. on file open error.
		pop eax
		pop ebx  ; Ignore saved EAX.
		pop edx  ; Ignore saved EDX.
		retf  ; exit(load_error_code).
.load_ok:	; Now: EAX: entry point address.
		xchg esi, eax  ; ESI := (entry point address); EAX := junk.
		pop eax  ; Restore. Incoming AH contains the operating system identifier.
		pop edx  ; Restore.
		xor ebp, ebp  ; Clear it and also set flags, to make it deterministic.
		push cs  ; For the `retf' of the far call.
		call esi  ; Run the loaded program, starting at its entry point.
		retf

%define CONFIG_LOAD_TRY_CF_AT_HDRSIZE
%define CONFIG_LOAD_SINGLE_READ
%define CONFIG_LOAD_INT21H call far [ebp+wcfd32_far_syscall_offset]
%undef  CONFIG_LOAD_MALLOC_EAX
%undef  CONFIG_LOAD_MALLOC_EBX
%define CONFIG_LOAD_CLEAR_BSS
%include "wcfd32load.inc.nasm"  ; We use the fact that this code doesn't read or write EBP.

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
		ret

%ifdef DEBUG
print_crlf:  ; Prints a CRLF ("\r", "\n") to stdout.
		push eax
		push 13|10<<8  ; String.
		mov eax, esp
		call print_str
		pop eax  ; String. Value ingored.
		pop eax
		ret
%endif

; /* Parses the first argument of the Windows command-line (specified in EAX)
;  * in place. Returns (in EAX) the pointer to the rest of the command-line.
;  * The parsed argument will be available as NUL-terminated string at the
;  * same location as the input.
;  *
;  * Similar to CommandLineToArgvW(...) in SHELL32.DLL, but doesn't aim for
;  * 100% accuracy, especially that it doesn't support non-ASCII characters
;  * beyond ANSI well, and that other implementations are also buggy (in
;  * different ways).
;  *
;  * It treats only space and tab and a few others as whitespece. (The Wine
;  * version of CommandLineToArgvA.c treats only space and tab as whitespace).
;  *
;  * This is based on the incorrect and incomplete description in:
;  *  https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw
;  *
;  * See https://nullprogram.com/blog/2022/02/18/ for a more detailed writeup
;  * and a better installation.
;  *
;  * https://github.com/futurist/CommandLineToArgvA/blob/master/CommandLineToArgvA.c
;  * has the 3*n rule, which Wine 1.6.2 doesn't seem to have. It also has special
;  * parsing rules for argv[0] (the program name).
;  *
;  * There is the CommandLineToArgvW function in SHELL32.DLL available since
;  * Windows NT 3.5 (not in Windows NT 3.1). For alternative implementations,
;  * see:
;  *
;  * * https://github.com/futurist/CommandLineToArgvA
;  *   (including a copy from Wine sources).
;  * * http://alter.org.ua/en/docs/win/args/
;  * * http://alter.org.ua/en/docs/win/args_port/
;  */
; char * __watcall parse_first_arg(char *pw) {
;   const char *p;
;   const char *q;
;   char c;
;   char is_quote = 0;
;   for (p = pw; c = *p, c == ' ' || c == '\t' || c == '\n' || c == '\v'; ++p) {}
;   if (*p == '\0') { *pw = '\0'; return pw; }
;   for (;;) {
;     if ((c = *p) == '\0') goto after_arg;
;     ++p;       
;     if (c == '\\') {
;       for (q = p; c = *q, c == '\\'; ++q) {}
;       if (c == '"') {
;         for (; p < q; p += 2) {
;           *pw++ = '\\';
;         }
;         if (p != q) {
;           is_quote ^= 1;
;         } else {
;           *pw++ = '"';
;           ++p;  /* Skip over the '"'. */
;         }
;       } else {
;         *pw++ = '\\';
;         for (; p != q; ++p) {
;           *pw++ = '\\';
;         }
;       }
;     } else if (c == '"') {
;       is_quote ^= 1;
;     } else if (!is_quote && (c == ' ' || c == '\t' || c == '\n' || c == '\v')) {
;      after_arg:
;       *pw = '\0';
;       return (char*)p;
;     } else {
;       *pw++ = c;  /* Overwrite in-place. */
;     }
;   }
; }
parse_first_arg:
		push ebx
		push ecx
		push edx
		push esi
		xor bh, bh  ; is_quote.
		mov edx, eax
.1:		mov bl, [edx]
		cmp bl, ' '
		je .2
		cmp bl, 0x9
		jb .3
		cmp bl, 0xb
		ja .3
.2:		inc edx
		jmp .1
.3:		test bl, bl
		jne .8
		mov [eax], bl
		jmp strict short .ret
.4:		cmp bl, '"'
		jne .11
.5:		lea esi, [eax+0x1]
		cmp edx, ecx
		jae .6
		mov byte [eax], 0x5c  ; "\\"
		mov eax, esi
		inc edx
		inc edx
		jmp .5
.6:		je .10
.7:		xor bh, 0x1
.8:		mov bl, [edx]
		test bl, bl
		je .16
		inc edx
		cmp bl, 0x5c  ; "\\"
		jne .13
		mov ecx, edx
.9:		mov bl, [ecx]
		cmp bl, 0x5c  ; "\\"
		jne .4
		inc ecx
		jmp .9
.10:		mov byte [eax], '"'
		mov eax, esi
		lea edx, [ecx+0x1]
		jmp .8
.11:		mov byte [eax], 0x5c  ; "\\"
		inc eax
.12:		cmp edx, ecx
		je .8
		mov byte [eax], 0x5c  ; "\\"
		inc eax
		inc edx
		jmp .12
.13:		cmp bl, '"'
		je .7
		test bh, bh
		jne .15
		cmp bl, ' '
		je .14
		cmp bl, 0x9
		jb .15
		cmp bl, 0xb
		jna .14
.15:		mov [eax], bl
		inc eax
		jmp .8
.14:		dec edx
.16:		mov byte [eax], 0x0
		xchg eax, edx  ; EAX := EDX: EDX := junk.
.ret:		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

%ifdef DEBUG
msg:		db 'Hello, World!', 13, 10, 0
%endif

msg_usage:	db 'Usage: oixrun <oixprog> [<arg> ...]', 13, 10, 0

emit_load_errors

prebss:
bss_align equ (text-$)&3
section .bss align=1  ; We could use `absolute $' here instead, but that's broken (breaks address calculation in program_end-bss+prebss-file_header) in NASM 0.95--0.97.
bss:		resb bss_align  ; Uninitialized data follows.

wcfd32_far_syscall_offset: resd 1
wcfd32_far_syscall_segment: resd 1  ; Only word size, but using dword for alignment.

program_end:
