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
; !! Do we need to pass a space in front of command-line arguments?
; !! TODO(pts): Implement Ctrl-<C> and Ctrl-<Break>.
; !! TODO(pts): Set up some exception handlers such as division by zero.
;

bits 32
cpu 386

%define .text _TEXT
%define .rodatastr CONST  ; Unused.
%define .rodata CONST2
%define .data _DATA
%define .bss _BSS
;%define .stack _STACK

section _TEXT  USE32 class=CODE align=1
section CONST  USE32 class=DATA align=1  ; OpenWatcom generates align=4.
section CONST2 USE32 class=DATA align=4
section _DATA  USE32 class=DATA align=4
section _BSS   USE32 class=BSS NOBITS align=4  ; NOBITS is ignored by NASM, but class=BSS works.
section STACK  USE32 class=STACK NOBITS align=1  ; Pacify WLINK: Warning! W1014: stack segment not found
group DGROUP CONST CONST2 _DATA _BSS

INT21H_FUNC_06H_DIRECT_CONSOLE_IO equ 0x6
INT21H_FUNC_08H_WAIT_FOR_CONSOLE_INPUT equ 0x8
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

LOAD_ERROR_SUCCESS       equ 0x0
LOAD_ERROR_OPEN_ERROR    equ 0x1
LOAD_ERROR_INVALID_EXE   equ 0x2
LOAD_ERROR_READ_ERROR    equ 0x3
LOAD_ERROR_OUT_OF_MEMORY equ 0x4

WCFD32_OS_DOS equ 1
WCFD32_OS_WIN32 equ 2

NULL equ 0

%define CONFIG_LOAD_SINGLE_READ
%define CONFIG_LOAD_INT21H int 21h
%define CONFIG_LOAD_MALLOC_EAX call malloc
%undef  CONFIG_LOAD_MALLOC_EBX

section .text

global _start
_start:
..start:
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
		mov eax, [english_errors+4*eax]
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
		; Input: dword [wcfd32_param_struct+0xc]: 0 (unknown parameter)
		; Input: dword [wcfd32_param_struct+0x10]: 0 (unknown parameter)
		; Input: dword [wcfd32_param_struct+0x14]: 0 (unknown parameter)
		; Input: dword [wcfd32_param_struct+0x18]: 0 (unknown parameter)
		; Call: far call.
		; Output: EAX: exit code (0 for EXIT_SUCCESS).
		mov [wcfd32_program_filename], edi
		mov [wcfd32_command_line], ebp
		mov [wcfd32_env_strings], ecx
		sub ecx, ecx  ; This is an unknown parameter, which we always set to 0.
		mov edx, wcfd32_far_syscall
		mov edi, wcfd32_param_struct
		mov bx, cs  ; Segment of wcfd32_far_syscall for the far call.
		xchg eax, esi  ; ESI := (entry point address); EAX := junk.
		mov ah, WCFD32_OS_DOS
		push cs  ; For the `retf' of the far call.
		call esi
		; !!! Real assembly work crashes with: Exit to error: JMP Illegal descriptor type 10.
.exit:		mov ah, 4ch  ; Exit with exit code in AL.
		int 21h  ; This is the only way to exit these don't work: `ret', `retf', `iret', `int 20h'.
		; Not reached.

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

print_chr:  ; !! Prints single byte in AL to stdout.
		push eax
		push edx
		mov ah, 2
		mov dl, al
		int 21h  ; DOS extended syscall.
		pop edx
		pop eax
		ret

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
.try_fit:	mov eax, [malloc_base]
		sub eax, [malloc_rest]
		sub [malloc_rest], ebp
		jc .full  ; We actually waste the rest of the current block, but for WASM it's zero waste.
		add eax, [malloc_capacity]
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
		mov [malloc_base], ebx  ; Newly allocated address.
		mov [malloc_rest], ecx
		mov [malloc_capacity], ecx
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
		mov [malloc_rest], ebx
		mov [malloc_capacity], ebx
		; PMODE/W (but not WDOSX): EAX is selector. !! Try DPMI syscall 100h instead, maybe they are compatible. But that allocates a selector in DX, we should free it.
		xchg ebx, eax  ; EBX := selector; EAX := junk.
		push edx  ; Save. !! pushad.
		mov ax, 6
		int 31h  ; Get segment base of BX. CX:DX.
		shl ecx, 16
		mov cx, dx  ; ECX := linear address of PSP.
		pop edx  ; Restore.
		mov [malloc_base], ecx
		;movzx eax, ax
		;shl eax, 4
		;mov [malloc_base], eax
		jmp .try_fit  ; It may not fit though.
.oom:		xor eax, eax  ; NULL.
.return:	pop ebp
		pop edi
		pop esi
		pop ecx
		pop ebx
		ret

; load_error_t __usercall load_wcfd32_program_image@<eax>(const char *filename@<eax>)
; Returns:
; * EAX: On success, entry point address. On error, -LOAD_ERROR_*. Success iff (unsigned)EAX < (unsigned)-10.
; * EDX: On success, image_base (memory address). On error, file open error code.
load_wcfd32_program_image:
		push ebx
		push ecx
		push esi
		push edi
		push ebp
		xchg edx, eax  ; EDX := EAX; EAX := junk.
		xor eax, eax
		mov ah, INT21H_FUNC_3DH_OPEN_FILE  ; r_eax
		CONFIG_LOAD_INT21H
		jnc .open_ok
		mov edx, eax
		mov eax, -LOAD_ERROR_OPEN_ERROR
		jmp return
.open_ok:	sub esp, 200h  ;  ESP[0 : 200h]: buffer for reading the CF header.
		movzx ebx, ax
		mov ecx, 200h	    ; r_ecx
		xor eax, eax
		mov edx, esp	    ; r_edx
		mov ah, INT21H_FUNC_3FH_READ_FROM_FILE  ; r_eax
		CONFIG_LOAD_INT21H
		jc .invalid
		lea edi, [esp+20h]
		cmp dword [edi], 4643h  ; "CF\0\0"
		je found_cf_header
%if 0  ; Not needed for the WCFD32 .exe files we create.
		mov edi, esp
		xor eax, eax
		mov ax, word [esp+8]  ; mz_header.hdrsize.
		shl eax, 4  ; Convert paragraph count to byte count.
		add edi, eax
		cmp dword [edi], 4643h  ; "CF\0\0"
		je found_cf_header
%endif
.invalid:	mov eax, -LOAD_ERROR_INVALID_EXE  ; error_code
		jmp close_return
found_cf_header:  ; The CF header (18h bytes) is now at EDI, and it will remain so.
		xor al, al	    ;  ; SEEK_SET.
		mov edx, [edi+4]    ; r_edx
		mov ah, INT21H_FUNC_42H_SEEK_IN_FILE  ; r_eax
		mov ecx, edx
		shr ecx, 10h	    ; r_ecx
		CONFIG_LOAD_INT21H
		jc .read_error
		shl edx, 10h
		mov dx, ax	    ; r_edx
		push ebx  ; Save DOS filehandle.
		mov ebx, [edi+10h]  ; Allocate this many bytes.
%ifdef CONFIG_LOAD_MALLOC_EBX
		CONFIG_LOAD_MALLOC_EBX
%else
  %ifdef CONFIG_LOAD_MALLOC_EAX
		xchg eax, ebx  ; EAX := EBX: EBX := junk.
		CONFIG_LOAD_MALLOC_EAX
  %else
		mov ah, INT21H_FUNC_48H_ALLOCATE_MEMORY
		CONFIG_LOAD_INT21H
  %endif
%endif
		pop ebx  ; Restore DOS filehandle.
		jc .oom
		test eax, eax
		jnz .loc_410362
.oom:		mov eax, -LOAD_ERROR_OUT_OF_MEMORY  ; error_code
		jmp close_return
.loc_410362:
		mov esi, eax  ; Save image_base.
		; Read the entire image in one big chunk.
		mov edx, esi	    ; r_edx
		mov ecx, [edi+8]    ; r_ecx
		mov ah, INT21H_FUNC_3FH_READ_FROM_FILE  ; r_eax
		CONFIG_LOAD_INT21H
%ifdef CONFIG_LOAD_SINGLE_READ
		jc .read_error
		cmp eax, ecx
		je .image_read_ok
.read_error:	mov eax, -LOAD_ERROR_READ_ERROR  ; error_code
		jmp close_return
%else
		jc .read_error1
		cmp eax, ecx
		je .image_read_ok
.read_error1:
		; If reading the image in one big chunk has failed, read it in 8000h (32 KiB) increments.
		mov edx, [edi+4]    ; r_edx
		mov ah, INT21H_FUNC_42H_SEEK_IN_FILE  ; r_eax
		mov al, 0  ; SEEK_SET.
		mov ecx, edx
		shr ecx, 10h	    ; r_ecx
		CONFIG_LOAD_INT21H
		jc .read_error
		shl edx, 10h
		mov dx, ax
		mov ecx, [edi+8]  ; Number of bytes to read in total.
		mov ebp, esi  ; Start reading to image_base.
.loc_4103D4:
		test ecx, ecx
		jz .image_read_ok  ; No more bytes to read.
		push ecx
		cmp ecx, 8000h
		jbe .loc_4103E7
		mov ecx, 8000h	    ; r_ecx
.loc_4103E7:
		mov edx, ebp	    ; r_edx
		mov ah, INT21H_FUNC_3FH_READ_FROM_FILE  ; r_eax
		CONFIG_LOAD_INT21H
		jc .read_error2
		cmp eax, ecx
		je .read_ok
.read_error2:	pop ecx
.read_error:	mov eax, -LOAD_ERROR_READ_ERROR  ; error_code
		jmp close_return
.read_ok:	pop ecx
		add ebp, 8000h
		sub ecx, eax
		jmp .loc_4103D4
%endif
.image_read_ok:
		mov edx, [edi+0Ch]
.apply_relocations:
		push ebx  ; Save DOS filehandle.
		; Apply relocations.
		; Input: ESI: image_base; EDX: reloc_rva.
		; Spoils: EAX, EBX, ECX, EDX.
		add edx, esi
.next_block:	movzx ebx, word [edx]
		inc edx
		inc edx
		test ebx, ebx
		jz strict short .rdone
		movzx eax, word [edx]
		inc edx
		inc edx
		shl eax, 0x10
		movzx ecx, word [edx]
		or eax, ecx
		inc edx
		inc edx
		add eax, esi
.next_reloc:	add [eax], esi
		dec ebx
		jz strict short .next_block
		movzx ecx, word [edx]
		inc edx
		inc edx
		add eax, ecx
		jmp strict short .next_reloc
.rdone:		;
		mov edx, esi  ; Return image_base in EDX.
		mov eax, [edi+14h]
		add eax, esi
		; Now: EAX: entry point address. It will be returned.
close_return:
		pop ebx  ; Restore DOS filehandle.
		push eax  ; Save return value.
		mov ah, INT21H_FUNC_3EH_CLOSE_FILE  ; r_eax
		CONFIG_LOAD_INT21H
		pop eax  ; Restore return value.
		add esp, 200h
return:
		pop ebp
		pop edi
		pop esi
		pop ecx
		pop ebx
		ret

wcfd32_near_syscall:
		push cs
		; Fall through to wcfd32_far_syscall.

wcfd32_far_syscall:  ; proc far
		;call debug_syscall  ; !!
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

;section .data  ; !! TODO(pts): Remove this to avoid 0x1000 bytes of LE alignment.
;section .rodata

message db '?$'  ; !!
done_message db '.', 13, 10, '$' ; !!

aCanTOpenSRcD	db 'Can',27h,'t open ',27h,'%s',27h,'; rc=%d',0Dh,0Ah,0
aInvalidExe	db 'Invalid EXE',0Dh,0Ah,0
aLoaderReadError db 'Loader read error',0Dh,0Ah,0
aMemoryAllocation db 'Memory allocation failed',0Dh,0Ah,0

; !! Unify these with some.
empty_env	db 0  ; Continues in empty_str.
empty_str	db 0

english_errors	dd empty_str  ; ""  ; Corresponding to LOAD_ERROR_SUCCESS .. LOAD_ERROR_OUT_OF_MEMORY.
		dd aCanTOpenSRcD  ; "Can't open '%s'; rc=%d\r\n"
		dd aInvalidExe	; "Invalid EXE\r\n"
		dd aLoaderReadError  ; "Loader read error\r\n"
		dd aMemoryAllocation  ; "Memory allocation failed\r\n"

;section .data


;.data?  ; section .bss
;db (62 shl 10) dup (?)  ; DOS/32A: Making this 62 KiB will still keep it `BC', but 63 KiB won't.

section .bss

malloc_base	resd 1  ; Address of the currently allocated block.
malloc_capacity	resd 1  ; Total number of bytes in the currently allocated block.
malloc_rest	resd 1  ; Number of bytes available at the end of the currently allocated block.
wcfd32_param_struct:  ; Contains 7 dd fields, see below.
  wcfd32_program_filename resd 1  ; dd empty_str  ; ""
  wcfd32_command_line resd 1  ; dd empty_str  ; ""
  wcfd32_env_strings resd 1  ; dd empty_env
  wcfd32_unknown_param3 resd 1
  wcfd32_unknown_param4 resd 1
  wcfd32_unknown_param5 resd 1
  wcfd32_unknown_param6 resd 1
