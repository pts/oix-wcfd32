;
; wcfd32win32.nasm: WCFD32 program runner for Win32
; by pts@fazekas.hu at Sat Apr 20 07:12:49 CEST 2024
;
; This is Win32 program which loads a WCFD32 program (from the same .exe
; file) and runs it. It passes the program filename, command-line argments
; and environments to the WCFD32 program, it does I/O for the WCFD32
; program, and it exits with the exit code returned by the WCFD32
; program.
;
; This implementation is based on bld/w32loadr/int21nt.c of OpenWatcom 1.0
; sources (https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip), and
; partially it has been reverse engineered from binw/wasm.exe in Watcom
; C/C++ 10.6.
;
; WCFD32 is an unofficial name for an ABI for i386 32-bit protected mode
; programs. It was used by some tools in Watcom C/C++ compiler, and the
; corresponding DOS extender was implemented in binw/w32run.exe. Watcom
; versions:
;
; * binw/wasm.exe in 10.0a, 10.5, 10.6, 11.0b.
; * binw/wlib.exe in 10.5, 10.6 and 11.0b. (In 10.0a, it was a 16-bit DOS
;   program.)
; * binw/wlink.exe never used WCFD32, it had its own DOS extender built in.
;
; In the name WCFD32:
;
; * W stands for Watcom.
; * CF stands for the signature of CF header describing the program image.
; * D stands for DOS, because the syscall numbers are the same as in DOS.
; * 32 stands for 32-bit protected mode on i386.
;
; !! wlib105.exe and wlib106.exe fail with `Wlib abort.' on mwperun.exe.
;    The corresponding *x*.exe do work with w32run.exe. Debug and fix.
;    Maybe some resoure file bug? Maybe some offsets there?
;
; TODO(pts): Use a single section, create the PE with NASM (and 208
; relocations).
;

bits 32
cpu 386

%define .text _TEXT
%define .rodatastr CONST  ; Unused.
%define .rodata CONST2
%define .data _DATA
%define .bss _BSS

section _TEXT  USE32 class=CODE align=1
section CONST  USE32 class=DATA align=1  ; OpenWatcom generates align=4.
section CONST2 USE32 class=DATA align=4
section _DATA  USE32 class=DATA align=4
section _BSS   USE32 class=BSS NOBITS align=4  ; NOBITS is ignored by NASM, but class=BSS works.
group DGROUP CONST CONST2 _DATA _BSS

; WLINK will add even unused (i.e. no extern) import directives to the .exe.
; Corresponding WLINK .lnk directives: import '_GetStdHandle' 'kernel32.dll'.GetStdHandle
extern __imp__GetStdHandle  ; HANDLE __stdcall GetStdHandle (DWORD nStdHandle);
extern __imp__WriteFile	  ; BOOL __stdcall WriteFile (HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED lpOverlapped);
extern __imp__ExitProcess  ; void __stdcall __noreturn ExitProcess (UINT uExitCode);
extern __imp__GetFileType  ; DWORD __stdcall GetFileType (HANDLE hFile);
extern __imp__SetFilePointer  ; DWORD __stdcall SetFilePointer (HANDLE hFile, LONG lDistanceToMove, PLONG lpDistanceToMoveHigh, DWORD dwMoveMethod);
extern __imp__DeleteFileA  ; BOOL __stdcall DeleteFileA (LPCSTR lpFileName);
extern __imp__SetEndOfFile  ; BOOL __stdcall SetEndOfFile (HANDLE hFile);
extern __imp__CloseHandle  ; BOOL __stdcall CloseHandle (HANDLE hObject);
extern __imp__MoveFileA	  ; BOOL __stdcall MoveFileA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName);
extern __imp__SetCurrentDirectoryA  ; BOOL __stdcall SetCurrentDirectoryA (LPCSTR lpPathName);
extern __imp__GetLocalTime  ; void __stdcall GetLocalTime (LPSYSTEMTIME lpSystemTime);
extern __imp__GetLastError  ; DWORD __stdcall GetLastError ();
extern __imp__GetCurrentDirectoryA  ; DWORD __stdcall GetCurrentDirectoryA (DWORD nBufferLength, LPSTR lpBuffer);
extern __imp__GetFileAttributesA  ; DWORD __stdcall GetFileAttributesA (LPCSTR lpFileName);
extern __imp__FindClose	  ; BOOL __stdcall FindClose (HANDLE hFindFile);
extern __imp__FindFirstFileA  ; HANDLE __stdcall FindFirstFileA (LPCSTR lpFileName, LPWIN32_FIND_DATAA lpFindFileData);
extern __imp__FindNextFileA  ; BOOL __stdcall FindNextFileA (HANDLE hFindFile, LPWIN32_FIND_DATAA lpFindFileData);
extern __imp__LocalFileTimeToFileTime  ; BOOL __stdcall LocalFileTimeToFileTime (const FILETIME *lpLocalFileTime, LPFILETIME lpFileTime);
extern __imp__DosDateTimeToFileTime  ; BOOL __stdcall DosDateTimeToFileTime (WORD wFatDate, WORD wFatTime, LPFILETIME lpFileTime);
extern __imp__FileTimeToDosDateTime  ; BOOL __stdcall FileTimeToDosDateTime (const FILETIME *lpFileTime, LPWORD lpFatDate, LPWORD lpFatTime);
extern __imp__FileTimeToLocalFileTime  ; BOOL __stdcall FileTimeToLocalFileTime (const FILETIME *lpFileTime, LPFILETIME lpLocalFileTime);
extern __imp__GetFullPathNameA	; DWORD __stdcall GetFullPathNameA (LPCSTR lpFileName, DWORD nBufferLength, LPSTR lpBuffer, LPSTR *lpFilePart);
extern __imp__SetFileTime  ; BOOL __stdcall SetFileTime (HANDLE hFile, const FILETIME *lpCreationTime, const FILETIME *lpLastAccessTime, const FILETIME *lpLastWriteTime);
extern __imp__GetFileTime  ; BOOL __stdcall GetFileTime (HANDLE hFile, LPFILETIME lpCreationTime, LPFILETIME lpLastAccessTime, LPFILETIME lpLastWriteTime);
extern __imp__ReadFile	; BOOL __stdcall ReadFile (HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, LPOVERLAPPED lpOverlapped);
extern __imp__SetConsoleMode  ; BOOL __stdcall SetConsoleMode (HANDLE hConsoleHandle, DWORD dwMode);
extern __imp__GetConsoleMode  ; BOOL __stdcall GetConsoleMode (HANDLE hConsoleHandle, LPDWORD lpMode);
extern __imp__CreateFileA  ; HANDLE __stdcall CreateFileA (LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
extern __imp__SetConsoleCtrlHandler  ; BOOL __stdcall SetConsoleCtrlHandler (PHANDLER_ROUTINE HandlerRoutine, BOOL Add);
extern __imp__GetModuleFileNameA  ; DWORD __stdcall GetModuleFileNameA (HMODULE hModule, LPSTR lpFilename, DWORD nSize);
extern __imp__GetEnvironmentStrings  ; LPCH __stdcall GetEnvironmentStrings ();
extern __imp__GetCommandLineA  ; LPSTR __stdcall GetCommandLineA ();
extern __imp__GetCPInfo	  ; BOOL __stdcall GetCPInfo (UINT CodePage, LPCPINFO lpCPInfo);
extern __imp__ReadConsoleInputA	  ; BOOL __stdcall ReadConsoleInputA (HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
extern __imp__PeekConsoleInputA	  ; BOOL __stdcall PeekConsoleInputA (HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
;extern __imp__LocalAlloc  ; HLOCAL __stdcall LocalAlloc (UINT uFlags, SIZE_T uBytes);
extern __imp__VirtualAlloc  ; LPVOID __stdcall VirtualAlloc(LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);

NULL equ 0

LANG_ENGLISH  equ 0x0
LANG_JAPANESE equ 0x1

WCFD32_OS_DOS equ 1
WCFD32_OS_WIN32 equ 2

STD_INPUT_HANDLE  equ -10
STD_OUTPUT_HANDLE equ -11
STD_ERROR_HANDLE  equ -12

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
INT21H_FUNC_42H_DELETE_NAMED_FILE equ 0x41
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

EXCEPTION_INT_DIVIDE_BY_ZERO    equ -1073741676
EXCEPTION_STACK_OVERFLOW        equ -1073741571
EXCEPTION_PRIV_INSTRUCTION      equ -1073741674
EXCEPTION_ACCESS_VIOLATION      equ -1073741819
EXCEPTION_ILLEGAL_INSTRUCTION   equ -1073741795
CONTROL_C_EXIT equ -1073741510

ERROR_TOO_MANY_OPEN_FILES        equ 0x4

FALSE equ 0
TRUE  equ 1

FILENO_STDIN  equ 0x0  ; In C: STDIN_FILENO.
FILENO_STDOUT equ 0x1
FILENO_STDERR equ 0x2

MEM_COMMIT equ 0x1000
MEM_RESERVE equ 0x2000

PAGE_EXECUTE_READWRITE equ 0x40

section .text

; char *__usercall getenv@<eax>(const char *name@<eax>)
getenv:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		mov edi, eax
		mov eax, [wcfd32_env_strings]
loc_41009B:
		cmp byte [eax], 0
		jz short loc_4100E8
		mov edx, edi
loc_4100A2:
		mov cl, [edx]
		lea ebx, [eax+1]
		test cl, cl
		jnz short loc_4100BB
		xor edx, edx
		mov dl, [eax]
		cmp edx, 3Dh  ; '='
		jnz short skip_rest_of_envvar
		mov eax, ebx
		jmp pop_edi_esi_edx_ecx_ebx_ret
loc_4100BB:
		mov cl, [eax]
		or cl, 20h
		movzx esi, cl
		mov cl, [edx]
		or cl, 20h
		and ecx, 0FFh
		cmp esi, ecx
		jnz short skip_rest_of_envvar
		mov eax, ebx
		inc edx
		jmp short loc_4100A2
skip_rest_of_envvar:
		mov ch, [eax]
		lea edx, [eax+1]
		test ch, ch
		jz short loc_4100E4
		mov eax, edx
		jmp short skip_rest_of_envvar
loc_4100E4:
		mov eax, edx
		jmp short loc_41009B
loc_4100E8:
		xor eax, eax
		jmp pop_edi_esi_edx_ecx_ebx_ret

; const char *__usercall PickMsg@<eax>(int error_code@<eax>)
PickMsg:
		push ebx
		push edx
		mov ebx, eax
		call WResLanguage
		mov dl, al
		mov eax, ebx
		shl eax, 2
		cmp dl, LANG_JAPANESE  ; !! TODO(pts): Remove all Japanese support.
		jnz short loc_41010D
		mov eax, [japanese_errors+eax]
		pop edx
		pop ebx
		ret
loc_41010D:
		mov eax, [english_errors+eax]
loc_410113:
		pop edx
		pop ebx
		ret

; int PrintMsg(const char *fmt, ...)
PrintMsg:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		push ebp
		sub esp, 80h	    ; printf output buffer: 80h bytes on stack.
		lea edi, [esp+98h+8]  ;  dword  8 
		xor ecx, ecx	    ; r_ecx
		mov ebp, 0Ah
loc_410130:
		mov eax, dword [esp+98h+4]
		lea edx, [eax+1]
		mov dword [esp+98h+4], edx
		mov al, [eax]
		test al, al
		jz end_of_fmt
		xor edx, edx
		mov dl, al
		cmp edx, '%'
		jnz literal_char_in_fmt
		mov eax, dword [esp+98h+4]
		lea ebx, [eax+1]
		mov dword [esp+98h+4], ebx
		mov al, [eax]
		and eax, 0FFh
		lea edx, [edi+4]
		cmp eax, 73h  ; 's'
		jnz short loc_41018B
		mov edi, edx
		mov eax, [edx-4]
loc_41017D:
		mov dl, [eax]
		inc eax
		test dl, dl
		jz short loc_410130
		inc ecx
		mov byte [esp+ecx+98h-99h], dl
		jmp short loc_41017D
loc_41018B:
		cmp eax, 'd'
		jnz short loc_4101A9
		mov edi, edx
		mov eax, [edx-4]
		mov edx, esp
		mov ebx, ebp
		add edx, ecx
		call itoa
loc_4101A0:
		cmp byte [esp+ecx+98h-98h], 0
		jz loc_410130
		inc ecx
		jmp loc_4101A0
loc_4101A9:
		mov ebx, 8
		mov edi, edx
		mov edx, [edx-4]
		cmp eax, 'x'
		jnz loc_4101C2
		mov ebx, 4
		shl edx, 10h
		jmp loc_4101CF
loc_4101C2:
		cmp eax, 'h'
		jnz loc_4101CF
		mov ebx, 2
		shl edx, 18h
loc_4101CF:
		mov eax, edx
		shr eax, 1Ch
		movzx esi, al	      ; r_esi
		shl edx, 4
		cmp esi, 0Ah
		jge loc_4101E3
		add al, '0'
		jmp loc_4101E5
loc_4101E3:
		add al, 37h
loc_4101E5:
		inc ecx
		mov byte [esp+ecx+98h-99h], al
		dec ebx
		jz loc_410130
		jmp loc_4101CF
literal_char_in_fmt:
		inc ecx
		mov byte [esp+ecx+98h-99h], al
		jmp loc_410130
end_of_fmt:
		mov edx, esp	    ; r_edx
		mov ebx, [MsgFileHandle]  ; r_ebx
		mov ah, INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE  ; r_eax
		call call_dos_int21h
		rcl eax, 1
		ror eax, 1
		add esp, 80h
pop_ebp_edi_esi_edx_ecx_ebx_ret:
		pop ebp
pop_edi_esi_edx_ecx_ebx_ret:
		pop edi
pop_esi_edx_ecx_ebx_ret:
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

%define CONFIG_LOAD_SINGLE_READ
%define CONFIG_LOAD_INT21H call call_dos_int21h
%undef  CONFIG_LOAD_MALLOC_EBX

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
		mov ah, INT21H_FUNC_48H_ALLOCATE_MEMORY  ; r_eax
		CONFIG_LOAD_INT21H
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

DumpEnvironment:
		push ebx
		push edx
		push fmt	     ; "Environment Variables:\r\n"
		call PrintMsg
		mov edx, [wcfd32_env_strings]
		add esp, 4
		xor bl, bl
loc_410484:
		cmp bl, [edx]
		jz loc_410113
		push edx
		push aS	     ; "%s\r\n"
		call PrintMsg
		add esp, 8
loc_41049A:
		mov bh, [edx]
		lea eax, [edx+1]
		cmp bl, bh
		jz loc_4104A7
		mov edx, eax
		jmp loc_41049A
loc_4104A7:
		mov edx, eax
		jmp loc_410484

; Attributes: noreturn
; void __usercall __noreturn dump_registers_to_file_and_abort(void *arg1@<eax>, void *arg2@<edx>)
dump_registers_to_file_and_abort:
		; No need to push, it doesn't return.
		;push ebx
		;push ecx
		;push esi
		mov ebx, eax	    ; r_ebx
		mov esi, edx	    ; r_esi
		call dump_registers
		mov edx, dump_filename  ; "_watcom_.dmp"
		xor ecx, ecx	    ; r_ecx
		mov ah, INT21H_FUNC_3CH_CREATE_FILE  ; r_eax
		call call_dos_int21h
		rcl eax, 1
		ror eax, 1
		mov edx, eax
		test eax, eax
		jl error_skip_writing_dump_file
		xor eax, eax
		mov ax, dx	    ; AX := DOS filehandle.
		mov edx, [wcfd32_program_filename]
		push edx
		push aProgramS  ; "Program: %s\r\n"
		mov [MsgFileHandle], eax
		call PrintMsg
		add esp, 8
		mov ecx, [wcfd32_command_line]
		push ecx
		push aCmdlineS  ; "CmdLine: %s\r\n"
		call PrintMsg
		add esp, 8
		mov edx, esi	    ; arg2
		mov eax, ebx	    ; arg1
		call dump_registers
		call DumpEnvironment
		mov ebx, [MsgFileHandle]  ; r_ebx
		mov esi, 1	    ; r_esi
		mov ah, INT21H_FUNC_3EH_CLOSE_FILE  ; r_eax
		call call_dos_int21h
		rcl eax, 1
		ror eax, 1
		mov [MsgFileHandle], esi
error_skip_writing_dump_file:
		push 8		     ; uExitCode
		jmp exit_pushed
		; Not reached.

; void __usercall __spoils<eax,edx> dump_registers(void *arg1@<eax>, void *arg2@<edx>)
dump_registers:
		push ebx
		push ecx
		push esi
		push edi
		push ebp
		push eax
		push aS_0     ; "**** %s ****\r\n"
		call PrintMsg
		add esp, 8
		mov ebx, [edx+0C4h]
		push ebx
		mov ecx, [edx+0C8h]
		push ecx
		mov esi, [edx+0B8h]
		push esi
		mov edi, [edx+0BCh]
		push edi
		mov ebp, [image_base_for_debug]
		push ebp
		push aOsNtBaseaddrXC  ; "OS=NT BaseAddr=%X CS:EIP=%x:%X SS:ESP=%"...
		call PrintMsg
		add esp, 18h
		mov eax, [edx+0A8h]
		push eax
		mov ebx, [edx+0ACh]
		push ebx
		mov ecx, [edx+0A4h]
		push ecx
		mov esi, [edx+0B0h]
		push esi
		push aEaxXEbxXEcxXEd  ; "EAX=%X EBX=%X ECX=%X EDX=%X\r\n"
		call PrintMsg
		add esp, 14h
		mov edi, [edx+0C0h]
		push edi
		mov ebp, [edx+0B4h]
		push ebp
		mov eax, [edx+9Ch]
		push eax
		mov ebx, [edx+0A0h]
		push ebx
		push aEsiXEdiXEbpXFl  ; "ESI=%X EDI=%X EBP=%X FLG=%X\r\n"
		call PrintMsg
		add esp, 14h
		mov ecx, [edx+8Ch]
		push ecx
		mov esi, [edx+90h]
		push esi
		mov edi, [edx+94h]
		push edi
		mov ebp, [edx+98h]
		push ebp
		push aDsXEsXFsXGsX  ; "DS=%x ES=%x FS=%x GS=%x\r\n"
		xor ebx, ebx
		call PrintMsg
		add esp, 14h
		mov ecx, [edx+0C4h]
		mov si, [edx+0C8h]
loc_410603:
		mov gs, esi
		mov eax, [gs:ecx]
		push eax
		push fmt_percent_hx  ; "%X "
		inc ebx
		add ecx, 4
		call PrintMsg
		add esp, 8
		test bl, 7
		jnz loc_41062C
		push str_crlf  ; "\r\n"
		call PrintMsg
		add esp, 4
loc_41062C:
		cmp ebx, 20h  ; ' '
		jl loc_410603
		push aCsEip   ; "CS:EIP -> "
		call PrintMsg
		add esp, 4
		mov ebx, [edx+0B8h]
		mov si, [edx+0BCh]
		mov edx, ebx
		xor ebx, ebx
loc_41064F:
		mov gs, esi
		xor ecx, ecx
		mov cl, [gs:edx]
		push ecx
		push fmt_percent_h  ; "%h "
		inc ebx
		inc edx
		call PrintMsg
		add esp, 8
		cmp ebx, 10h
		jl loc_41064F
		push str_crlf  ; "\r\n"
		call PrintMsg
		add esp, 4
		pop ebp
		pop edi
		pop esi
		pop ecx
		pop ebx
		ret

; http://bytepointer.com/resources/pietrek_crash_course_depths_of_win32_seh.htm
; int __stdcall seh_handler(PEXCEPTION_RECORD record, PEXCEPTION_REGISTRATION registration, PCONTEXT context, PEXCEPTION_RECORD record2)
seh_handler:
		push ebx
		mov eax, dword [esp+4+4]
		mov edx, dword [esp+4+0Ch]  ; arg2
		mov bl, [eax+4]	    ; BL :=  dword  4 ->ExceptionFlags.
		test bl, 1
		jnz return_true
		test bl, 6
		jnz return_true
		mov eax, [eax]	    ; EAX :=  dword  4 ->ExceptionCode.
		cmp eax, EXCEPTION_INT_DIVIDE_BY_ZERO
		jb loc_4106CD
		jbe abort_on_EXCEPTION_INT_DIVIDE_BY_ZERO
		cmp eax, EXCEPTION_STACK_OVERFLOW
		jb loc_4106C4
		jbe abort_on_EXCEPTION_STACK_OVERFLOW
		cmp eax, CONTROL_C_EXIT
		jz handle_ctrl_c
		jmp return_true
loc_4106C4:
		cmp eax, EXCEPTION_PRIV_INSTRUCTION
		jz abort_on_EXCEPTION_PRIV_INSTRUCTION
		jmp return_true
loc_4106CD:
		cmp eax, EXCEPTION_ACCESS_VIOLATION
		jb return_true
		jbe abort_on_EXCEPTION_ACCESS_VIOLATION
		cmp eax, EXCEPTION_ILLEGAL_INSTRUCTION
		jz abort_on_EXCEPTION_ILLEGAL_INSTRUCTION
		jmp return_true
handle_ctrl_c:
		xor eax, eax
		mov al, [had_ctrl_c]
		cmp eax, 1
		jz exit_eax
		mov cl, 1
		xor eax, eax
		mov [had_ctrl_c], cl
		pop ebx
		ret 10h
abort_on_EXCEPTION_ACCESS_VIOLATION:
		mov eax, aAccessViolatio  ; "Access violation"
		jmp loc_410720
abort_on_EXCEPTION_PRIV_INSTRUCTION:
		mov eax, aPrivilegedInst  ; "Privileged instruction"
		jmp loc_410720
abort_on_EXCEPTION_ILLEGAL_INSTRUCTION:
		mov eax, aIllegalInstruc  ; "Illegal instruction"
		jmp loc_410720
abort_on_EXCEPTION_INT_DIVIDE_BY_ZERO:
		mov eax, aIntegerDivideB  ; "Integer divide by 0"
		jmp loc_410720
abort_on_EXCEPTION_STACK_OVERFLOW:
		mov eax, aStackOverflow  ; "Stack overflow"
loc_410720:
		call dump_registers_to_file_and_abort
return_true:
		xor eax, eax
		inc eax  ; EAX := 1.
		pop ebx
		ret 10h

; BOOL __stdcall ctrl_c_handler(DWORD CtrlType)
ctrl_c_handler:
		push ebx
		sub esp, 18h
		mov edx, dword [esp+1Ch+4]
		test edx, edx
		jz loc_410765
		cmp edx, 1
		jnz loc_4107BE
loc_410765:
		xor eax, eax
		mov al, [had_ctrl_c]
		cmp eax, 1
		jnz loc_410777
exit_eax:
		push eax	     ; uExitCode
exit_pushed:
		call [__imp__ExitProcess]
		; Not reached.
loc_410777:
		mov ah, 1
		mov ebx, [stdin_handle]
		mov [had_ctrl_c], ah
loc_410785:
		lea eax, [esp+1Ch-8]
		push eax	     ; lpNumberOfEventsRead
		push 1		     ; nLength
		lea eax, [esp+24h+ -1Ch]
		push eax	     ; lpBuffer
		xor ecx, ecx
		push ebx	     ; hConsoleInput
		mov dword [esp+2Ch-8], ecx
		call [__imp__PeekConsoleInputA]
		test eax, eax
		jz loc_4107BE
		cmp dword [esp+1Ch-8], 0
		jz loc_4107BE
		lea eax, [esp+1Ch-8]
		push eax	     ; lpNumberOfEventsRead
		push 1		     ; nLength
		lea eax, [esp+24h+ -1Ch]
		push eax	     ; lpBuffer
		push ebx	     ; hConsoleInput
		call [__imp__ReadConsoleInputA]
		test eax, eax
		jnz loc_410785
loc_4107BE:
		mov eax, 1
		add esp, 18h
		pop ebx
		ret 4

; int __cdecl detect_code_page()
detect_code_page:  ; !! TODO(pts): Remove all Japanese support.
		push ecx
		push edx
		sub esp, 14h
		mov eax, esp
		push eax	     ; lpCPInfo
		push 1		     ; CodePage
		call [__imp__GetCPInfo]
		test eax, eax
		jz loc_4107F2
		cmp byte [esp+1Ch-16h], 0  ; cpinfo.LeadByte[0]
		jnz loc_4107EB
		cmp byte [esp+1Ch-15h], 0  ; cpinfo.LeadByte[1]
		jz loc_4107F2
loc_4107EB:
		mov eax, 1	    ; Code page has nonzero LeadByte. It's probably Japanese.
		jmp loc_4107F4
loc_4107F2:
		xor eax, eax
loc_4107F4:
		add esp, 14h
		pop edx
		pop ecx
		ret

%if 0  ; Unused.
; void __usercall change_binnt_to_binw_in_full_pathname(char *filename@<eax>)
change_binnt_to_binw_in_full_pathname:
		push ebx
		push edx
next_pathname_component:
		cmp byte [eax], 0
		jz after_backslash
		xor edx, edx
		mov dl, [eax]
		cmp edx, '\'
		jz after_backslash
		inc eax
		jmp next_pathname_component
after_backslash:
		cmp byte [eax], 0
		jz pop_edx_ebx_ret
		inc eax
		mov dl, [eax]
		or dl, 20h
		and edx, 0FFh
		cmp edx, 'b'
		jnz next_pathname_component
		mov dl, [eax+1]
		or dl, 20h
		and edx, 0FFh
		cmp edx, 'i'
		jnz next_pathname_component
		mov dl, [eax+2]
		or dl, 20h
		and edx, 0FFh
		cmp edx, 'n'
		jnz next_pathname_component
		mov dl, [eax+3]
		or dl, 20h
		and edx, 0FFh
		cmp edx, 'n'
		jnz next_pathname_component
		mov dl, [eax+4]
		or dl, 20h
		and edx, 0FFh
		cmp edx, 't'
		jnz next_pathname_component
		xor edx, edx
		mov dl, [eax+5]
		cmp edx, '\'
		jnz next_pathname_component
		mov bl, [eax+3]
		add eax, 4
		add bl, 9	    ; Change "binnt\\" to "binw\\" . In this step, change 'n' to 'w'.
		mov [eax-1], bl	    ; Change 'n' to 'w' in place.
copy_next_byte:
		mov dl, [eax+1]
		mov [eax], dl
		test dl, dl
		jz pop_edx_ebx_ret
		inc eax
		jmp copy_next_byte
%endif

; void __usercall add_seh_frame(void *frame@<eax>)
add_seh_frame:
		push ebx
		push edx
		mov ebx, eax
		xor eax, eax
		mov eax, [fs:eax]
		xor edx, edx
		mov [ebx], eax
		mov eax, ebx
		mov dword [ebx+4], seh_handler
		mov [fs:edx], eax
pop_edx_ebx_ret:
		pop edx
		pop ebx
		ret

%if 0  ; Unused.
; void __usercall set_seh_frame_ref(void **frame_ref)
set_seh_frame_ref:
		push edx
		mov eax, [eax]
		xor edx, edx
		mov [fs:edx], eax   ; Set SEH frame (thread-local).
		pop edx
		ret
%endif

; Attributes: noreturn
global _start
_start:
global _mainCRTStartup
_mainCRTStartup:
..start:
		sub esp, 128h
		call detect_code_page
		mov [is_code_page_maybe_japanese], eax
		mov dword [esp+13Ch-24h], eax
		lea eax, [esp+13Ch-1Ch]  ;  frame
		call add_seh_frame
		call populate_stdio_handles
		call [__imp__GetCommandLineA]
loc_4108C3:
		xor edx, edx
		mov dl, [eax]
		cmp edx, ' '
		jz loc_4108D1
		cmp edx, 9
		jnz loc_4108D4
loc_4108D1:
		inc eax
		jmp loc_4108C3
loc_4108D4:
		cmp byte [eax], 0
		jz loc_4108EA
		xor edx, edx
		mov dl, [eax]
		cmp edx, ' '
		jz loc_4108EA
		cmp edx, 9
		jz loc_4108EA
		inc eax
		jmp loc_4108D4
loc_4108EA:
		xor edx, edx
		mov dl, [eax]
		cmp edx, ' '
		jz loc_4108F8
		cmp edx, 9
		jnz loc_4108FB
loc_4108F8:
		inc eax
		jmp loc_4108EA
loc_4108FB:
		mov [wcfd32_command_line], eax
		;
		call [__imp__GetEnvironmentStrings]
		mov [wcfd32_env_strings], eax
		;
		mov eax, esp
		push 104h	     ; nSize
		push eax	     ; lpFilename
		push 0		     ; hModule
		call [__imp__GetModuleFileNameA]
		;
		mov eax, esp	    ;  ; var_wcfd32_program_filename_buf.
		;call change_binnt_to_binw_in_full_pathname  ; No need to change the pathname, the program is self-contained.
		mov [wcfd32_program_filename], eax
		;mov eax, esp	    ;  ; var_wcfd32_program_filename_buf.
		call load_wcfd32_program_image  ; Sets EAX and EDX.
		;
		cmp eax, -10
		jb .load_ok
		neg eax
		push eax  ; Save exit code for exit_pushed.
		push edx
		push dword [wcfd32_program_filename]
		call PickMsg  ; Sets EAX to the error string format.
		push eax	     ; fmt
		call PrintMsg
		add esp, 0Ch  ; Clean up arguments of PrintMsg.
		jmp exit_pushed
.load_ok:	mov [image_base_for_debug], edx  ; Just for debugging.
		push eax  ; Save entry point address.
		push TRUE	     ; Add
		push ctrl_c_handler  ; HandlerRoutine
		call [__imp__SetConsoleCtrlHandler]
		;
		; Now we call the entry point.
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
		sub ecx, ecx  ; This is an unknown parameter, which we always set to 0.
		mov edx, call_far_dos_int21h
		mov edi, wcfd32_param_struct
		mov bx, cs  ; Segment of call_far_dos_int21h for the far call.
		mov ah, WCFD32_OS_WIN32  ; The LX program in the DOS version sets this to WCFD32_OS_DOS.
		pop esi  ; Entry point address.
		push cs  ; For the `retf' of the far call.
		call esi
		;lea eax, [esp+13Ch-1Ch]
		;call set_seh_frame_ref  ; TODO(pts): Why is this needed near the end?
		jmp exit_eax
		; Not reached.

call_far_dos_int21h:  ; proc far
		call call_dos_int21h
		retf

; unsigned __int8 __usercall call_dos_int21h@<cf>(unsigned int r_eax@<eax>, unsigned int r_ebx@<ebx>, unsigned int r_ecx@<ecx>, unsigned int r_edx@<edx>, unsigned int r_esi@<esi>, unsigned int  dword  8 @<edi>)
call_dos_int21h:
		push edi
		push esi
		push edx
		push ecx
		push ebx
		push eax	     ; regs
		mov eax, esp	    ; regs
		call call_dos_int21h_low
		sahf
		pop eax
		pop ebx
		pop ecx
		pop edx
		pop esi
		pop edi
		ret

; int __fastcall __open_file(DWORD dwCreationDisposition, DWORD dwDesiredAccess, DWORD dwFlagsAndAttributes)
__open_file:
		push esi
		push edi
		push ebp
		sub esp, 4
		mov edi, eax
		mov dword [esp+10h-10h], ebx
		mov eax, [dword_420294]
		xor esi, esi
		xor ebx, ebx
		shl eax, 2
loc_4109E0:
		mov ebp, [stdin_handle+ebx]
		test ebp, ebp
		jz loc_410A00
		add ebx, 4
		inc esi
		cmp ebx, eax
		jnz loc_4109E0
		mov dword [force_last_error], ERROR_TOO_MANY_OPEN_FILES
loc_4109FC:
		xor eax, eax
		jmp loc_410A2A
loc_410A00:
		push ebp	     ; hTemplateFile
		mov ebp, dword [esp+14h+4]
		push ebp	     ;  dword ptr	 4 
		push ecx	     ; dwCreationDisposition
		push 0		     ; lpSecurityAttributes
		mov eax, dword [esp+20h-10h]
		push eax	     ;  dword -10h 
		push edx	     ; dwDesiredAccess
		mov edx, [edi+0Ch]
		push edx	     ; lpFileName
		call [__imp__CreateFileA]
		cmp eax, 0FFFFFFFFh
		jz loc_4109FC
		mov [stdin_handle+ebx], eax
		mov eax, 1
		mov [edi], esi
loc_410A2A:
		add esp, 4
		pop ebp
		pop edi
		pop esi
		ret 4

func_INT21H_FUNC_3CH_CREATE_FILE:
		push ebx
		push ecx
		push edx
		push esi
		test byte [eax+8], 1
		jz loc_410A49
		mov esi, 80000000h
		mov edx, 1
		jmp loc_410A53
loc_410A49:
		mov esi, 0C0000000h
		mov edx, 80h
loc_410A53:
		test byte [eax+8], 2
		jz loc_410A5C
		or dl, 2
loc_410A5C:
		test byte [eax+8], 4
		jz loc_410A65
		or dl, 4
loc_410A65:
		mov ecx, 2	    ; dwCreationDisposition
		push edx	     ;  dword ptr	 4 
		xor ebx, ebx
		mov edx, esi	    ; dwDesiredAccess
		call __open_file
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

func_INT21H_FUNC_3DH_OPEN_FILE:
		push ebx
		push ecx
		push edx
		mov dl, [eax]
		and dl, 3
		and edx, 0FFh
		jnz loc_410A95
		mov ecx, 3
		mov edx, 80000000h
		jmp loc_410AB0
loc_410A95:
		cmp edx, 1
		jnz loc_410AA6
		mov ecx, 3
		mov edx, 40000000h
		jmp loc_410AB0
loc_410AA6:
		mov ecx, 4	    ; dwCreationDisposition
		mov edx, 0C0000000h  ; dwDesiredAccess
loc_410AB0:
		mov bl, [eax]
		and bl, 70h
		and ebx, 0FFh
		jz loc_410AC2
		cmp ebx, 40h  ; '@'
		jnz loc_410AC9
loc_410AC2:
		mov ebx, 3
		jmp loc_410AE3
loc_410AC9:
		cmp ebx, 20h  ; ' '
		jnz loc_410AD5
		mov ebx, 1
		jmp loc_410AE3
loc_410AD5:
		cmp ebx, 30h  ; '0'
		jnz loc_410AE1
		mov ebx, 2
		jmp loc_410AE3
loc_410AE1:
		xor ebx, ebx
loc_410AE3:
		push 80h	     ; dwFlagsAndAttributes
		call __open_file
		pop edx
		pop ecx
		pop ebx
		ret

func_INT21H_FUNC_08H_WAIT_FOR_CONSOLE_INPUT:
		push ebx
		push ecx
		push edx
		push esi
		sub esp, 8
		mov esi, eax
		mov eax, esp
		push eax	     ; lpMode
		mov ebx, [stdin_handle]
		push ebx	     ; hConsoleHandle
		call [__imp__GetConsoleMode]
		push 0		     ;  dword -18h 
		push ebx	     ; hConsoleHandle
		call [__imp__SetConsoleMode]
		push 0		     ; lpOverlapped
		lea eax, [esp+1Ch-14h]
		push eax	     ; lpNumberOfBytesRead
		push 1		     ; nNumberOfBytesToRead
		push esi	     ; lpBuffer
		push ebx	     ; hFile
		call [__imp__ReadFile]
		mov edx, dword [esp+18h-18h]
		push edx	     ;  dword -18h 
		push ebx	     ; hConsoleHandle
		mov esi, eax
		call [__imp__SetConsoleMode]
		mov eax, esi
		add esp, 8
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

func_INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		push ebp
		sub esp, 18h
		mov ebx, eax
		cmp byte [eax], 0
		jnz loc_410B82
		xor eax, eax
		mov ax, [ebx+4]
		mov edx, [stdin_handle+eax*4]
		mov eax, esp
		push eax	     ; lpLastWriteTime
		lea eax, [esp+34h+ -28h]
		push eax	     ; lpLastAccessTime
		lea eax, [esp+38h+ -20h]
		push eax	     ; lpCreationTime
		push edx	     ; hFile
		call [__imp__GetFileTime]
		mov esi, eax
		test eax, eax
		jz loc_410BE7
		lea eax, [ebx+8]
		lea edx, [ebx+0Ch]
		mov ebx, eax
		mov eax, esp
		call __MakeDOSDT
		jmp loc_410BE7
loc_410B82:
		xor eax, eax
		mov al, [ebx]
		cmp eax, 1
		jnz loc_410BE5
		xor eax, eax
		mov ax, [ebx+4]
		mov ebp, [stdin_handle+eax*4]
		mov eax, esp
		push eax	     ; lpLastWriteTime
		lea eax, [esp+34h+ -28h]
		push eax	     ; lpLastAccessTime
		lea eax, [esp+38h+ -20h]
		push eax	     ; lpCreationTime
		push ebp	     ; hFile
		call [__imp__GetFileTime]
		mov esi, eax
		test eax, eax
		jz loc_410BE7
		xor edx, edx
		xor eax, eax
		mov dx, [ebx+8]
		mov ax, [ebx+0Ch]
		mov ebx, esp
		call __FromDOSDT
		mov eax, esp
		push eax	     ; lpLastWriteTime
		lea eax, [esp+34h-28h]
		push eax	     ; lpLastAccessTime
		lea eax, [esp+38h-20h]
		push eax	     ; lpCreationTime
		lea edi, [esp+3Ch-28h]
		lea esi, [esp+3Ch-30h]
		push ebp	     ; hFile
		movsd
		movsd
		call [__imp__SetFileTime]
		mov esi, eax
		jmp loc_410BE7
loc_410BE5:
		xor esi, esi
loc_410BE7:
		mov eax, esi
loc_410BE9:
		add esp, 18h
loc_410BEC:
		pop ebp
loc_410BED:
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

func_INT21H_FUNC_60H_GET_FULL_FILENAME:
		push ebx
		push ecx
		push edx
		push esi
		sub esp, 4
		mov ebx, eax
		mov edx, aCon  ; "con"
		mov eax, [eax+0Ch]
		call strcmp
		test eax, eax
		jnz loc_410C1F
		mov eax, [ebx+4]
		mov ebx, dword [aCon]  ; "con"
		mov [eax], ebx
		mov eax, 1
		jmp loc_410C33
loc_410C1F:
		mov eax, esp
		push eax	     ; lpFilePart
		mov edx, [ebx+4]
		push edx	     ; lpBuffer
		mov ecx, [ebx+8]
		push ecx	     ; nBufferLength
		mov esi, [ebx+0Ch]
		push esi	     ; lpFileName
		call [__imp__GetFullPathNameA]
loc_410C33:
		add esp, 4
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

__MakeDOSDT:
		push ecx
		push esi
		sub esp, 8
		mov esi, edx
		mov edx, esp
		push edx	     ; lpLocalFileTime
		push eax	     ; lpFileTime
		call [__imp__FileTimeToLocalFileTime]
		push ebx	     ; lpFatTime
		push esi	     ; lpFatDate
		lea eax, [esp+18h-10h]
		push eax	     ; lpFileTime
		call [__imp__FileTimeToDosDateTime]
		add esp, 8
		pop esi
		pop ecx
		ret

__FromDOSDT:
		push ecx
		sub esp, 8
		mov ecx, esp
		push ecx	     ; lpFileTime
		xor ecx, ecx
		mov cx, dx
		push ecx	     ; wFatTime
		xor ecx, ecx
		mov cx, ax
		push ecx	     ; wFatDate
		call [__imp__DosDateTimeToFileTime]
		push ebx	     ; lpFileTime
		lea ebx, [esp+10h-0Ch]
		push ebx	     ; lpLocalFileTime
		call [__imp__LocalFileTimeToFileTime]
		add esp, 8
		pop ecx
		ret

__GetNTDirInfo:
		push ebx
		push ecx
		push esi
		mov ecx, eax
		mov esi, edx
		lea ebx, [eax+16h]
		lea edx, [eax+18h]
		lea eax, [esi+14h]
		call __MakeDOSDT
		mov al, [esi]
		mov [ecx+15h], al
		mov ebx, 0FFh
		mov eax, [esi+20h]
		lea edx, [esi+2Ch]
		mov [ecx+1Ah], eax
		lea eax, [ecx+1Eh]
		call strncpy
		pop esi
		pop ecx
		pop ebx
		ret

__NTFindNextFileWithAttr:
		push ecx
		push esi
		sub esp, 4
		mov esi, eax
		mov dword [esp+0Ch-0Ch], edx
		mov ah, byte dword [esp+0Ch-0Ch]
		or ah, 0A1h
		mov byte dword [esp+0Ch-0Ch], ah
		test ah, 8
		jz loc_410CD9
		mov dh, ah
		and dh, 0F7h
		mov byte dword [esp+0Ch-0Ch], dh
loc_410CD9:
		mov edx, [ebx]
		test edx, edx
		jnz loc_410CE6
loc_410CDF:
		mov eax, 1
		jmp loc_410CF6
loc_410CE6:
		test dword [esp+0Ch-0Ch], edx
		jnz loc_410CDF
		push ebx	     ; lpFindFileData
		push esi	     ; hFindFile
		call [__imp__FindNextFileA]
		test eax, eax
		jnz loc_410CD9
loc_410CF6:
		add esp, 4
		pop esi
		pop ecx
		ret

func_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		sub esp, 140h
		mov esi, eax
		mov edi, [eax+4]
		mov eax, esp
		push eax	     ; lpFindFileData
		mov edx, [esi+0Ch]
		push edx	     ; lpFileName
		xor ebx, ebx
		call [__imp__FindFirstFileA]
		mov ecx, eax
		cmp eax, 0FFFFFFFFh
		jnz loc_410D25
		mov [edi], eax
		jmp loc_410D69
loc_410D25:
		mov ebx, 1
		mov eax, [esi+0Ch]
loc_410D2D:
		cmp byte [eax], 0
		jz loc_410D53
		xor edx, edx
		mov dl, [eax]
		cmp edx, 2Ah  ; '*'
		jz loc_410D40
		cmp edx, 3Fh  ; '?'
		jnz loc_410D50
loc_410D40:
		mov ebx, esp
		mov eax, ecx
		mov edx, [esi+8]
		call __NTFindNextFileWithAttr
		mov ebx, eax
		jmp loc_410D53
loc_410D50:
		inc eax
		jmp loc_410D2D
loc_410D53:
		cmp ebx, 1
		jnz loc_410D69
		mov [edi], ecx
		mov eax, [esi+8]
		mov edx, esp
		mov [edi+4], eax
		mov eax, edi
		call __GetNTDirInfo
loc_410D69:
		mov eax, ebx
		add esp, 140h
		jmp loc_410BED

func_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		push ebp
		sub esp, 140h
		mov esi, [eax+0Ch]
		mov edi, [esi]
		xor ebp, ebp
		cmp edi, 0FFFFFFFFh
		jz loc_410DC8
		cmp byte [eax], 0
		jnz loc_410DC0
		mov eax, esp
		push eax	     ; lpFindFileData
		push edi	     ; hFindFile
		call [__imp__FindNextFileA]
		test eax, eax
		jz loc_410DC8
		mov ebx, esp
		mov eax, edi
		mov edx, [esi+4]
		call __NTFindNextFileWithAttr
		test eax, eax
		jz loc_410DC8
		mov edx, esp
		mov eax, esi
		mov ebp, 1
		call __GetNTDirInfo
		jmp loc_410DC8
loc_410DC0:
		push edi	     ; hFindFile
		call [__imp__FindClose]
		mov ebp, eax
loc_410DC8:
		mov eax, ebp
		add esp, 140h
		jmp loc_410BEC

func_INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES:
		push ebx
		push ecx
		push edx
		push esi
		mov ebx, eax
		mov ah, [eax]
		xor esi, esi
		test ah, ah
		jnz loc_410DFD
		mov edx, [ebx+0Ch]
		push edx	     ; lpFileName
		call [__imp__GetFileAttributesA]
		mov edx, eax
		cmp eax, 0FFFFFFFFh
		jz loc_410E04
		mov esi, 1
		mov [ebx+8], al
		jmp loc_410E04
loc_410DFD:
		xor eax, eax
		mov al, [ebx]
		cmp eax, 1
loc_410E04:
		mov eax, esi
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

func_INT21H_FUNC_2AH_GET_CURRENT_DRIVE:
		push ecx
		push edx
		sub esp, 104h
		mov eax, esp
		push eax	     ; lpBuffer
		push 104h	     ; nBufferLength
		call [__imp__GetCurrentDirectoryA]
		xor eax, eax
		mov al, byte [esp+10Ch-10Ch]
		cmp al, 'A'
		jl .lowered
		cmp al, 'Z'
		jg .lowered
		add eax, 20h
.lowered:	sub al, 'a'
		add esp, 104h
		pop edx
		pop ecx
		ret

section .rodata

dos_syscall_numbers db 60h, 57h, 56h, 4Fh, 4Eh, 4Ch, 48h, 47h, 44h, 43h, 42h
		db 41h, 40h, 3Fh, 3Eh, 3Dh, 3Ch, 3Bh, 2Ch, 2Ah, 1Ah, 19h  ; Reverse order than dos_syscall_handlers.
		db 8, 6
		align 4
dos_syscall_handlers:
		dd handle_unsupported_int21h_function  ; jump table for switch statement
		dd handle_INT21H_FUNC_06H_DIRECT_CONSOLE_IO  ; jumptable 00410ED7 case 1
		dd handle_INT21H_FUNC_08H_WAIT_FOR_CONSOLE_INPUT  ; jumptable 00410ED7 case 2
		dd handle_INT21H_FUNC_2AH_GET_CURRENT_DRIVE  ; jumptable 00410ED7 case 3
		dd handle_INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS  ; jumptable 00410ED7 case 4
		dd handle_INT21H_FUNC_2AH_GET_DATE  ; jumptable 00410ED7 case 5
		dd handle_INT21H_FUNC_2CH_GET_TIME  ; jumptable 00410ED7 case 6
		dd handle_INT21H_FUNC_3BH_CHDIR  ; jumptable 00410ED7 case 7
		dd handle_INT21H_FUNC_3CH_CREATE_FILE  ; jumptable 00410ED7 case 8
		dd handle_INT21H_FUNC_3DH_OPEN_FILE  ; jumptable 00410ED7 case 9
		dd handle_INT21H_FUNC_3EH_CLOSE_FILE  ; jumptable 00410ED7 case 10
		dd handle_INT21H_FUNC_3FH_READ_FROM_FILE  ; jumptable 00410ED7 case 11
		dd handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE  ; jumptable 00410ED7 case 12
		dd handle_INT21H_FUNC_41H_DELETE_NAMED_FILE  ; jumptable 00410ED7 case 13
		dd handle_INT21H_FUNC_42H_SEEK_IN_FILE  ; jumptable 00410ED7 case 14
		dd handle_INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES  ; jumptable 00410ED7 case 15
		dd handle_INT21H_FUNC_44H_IOCTL_IN_FILE  ; jumptable 00410ED7 case 16
		dd handle_INT21H_FUNC_47H_GET_CURRENT_DIR  ; jumptable 00410ED7 case 17
		dd handle_INT21H_FUNC_48H_ALLOCATE_MEMORY  ; jumptable 00410ED7 case 18
		dd handle_INT21H_FUNC_4CH_EXIT_PROCESS  ; jumptable 00410ED7 case 19
		dd handle_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE  ; jumptable 00410ED7 case 20
		dd handle_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE  ; jumptable 00410ED7 case 21
		dd handle_INT21H_FUNC_56H_RENAME_FILE  ; jumptable 00410ED7 case 22
		dd handle_INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME  ; jumptable 00410ED7 case 23
		dd handle_INT21H_FUNC_60H_GET_FULL_FILENAME  ; jumptable 00410ED7 case 24

section .text
; Returns flags in AH. Modifies regs in place.
; unsigned __int8 __usercall call_dos_int21h_low@<ah>(struct dos_int21h_regs *regs@<eax>)
call_dos_int21h_low:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		push ebp
		sub esp, 18h
		mov esi, eax
		xor edx, edx
		mov ecx, 19h
		mov [force_last_error], edx  ; ERROR_SUCCESS. Don't force the last error.
		mov edi, dos_syscall_numbers
		mov al, [eax+1]
		repne scasb
		jmp [dos_syscall_handlers+ecx*4]  ; switch 25 cases
handle_INT21H_FUNC_06H_DIRECT_CONSOLE_IO:
		push 0		     ; jumptable 00410ED7 case 1
		lea eax, [esp+34h-20h]
		push eax	     ; lpNumberOfBytesWritten
		push 1		     ; nNumberOfBytesToWrite
		lea eax, [esi+0Ch]
		push eax	     ; lpBuffer
		mov edx, [stdout_handle]
		push edx	     ; hFile
loc_410EF3:
		call [__imp__WriteFile]
done_handling:
		mov ebp, eax  ; EBP := EAX; EAX := junk.
loc_410EFA:
		xor eax, eax  ; Set CF=0 (success) in returned flags.
		test ebp, ebp
		jnz loc_410BE9
		mov eax, [force_last_error]
		test eax, eax
		jnz dos_error_with_code
		call [__imp__GetLastError]
dos_error_with_code:
		mov [esi], eax  ; Return DOS error code in AX.
dos_error:
		mov eax, 100h  ; Set CF=1 (error) in returned flags.
		jmp loc_410BE9
handle_INT21H_FUNC_08H_WAIT_FOR_CONSOLE_INPUT:
		mov eax, esi	    ; jumptable 00410ED7 case 2
		call func_INT21H_FUNC_08H_WAIT_FOR_CONSOLE_INPUT
		jmp done_handling
handle_INT21H_FUNC_2AH_GET_CURRENT_DRIVE:
		call func_INT21H_FUNC_2AH_GET_CURRENT_DRIVE	     ; jumptable 00410ED7 case 3
		xor ebp, ebp
		inc ebp  ; Force success.
		mov [esi], eax
		jmp loc_410EFA  ; Force success.
handle_INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS:
		mov eax, [esi+0Ch]  ; jumptable 00410ED7 case 4
		xor ebp, ebp  ; Force error.
		mov [dta_addr], eax
		jmp loc_410EFA  ; Force success.
handle_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE:
		mov eax, esi	    ; jumptable 00410ED7 case 20
		call func_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE
		jmp done_handling
handle_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE:
		mov eax, esi	    ; jumptable 00410ED7 case 21
		call func_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE
		jmp done_handling
handle_INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES:
		mov eax, esi	    ; jumptable 00410ED7 case 15
		call func_INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES
		jmp done_handling
handle_INT21H_FUNC_47H_GET_CURRENT_DIR:
		mov edx, [esi+10h]  ; jumptable 00410ED7 case 17
		push edx	     ; lpBuffer
		push 40h	     ; nBufferLength; DOS supports only 64 bytes.
		call [__imp__GetCurrentDirectoryA]
		mov ebp, eax  ; Number of characters written to the buffer.
		test eax, eax
		jz .bad
		cmp eax, 40h
		jb .good
		xor ebp, ebp
.bad:		jz loc_410EFA  ; Force error.
.good:		mov eax, [esi+10h]
		mov dword [esp+30h-1Ch], eax
		mov edi, eax  ; Ignore the first 3 bytes: drive letter, ':', '\'.
.copy:		mov al, [edi+3]
		stosb
		test al, al
		jnz .copy
		jmp loc_410EFA  ; Force success.
handle_INT21H_FUNC_2AH_GET_DATE:
		mov eax, esp	    ; jumptable 00410ED7 case 5
		push eax	     ; lpSystemTime
		call [__imp__GetLocalTime]
		mov al, byte [esp+30h-2Ch]
		mov [esi], al
		mov eax, dword [esp+30h-30h]
		mov [esi+8], ax
		mov al, byte dword [esp+30h-30h +2]
		mov [esi+0Dh], al
		mov al, byte [esp+30h-2Ah]
loc_410FB5:
		xor ebp, ebp
		inc ebp  ; Force success.
		mov [esi+0Ch], al
		jmp loc_410EFA  ; Force success.
handle_INT21H_FUNC_2CH_GET_TIME:
		mov eax, esp	    ; jumptable 00410ED7 case 6
		push eax	     ; lpSystemTime
		call [__imp__GetLocalTime]
		mov al, byte [esp+30h-28h]
		mov [esi+9], al
		mov al, byte [esp+30h-26h]
		mov [esi+8], al
		mov al, byte [esp+30h-24h]
		xor edx, edx
		mov [esi+0Dh], al
		mov dx, word [esp+30h-22h]
		mov ebx, 0Ah
		mov eax, edx
		sar edx, 1Fh
		idiv ebx
		jmp loc_410FB5
handle_INT21H_FUNC_3BH_CHDIR:
		mov ebp, [esi+0Ch]  ; jumptable 00410ED7 case 7
		push ebp	     ; lpPathName
		call [__imp__SetCurrentDirectoryA]
		jmp done_handling
handle_INT21H_FUNC_3CH_CREATE_FILE:
		mov eax, esi	    ; jumptable 00410ED7 case 8
		call func_INT21H_FUNC_3CH_CREATE_FILE
		jmp done_handling
handle_INT21H_FUNC_3DH_OPEN_FILE:
		mov eax, esi	    ; jumptable 00410ED7 case 9
		call func_INT21H_FUNC_3DH_OPEN_FILE
		jmp done_handling
handle_INT21H_FUNC_56H_RENAME_FILE:
		mov ebx, [esi+14h]  ; jumptable 00410ED7 case 22
		push ebx	     ; lpNewFileName
		mov ecx, [esi+0Ch]
		push ecx	     ; lpExistingFileName
		call [__imp__MoveFileA]
		jmp done_handling
handle_INT21H_FUNC_3EH_CLOSE_FILE:
		xor eax, eax	    ; jumptable 00410ED7 case 10
		mov ax, [esi+4]
		mov edx, [stdin_handle+eax*4]
		xor edi, edi
		push edx	     ; hObject
		mov [stdin_handle+eax*4], edi
		call [__imp__CloseHandle]
		jmp done_handling
handle_INT21H_FUNC_3FH_READ_FROM_FILE:
		push edx	     ; jumptable 00410ED7 case 11
		push esi	     ; lpNumberOfBytesRead
		mov ebx, [esi+8]
		xor eax, eax
		push ebx	     ; nNumberOfBytesToRead
		mov ecx, [esi+0Ch]
		mov ax, [esi+4]
		push ecx	     ; lpBuffer
		mov eax, [stdin_handle+eax*4]
		push eax	     ; hFile
		call [__imp__ReadFile]
		jmp done_handling
handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE:
		xor eax, eax	    ; jumptable 00410ED7 case 12
		mov ax, [esi+4]
		mov edi, [esi+8]
		mov eax, [stdin_handle+eax*4]
		test edi, edi
		jnz loc_411090
		push eax	     ; hFile
		mov [esi], edx
		call [__imp__SetEndOfFile]
		jmp done_handling
loc_411090:
		push edx
		push esi
		push edi
		mov edx, [esi+0Ch]
		push edx
		push eax
		jmp loc_410EF3
handle_INT21H_FUNC_41H_DELETE_NAMED_FILE:
		mov ecx, [esi+0Ch]  ; jumptable 00410ED7 case 13
		push ecx	     ; lpFileName
		call [__imp__DeleteFileA]
		jmp done_handling
handle_INT21H_FUNC_42H_SEEK_IN_FILE:
		xor eax, eax	    ; jumptable 00410ED7 case 14
		mov ax, [esi+4]
		mov ebx, [stdin_handle+eax*4]
		xor eax, eax
		mov al, [esi]
		push eax	     ; dwMoveMethod
		push edx	     ; lpDistanceToMoveHigh
		xor eax, eax
		mov edx, [esi+8]
		mov ax, [esi+0Ch]
		shl edx, 10h
		add eax, edx
		push eax	     ; lDistanceToMove
		push ebx	     ; hFile
		call [__imp__SetFilePointer]
		mov [esi], eax
		shr eax, 10h
		mov ebx, [esi]
		mov [esi+0Ch], eax
		xor ebp, ebp
		cmp ebx, 0FFFFFFFFh
		je .done  ; Force error.
		inc ebp  ; Force success.
.done:		jmp loc_410EFA  ; Success or error.
handle_INT21H_FUNC_48H_ALLOCATE_MEMORY:
		mov ebp, [esi+4]    ; jumptable 00410ED7 case 18
		;
		; We need to allocate EBP bytes of memory here. With WASM,
		; EBP (new_amount) is typically 0x30000 for the CF image
		; load, then 0x2000 a few times, then 0x1000 many times.
%if 0
		; On Win32, we can simply use GlobalAlloc, LocalAlloc or
		; HeapAlloc. But that doesn't work with mwpestub, because
		; GlobalAlloc always fails, LocalAlloc and HeapAlloc only
		; return memory from the local heap, which is preallocated
		; to SizeOfHeapCommit bytes (WLINK directive `commit
		; heap='), and preallocation doesn't work for us.
		;
		push ebp	     ; uBytes
		push edx	     ; uFlags, 0.
		call [__imp__LocalAlloc]
		test eax, eax
		jnz .alloced
		mov al, 8  ; DOS error: insufficient memory.
		jmp dos_error_with_code
.got_it:
%else
		; We use VirtualAlloc. But we don't want to call
		; VirtualAlloc for each call, because that has lots of
		; overhead, and it wastes precious XMS handles with
		; mwpestub. Growing the previously allocated block in place
		; whenever we can has still too much overhead in mwpestub,
		; so we allocate memory in 256 KiB blocks, and keep track.
		;
		;push '.'
		;mov eax, esp
		;push eax
		;call PrintMsg
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
		;call PrintMsg
		;add esp, 8
		;pop eax
		jmp .alloced
.full:		; Try to allocate new block or extend the current block by at least 256 KiB.
		; It's possible to extend in Wine, but not with mwpestub.
		mov ebx, 0x100<<10  ; 256 KiB.
		cmp ebx, ebp
		jae .try_alloc
		mov ebx, ebp
		add ebx, 0xfff
		and ebx, ~0xfff  ; Round up to multiple of 4096 bytes (page size).
.try_alloc:	mov eax, [malloc_base]
		add eax, [malloc_capacity]
		push PAGE_EXECUTE_READWRITE  ; flProtect
		push MEM_COMMIT|MEM_RESERVE  ; flAllocationType
		push ebx  ; dwSize
		push eax  ; lpAddress
		call [__imp__VirtualAlloc]
		;push eax
		;push '*'
		;mov eax, esp
		;push eax
		;call PrintMsg
		;add esp, 8
		;pop eax
		test eax, eax
		jz .no_extend
		cmp dword [malloc_base], 0
		jne .extended
		mov [malloc_base], eax
.extended:	add [malloc_rest], ebx
		add [malloc_capacity], ebx
		;push '#'
		;mov eax, esp
		;push eax
		;call PrintMsg
		;add esp, 8
		jmp .try_fit  ; It will fit now.
.no_extend:	xor eax, eax
		cmp [malloc_base], eax
		je .no_alloc
		mov [malloc_base], eax
		mov [malloc_capacity], eax
		mov [malloc_rest], eax
		;push '+'
		;mov eax, esp
		;push eax
		;call PrintMsg
		;add esp, 8
		jmp .try_alloc  ; Retry with allocating new block.
.no_alloc:	shr ebx, 1  ; Try to allocate half as much.
		;push '_'
		;mov eax, esp
		;push eax
		;call PrintMsg
		;add esp, 8
		cmp ebx, ebp
		jb .oom  ; Not enough memory for new_amount bytes.
		cmp ebx, 0xfff
		ja .try_alloc  ; Enough memory to for new_amount bytes and also at least a single page.
.oom:		mov al, 8  ; DOS error: insufficient memory.
		jmp dos_error_with_code
		; Not reached.
		;
		; Debug the malloc byte counts.
		;push '%'|'X'<<8|10<<16
		;mov eax, esp
		;push ebp
		;push eax
		;call PrintMsg
		;add esp, 12
%endif
.alloced:
		mov [esi], eax  ; Return result to caller in EAX.
		jmp done_handling  ; Force success, because EAX is not 0.
handle_INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME:  ; !! WDOSX and PMODE/W (e.g. _int213C) don't extend it. !! What else?
		mov eax, esi	    ; jumptable 00410ED7 case 23
		call func_INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME
		jmp done_handling
handle_INT21H_FUNC_60H_GET_FULL_FILENAME:  ; !! WDOSX and PMODE/W (e.g. _int213C) don't extend it. What else?
		mov eax, esi	    ; jumptable 00410ED7 case 24
		call func_INT21H_FUNC_60H_GET_FULL_FILENAME
		jmp done_handling
handle_INT21H_FUNC_4CH_EXIT_PROCESS:
		push dword [esi]	    ; jumptable 00410ED7 case 19
		jmp exit_pushed
		; Not reached.
handle_INT21H_FUNC_44H_IOCTL_IN_FILE:
		cmp byte [esi], 0  ; jumptable 00410ED7 case 16
		jnz handle_unsupported_int21h_function  ; jumptable 00410ED7 case 0
		xor eax, eax
		mov ax, [esi+4]
		mov dword [esi+0Ch], 0
		mov eax, [stdin_handle+eax*4]
		push eax	     ; hFile
		call [__imp__GetFileType]
		cmp eax, 2
		jnz .skip
		mov dword [esi+0Ch], 80h
.skip:		xor eax, eax  ; Set CF=0 (success) in returned flags.
		jmp loc_410BE9
handle_unsupported_int21h_function:
		xor eax, eax	    ; jumptable 00410ED7 case 0
		mov al, [esi+1]
		push eax
		push aUnsupportedInt  ; "Unsupported int 21h function AH=%h\r\n"
		call PrintMsg
		add esp, 8
		jmp dos_error

populate_stdio_handles:
		push ecx
		push edx
		push STD_INPUT_HANDLE  ; nStdHandle
		call [__imp__GetStdHandle]
		push STD_OUTPUT_HANDLE  ; nStdHandle
		mov [stdin_handle], eax
		call [__imp__GetStdHandle]
		push STD_ERROR_HANDLE  ; nStdHandle
		mov [stdout_handle], eax
		call [__imp__GetStdHandle]
		mov [stderr_handle], eax
		pop edx
		pop ecx
		ret

; language_t __usercall WResLanguage@<al.4>()
WResLanguage:
		push ebx
		push edx	     ;  dword  4 
		mov eax, envvar_name_wlang  ; "WLANG"
		call getenv
		mov ebx, eax
		test eax, eax
		jnz loc_4111C2
		cmp dword [is_code_page_maybe_japanese], 0
		jz loc_4111F3
loc_4111BD:
		mov al, LANG_JAPANESE
		pop edx
		pop ebx
		ret
loc_4111C2:
		mov edx, aEnglish  ; "english"
		call stricmp
		test eax, eax
		jz loc_4111F3
		mov edx, aJapanese  ; "japanese"
		mov eax, ebx	    ; s1
		call stricmp
		test eax, eax
		jz loc_4111BD
		xor eax, eax
		mov al, [ebx]
		cmp eax, '0'
		jl loc_4111F3
		cmp eax, '9'
		jg loc_4111F3
		sub al, '0'
		pop edx
		pop ebx
		ret
loc_4111F3:
		xor al, al
		pop edx
		pop ebx
		ret

section .rodata

a0123456789abcde db '0123456789abcdefghijklmnopqrstuvwxyz',0

section .text

utoa:
		push ecx
		push esi
		push edi
		push ebp
		sub esp, 28h
		mov ebp, edx
		mov edi, ebx
		mov esi, edx
		xor dl, dl
		lea ecx, [esp+38h-37h]
		mov byte [esp+38h-38h], dl
loc_411233:
		lea ebx, [esp+38h-14h]
		mov dword [esp+38h-14h], edi
		xor edx, edx
		div dword [ebx]
		mov [ebx], eax
		mov al, [a0123456789abcde+edx]
		mov [ecx], al
		mov eax, dword [esp+38h-14h]
		inc ecx
		test eax, eax
		jnz loc_411233
loc_411253:
		dec ecx
		mov al, [ecx]
		mov [esi], al
		inc esi
		test al, al
		jnz loc_411253
		mov eax, ebp
		add esp, 28h
		pop ebp
		pop edi
		pop esi
		pop ecx
		ret

itoa:
		push ecx
		mov ecx, edx
		cmp ebx, 10
		jnz loc_411279
		test eax, eax
		jge loc_411279
		neg eax
		mov byte [edx], '-'
		inc edx
loc_411279:
		call utoa
		mov eax, ecx
		pop ecx
		ret

; !! Make it much shorter!
strcmp:
		push ebx
		push ecx
		mov ebx, eax
		cmp eax, edx
		jz loc_411304
loc_411298:
		mov eax, [ebx]
		mov ecx, [edx]
		cmp ecx, eax
		jnz loc_411309
		not ecx
		add eax, 0FEFEFEFFh
		and eax, ecx
		and eax, 80808080h
		jnz loc_411304
		mov eax, [ebx+4]
		mov ecx, [edx+4]
		cmp ecx, eax
		jnz loc_411309
		not ecx
		add eax, 0FEFEFEFFh
		and eax, ecx
		and eax, 80808080h
		jnz loc_411304
		mov eax, [ebx+8]
		mov ecx, [edx+8]
		cmp ecx, eax
		jnz loc_411309
		not ecx
		add eax, 0FEFEFEFFh
		and eax, ecx
		and eax, 80808080h
		jnz loc_411304
		mov eax, [ebx+0Ch]
		mov ecx, [edx+0Ch]
		cmp ecx, eax
		jnz loc_411309
		add ebx, 10h
		add edx, 10h
		not ecx
		add eax, 0FEFEFEFFh
		and eax, ecx
		and eax, 80808080h
		jz loc_411298
loc_411304:
		sub eax, eax
		pop ecx
		pop ebx
		ret
loc_411309:
		cmp al, cl
		jnz loc_41132A
		cmp al, 0
		jz loc_411304
		cmp ah, ch
		jnz loc_41132A
		cmp ah, 0
		jz loc_411304
		shr eax, 10h
		shr ecx, 10h
		cmp al, cl
		jnz loc_41132A
		cmp al, 0
		jz loc_411304
		cmp ah, ch
loc_41132A:
		sbb eax, eax
		or al, 1
		pop ecx
		pop ebx
		ret

; !! Make this shorter.
strncpy:
		push ecx
		push esi
		mov esi, eax
		jmp loc_411342
loc_411337:
		mov cl, [edx]
		test cl, cl
		jz loc_411346
		inc edx
		dec ebx
		mov [eax], cl
		inc eax
loc_411342:
		test ebx, ebx
		jnz loc_411337
loc_411346:
		test ebx, ebx
		jz loc_411351
		dec ebx
		mov byte [eax], 0
		inc eax
		jmp loc_411346
loc_411351:
		mov eax, esi
		pop esi
		pop ecx
		ret

; int __usercall __spoils<edx> stricmp@<eax>(const char *s1@<eax>, const char *s2@<edx>)
stricmp:
		push ebx
loc_4113B1:
		mov bl, [eax]
		mov bh, [edx]
		cmp bl, 'A'
		jb loc_4113C2
		cmp bl, 'Z'
		ja loc_4113C2
		add bl, 20h  ; ' '
loc_4113C2:
		cmp bh, 'A'
		jb loc_4113CF
		cmp bh, 'Z'
		ja loc_4113CF
		add bh, 20h
loc_4113CF:
		cmp bl, bh
		jnz loc_4113DB
		test bh, bh
		jz loc_4113DB
		inc eax
		inc edx
		jmp loc_4113B1
loc_4113DB:
		xor edx, edx
		xor eax, eax
		mov dl, bl
		mov al, bh
		sub edx, eax
		mov eax, edx
		pop ebx
		ret

section .rodata

aCanTOpenSRcD	db 'Can',27h,'t open ',27h,'%s',27h,'; rc=%d',0Dh,0Ah,0
aInvalidExe	db 'Invalid EXE',0Dh,0Ah,0
aLoaderReadError db 'Loader read error',0Dh,0Ah,0
aMemoryAllocation db 'Memory allocation failed',0Dh,0Ah,0
aJapaneseCanTOpenSRcD db 83h,'I',81h,'[',83h,'v',83h,93h,82h,'ł',0ABh,82h,'܂',0B9h,82h,0F1h,20h,27h,25h
		db 's',27h,'; rc=%d',0Dh,0Ah,0
aJapaneseaInvalidExe db 95h,'s',90h,0B3h,82h,0C8h,20h,'EXE',0Dh,0Ah,0
aJapaneseLoaderReadError db 83h,8Dh,81h,'[',83h,'_',81h,'[',93h,'ǂݍ',9Eh,82h,'݃G',83h,89h,81h,'['
		db 0Dh,0Ah,0
aJapaneseMemoryAllocation db 83h, 81h, 83h, 82h, 83h, 8Ah, 8Ah, 84h, 82h, 0E8h
		db 95h, 74h, 82h, 0AFh, 82h, 0AAh, 8Eh, 0B8h, 94h
		db 's',82h,0B5h,82h,'܂',0B5h,82h,0BDh,0Dh,0Ah,0
; char fmt[]
fmt		db 'Environment Variables:',0Dh,0Ah,0
; char aS[]
aS		db '%s',0Dh,0Ah,0
dump_filename	db '_watcom_.dmp',0
; char aProgramS[]
aProgramS	db 'Program: %s',0Dh,0Ah,0
; char aCmdlineS[]
aCmdlineS	db 'CmdLine: %s',0Dh,0Ah,0
; char aS_0[]
aS_0		db '**** %s ****',0Dh,0Ah,0
; char aOsNtBaseaddrXC[]
aOsNtBaseaddrXC db 'OS=NT BaseAddr=%X CS:EIP=%x:%X SS:ESP=%x:%X',0Dh,0Ah,0
; char aEaxXEbxXEcxXEd[]
aEaxXEbxXEcxXEd db 'EAX=%X EBX=%X ECX=%X EDX=%X',0Dh,0Ah,0
; char aEsiXEdiXEbpXFl[]
aEsiXEdiXEbpXFl db 'ESI=%X EDI=%X EBP=%X FLG=%X',0Dh,0Ah,0
; char aDsXEsXFsXGsX[]
aDsXEsXFsXGsX	db 'DS=%x ES=%x FS=%x GS=%x',0Dh,0Ah,0
; char fmt_percent_hx[]
fmt_percent_hx	db '%X ',0
; char str_crlf[]
str_crlf	db 0Dh,0Ah,0
; char aCsEip[]
aCsEip		db 'CS:EIP -> ',0
; char fmt_percent_h[]
fmt_percent_h	db '%h ',0
aAccessViolatio db 'Access violation',0
aPrivilegedInst db 'Privileged instruction',0
aIllegalInstruc db 'Illegal instruction',0
aIntegerDivideB db 'Integer divide by 0',0
aStackOverflow	db 'Stack overflow',0
aCon		db 'con',0
; char aUnsupportedInt[]
aUnsupportedInt db 'Unsupported int 21h function AH=%h',0Dh,0Ah  ; Continues in empty_env.
empty_env	db 0  ; Continues in empty_str.
empty_str	db 0
; char envvar_name_wlang[]
envvar_name_wlang db 'WLANG',0
; char aEnglish[]
aEnglish	db 'english',0
; char aJapanese[]
aJapanese	db 'japanese',0

english_errors	dd empty_str  ; ""  ; Corresponding to LOAD_ERROR_SUCCESS .. LOAD_ERROR_OUT_OF_MEMORY.
		dd aCanTOpenSRcD  ; "Can't open '%s'; rc=%d\r\n"
		dd aInvalidExe	; "Invalid EXE\r\n"
		dd aLoaderReadError  ; "Loader read error\r\n"
		dd aMemoryAllocation  ; "Memory allocation failed\r\n"
japanese_errors dd empty_str  ; ""
		dd aJapaneseCanTOpenSRcD
		dd aJapaneseaInvalidExe
		dd aJapaneseLoaderReadError
		dd aJapaneseMemoryAllocation
dword_420294	dd 14h

section .data

is_code_page_maybe_japanese dd 0
; unsigned int MsgFileHandle
MsgFileHandle dd FILENO_STDOUT
wcfd32_param_struct:  ; Contains 7 dd fields, see below.
  wcfd32_program_filename dd empty_str  ; ""
  wcfd32_command_line dd empty_str  ; ""
  wcfd32_env_strings dd empty_env
  wcfd32_unknown_param3 dd 0
  wcfd32_unknown_param4 dd 0
  wcfd32_unknown_param5 dd 0
  wcfd32_unknown_param6 dd 0

section .bss

image_base_for_debug resd 1
; HANDLE stdin_handle
stdin_handle	resd 1
; HANDLE stdout_handle
stdout_handle	resd 1
stderr_handle	resd 1
other_stdio_handles resd 61  ; 64 in total.
dta_addr	resd 1
force_last_error resd 1
malloc_base	resd 1  ; Address of the currently allocated block.
malloc_capacity	resd 1  ; Total number of bytes in the currently allocated block.
malloc_rest	resd 1  ; Number of bytes available at the end of the currently allocated block.
had_ctrl_c	resb 1