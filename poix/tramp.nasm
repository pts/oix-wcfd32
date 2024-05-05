; by pts@fazekas.hu at Sat May  4 01:33:56 CEST 2024

bits 32
cpu 386

; struct tramp_args {
;   void (*c_handler)(struct pushad_regs *r);  /* Will be saved to EDX. Must be a near call. */
;   char *program_entry;  /* Will be jumped to. */
;   char *stack_low;  /* Can be set to NULL to indicate that the stack low limit is unknown. */
;   unsigned operating_system;  /* Will be saved to AH. */
;   char *program_filename;  /* EDI will be set to its address (OIX param_struct). */
;   char *command_line;
;   char *env_strings;
;   unsigned *break_flag_ptr;
;   char *copyright;
;   unsigned is_japanese;
;   unsigned max_handle_for_os2;
; };
;
; All function pointers are 32-bit near (i.e. no segment part). But this trampoline can take both near and far calls:
;
; * tramp works when called as either near or far call.
; * tramp calls `program_entry' so that it works if program_entry expects a near or far call.
; * handle_far_syscall expects to be called as a far call. This is part of the OIX ABI, and can't be reliably autodetected.
; * handle_far_syscall calls c_handler is called as a near call. TODO(pts): Make it work as either.
;

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
		lea esi, [esp+0x24]  ; ESI := address of the struct tramp_args pointer, or return CS in a far call.
		call .me
.me:		pop ebp  ; For position-independent code with ebp-.me+
		lodsd
		test eax, eax
		jz strict short .skip  ; It was a near call, `ret' below will suffice.
		mov byte [ebp-.me+.ret], 0xcb  ; Replace ret with retf, to support return from far call.
.skip:		lodsd
		test eax, eax
		jz strict short .skip
.got_args:	xchg esi, eax ; ESI := address of c_handler; EAX := junk. Previously it was address of struct tramp_args
		lodsd  ; EAX := c_handler.
		lea edx, [ebp-.me+handle_far_syscall]
		mov [ebp-.me+handle_far_syscall.c_handler], eax  ; This needs read-write-execute memory.
		lodsd  ; EAX := program_entry.
		xchg edi, eax  ; EDI := EAX (program entry point); EAX := junk.
		lodsd  ; EAX := stack_low.
		xchg ecx, eax  ; ECX := EAX (stack low); EAX := junk.
		lodsd  ; EAX := operating_system.
		movzx eax, al  ; Make sure to use only the low byte.
		shl eax, 8  ; AH := operating_system.
		xchg edi, esi  ; EDI := ESI (OIX param_struct); ESI := EDI (program entry point).
		mov ebx, cs  ; Segment of handle_far_syscall.
		push byte 0  ; Sentinel in case the function does a retf (far return). OIX entry points do.
		push ebx  ; CS, assuming nonzero.
		sub ebp, ebp  ; Not needed by the ABI, just make it deterministic. Also initializes many flags in EFLAGS.
		call esi  ; Far or near call to the program entry point. Return value in EAX.
.pop_again:	pop ebx  ; Find sentinel.
		test ebx, ebx
		jnz .pop_again
		mov [esp+0x1c], eax  ; Overwrite the EAX saved by pushad.
		popad
.ret:		ret
