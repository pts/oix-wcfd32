;
; wcfd32dos.nasm: WCFD32 program runner for 32-bit DOS
; by pts@fazekas.hu at Tue Apr 23 00:33:22 CEST 2024
;
; This is 32-bit DOS program which loads a WCFD32 program (from the same .exe
; file) and runs it. It passes the program filename, command-line argments
; and environments to the WCFD32 program, it does I/O for the WCFD32
; program, and it exits with the exit code returned by the WCFD32
; program.
;
; !! Implement it properly.
; !! TODO(pts): How do I get an exception dump in dosbox --cmd? pmodew.exe seems to
;    write it to video memory.
; !! TODO(pts): Implement Ctrl-<C> and Ctrl-<Break>.
; !! TODO(pts): Set up some exception handlers such as division by zero.
; !! TODO(pts): Support long filenames using some Windows 95 DOS APIs, if available. This will not work on DOSBox.
;

bits 32
cpu 386

%ifnidn __OUTPUT_FORMAT__, bin
  %define .le.text _TEXT
  ;%define .rodatastr CONST  ; Unused.
  ;%define .rodata CONST2
  ;%define .data _DATA
  %define .le.bss _BSS
  ;%define .stack _STACK

  section _TEXT  USE32 class=CODE align=1
  section CONST  USE32 class=DATA align=1  ; OpenWatcom generates align=4.
  section CONST2 USE32 class=DATA align=4
  section _DATA  USE32 class=DATA align=4
  section _BSS   USE32 class=BSS NOBITS align=4  ; NOBITS is ignored by NASM, but class=BSS works.
  section STACK  USE32 class=STACK NOBITS align=1  ; Pacify WLINK: Warning! W1014: stack segment not found
  group DGROUP CONST CONST2 _DATA _BSS

  %macro relocated_le.text 2+
    %define relval %1
    %2
    %undef relval
  %endm
  %define relocated_le.bss relocated_le.text
%endif
%macro relocated_le.text.dd 1
  relocated_le.text %1, dd (relval)
%endm

INT21H_FUNC_06H_DIRECT_CONSOLE_IO equ 0x6
INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO equ 0x8
INT21H_FUNC_19H_GET_CURRENT_DRIVE equ 0x19
INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS equ 0x1A
INT21H_FUNC_2AH_GET_DATE        equ 0x2A
INT21H_FUNC_2CH_GET_TIME        equ 0x2C
INT21H_FUNC_3BH_CHDIR           equ 0x3B
INT21H_FUNC_3CH_CREATE_FILE     equ 0x3C
INT21H_FUNC_3DH_OPEN_FILE       equ 0x3D
INT21H_FUNC_3EH_CLOSE_FILE      equ 0x3E
INT21H_FUNC_3FH_READ_FROM_FILE  equ 0x3F
INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE equ 0x40
INT21H_FUNC_41H_DELETE_NAMED_FILE equ 0x41
INT21H_FUNC_42H_SEEK_IN_FILE    equ 0x42
INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES equ 0x43
INT21H_FUNC_44H_IOCTL_IN_FILE   equ 0x44
INT21H_FUNC_47H_GET_CURRENT_DIR equ 0x47
INT21H_FUNC_48H_ALLOCATE_MEMORY equ 0x48
INT21H_FUNC_4CH_EXIT_PROCESS    equ 0x4C
INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE equ 0x4E
INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE equ 0x4F
INT21H_FUNC_56H_RENAME_FILE     equ 0x56
INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME equ 0x57
INT21H_FUNC_60H_GET_FULL_FILENAME equ 0x60

WCFD32_OS_DOS equ 0
WCFD32_OS_OS2 equ 1
WCFD32_OS_WIN32 equ 2
WCFD32_OS_WIN16 equ 3
WCFD32_OS_UNKNOWN equ 4  ; Anything above 3 is unknown.

NULL equ 0

section .le.text

global le.start
le.start:
%ifnidn __OUTPUT_FORMAT__, bin
  ..start:
%endif
		sti  ; Enable virtual interrupts. TODO(pts): Do we need it?
		;int 3  ; This would cause an exception, making PMODE/W dump the registers to video memory and exit.
		push ds
		pop es  ; Default value is different.
		mov ah, 62h  ; Get PSP selector.
		int 21h
		mov ax, 6
		int 31h  ; Get segment base of BX. CX:DX.
		shl ecx, 16
		mov cx, dx  ; ECX := linear address of PSP.
		lea ebp, [ecx+81h]  ; Command-line arguments.
		mov ebx, [ecx+2ch]  ; Environment DOS segment, now as selector. We only use the BX part.
		;mov ax, 6  ; Still 6, no need to set it again.
		int 31h  ; Get segment base of BX. CX:DX.
		shl ecx, 16
		mov cx, dx  ; ECX := linear address of the environment variable strings.
		movzx eax, byte [ebp-1]
		mov byte [ebp+eax], 0
		mov al, [ebp]
		cmp al, ' '
		je .done_inc
		cmp al, 9
		je .done_inc
		mov byte [ebp], ' '  ; Prepend a space.
		dec ebp
.done_inc:	; Now: EBP: command-line arguments terminated by NUL; ECX: DOS environment variable strings.
		push ecx
		mov edi, ecx
		or ecx, -1
		xor al, al  ; Also sets ZF=1.
.cont_var:	repne scasb  ; Skip environment variable and terminating NUL.
		scasb  ; Skip terminating NUL.
		jne .cont_var
		inc edi
		inc edi
		pop ecx
		; Now: EBP: command-line arguments terminated by NUL; ECX: DOS environment variable strings; EDI: full program pathname terminated by NUL.
		mov eax, edi
		call load_wcfd32_program_image
		cmp eax, -10
		jb .load_ok
		neg eax  ; EAX := load_error_code.
		push eax
		relocated_le.text load_errors, mov eax, [relval+4*eax]
		call print_str  ; !! Report filename etc. on file open error.
		pop eax
		jmp .exit ; exit(load_error_code).
.load_ok:	; Now we call the entry point.
		;
		; Input: AH: operating system (WCFD32_OS_DOS or WCFD32_OS_WIN32).
		; Input: BX: segment of the call_far_dos_int21h syscall.
		; Input: EDX: offset of the call_far_dos_int21h syscall.
		; Input: ECX: must be 0 (unknown parameter).
		; Input: EDI: wcfd32_param_struct
		; Input: dword [wcfd32_param_struct]: program filename (ASCIIZ)
		; Input: dword [wcfd32_param_struct+4]: command-line (ASCIIZ)
		; Input: dword [wcfd32_param_struct+8]: environment variables (each ASCIIZ, terminated by a final NUL)
		; Input: dword [wcfd32_param_struct+0xc]: 0 (wcfd32_break_flag_ptr)
		; Input: dword [wcfd32_param_struct+0x10]: 0 (wcfd32_copyright)
		; Input: dword [wcfd32_param_struct+0x14]: 0 (wcfd32_is_japanese)
		; Input: dword [wcfd32_param_struct+0x18]: 0 (wcfd32_max_handle_for_os2)
		; Call: far call.
		; Output: EAX: exit code (0 for EXIT_SUCCESS).
		push 0  ; Simulate that the break flag is always 0. WLIB needs it.
		; TODO(pts): Make it smaller by using stosd or push.
		;mov dword [wcfd32_copyright], 0  ; Not needed, .bss is zero-initialized by PMODE/W.
		;mov dword [wcfd32_is_japanese], 0  ; Not needed, .bss is zero-initialized by PMODE/W.
		;mov dword [wcfd32_max_handle_for_os2], 0  ; Not needed, .bss is zero-initialized by PMODE/W.
		relocated_le.bss wcfd32_break_flag_ptr, mov [relval], esp
		relocated_le.bss wcfd32_program_filename, mov [relval], edi
		relocated_le.bss wcfd32_command_line, mov [relval], ebp
		relocated_le.bss wcfd32_env_strings, mov [relval], ecx
		xor ebx, ebx  ; Not needed by the ABI, just make it deterministic.
		xor esi, esi  ; Not needed by the ABI, just make it deterministic.
		xor ebp, ebp  ; Not needed by the ABI, just make it deterministic.
		sub ecx, ecx  ; This is an unknown parameter, which we always set to 0.
		relocated_le.text wcfd32_far_syscall, mov edx, relval
		relocated_le.bss wcfd32_param_struct, mov edi, relval
		mov bx, cs  ; Segment of wcfd32_far_syscall for the far call.
		xchg esi, eax  ; ESI := (entry point address); EAX := junk.
		mov ah, WCFD32_OS_DOS  ; !! wasmx106.exe (loader16.asm) does OS_WIN16. !! Why? Which of DOS or OS2? Double check.
		push cs  ; For the `retf' of the far call.
		call esi
.exit:		mov ah, 4ch  ; Exit with exit code in AL.
		int 21h  ; This is the only way to exit from PMODE/W, these don't work: `ret', `retf', `iret', `int 20h'.
		; Not reached.

%ifdef DEBUG
print_crlf:  ; !! Prints a CRLF ("\r", "\n") to stdout.
		push eax
		push edx
		push 13|10<<8|'$'<<16
		mov ah, 9  ; Print '$'-terminated string.
		mov edx, esp
		int 21h  ; DOS extended syscall.
		pop edx  ; Clean up.
		pop edx
		pop eax
		ret
%endif

%ifdef DEBUG
print_chr:  ; !! Prints single byte in AL to stdout.
		push eax
		push edx
		mov ah, 2
		mov dl, al
		int 21h  ; DOS extended syscall.
		pop edx
		pop eax
		ret
%endif

print_str:  ; !! Prints the ASCIIZ string (NUL-terminated) at EAX to stdout.
		push eax
		push ebx
		push ecx
		push edx
		mov edx, eax
		mov ah, 40h  ; Write.
		xor ebx, ebx
		inc ebx  ; STDOUT_FILENO.
		or ecx, -1
.next:		inc ecx
		cmp byte [edx+ecx], 0  ; TODO(pts): rep scasb.
		jne .next
		int 21h  ; DOS extended syscall. Error indication in CF.
		pop edx
		pop ecx
		pop ebx
		pop eax
		ret

malloc:  ; Allocates EAX bytes of memory. First it tries high memory, then conventional memory. On success, returns starting address. On failure, returns NULL.
		push ebx
		push ecx
		push esi
		push edi
		push ebp
		add eax,  3  ; Part of the align fix to dword.
		and eax, ~3  ; Part of the align fix to dword.
		xchg ebp, eax  ; EBP := EAX; EAX := junk.
		; We need to allocate EBP bytes of memory here. With WASM,
		; EBP (new_amount) is typically 0x30000 for the CF image
		; load, then 0x2000 a few times, then 0x1000 many times.
		;
		; We use DPMI function 501h
		; (https://fd.lod.bz/rbil/interrup/dos_extenders/310501.html).
		; But we don't want to call it for each call, because that
		; has lots of overhead (e.g. it can run out of XMS handles
		; very quickly). We allocate memory in 256 KiB blocks, and
		; keep track.
		;
		; !! TODO(pts): Grow from 256 KiB, try up to 4 MiB allocations.
		;
		;push '.'
		;mov eax, esp
		;push eax
		;call dos_printf
		;add esp, 8
.try_fit:	relocated_le.bss malloc_base, mov eax, [relval]
		relocated_le.bss malloc_rest, sub eax, [relval]
		relocated_le.bss malloc_rest, sub [relval], ebp
		jc .full  ; We actually waste the rest of the current block, but for WASM it's zero waste.
		relocated_le.bss malloc_capacity, add eax, [relval]
		;push eax
		;push '!'
		;mov eax, esp
		;push eax
		;call dos_printf
		;add esp, 8
		;pop eax
		jmp .return
.full:		; Try to allocate new block or extend the current block by at least 256 KiB.
		; It's possible to extend in Wine, but not with mwpestub.
		mov ecx, 0x100<<10  ; 256 KiB.
		cmp ecx, ebp
		jae .try_alloc
		mov ecx, ebp
		add ecx, 0xfff
		and ecx, ~0xfff  ; Round up to multiple of 4096 bytes (page size).
.try_alloc:	push ecx
		; Now try to allocate ECX bytes of high memory.
		mov ebx, ecx
		shr ebx, 16
		; Now try to allocate BX:CX bytes of high memory.
		mov ax, 501h  ; DPMI syscall allocate memory block.
		int 31h  ; DPMI syscall. Also changes ESI and EDI.
		;stc  ; Simulate failure of high memory allocation.
		jc .no_alloc
		; Now BX:CX is the linear address of the allocated block.
		shl ebx, 16
		mov bx, cx
		pop ecx
		relocated_le.bss malloc_base, mov [relval], ebx  ; Newly allocated address.
		relocated_le.bss malloc_rest, mov [relval], ecx
		relocated_le.bss malloc_capacity, mov [relval], ecx
		;push '#'
		;mov eax, esp
		;push eax
		;call dos_printf
		;add esp, 8
		jmp .try_fit  ; It will fit now.
.no_alloc:	pop ecx
		shr ecx, 1  ; Try to allocate half as much.
		;push '_'
		;mov eax, esp
		;push eax
		;call dos_printf
		;add esp, 8
		cmp ecx, ebp
		jb .oom_high  ; Not enough memory for new_amount bytes.  !! Also compare it with malloc_rest.
		cmp ecx, 0xfff
		ja .try_alloc  ; Enough memory to for new_amount bytes and also at least a single page.
.oom_high:	; Try to allocate conventional memory.
		;
		; Not using DPMI syscall 100h
		; (https://fd.lod.bz/rbil/interrup/dos_extenders/310100.html) here, because
		; that also allocates selectors.
		;jmp .oom  ; !!! This prevents the crash with --mem-mb=2.
		mov ah, 48h
		xor ebx, ebx
		dec bx  ; Try to allocate maximum available conventional memory.
		int 21h
		jnc .oom  ; This should fail, returning in BX the number of paragraphs (16-byte blocks) available.
		test ebx, ebx
		jz .oom
		push ebx
		mov ah, 48h
		int 21h  ; Allocate maximum number of paragraphs available.
		pop ebx
		jc .oom
		shl ebx, 4
		relocated_le.bss malloc_rest, mov [relval], ebx
		relocated_le.bss malloc_capacity, mov [relval], ebx
		; PMODE/W (but not WDOSX): EAX is selector. !! Try DPMI syscall 100h instead, maybe they are compatible. But that allocates a selector in DX, we should free it.
		xchg ebx, eax  ; EBX := selector; EAX := junk.
		push edx  ; Save. !! pushad.
		mov ax, 6
		int 31h  ; Get segment base of BX. CX:DX.
		shl ecx, 16
		mov cx, dx  ; ECX := linear address of PSP.
		pop edx  ; Restore.
		relocated_le.bss malloc_base, mov [relval], ecx
		;movzx eax, ax
		;shl eax, 4
		;relocated_le.bss malloc_base, mov [relval], eax
		jmp .try_fit  ; It may not fit though.
.oom:		xor eax, eax  ; NULL.
.return:	pop ebp
		pop edi
		pop esi
		pop ecx
		pop ebx
		ret

%undef  CONFIG_LOAD_FIND_CF_HEADER
%define CONFIG_LOAD_SINGLE_READ  ; For testing, comment it out and add `stc' where indicated to wcfd32load.inc.nasm.
%define CONFIG_LOAD_INT21H int 21h
%define CONFIG_LOAD_MALLOC_EAX call malloc
%undef  CONFIG_LOAD_MALLOC_EBX
%define CONFIG_LOAD_CLEAR_BSS
%define CONFIG_LOAD_RELOCATED_DD relocated_le.text.dd
%include "wcfd32load.inc.nasm"

wcfd32_far_syscall:  ; proc far
%ifdef DEBUG
		call debug_syscall
%endif
		cmp ah, INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE
		je strict short .handle_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE
		cmp ah, INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE
		je strict short .handle_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE
		cmp ah, INT21H_FUNC_48H_ALLOCATE_MEMORY
		jne .not_48h
		mov eax, ebx
		call malloc
		cmp eax, 1
		jnc .done  ; Success with CF=0.
		mov al, 8  ; DOS error: insufficient memory.
		jmp .done  ; Keep CF=1 for indicating error.
.not_48h:	int 21h  ; !! TODO(pts): Which PMODE/W DOS extended syscalls are also incorrect for the WCFD32 ABI?
.done:		retf
.handle_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE:  ; Based on OpenWatcom 1.0 bld/w32loadr/int21dos.asm
		push edx		; save filename address
		mov edx,ebx		; get DTA address
		mov ah, 1ah		; set DTA address
		int 21h			; ...
		pop edx			; restore filename address
		mov ah, 4eh		; find first
		int 21h			; ...
		jmp strict short .done
.handle_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE:  ; Based on OpenWatcom 1.0 bld/w32loadr/int21dos.asm
		cmp AL,0		; if not FIND NEXT
		jne strict short .done  ; then return
		push edx		; save EDX
		mov ah, 1ah		; set DTA address
		int 21h			; ...
		mov ah, 4fh		; find next
		int 21h			; ...
		pop edx			; restore EDX
		jmp strict short .done

%ifdef DEBUG
debug_syscall:	push eax
		mov al, ah
		shr al, 4
		add al, '0'
		cmp al, '9'
		jna .d1
		add al, 'A'-'0'-10
.d1:		call print_chr
		mov al, ah
		and al, 0xf
		add al, '0'
		cmp al, '9'
		jna .d2
		add al, 'A'-'0'-10
.d2:		call print_chr
		call print_crlf
		pop eax
		ret

message db '?$'  ; !!
done_message db '.', 13, 10, '$' ; !!
%endif

; Unfortunately the format LE 4 KiB of alignment between .code and .data, no
; way to make it smaller, but PMODE/W supports LE only. So we just put
; everything to .text to save a few KiB.
;
;section .le.data
;section .le.rodata

emit_load_errors

section .le.bss  ; align=4 specified above. Good.
malloc_base	resd 1  ; Address of the currently allocated block.
malloc_capacity	resd 1  ; Total number of bytes in the currently allocated block.
malloc_rest	resd 1  ; Number of bytes available at the end of the currently allocated block.
wcfd32_param_struct:  ; Contains 7 dd fields, see below.
  wcfd32_program_filename resd 1  ; dd empty_str  ; ""
  wcfd32_command_line resd 1  ; dd empty_str  ; ""
  wcfd32_env_strings resd 1  ; dd empty_env
  wcfd32_break_flag_ptr resd 1  ; !! Set.
  wcfd32_copyright resd 1
  wcfd32_is_japanese resd 1
  wcfd32_max_handle_for_os2 resd 1
