; by pts@fazekas.hu at Sat May  4 01:33:56 CEST 2024

bits 32
cpu 386

; struct tramp_args {
;   void (*c_handler)(struct pushad_regs *r);  /* Will be saved to EDX. Must be a near call. */
;   char *entry;  /* Will be jumped to. */
;   unsigned operating_system;  /* Will be saved to AH. */
;   char *program_filename;  /* EDI will be set to its address (OIX param_struct). */
;   char *command_line;
;   char *env_strings;
;   unsigned *break_flag_ptr;
;   char *copyright;
;   unsigned is_japanese;
;   unsigned max_handle_for_os2;
; };

tramp:  ; Only works as a near call.
		jmp strict short tramp2

handle_far_syscall:  ; We assume far call (`retf'), we can't autodetect without active cooperation (stack pushing) from the program.
		pushfd
		pushad
		mov eax, esp  ; EAX := (address of struct pushad_regs).
		push eax  ; For the cdecl calling convention.
		mov ebx, eax  ; Make it work with any calling convention by making EAX, EBX, ECX and EDX the same. https://en.wikipedia.org/wiki/X86_calling_conventions
		mov ecx, eax
		mov edx, eax
		db 0xbe  ; mov esi, ...
.c_handler:	dd 0  ; Will be populated by tramp.
		call esi
		pop eax  ; Clean up the argument of c_handler from the stack.
		popad
		popfd
		retf

tramp2:  ; Only works as a near call.
		pushad
		mov esi, [esp+0x24]  ; ESI := address of the struct tramp_args.
		lodsd  ; EAX := c_handler.
		call .me
.me:		pop ebp  ; For position-independent code with ebp-.me+
		lea edx, [ebp-.me+handle_far_syscall]
		mov [ebp-.me+handle_far_syscall.c_handler], eax  ; This needs read-write-execute memory.
		lodsd  ; EAX := program_entry.
		xchg edi, eax  ; EDI := EAX (program entry point); EAX := junk.
		lodsd  ; EAX := operating_system.
		shl eax, 8  ; AH := operating_system.
		xchg edi, esi  ; EDI := ESI (OIX param_struct), ESI := EDI (program entry point).
		mov ebx, cs  ; Segment of handle_far_syscall.
		push byte 0  ; Sentinel in case the function does a retf (far return). OIX entry points do.
		push ebx  ; CS, assuming nonzero.
		xor ebp, ebp  ; Not needed by the ABI, just make it deterministic.
		sub ecx, ecx  ; Stack limit, which we always set to 0.
		call esi  ; Far or near call to the program entry point. Return value in EAX.
.pop_again:	pop ebx  ; Find sentinel.
		test ebx, ebx
		jnz .pop_again
		mov [esp+0x1c], eax  ; Overwrite the EAX saved by pushad.
		popad
		ret  ; TODO(pts): Autodetect retf (and far call to c_handler). We already support multiple calling conventions.
