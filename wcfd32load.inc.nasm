LOAD_ERROR_SUCCESS       equ 0x0
LOAD_ERROR_OPEN_ERROR    equ 0x1
LOAD_ERROR_INVALID_EXE   equ 0x2
LOAD_ERROR_READ_ERROR    equ 0x3
LOAD_ERROR_OUT_OF_MEMORY equ 0x4

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
		jmp .return
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
		je .found_cf_header
%ifdef CONFIG_LOAD_TRY_CF_AT_HDRSIZE  ; Not needed for the WCFD32 .exe files we create.
		mov edi, esp
		xor eax, eax
		mov ax, word [esp+8]  ; mz_header.hdrsize.
		shl eax, 4  ; Convert paragraph count to byte count.
		add edi, eax
		cmp dword [edi], 4643h  ; "CF\0\0"
		je .found_cf_header
%endif
.invalid:	mov eax, -LOAD_ERROR_INVALID_EXE  ; error_code
		jmp .close_return
.found_cf_header:  ; The CF header (18h bytes) is now at EDI, and it will remain so.
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
		jnz .malloc_ok
.oom:		mov eax, -LOAD_ERROR_OUT_OF_MEMORY  ; error_code
		jmp .close_return
.malloc_ok:
		mov esi, eax  ; ESI := image_base.
		; Read the entire image in one big chunk.
		mov edx, esi  ; EDX := image_base.
		mov ecx, [edi+8]    ; r_ecx
		mov ah, INT21H_FUNC_3FH_READ_FROM_FILE  ; r_eax
		CONFIG_LOAD_INT21H
%ifdef CONFIG_LOAD_SINGLE_READ
		jc .read_error
		cmp eax, ecx
		je .image_read_ok
.read_error:	mov eax, -LOAD_ERROR_READ_ERROR  ; error_code
		jmp .close_return
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
		jmp .close_return
.read_ok:	pop ecx
		add ebp, 8000h
		sub ecx, eax
		jmp .loc_4103D4
%endif
.image_read_ok:
%ifdef CONFIG_LOAD_CLEAR_BSS
		push ecx
		push edi
		push eax
		mov ecx, [edi+0x10]  ; mem_size.
		mov edi, [edi+8]  ; load_size.
		sub ecx, edi
		add edi, esi  ; image_base.
		xor eax, eax
		push ecx
		shr ecx, 2
		rep stosd
		pop ecx
		and ecx, 3
		rep stosb
		pop eax
		pop edi
		pop ecx
%endif
		mov edx, [edi+0Ch]  ; cf_header.reloc_rva.
		push ebx  ; Save DOS filehandle.
		xchg esi, edx
.apply_relocations:
		; Apply relocations.
		; Input: EDX: image_base; ESI: reloc_rva.
		; Spoils: EAX, EBX, ECX, ESI.
		add esi, edx  ; ESI := image_base + cf_header.reloc_rva (old EDX).
		jmp strict short .next_block
.next_reloc:	lodsw
		add ebx, eax
.first_reloc:	add [ebx], edx
		loop .next_reloc
.next_block:	lodsw
		movzx ecx, ax
		jecxz .rdone
		lodsd
		xchg ebx, eax  ; EBX := EAX; EAX := junk.
		ror ebx, 16
		add ebx, edx
		xor eax, eax
		jmp strict short .first_reloc
.rdone:		; Return image_base in EDX.
		mov eax, [edi+14h]  ; cf_header.entry_rva.
		add eax, edx
		; Now: EAX: entry point address. It will be returned.
.close_return:
		pop ebx  ; Restore DOS filehandle.
		push eax  ; Save return value.
		mov ah, INT21H_FUNC_3EH_CLOSE_FILE  ; r_eax
		CONFIG_LOAD_INT21H
		pop eax  ; Restore return value.
		add esp, 200h
.return:
		pop ebp
		pop edi
		pop esi
		pop ecx
		pop ebx
		ret

%macro emit_load_errors 0
aCanTOpenSRcD	db 'Can',27h,'t open ',27h,'%s',27h,'; rc=%d',0Dh,0Ah,0
.end:
aInvalidExe	db 'Invalid EXE',0Dh,0Ah,0
aLoaderReadError db 'Loader read error',0Dh,0Ah,0
aMemoryAllocation db 'Memory allocation failed',0Dh,0Ah,0

; Corresponding to LOAD_ERROR_SUCCESS .. LOAD_ERROR_OUT_OF_MEMORY.
load_errors:	dd aCanTOpenSRcD.end-1  ; empty_str  ; ""
		dd aCanTOpenSRcD  ; "Can't open '%s'; rc=%d\r\n"
		dd aInvalidExe	; "Invalid EXE\r\n"
		dd aLoaderReadError  ; "Loader read error\r\n"
		dd aMemoryAllocation  ; "Memory allocation failed\r\n"
%endm
