;
; talk.nasm: command-line and environment printer demo program for IOX, written in NASM
; by pts@fazekas.hu at Wed May  1 11:00:52 CEST 2024
;
; Compile with: nasm -O999999999 -w+orphan-labels -f bin -o talk.oix talk.nasm
;
; It has the same functionality as talk.c. It splits the command-line arguments to argv.
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
.argv_next:	mov edx, eax		; Save EAX (remaining command line).
		call parse_first_arg
		cmp eax, edx
		je .argv_end		; No more arguments in argv.
		push eax
		lea eax, [ebp+spsp_msg]
		call print_str
		pop eax
		xchg eax, edx		; EAX := argv[i]; EDX := rest of command-line.
		call print_str
		lea eax, [ebp+crlf_msg]
		call print_str
		xchg eax, edx		; EAX := rest of command-line; EDX := junk.
		jmp .argv_next
.argv_end:	lea eax, [ebp+env_vars_msg]
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

; This is a helper function used by _start.
;
; Reverses the elements in a NULL-terminated array of (void*)s.
global reverse_ptrs  ; In case it is useful for the program.
reverse_ptrs:  ; void __watcall reverse_ptrs(void **p);
		push ecx
		push edx
		lea edx, [eax-4]
.next1:		add edx, 4
		cmp dword [edx], 0
		jne short .next1
		cmp edx, eax
		je short .nothing
		sub edx, 4
		jmp short .cmp2
.next2:		mov ecx, [eax]
		xchg ecx, [edx]
		mov [eax], ecx
		add eax, 4
		sub edx, 4
.cmp2:		cmp eax, edx
		jb short .next2
.nothing:	pop edx
		pop ecx
.ret:
WEAK..mini___M_start_isatty_stdin:   ; Fallback, tools/elfofix will convert it to a weak symbol.
WEAK..mini___M_start_isatty_stdout:  ; Fallback, tools/elfofix will convert it to a weak symbol.
WEAK..mini___M_start_flush_stdout:   ; Fallback, tools/elfofix will convert it to a weak symbol.
WEAK..mini___M_start_flush_opened:   ; Fallback, tools/elfofix will convert it to a weak symbol.
		ret

; This is a helper function used by _start.
;
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
; static char * __watcall parse_first_arg(char *pw) {
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
;       if (p == pw) ++p;  /* Don't clobber the rest with '\0' below. */
;      after_arg:
;       *pw = '\0';
;       return (char*)p;
;     } else {
;       *pw++ = c;  /* Overwrite in-place. */
;     }
;   }
; }
parse_first_arg:  ; static char * __watcall parse_first_arg(char *pw);
		push ebx
		push ecx
		push edx
		push esi
		xor bh, bh  ; is_quote.
		mov edx, eax
.1:		mov bl, [edx]
		cmp bl, ' '
		je short .2  ; The inline assembler is not smart enough with forward references, we need these shorts.
		cmp bl, 0x9
		jb short .3
		cmp bl, 0xb
		ja short .3
.2:		inc edx
		jmp short .1
.3:		test bl, bl
		jne short .8
		mov [eax], bl
		jmp short .ret
.4:		cmp bl, '"'
		jne short .11
.5:		lea esi, [eax+0x1]
		cmp edx, ecx
		jae short .6
		mov byte [eax], 0x5c  ; "\\"
		mov eax, esi
		inc edx
		inc edx
		jmp short .5
.6:		je short .10
.7:		xor bh, 0x1
.8:		mov bl, [edx]
		test bl, bl
		je short .16
		inc edx
		cmp bl, 0x5c  ; "\\"
		jne short .13
		mov ecx, edx
.9:		mov bl, [ecx]
		cmp bl, 0x5c  ; "\\"
		jne short .4
		inc ecx
		jmp short .9
.10:		mov byte [eax], '"'
		mov eax, esi
		lea edx, [ecx+0x1]
		jmp short .8
.11:		mov byte [eax], 0x5c  ; "\\"
		inc eax
.12:		cmp edx, ecx
		je short .8
		mov byte [eax], 0x5c  ; "\\"
		inc eax
		inc edx
		jmp short .12
.13:		cmp bl, '"'
		je short .7
		test bh, bh
		jne short .15
		cmp bl, ' '
		je short .14
		cmp bl, 0x9
		jb short .15
		cmp bl, 0xb
		jna short .14
.15:		mov [eax], bl
		inc eax
		jmp short .8
.14:		dec edx
		cmp eax, edx
		jne .16
		inc edx
.16:		mov byte [eax], 0x0
		xchg eax, edx  ; EAX := EDX: EDX := junk.
.ret:		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

; __END__

;section .rodata align=1  ; No separate section in OIX.

hello_msg:	db 'Hello, World from NASM!', 13, 10, 0
program_name_msg: db 'Program name: ', 0
crlf_msg:	db 13, 10, 0
argv_msg:	db 'Command-line arguments: 13', 10, 0
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
