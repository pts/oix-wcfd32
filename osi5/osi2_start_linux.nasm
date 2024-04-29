; by pts@fazekas.hu at Sun Apr 28 02:07:17 CEST 2024
;
; !! Make the number of files (-mfiles=...) in libci.a:stdio_medium_flobal_files.o configurable.

bits 32
cpu 386

section .text align=1
section .rodata align=1
section .data align=1
section .bss align=4

;global _start
;_start:		mov eax, 1
;		mov ebx, 5
;		int 0x80

global _start
global mini__exit
global mini_environ
;global mini_syscall3_AL
;global mini_syscall3_RP1
;global mini___M_jmp_pop_ebx_syscall_return
;global mini___M_jmp_syscall_return
global mini_exit
global mini_open
global mini_close
global mini_read
global mini_write
global mini_lseek
global mini_isatty
global mini_remove
global mini_unlink
global mini_time
global mini_malloc_simple_unaligned
global mini_strerror

extern main

%macro define_weak 1
  extern %1
%endmacro
define_weak mini___M_start_isatty_stdin
define_weak mini___M_start_isatty_stdout
define_weak mini___M_start_flush_stdout
define_weak mini___M_start_flush_opened

section .text

_start:
;mini__start:  ; Entry point (_start) of the Linux i386 executable.
		; Now the stack looks like (from top to bottom):
		;   dword [esp]: argc
		;   dword [esp+4]: argv[0] pointer
		;   esp+8...: argv[1..] pointers
		;   NULL that ends argv[]
		;   environment pointers
		;   NULL that ends envp[]
		;   ELF Auxiliary Table
		;   argv strings
		;   environment strings
		;   program name
		;   NULL		
		pop eax  ; argc.
		mov edx, esp  ; argv.
		lea ecx, [edx+eax*4+4]  ; envp.
		mov [mini_environ], ecx
		push ecx  ; Argument envp for main.
		push edx  ; Argument argv for main.
		push eax  ; Argument argc for main.
		call mini___M_start_isatty_stdin  ; Smart linking (smart.nasm) may omits this call.
		call mini___M_start_isatty_stdout  ; Smart linking (smart.nasm) may omits this call.
		call main  ; Return value (exit code) in EAX (AL).
		push eax  ; Save exit code, for mini__exit.
		push eax  ; Fake return address, for mini__exit.
		; Fall through to mini_exit(...).
mini_exit:  ; void mini_exit(int exit_code);
		call mini___M_start_flush_stdout  ; Smart linking (smart.nasm) may omits this call.
		call mini___M_start_flush_opened  ; Smart linking (smart.nasm) may omits this call.
		; Fall through to mini__exit(...).
mini__exit:  ; void mini__exit(int exit_code);
_exit:
		mov al, 1  ; __NR_exit.
		; Fall through to syscall3.
syscall3:
mini_syscall3_AL:  ; Useful from assembly language.
; Calls syscall(number, arg1, arg2, arg3).
;
; It takes the syscall number from AL (8 bits only!), arg1 (optional) from
; [esp+4], arg2 (optional) from [esp+8], arg3 (optional) from [esp+0xc]. It
; keeps these args on the stack.
;
; It can EAX, EDX and ECX as scratch.
;
; It returns result (or -1 as error) in EAX.
		movzx eax, al  ; number.
mini_syscall3_RP1:  ; long mini_syscall3_RP1(long nr, long arg1, long arg2, long arg3) __attribute__((__regparm__(1)));
		push ebx  ; Save it, it's not a scratch register.
		mov ebx, [esp+8]  ; arg1.
		mov ecx, [esp+0xc]  ; arg2.
		mov edx, [esp+0x10]  ; arg3.
		int 0x80  ; Linux i386 syscall.
mini___M_jmp_pop_ebx_syscall_return:
		pop ebx
mini___M_jmp_syscall_return:
		; test eax, eax
		; jns .final_result
		cmp eax, -0x100  ; Treat very large (e.g. <-0x100; with Linux 5.4.0, 0x85 seems to be the smallest) non-negative return values as success rather than errno. This is needed by time(2) when it returns a negative timestamp. uClibc has -0x1000 here.
		jna .final_result
		neg eax
		mov dword [mini_errno], eax
		or eax, byte -1  ; EAX := -1 (error).
.final_result:
WEAK..mini___M_start_isatty_stdin:   ; Fallback, tools/elfofix will convert it to a weak symbol.
WEAK..mini___M_start_isatty_stdout:  ; Fallback, tools/elfofix will convert it to a weak symbol.
WEAK..mini___M_start_flush_stdout:   ; Fallback, tools/elfofix will convert it to a weak symbol.
WEAK..mini___M_start_flush_opened:   ; Fallback, tools/elfofix will convert it to a weak symbol.
		ret

section .bss
mini_environ:	resd 1  ; char **mini_environ;
global mini_errno
mini_errno:	resd 1  ; int mini_errno;
section .text

; TODO(pts): Use smart linking to get rid of the unnecessary syscalls. Move everything from here, keep them in smart.nasm only.
mini_read:	mov al, 3  ; __NR_read.
		jmp strict short syscall3
mini_write:	mov al, 4  ; __NR_write.
		jmp strict short syscall3
mini_open:	mov al, 5  ; __NR_open.
		jmp strict short syscall3
mini_close:	mov al, 6  ; __NR_close.
		jmp strict short syscall3
mini_lseek:	mov al, 19  ; __NR_lseek.
		jmp strict short syscall3
mini_remove:
mini_unlink:	mov al, 10  ; __NR_unlink.
		jmp strict short syscall3
mini_time:	mov al, 13  ; __NR_time.
		jmp strict short syscall3

mini_isatty:  ; int __cdecl mini_isatty(int fd);
		sub esp, strict byte 0x24
		push esp  ; 3rd argument of ioctl TCGETS.
		push strict dword 0x5401  ; TCGETS.
		push dword [esp+0x24+4+2*4]  ; fd argument of ioctl.
		mov al, 54  ; __NR_ioctl.
		call syscall3
		add esp, strict byte 0x24+3*4  ; Clean up everything pushed.
		; Now convert result EAX: 0 to 1, everything else to 0.
		cmp eax, byte 1
		sbb eax, eax
		neg eax
		ret

mini_strerror:  ; char * __cdecl mini_strerror(int errnum);
		mov eax, msg_fake_error
		ret

section .rodata
msg_fake_error:	db 'Error', 0
section .text

mini_malloc_simple_unaligned:  ; void * __cdecl mini_malloc_simple_unaligned(size_t size);
; Implemented using sys_brk(2). Equivalent to the following C code, but was
; size-optimized.
;
; A simplistic allocator which creates a heap of 64 KiB first, and then
; doubles it when necessary. It is implemented using Linux system call
; brk(2), exported by the libc as sys_brk(...). free(...)ing is not
; supported. Returns an unaligned address (which is OK on x86).
;
; void *mini_malloc_simple_unaligned(size_t size) {
;     static char *base, *free, *end;
;     ssize_t new_heap_size;
;     if ((ssize_t)size <= 0) return NULL;  /* Fail if size is too large (or 0). */
;     if (!base) {
;         if (!(base = free = (char*)sys_brk(NULL))) return NULL;  /* Error getting the initial data segment size for the very first time. */
;         new_heap_size = 64 << 10;  /* 64 KiB. */
;         goto grow_heap;  /* TODO(pts): Reset base to NULL if we overflow below. */
;     }
;     while (size > (size_t)(end - free)) {  /* Double the heap size until there is `size' bytes free. */
;         new_heap_size = (end - base) >= (1 << 20) ? (end - base) + (1 << 20) : (end - base) << 1;  /* Double it until 1 MiB. */
;       grow_heap:
;         if ((ssize_t)new_heap_size <= 0 || (size_t)base + new_heap_size < (size_t)base) return NULL;  /* Heap would be too large. */
;         if ((char*)sys_brk(base + new_heap_size) != base + new_heap_size) return NULL;  /* Out of memory. */
;         end = base + new_heap_size;
;     }
;     free += size;
;     return free - size;
; }
		push ebx
		mov eax, [esp+8]  ; Argument named size.
		test eax, eax
		jle .18
		mov ebx, eax
		cmp dword [_malloc_simple_base], byte 0
		jne .7
		xor eax, eax
		push eax ; Argument of sys_brk(2).
		mov al, 45  ; __NR_brk.
		; TODO(pts): Add sys_brk symbol with smart linking.
		call mini_syscall3_AL  ; It destroys ECX and EDX.
		pop ecx  ; Clean up argument of sys_brk2(0).
		mov [_malloc_simple_free], eax
		mov [_malloc_simple_base], eax
		test eax, eax
		jz short .18
		mov eax, 0x10000	; 64 KiB minimum allocation.
.9:		add eax, [_malloc_simple_base]
		jc .18
		push eax
		push eax ; Argument of sys_brk(2).
		mov al, 45  ; __NR_brk.
		; TODO(pts): Add sys_brk symbol with smart linking.
		call mini_syscall3_AL	; It destroys ECX and EDX.
		pop ecx  ; Clean up argument of sys_brk(2).
		pop edx			; This (and the next line) could be ECX instead.
		cmp eax, edx
		jne .18
		mov [_malloc_simple_end], eax
.7:		mov edx, [_malloc_simple_end]
		mov eax, [_malloc_simple_free]
		mov ecx, edx
		sub ecx, eax
		cmp ecx, ebx
		jb .21
		add ebx, eax
		mov [_malloc_simple_free], ebx
		jmp short .17
.21:		sub edx, [_malloc_simple_base]
		mov eax, 1<<20  ; 1 MiB.
		cmp edx, eax
		jnbe .22
		mov eax, edx
.22:		add eax, edx
		test eax, eax  ; ZF=..., SF=..., OF=0.
		jg .9  ; Jump iff ZF=0 and SF=OF=0. Why is this correct?
.18:		xor eax, eax
.17:		pop ebx
		ret

section .bss
_malloc_simple_base	resd 1  ; char *base;
_malloc_simple_free	resd 1  ; char *free;
_malloc_simple_end	resd 1  ; char *end;
section .text
