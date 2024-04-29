#ifndef ___OSI___H_INCLUDED
#  include <__osi__.h>
#endif

#ifndef __WATCOMC__
#  error Only Watcom C compiler is supported.
#endif
#ifndef __386__
#  error i386 CPU target is required.
#endif
#ifndef __OSI__  /* Just specify: owcc -D__OSI__ */
#  error Watcom OS-independent target is required.
#endif

void (__far *_INT21ADDR)(void);
void *_STACKTOP;
unsigned *_BreakFlagPtr;
char __OS;
char **_EnvPtr;
char **environ;
char *_LpPgmName;

extern char _edata[], _end[];  /* Populated by WLINK. */

int _argc;  /* Autogenerted by __WATCOMC__ as a dependency of main(...). TODO(pts): Make it an alias. */
extern int __watcall main(int argc, char **argv);

/* Reverses the elements in a NULL-terminated array of (void*)s. */
static __declspec(naked) void __watcall reverse_ptrs(void **p) { (void)p; __asm {
		push ecx
		push edx
		lea edx, [eax-4]
  Lnext1:	add edx, 4
		cmp dword ptr [edx], 0
		jne short Lnext1
		cmp edx, eax
		je short Lnothing
		sub edx, 4
		jmp short Lcmp2
  Lnext2:	mov ecx, [eax]
		xchg ecx, [edx]
		mov [eax], ecx
		add eax, 4
		sub edx, 4
  Lcmp2:	cmp eax, edx
		jb short Lnext2
  Lnothing:	pop edx
		pop ecx
  Lret:		ret
} }

/* Parses the first argument of the Windows command-line (specified in EAX)
 * in place. Returns (in EAX) the pointer to the rest of the command-line.
 * The parsed argument will be available as NUL-terminated string at the
 * same location as the input.
 *
 * Similar to CommandLineToArgvW(...) in SHELL32.DLL, but doesn't aim for
 * 100% accuracy, especially that it doesn't support non-ASCII characters
 * beyond ANSI well, and that other implementations are also buggy (in
 * different ways).
 *
 * It treats only space and tab and a few others as whitespece. (The Wine
 * version of CommandLineToArgvA.c treats only space and tab as whitespace).
 *
 * This is based on the incorrect and incomplete description in:
 *  https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw
 *
 * See https://nullprogram.com/blog/2022/02/18/ for a more detailed writeup
 * and a better installation.
 *
 * https://github.com/futurist/CommandLineToArgvA/blob/master/CommandLineToArgvA.c
 * has the 3*n rule, which Wine 1.6.2 doesn't seem to have. It also has special
 * parsing rules for argv[0] (the program name).
 *
 * There is the CommandLineToArgvW function in SHELL32.DLL available since
 * Windows NT 3.5 (not in Windows NT 3.1). For alternative implementations,
 * see:
 *
 * * https://github.com/futurist/CommandLineToArgvA
 *   (including a copy from Wine sources).
 * * http://alter.org.ua/en/docs/win/args/
 * * http://alter.org.ua/en/docs/win/args_port/
 */
#if 0  /* Long reference implementation. */
static char * __watcall parse_first_arg(char *pw) {
  const char *p;
  const char *q;
  char c;
  char is_quote = 0;
  for (p = pw; c = *p, c == ' ' || c == '\t' || c == '\n' || c == '\v'; ++p) {}
  if (*p == '\0') { *pw = '\0'; return pw; }
  for (;;) {
    if ((c = *p) == '\0') goto after_arg;
    ++p;       
    if (c == '\\') {
      for (q = p; c = *q, c == '\\'; ++q) {}
      if (c == '"') {
        for (; p < q; p += 2) {
          *pw++ = '\\';
        }
        if (p != q) {
          is_quote ^= 1;
        } else {
          *pw++ = '"';
          ++p;  /* Skip over the '"'. */
        }
      } else {
        *pw++ = '\\';
        for (; p != q; ++p) {
          *pw++ = '\\';
        }
      }
    } else if (c == '"') {
      is_quote ^= 1;
    } else if (!is_quote && (c == ' ' || c == '\t' || c == '\n' || c == '\v')) {
      if (p == pw) ++p;  /* Don't clobber the rest with '\0' below. */
     after_arg:
      *pw = '\0';
      return (char*)p;
    } else {
      *pw++ = c;  /* Overwrite in-place. */
    }
  }
}
#else  /* Short assembly implementation. */
__declspec(naked) char * __watcall parse_first_arg(char *pw) { (void)pw; __asm {
		push ebx
		push ecx
		push edx
		push esi
		xor bh, bh  /* is_quote. */
		mov edx, eax
  L1:		mov bl, [edx]
		cmp bl, ' '
		je short L2  /* The inline assembler is not smart enough with forward references, we need these shorts. */
		cmp bl, 0x9
		jb short L3
		cmp bl, 0xb
		ja short L3
  L2:		inc edx
		jmp short L1
  L3:		test bl, bl
		jne short L8
		mov [eax], bl
		jmp short Lret
  L4:		cmp bl, '"'
		jne short L11
  L5:		lea esi, [eax+0x1]
		cmp edx, ecx
		jae short L6
		mov byte ptr [eax], 0x5c  /* "\\" */
		mov eax, esi
		inc edx
		inc edx
		jmp short L5
  L6:		je short L10
  L7:		xor bh, 0x1
  L8:		mov bl, [edx]
		test bl, bl
		je short L16
		inc edx
		cmp bl, 0x5c  /* "\\" */
		jne short L13
		mov ecx, edx
  L9:		mov bl, [ecx]
		cmp bl, 0x5c  /* "\\" */
		jne short L4
		inc ecx
		jmp short L9
  L10:		mov byte ptr [eax], '"'
		mov eax, esi
		lea edx, [ecx+0x1]
		jmp short L8
  L11:		mov byte ptr [eax], 0x5c  /* "\\" */
		inc eax
  L12:		cmp edx, ecx
		je short L8
		mov byte ptr [eax], 0x5c  /* "\\" */
		inc eax
		inc edx
		jmp short L12
  L13:		cmp bl, '"'
		je short L7
		test bh, bh
		jne short L15
		cmp bl, ' '
		je short L14
		cmp bl, 0x9
		jb short L15
		cmp bl, 0xb
		jna short L14
  L15:		mov [eax], bl
		inc eax
		jmp short L8
  L14:		dec edx
		cmp eax, edx
		jne L16
		inc edx
  L16:		mov byte ptr [eax], 0x0
		xchg eax, edx  /* EAX := EDX: EDX := junk. */
  Lret:		pop esi
		pop edx
		pop ecx
		pop ebx
		ret
} }
#endif

/* __OSI__ program entry point. */
__declspec(naked) void __watcall __far _cstart(void) { __asm {
		/* Zero-initialize BSS. !! TODO(pts): The WCFD32 loader has done it. */
		push edx
		push edi
		push eax
		mov ecx, offset _end	/* end of _BSS segment (start of free) */ 
		mov edi, offset _edata	/* start of _BSS segment */
		sub ecx, edi		/* calc # of bytes in _BSS segment */
		xor eax, eax		/* zero the _BSS segment */
		mov dl, cl		/* copy the lower bits of size */
		shr ecx, 2		/* get number of dwords */
		rep stosd		/* copy them */
		mov cl, dl		/* get lower bits */
		and cl, 3		/* get number of bytes left (modulo 4) */
		rep stosb		/* copy remaining few bytes */
		pop eax
		pop edi
		pop edx
		/* Initialize variables in BSS. */
		mov _STACKTOP, esp
		mov  word ptr _INT21ADDR+4, bx
		mov dword ptr _INT21ADDR+0, edx
		mov __OS, ah		/* save OS ID */
		mov eax, [edi+12]	/* get address of break flag */
		mov _BreakFlagPtr, eax	/* save it */
		mov eax, [edi]		/* get program name */
		push 0			/* NULL marks end of argv array. */
		mov _LpPgmName, eax
		push eax		/* Push argv[0]. */
		mov eax, [edi+4]	/* Get command line. */
		/*mov _LpCmdLine, eax*/	/* Don't save it, parse_first_arg has overwritten it. */
		xor ecx, ecx
		inc ecx			/* ECX := 1 (current argc). */
  Largv_next:	mov edx, eax		/* Save EAX (remaining command line). */
		call parse_first_arg
		cmp eax, edx
		je Largv_end		/* No more arguments in argv. */
		inc ecx			/* argc += 1. */
		push edx		/* Push argv[i]. */
		jmp Largv_next
  Largv_end:	mov eax, esp
		call reverse_ptrs
		mov ebp, esp		/* Save argv to EBP. */
		/* Initialize environ. */
		/* TODO(pts): Allocate pointers on the heap, not on the stack. */
		/* !! TODO(pts): Reverse order. */
		mov esi, [edi+8]	/* get environment pointer */
		mov _EnvPtr, esi	/* save environment pointer */
		push 0			/* NULL marks end of env array */
  L2:		push esi		/* push ptr to next string */
  L3:		lodsb			/* get character */
		cmp al, 0		/* check for null char */
		jne L3			/* until end of string */
		cmp byte ptr [esi], 0   /* check for double null char */
		jne L2			/* until end of environment strings */
		mov eax, esp
		call reverse_ptrs
		mov environ, esp	/* set pointer to array of ptrs */
		/* Call main. */
		xchg eax, ecx		/* EAX := ECX (argc). ECX := junk. */
		mov edx, ebp		/* EDX := EBP (saved argv). */
		/*push edx*/		/* Make it also work with __cdecl main. That has a different symbol name. */
		/*push eax*/		/* Make it also work with __cdecl main. That has a different symbol name. */
		call main
		mov esp, _STACKTOP
		retf			/* Return value is exit_code in EAX. */
} }
