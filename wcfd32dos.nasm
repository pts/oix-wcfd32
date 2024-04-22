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

section .text

global _start
_start:
..start:
sti  ; Enable virtual interrupts. TODO(pts): Do we need it?

; Allocate high memory.
mov ebx, 10h  ; 1 MiB.
mov byte [message], 'A'
try_alloc:
mov ax, 501h  ; https://fd.lod.bz/rbil/interrup/dos_extenders/310501.html
xor cx, cx
push ebx
int 31h
pop ebx
jc smaller
mov ah, 9
mov edx, message
int 21h
jmp try_alloc
smaller:
inc byte [message]
shr ebx, 1
jnz try_alloc

; Allocate conventional memory.
xor ebx, ebx
dec ebx
mov ah, 48h
int 21h
jnc done  ; Shouldn't happen.
movzx ebx, bx
mov ecx, 8000h  ; 512 KiB
mov byte [message], 'b'
print_conv:
cmp ebx, ecx
jc smaller_conv
sub ebx, ecx
mov ah, 9
mov edx, message
int 21h
jmp print_conv
smaller_conv:
inc byte [message]
shr ecx, 1
jnz print_conv

done:
mov ah, 9
mov edx, done_message
int 21h
mov ax, 4c00h  ; exit(EXIT_SUCCESS).
int 21h

section .data  ; !! TODO(pts): Remove this to avoid 0x1000 bytes of LE alignment.
message db '?$'
done_message db '.', 13, 10, '$'

;.data?  ; section .bss
;db (62 shl 10) dup (?)  ; DOS/32A: Making this 62 KiB will still keep it `BC', but 63 KiB won't.
