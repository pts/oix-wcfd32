;
; wcfd32dosexe.nasm: builds oixrun.exe, a combined MZ (PMODE/W), LE (DOS 32-bit runner) and Win32 PE (Win32 runner), CF (oixrun.oix) executable
; by pts@fazekas.hu at Tue Apr 30 04:49:07 CEST 2024
;
; This contains a manual replacement for: wlink form os2 le op stub=pmodew133.exe op q n w.exe f wcfd32dos.obj
; This contains a manual replacement for: wlink form win nt ru con=3.10 op stub=wcfd32dosp.exe op q op d op h=1 com h=0 n wcfd32win32.exe f wcfd32win32.obj
;
; The .exe file was created by OpenWatcom 1.4 WLINK.
;

bits 32
cpu 386

%macro assert_at 1
  times  (%1)-($-$$) times 0 db 0
  times -(%1)+($-$$) times 0 db 0
%endm

%macro assert_eq 2
  times  (%1)-(%2) times 0 db 0
  times -(%1)+(%2) times 0 db 0
%endm

%macro assert_le 2  ; If false, NASM issueas a warning, and continues compilation.
  times (%2)-(%1) times 0 db 0
%endm

section .le.text align=1

file:
pe.header_section:
mz_header:
.signature:	db 'MZ'
.lastsize:	dw (dos_stub_end-file)&0x1ff
.nblocks:	dw (dos_stub_end-file+0x1ff)>>9
.nreloc:	dw 0
.hdrsize:	dw (dos_image-file)>>4
assert_at 0xa
%macro emit_cf_header 0
  cf_header:
  .signature:	dd 'CF'
  .load_fofs:	dd oixrun_image-file
  .load_size:	dd oixrun_image.end-oixrun_image
  .reloc_rva:	;dd ?
  ;.mem_size:	dd ?
  ;.entry_rva:	dd ?
  incbin 'oixrun.oix', 0xc, 0xc
%endm
;.minalloc:	dw ?
;.maxalloc:	dw ?
;.ss:		dw ?
;.sp:		dw ?
;.checksum:	dw ?
;.ip:		dw ?
;.cs:		dw ?
incbin 'pmodew133.exe', 0xa, 0x18-0xa
assert_at 0x18
.relocpos:	dw 0x40  ; WLINK changed 0x3a to 0x40. It doesn't matter, there are no relocs in PMODE/W (.nrelocs==0). !! Change it to 0.
.noverlay:	;dw 0
incbin 'pmodew133.exe', 0x1a, 0x20-0x1a
assert_at 0x20
emit_cf_header
assert_at 0x38
le_ofs:
..@0x0038: dd le_header-file
pe_ofs:
..@0x003c: dd pe_header-file
assert_at 0x40
times (file-$)&(0x10-1) db 0  ; dos_image must be aligned to 0x10.
dos_image:
assert_at 0x40
; PMODE/W config (struct cfg). The /... flags are for pmwsetup.exe.
pmodew_config:
%if 0  ; PMODE/W 1.33 defaults.
.pagetables	db 4		; /V number of page tables under VCPI; Number of VCPI page tables to allocate. Each page table needs 4 KiB, and gives 4 MiB of memory for VCPI. These are allocated only for VCPI.
.selectors	dw 0x100	; /S max selectors under VCPI/XMS/raw; VCPI/XMS/Raw maximum selectors.
.rmstacklen	dw 0x40		; /R real mode stack length, in para; Real mode stack length (in paragraphs).
.pmstacklen	dw 0x80		; /P protected mode stack length, in para; Protected mode stack length (in paragraphs).
.rmstacks	db 8		; /N real mode stack nesting; Real mode stack nesting.
.pmstacks	db 8		; /E protected mode stack nesting; Protected mode stack nesting.
.callbacks	db 0x20		; /C number of real mode callbacks; Number of real mode callbacks.
.mode		db 1		; /M mode bits; VCPI/DPMI detection mode (0=DPMI first, 1=VCPI first).
.pamapping	db 1		; /A physical address mappings; Number of physical address mapping page tables.
.crap		dw 0		; Unused.
.options	db 1		; /B option flags; Display copyright message at startup (0=No, 1=Yes).
.extmax	dd 0x7fffffff	; /X maximum extended memory to allocate; Maximum extended memory to allocate (in bytes).
.lowmin	dw 0		; /L amount of low memory to try and save; Low memory to reserve (in paragraphs)
%elif 0  ; PMODE/W 1.33 defaults, but hide the copyright message.
.pagetables	db 4
.selectors	dw 0x100
.rmstacklen	dw 0x40
.pmstacklen	dw 0x80
.rmstacks	db 8
.pmstacks	db 8
.callbacks	db 0x20
.mode		db 1
.pamapping	db 1
.crap		dw 0
.options	db 0
.extmax	dd 0x7fffffff
.lowmin	dw 0
%else  ; Settings optimized to save conventional memory for WCFD32.
; We tweak these settings to get some extra free conventional memory. By
; default, DOSBox has 40546 paragraphs (~633 KiB) free, kvikdos has 40688
; paragraphs (~635 KiB) free. Out of this, PMODE/W and the runner
; wcfd32dos.nasm (including 4 KiB of stack for the program) uses 1943
; paragraphs (~30 KiB) with these tweaks, and 3735 paragraphs (~58 KiB) with
; the PMODE/W defaults. Thus these tweaks save about ~28 KiB of conventional
; memory.
.pagetables	db 0x10  ; Not a problem, only allocated for VCPI and if high memory (above 1 MiB) is available.
.selectors	dw 0x10  ; Doesn't save much.
.rmstacklen	dw 0x40
.pmstacklen	dw 0x40
.rmstacks	db 1
.pmstacks	db 1
.callbacks	db 0
.mode		db 0  ; DPMI first. It gives more memory.
.pamapping	db 0
.crap		dw 0
.options	db 0
.extmax	dd 0x7fffffff
.lowmin	dw 0
%endif
.end: assert_at (pmodew_config-$$)+0x15
incbin 'pmodew133.exe', 0x35, 0x1ee3-0x35 ; Copy the DOS stub image.
db le_ofs-file  ; Change the file offset from 0x3c to 0x38 at which PMODE/W looks for the LE header offset. This changes the compressed stream. Fortunately it doesn't affect subsequent repeat copies in this case.
incbin 'pmodew133.exe', 0x1ee4 ; Copy the DOS stub image.
dos_stub_end:
times (file-$)&(0x10-1) db 0  ; Align to 0x10. This padding is not part of pmodew133.exe, WLINK adds it in later phases for aligning the LE header after it.
assert_at 0x2d00

; --- Relocation and fixup generation.
;
; fixup record source (in .type, dl in PMODE/W _relocate2).
;OSF_SOURCE_MASK             equ 0x0f
;OSF_SOURCE_BYTE             equ 0x00  ; PMODE/W _r_byteoffset
;OSF_SOURCE_UNDEFINED1       equ 0x01  ; PMODE/W reports an error (_r_unknown).
;OSF_SOURCE_SEG              equ 0x02  ; PMODE/W _r_wordsegment  ; Supported by PMODE/W, jumps to _relocate2b. There is no target_ofs, PMODE/W uses the number 2 (!) as target_ofs.
;OSF_SOURCE_PTR_32           equ 0x03  ; PMODE/W _r_16bitfarptr
;OSF_SOURCE_UNDEFINED4       equ 0x04  ; PMODE/W reports an error (_r_unknown).
;OSF_SOURCE_OFF_16           equ 0x05  ; PMODE/W _r_16bitoffset
;OSF_SOURCE_PTR_48           equ 0x06  ; PMODE/W _r_32bitfarptr
 OSF_SOURCE_OFF_32           equ 0x07  ; PMODE/W _r_32bitoffset  ; target_ofs is dw or dd.
;OSF_SOURCE_OFF_32_REL       equ 0x08  ; PMODE/W _r_nearcalljmp
; PMODE/W reports an error (_r_unknown) for anything larger.
; fixup record source flags (in .type, dl in PMODE/W _relocate2).
;OSF_SFLAG_FIXUP_TO_ALIAS    equ 0x10
;OSF_SFLAG_LIST              equ 0x20  ; Not supported by PMODE/W.
; fixup record target (in .flags, dh in PMODE/W _relocate2).
;OSF_TARGET_MASK             equ 0x03
OSF_TARGET_INTERNAL         equ 0x00  ; Only this target is supported by PMODE/W.
;OSF_TARGET_EXT_ORD          equ 0x01  ; Not supported by PMODE/W.
;OSF_TARGET_EXT_NAME         equ 0x02  ; Not supported by PMODE/W.
;OSF_TARGET_INT_VIA_ENTRY    equ 0x03  ; Not supported by PMODE/W.
; fixup record target flag (in .flags, dh in PMODE/W _relocate2).
;OSF_TFLAG_ADDITIVE_VAL      equ 0x04  ; Not supported by PMODE/W.
;OSF_TFLAG_INT_CHAIN         equ 0x08
;OSF_TFLAG_OFF_32BIT         equ 0x10  : Respected by PMODE/W. Makes %%target_ofs dd instead of dw.
;OSF_TFLAG_ADD_32BIT         equ 0x20
;OSF_TFLAG_OBJ_MOD_16BIT     equ 0x40  ; Respected by PMODE/W. Makes %%object dw instead of db.
;OSF_TFLAG_ORDINAL_8BIT      equ 0x80
%macro fixup_o32_int 3  ; reloc_o32_int source_ofs, object, target_ofs  ; 7 bytes each.
; .type=7=OSF_SOURCE_OFF_32  ; Always 1 byte.
; .flags=0=OSF_TARGET_INTERNAL  ; Always 1 byte.  OSF_TARGET_INTERNAL|OSF_TARGET_ADDITIVE_VA, but PMODE/W doesn't support it (PMODE/W supports ~0x7 for .flags, ~0x20 for type). There is `mov' in PMODE/W _r_32bitoffset etc., so the actual data in the image is ignored and overwritten.
; .source_off=0x005f  ; Byte size is 1 if (f->type & OSF_SFLAG_LIST), otherwise 2.
; .object=1  ; Target object. Can be 1 (LE .text) or 2 (LE .bss). Byte size is 2 if (f->flags & OSF_TFLAG_OBJ_MOD_16BIT), otherwise 1.
; .target_off=0x0306  ; With (f->flags & OSF_TARGET_MASK) == OSF_TARGET_INTERNAL, byte size can be 0, 2 or 4 , depending on .type and .flags.
  %%type:        db OSF_SOURCE_OFF_32
  %%flags:       db OSF_TARGET_INTERNAL
  %%source_ofs:  dw %1  ; !! Is it within-page ofs? Check PMODE/W.
  %%object:      db %2
  %%target_ofs:  dw %3
%endm
..@0x2e1e:
%assign le_found_reloc_count 0
%macro le_set_fixup_at 3  ; %1 is le_found_reloc_count
  le_ary_reloc_at_ %+ %1 equ $-4-le.text
  le_ary_reloc_obj_ %+ %1 equ %2
  le_ary_reloc_val_ %+ %1 equ %3
%endm
%macro relocated_le.text 2+
  %define relval (%1)-le.text
  %2
  le_set_fixup_at le_found_reloc_count, objid_le.text, relval
  %undef relval
  %assign le_found_reloc_count le_found_reloc_count+1
%endm
%assign le_reloc_count 0
%macro le_add_fixup 1  ; %1 is le_reloc_count
  fixup_o32_int le_ary_reloc_at_ %+ %1, le_ary_reloc_obj_ %+ %1, le_ary_reloc_val_ %+ %1  ; All values will be defined later, by `relocated_le.text'.
  %assign le_reloc_count %1+1
%endm
%macro le_fixups 1
  %rep %1
    le_add_fixup le_reloc_count
  %endrep
%endm

; --- Common WCFD32 domain constants

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

; ---

section .le.text align=1
le.stack_size equ 0x1000  ; !! TODO(pts): Is this enough for a real-world program? It seems to be enough for NASM< but way too small for anything serious.
;le.stack_size equ 0x100000

le_header:
assert_at 0x2d00
; This LE header generation a manual replacement for: wlink form os2 le op stub=pmodew133.exe op q n w.exe f wcfd32dos.obj
;
; LE file format doc: https://faydoc.tripod.com/formats/exe-LE.htm
; LE file format doc: (documents both LX and LE, there is little difference.): https://github.com/yetmorecode/lxedit/blob/main/lx.h
;
; LE header and overhead sizes:
; * 0xc4 bytes for the LE header
; * 3*0x18 bytes (or just 2*0x18 bytes) for the object_table
; * >=0x16 bytes of non-fixup data after the object_table
; * >=8 bytes for fixup_page_table
; * >=7 bytes per fixup
; * up to 3 bytes for 4-byte alignment
; * up to 0xf bytes of alignment if WLINK adds a PE header afterwards
; * (nothing else)
; So the absolute minimum is 0x119 bytes + 7 bytes per fixup.
le_information_block:
; Offsets and sizes based on: https://github.com/yetmorecode/lxedit/blob/09de1f3d253cc9123b8392db1d466e586416fb33/info.c#L8-L49
; sizeof(IMAGE_DOS_HEADER) == 0x40.
; sizeof(os2_flat_header) == 0xc4.
; report("MZ header", 0, sizeof(IMAGE_DOS_HEADER))
; report("MZ relocations", sizeof(IMAGE_DOS_HEADER), exe->mz.e_cparhdr*16)
; report("MZ code", exe->mz.e_cparhdr*16, (exe->mz.e_cp-1)*512 + exe->mz.e_cblp)
; report("LX header", exe->mz.e_lfanew, exe->mz.e_lfanew + sizeof(os2_flat_header))
; report("LX loader", exe->mz.e_lfanew + sizeof(os2_flat_header), exe->mz.e_lfanew + sizeof(os2_flat_header) + exe->lx.loader_size)
; report("object table", exe->mz.e_lfanew + exe->lx.objtab_off, exe->mz.e_lfanew + exe->lx.objtab_off + exe->lx.num_objects*sizeof(object_record))
; report("page table", exe->mz.e_lfanew + exe->lx.objmap_off, exe->mz.e_lfanew + exe->lx.objmap_off + exe->lx.num_pages * (exe->lx.signature == OSF_FLAT_SIGNATURE ? sizeof(le_map_entry) : sizeof(lx_map_entry)))
; if (exe->lx.num_rsrcs) report("resource table", exe->mz.e_lfanew + exe->lx.rsrc_off, exe->mz.e_lfanew + exe->lx.rsrc_off + 16*exe->lx.num_rsrcs)
; report("name table", exe->mz.e_lfanew + exe->lx.resname_off, exe->mz.e_lfanew + exe->lx.entry_off)
; report("entry table", exe->mz.e_lfanew + exe->lx.entry_off, exe->mz.e_lfanew + exe->lx.entry_off + 1)
; if (exe->lx.cksum_off) report("checksum table", exe->mz.e_lfanew + exe->lx.cksum_off, exe->mz.e_lfanew + exe->lx.cksum_off)
; report("fixup table", exe->mz.e_lfanew + exe->lx.fixpage_off, exe->mz.e_lfanew + exe->lx.fixpage_off + (exe->lx.num_pages+1)*4)
; report("fixup records", exe->mz.e_lfanew + exe->lx.fixrec_off, exe->mz.e_lfanew + exe->lx.impmod_off)
; if (exe->lx.impproc_off > exe->lx.impmod_off) report("import mods", exe->mz.e_lfanew + exe->lx.impmod_off, exe->mz.e_lfanew + exe->lx.impproc_off)
; report("import proc", exe->mz.e_lfanew + exe->lx.impproc_off, exe->mz.e_lfanew + exe->lx.fixpage_off + exe->lx.fixup_size)
; report("LX pages", exe->lx.page_off, exe->lx.page_off + (exe->lx.num_pages-1)*exe->lx.page_size + exe->lx.l.last_page)
..@0x2d00:
.signature: db 'LE'  ; LX would be db 'LX'.
db 0  ; Byte order: little endian.
db 0  ; Word order: little endian.
dd 0  ; Executable format level.
dw 2  ; CPU type: Intel 386 or later.
dw 1  ; Target operating system. 01h: OS/2; 02h: Windows; 03h: DOS 4.x; 04h: Windows 386 (VxD).
dd 0  ; Module version.
..@0x2d10:
dd 0x200  ; Module type flags. 0x200: Compatible with PM (OS/2 Presentation Manager) windowing. PMODE/W ignores it.
dd ((le.text_end-le.text+0xfff)>>12)  ; 1. num_pages. Number of memory pages, excluding BSS and stack.
dd objid_le.text  ; Initial object CS number.
dd le.start-le.text  ; Initial EIP. Entry point.
..@0x2d20:
dd objid_le.text  ; Initial object SS number.
dd le.text_stack_end-le.text  ; Initial ESP. PMODE/W sets ESP to this + the SS object base.  ; Initial ESP.
dd 0x1000  ; Memory page size. Always 0x1000 for i386.
dd le.text_end-le.text  ; 0x31a. Bytes on last page.
..@0x2d30:
dd fixup_record_table_end-fixup_page_table+1  ; Fix-up section size. fixup_size. !! Why +1 byte?
dd 0 ; Fix-up section checksum. Ignored.
dd loader_section_end-le_header_end  ; Loader section size. loader_size.
dd 0  ; Loader section checksum. Ignored.
..@0x2d40:
dd object_table-le_header  ; 0xc4  ; Offset of object table.
dd (object_table_end-object_table)/0x18  ; Object table entries. It's actually the section table.
dd object_page_map-le_header  ; Object page map offset.
dd 0  ; Object iterate data map offset.
..@0x2d50:
dd resource_table-le_header  ; Resource table offset.
dd (resource_table_end-resource_table)/0x10  ; Resource table entries.
dd resident_names_table-le_header  ; Resident names table offset. Ends at `entry_table'. resname_off.
dd entry_table-le_header  ; Entry table offset. entry_off.
..@0x2d60:
dd 0  ; Module directives table offset.
dd 0  ; Module directives entries.
dd fixup_page_table-le_header ; Fix-up page table offset.
dd fixup_record_table-le_header  ; Fix-up record table offset.
..@0x2d70:
dd imported_modules_name_table-le_header  ; Imported modules name table offset.
dd 0  ; Imported modules count.
dd imported_procedures_name_table-le_header  ; Imported procedure name table offset
dd 0  ; Per-page checksum table offset.
..@0x2d80:
dd data_pages-file  ; Data pages offset from top of file.
dd 0  ; Preload page count.
dd 0  ; Non-resident names table offset from top of file.
dd 0  ; Non-resident names table length
..@0x2d90:
dd 0  ; Non-resident names table checksum.
dd 0  ; Automatic data (autodata) object.
dd 0  ; Debug information offset.
dd 0  ; Debug information length.
..@0x2da0:
dd 0  ; Preload instance pages number.
dd 0  ; Demand instance pages number.
dd 0  ; Extra heap allocation.
dd le.stack_size  ; Stack size. PMODE/W seems to ignore this field.
..@0x2db0:
times 5 dd 0  ; Windows VxD fields, we don't need them with PMODE/W.  https://github.com/yetmorecode/lxedit/blob/09de1f3d253cc9123b8392db1d466e586416fb33/lx.h#L102-L106
le_header_end:
..@0x2bc4:
assert_at le_header-$$+0xc4
object_table:
object_table_le.text:
objid_le.text equ ($-object_table)/0x18+1
.byte_size: dd le.text_stack_end-le.text  ; Larger than the number of bytes in the file, because it includes the stack as well.
.relocation_base: dd 0x10000  ; !! What does it mean?
OBJ_READABLE equ 1
OBJ_WRITEABLE equ 2
OBJ_EXECUTABLE equ 4
OBJ_BIG equ 0x2000
.object_flags: dd OBJ_BIG|OBJ_READABLE|OBJ_WRITEABLE|OBJ_EXECUTABLE  ; PMODE/W maps it to read-write-execute even without OBJ_WRITEABLE.
.page_map_index: dd 1
.page_map_entries: dd 1
.unknown: dd 0
object_table_end:
..@0x2e0c:
object_page_map:  ; Number of dds: num_pages.
entry_1:  ; Why not 0?
.page_number: db 0, 0, 1  ; 24 bits. Is this big-endian? If little-endian, then 0x10000. Same as object_table_le.text-relocation_base.
.flags: db 0
resource_table:
resource_table_end:
resident_names_table:
..@0x2e10:
name_1: db .end-$-1
db 'w'  ; The name of the output file (w.exe) without the extension.
.end:
name_1_ordinal: dw 0
terminator: db 0
entry_table:
..@0x2e15: db 0x00
loader_section_end:
fixup_page_table:  ; Number of dds: 1+num_pages. This is an index for fixup_record_table, for quick lookups.
..@0x2e16: dd 0, fixup_record_table_end-fixup_record_table_page_0  ; !! What does it mean? Does PMODE/W use it?
fixup_record_table:  ; Relocations. https://github.com/yetmorecode/lxedit/blob/09de1f3d253cc9123b8392db1d466e586416fb33/lx.c#L6
fixup_record_table_page_0:
; TODO(pts): Move the fixups after le.text_end, thus we know their count.
le_fixups 17  ; There will be this many relocation, sets le_reloc_count.
fixup_record_table_end:
imported_modules_name_table:
imported_procedures_name_table:
..@0x2eb8: dd 0
data_pages:
le.text:

; ---
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

le.start:
%assign obss_size 0
%macro obss_resb 1
  %00 equ obss+obss_size
  %assign obss_size obss_size+(%1)
%endm
obss:  ; We overlap BSS with the start of our code. That's fine, the beginning of the code won't be used.
malloc_base	obss_resb 4  ; Address of the currently allocated block.
malloc_capacity	obss_resb 4  ; Total number of bytes in the currently allocated block.
malloc_rest	obss_resb 4  ; Number of bytes available at the end of the currently allocated block.
wcfd32_param_struct: obss_resb 0  ; Contains 7 dd fields, see below.
  wcfd32_program_filename obss_resb 4  ; dd empty_str  ; ""
  wcfd32_command_line obss_resb 4  ; dd empty_str  ; ""
  wcfd32_env_strings obss_resb 4  ; dd empty_env
  wcfd32_break_flag_ptr obss_resb 4
  wcfd32_copyright obss_resb 4
  wcfd32_is_japanese obss_resb 4
  wcfd32_max_handle_for_os2 obss_resb 4
obss_align4: obss_resb 0
obss_align44: obss_resb (obss-obss_align4)&3
obss_end: obss_resb 0

		push ds
		pop es  ; Default value is different.
		sti  ; Enable virtual interrupts. TODO(pts): Do we need it?
		; PMODE/W doesn't zero-initialized the BSS, so we do it. But we do it later, because here we still need our code.
		;int3  ; This would cause an exception, making PMODE/W dump the registers to video memory and exit.
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
		; Now: EBP: command-line arguments terminated by NUL; dword [esp]: DOS environment variable strings; EDI: full program pathname terminated by NUL.
		push edi
		relocated_le.text obss, mov edi, relval
		mov ecx, (obss_end-obss)>>2
		xor eax, eax
		rep stosd  ; PMODE/W initializes DF=1, good.
		assert_le obss_end, $
		pop edi
		pop ecx
		; Now: EBP: command-line arguments terminated by NUL; ECX: DOS environment variable strings; EDI: full program pathname terminated by NUL.
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
		;mov dword [wcfd32_copyright], 0  ; Not needed, we've zero-initialized obss.
		;mov dword [wcfd32_is_japanese], 0  ; Not needed, we've zero-initialized obss.
		;mov dword [wcfd32_max_handle_for_os2], 0  ; Not needed, we've zero-initialized obss.
		relocated_le.text wcfd32_break_flag_ptr, mov [relval], esp
		relocated_le.text wcfd32_program_filename, mov [relval], edi
		relocated_le.text wcfd32_command_line, mov [relval], ebp
		relocated_le.text wcfd32_env_strings, mov [relval], ecx
		xor ebx, ebx  ; Not needed by the ABI, just make it deterministic.
		xor esi, esi  ; Not needed by the ABI, just make it deterministic.
		xor ebp, ebp  ; Not needed by the ABI, just make it deterministic.
		sub ecx, ecx  ; This is an unknown parameter, which we always set to 0.
		relocated_le.text wcfd32_far_syscall, mov edx, relval
		relocated_le.text wcfd32_param_struct, mov edi, relval
		mov bx, cs  ; Segment of wcfd32_far_syscall for the far call.
		mov ah, WCFD32_OS_DOS  ; !! wasmx106.exe (loader16.asm) does OS_WIN16. !! Why? Which of DOS or OS2? Double check.
		push cs  ; For the `retf' of the far call.
		call oixrun_image
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

%ifdef DEBUG
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
%endif

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
.try_fit:	relocated_le.text malloc_base, mov eax, [relval]
		relocated_le.text malloc_rest, sub eax, [relval]
		relocated_le.text malloc_rest, sub [relval], ebp
		jc .full  ; We actually waste the rest of the current block, but for WASM it's zero waste.
		relocated_le.text malloc_capacity, add eax, [relval]
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
		relocated_le.text malloc_base, mov [relval], ebx  ; Newly allocated address.
		relocated_le.text malloc_rest, mov [relval], ecx
		relocated_le.text malloc_capacity, mov [relval], ecx
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
		mov ah, 48h
		xor ebx, ebx
		dec bx  ; Try to allocate maximum available conventional memory.
		int 21h
		jnc .oom  ; This should fail, returning in BX the number of paragraphs (16-byte blocks) available.
		test ebx, ebx
		jz .oom  ; All conventional memory is already allocated, possibly by the previous call to .oom_high.
		push ebx
		mov ah, 48h
		int 21h  ; Allocate maximum number of paragraphs available.
		pop ebx
		jc .oom
		shl ebx, 4
		relocated_le.text malloc_rest, mov [relval], ebx
		relocated_le.text malloc_capacity, mov [relval], ebx
		; PMODE/W (but not WDOSX): EAX is selector. !! Try DPMI syscall 100h instead, maybe they are compatible. But that allocates a selector in DX, we should free it.
		xchg ebx, eax  ; EBX := selector; EAX := junk.
		push edx  ; Save.
		mov ax, 6
		int 31h  ; Get segment base of BX. CX:DX.
		shl ecx, 16
		mov cx, dx  ; ECX := linear address of PSP.
		pop edx  ; Restore original value for the caller of malloc.
		relocated_le.text malloc_base, mov [relval], ecx
		;movzx eax, ax
		;shl eax, 4
		;relocated_le.text malloc_base, mov [relval], eax
		jmp .try_fit  ; It may not fit though.
.oom:		xor eax, eax  ; NULL.
.return:	pop ebp
		pop edi
		pop esi
		pop ecx
		pop ebx
		ret

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

		times (le.start-$)&3 db 0  ; Align to 4 bytes.
oixrun_image:	incbin 'oixrun.oix', 0x18
.end:

; Unfortunately the format LE 4 KiB of alignment between .code and .data, no
; way to make it smaller, but PMODE/W supports LE only. So we just put
; everything to .text to save a few KiB.
;
;section .le.data
;section .le.rodata

; --- End of LE.

section .le.text
le.text_end:
le.text_stack equ $+((le.text-$)&3)  ; Align to 4.
le.text_stack_end equ le.text_stack+le.stack_size
times 0x1000-($-le.text) times 0 db 0; Check that .le.text size is at most 0x1000 bytes (single page).
assert_eq le_reloc_count, le_found_reloc_count  ; Upon a difference, update the value of `le_fixups'.
section .le.text

; ---
;
; This PE header generation is manual replacement for: wlink form win nt ru
; con=3.10 op stub=wcfd32dosp.exe op q op d op h=1 com h=0 n wcfd32win32.exe
; f wcfd32win32.obj

; Generate a Win32 PE .exe executable purely in `nasm -f bin', without the
; need for `wlink form win nt'.
;
; This is a preliminary implementation, there is lots of room for optimization.
;

; Example, to be defined in wcfd32win32.nasm:
; %macro emit_ifuncs 1
;   %1 'WriteFile', WriteFile, 0
;   %1 'ExitProcess', ExitProcess, 0
; %endm
%macro emit_ifunc_ptr 3
  dd ifunc_%2+(idata_rva-pe.idata)
%endm
%macro emit_ifunc_ptr_label 3
  __imp__%2: dd ifunc_%2+(idata_rva-pe.idata)
%endm
%macro emit_ifunc_name 3  ; !! Can we do it without padding (%3 == 0 always)?
  %assign PE_IFUNC_NUMBER PE_IFUNC_NUMBER+1  ; !! Can we use all-zero ifunc_numbers?
  ifunc_%2: db PE_IFUNC_NUMBER, 0, %1, 0
  times %3 db 0
%endm
%macro pe.reloc.in.data.text.dd 1
  %assign THIS_RELOC_AT $-pe.data
  %assign  PE_RELOC_PADDING_IN_DATA PE_RELOC_PADDING_IN_DATA^1
  %xdefine PE_RELOCS_IN_DATA PE_RELOCS_IN_DATA PER32|THIS_RELOC_AT,
  dd image_base+(text_rva-pe.text)+(%1)
%endm
%macro pe.reloc.in.data.data.dd 1
  %assign THIS_RELOC_AT $-pe.data
  %assign  PE_RELOC_PADDING_IN_DATA PE_RELOC_PADDING_IN_DATA^1
  %xdefine PE_RELOCS_IN_DATA PE_RELOCS_IN_DATA PER32|THIS_RELOC_AT,
  dd image_base+(data_rva-pe.data)+(%1)
%endm
%macro pe.switch.to.text 0
%endm
%macro pe.switch.to.data 0
  %define pe.switch.to.text DO_NOT_SWITCH_BACK_TO_TEXT
  %define pe.switch.to.data times 0 nop  ; Just nothing (idempotent).
  pe.text.uend:
  times (file-$)&0x1ff db 0  ; Align to PE file alignment.
  pe.text.end:
  pe.idata:
  import_directory_table0:  ; One for each DLL.
  ..@0x4400:
  .ImportLookupTableRVA: dd import_lookup_table+(idata_rva-pe.idata)
  .TimeDateStamp: dd 0
  .ForwarderChain: dd 0
  .NameRVA: dd import_dll_name+(idata_rva-pe.idata)
  ..@0x4410:
  .ImportAddressTableRVA: dd import_address_table+(idata_rva-pe.idata)
  ..@0x4414:
  times 5 dd 0  ; Indicates that there is no more imported DLL.
  import_lookup_table:
  ..@0x4428:
  %define PE_RELOCS_IN_DATA
  %define PE_RELOC_PADDING_IN_DATA 0
  %define pe.reloc.text.dd pe.reloc.in.data.text.dd
  %define pe.reloc.data.dd pe.reloc.in.data.data.dd
  emit_ifuncs emit_ifunc_ptr
  ..@0x44b8:
  dd 0  ; End of import lookup table.
  import_address_table:  ; !! Don't repeat this, overlap it with the import_lookup_table.
  ..@0x44bc:
  emit_ifuncs emit_ifunc_ptr_label
  ..@0x454c:
  dd 0  ; End of import address table.
  import_dll_name:
  ..@0x4550:
  db 'kernel32.dll', 0, 0
  ..@0x454e:
  %define PE_IFUNC_NUMBER 0
  emit_ifuncs emit_ifunc_name
  pe.idata.dirend:
  times (file-$)&0x1ff db 0  ; Align to PE file alignment.
  pe.idata.end:
  pe.data:
%endm
%macro pe.switch.to.bss 0
  %ifndef pe.switch.to.data
    pe.switch.to.data
  %endif
  %define pe.switch.to.data DO_NOT_SWITCH_BACK_TO_DATA
  %define pe.switch.to.bss  times 0 nop  ; Just nothing (idempotent).
  %define pe.resb pe.macro.resb
%endm
%define PE_RELOCS_IN_TEXT
%define PE_RELOC_PADDING_IN_TEXT 0
%macro pe.reloc.above 1
  %assign THIS_RELOC_AT $-(%1)-pe.text
  %assign  PE_RELOC_PADDING_IN_TEXT PE_RELOC_PADDING_IN_TEXT^1
  %xdefine PE_RELOCS_IN_TEXT PE_RELOCS_IN_TEXT PER32|THIS_RELOC_AT,
%endm
%macro pe.reloc 3+  ; %1 is number of bytes back from the end of the instruction (typically 4), %2 is PE_...REF(...), %3 is the instruction.
  %define relval %2
  %3
  %undef  relval
  pe.reloc.above %1
%endm
%define PE_TEXTREF(var)  ((var)+image_base+(text_rva-pe.text))
%define PE_DATAREF(var)  ((var)+image_base+(data_rva-pe.data))
%define PE_BSSREF(var)   ((var)+image_base+(data_rva-pe.data))  ; pe.bss is within pe.data.
%define PE_IDATAREF(var) ((var)+image_base+(idata_rva-pe.idata))
%macro pe.call.imp 1
  call [PE_IDATAREF(__imp__%1)]
  pe.reloc.above 4
%endm
%macro pe.jmp.imp 1
  jmp [PE_IDATAREF(__imp__%1)]
  pe.reloc.above 4
%endm
%macro pe.macro.resb 1
  times (%1) db 0  ; !! Overlap with the beginning of pe.text.
%endm
times (file-$)&(0x10-1) db 0  ; Align to 0x10. This padding is not part of wcfd32dos.exe, it's added in later phases for aligning the PE header after it. !! Align only to 4.
..@0x32e0:
assert_at 0x32e0
pe_header:  ; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format
..@0x31e0:
Signature: db 'PE', 0, 0
..@0x31e4:
coff_header:
IMAGE_FILE_MACHINE_I386 equ 0x014c
.Machine: dw IMAGE_FILE_MACHINE_I386
.NumberOfSections: dw (section_header.end-section_header)/0x28
.TimeDateStamp: dd 0  ; Forced to 0 for reproducibility.
.PointerToSymbolTable: dd 0
..@0x31f0:
.NumberOfSymbols: dd 0
.SizeOfOptionalHeader: dw optional_header.end-optional_header
IMAGE_FILE_EXECUTABLE_IMAGE equ 2
IMAGE_FILE_LINE_NUMS_STRIPPED equ 4  ; !! Add.
IMAGE_FILE_LOCAL_SYMS_STRIPPED equ 8  ; !! Add.
IMAGE_FILE_BYTES_REVERSED_LO equ 0x80  ; !! Deprecated, shouldn't be specified.
IMAGE_FILE_32BIT_MACHINE equ 0x100
IMAGE_FILE_DEBUG_STRIPPED equ 0x200  ; !! Add.
IMAGE_FILE_DLL equ 0x2000
.Characteristics: dw IMAGE_FILE_EXECUTABLE_IMAGE|IMAGE_FILE_BYTES_REVERSED_LO|IMAGE_FILE_32BIT_MACHINE
optional_header:
PE32_MAGIC equ 0x010b
.Magic: dw PE32_MAGIC
.MajorLinkerVersion: db 2
.MinorLinkerVersion: db 18
.SizeOfCode: dd pe.text.end-pe.text
..@0x3200:
.SizeOfInitializedData: dd 0x800  ; !! why? Can we set it to 0? How do we get it?
.SizeOfUninitializedData: dd 0  ; !! why 0? Can we set it to 0?
.AddressOfEntryPoint: dd pe_start+(text_rva-pe.text)
header_rva equ 0
text_rva equ 0x4000
idata_rva equ 0x5000
data_rva equ 0x6000
reloc_rva equ 0x8000
.BaseOfCode: dd text_rva
..@0x3210:
.BaseOfData: dd idata_rva
;image_base equ 0x10000000  ; Default for DLLs.
image_base equ 0x400000  ; Default for executables.
.ImageBase: dd image_base
.SectionAlignment: dd 0x1000  ; Typical minimum for Windows NT.
.FileAlignment: dd 0x200  ; Typical minimum for Windows NT.
..@0x3220:
.MajorOperatingSystemVersion: dw 1
.MinorOperatingSystemVersion: dw 0xb
.MajorImageVersion: dw 0
.MinorImageVersion: dw 0
.MajorSubsystemVersion: dw 3
.MinorSubsystemVersion: dw 10
.Win32VersionValue: dd 0
.SizeOfImage: dd reloc_rva+((pe.reloc.end-pe.reloc+0xfff)&~0xfff)  ; TODO(pts): Merge sections.
.SizeOfHeaders: dd pe.header_section.end-pe.header_section  ; Must be aligned to FileAlignment, but Windows accepts anything.
..@0x3230:
.CheckSum: dd 0
IMAGE_SUBSYSTEM_WINDOWS_GUI equ 2
IMAGE_SUBSYSTEM_WINDOWS_CUI equ 3  ; Console.
.Subsystem: dw IMAGE_SUBSYSTEM_WINDOWS_CUI
.DllCharacteristics: dw 0
..@0x3240:
; `option heapsize=' is ignored by WLINK, SizeOfHeapReserve will always be
; 0. `commit heap=' is saved to SizeOfHeapCommit. SizeOfHeapCommit matters
; for mwpestub LocalAlloc and HeapAlloc. It's not needed by Win32
; LocalAlloc or mwpestub VirtualAlloc.
.SizeOfStackReserve: dd 0x1000
.SizeOfStackCommit: dd 0x1000
.SizeOfHeapReserve: dd 1
.SizeOfHeapCommit: dd 0
..@0x3250:
.LoaderFlags: dd 0
.NumberOfRvaAndSizes: dd (optional_header.end-data_directories)>>3  ; !! 6 is the minimum count accepted by WDOSX. It crashes for less. What about Win32?
data_directories:
..@0x3258:
dir0_export_table: dd 0, 0  ; `dd rva, size'.
..@0x3260:
dir1_import_table: dd idata_rva, pe.idata.dirend-pe.idata
dir2_resource_table: dd 0, 0
..@0x3270:
dir3_exception_table: dd 0, 0
dir4_cretificate_table: dd 0, 0
..@0x3280:
dir5_base_relocation_table: dd reloc_rva, pe.reloc.dirend-pe.reloc
..@0x3288:
times 10 dd 0, 0
optional_header.end:
section_header:
..@0x32d8:
IMAGE_SCN_CNT_CODE equ 0x20
IMAGE_SCN_CNT_INITIALIZED_DATA equ 0x40
IMAGE_SCN_MEM_DISCARDABLE equ 0x2000000
IMAGE_SCN_MEM_EXECUTE equ 0x20000000
IMAGE_SCN_MEM_READ equ 0x40000000
IMAGE_SCN_MEM_WRITE equ 0x80000000
section0_text:  ; !! Merge all sections to .text.
.Name: db '.text', 0, 0, 0
.VirtualSize: dd pe.text.uend-pe.text
.VirtualAddress: dd text_rva
.SizeOfRawData: dd pe.text.end-pe.text
.PointerToRawData: dd pe.text-file
.PointerToRelocations: dd 0
.PointerToLineNumbers: dd 0
.NumberOfRelocations: dw 0
.NumberOfLineNumbers: dw 0
.Characteristics: dd IMAGE_SCN_CNT_CODE|IMAGE_SCN_MEM_EXECUTE|IMAGE_SCN_MEM_READ
..@0x32f0:
section1_idata:
.Name: db '.idata', 0, 0
.VirtualSize: dd pe.idata.dirend-pe.idata
.VirtualAddress: dd idata_rva
.SizeOfRawData: dd pe.idata.end-pe.idata
.PointerToRawData: dd pe.idata-file
.PointerToRelocations: dd 0
.PointerToLineNumbers: dd 0
.NumberOfRelocations: dw 0
.NumberOfLineNumbers: dw 0
.Characteristics: dd IMAGE_SCN_CNT_INITIALIZED_DATA|IMAGE_SCN_MEM_READ|IMAGE_SCN_MEM_WRITE
..@0x3328:
section2_data:
.Name: db '.data', 0, 0, 0
.VirtualSize: dd pe.data.uend-pe.data+pe.bss.size
.VirtualAddress: dd data_rva
.SizeOfRawData: dd pe.data.end-pe.data
.PointerToRawData: dd pe.data-file
.PointerToRelocations: dd 0
.PointerToLineNumbers: dd 0
.NumberOfRelocations: dw 0
.NumberOfLineNumbers: dw 0
.Characteristics: dd IMAGE_SCN_CNT_INITIALIZED_DATA|IMAGE_SCN_MEM_READ|IMAGE_SCN_MEM_WRITE
..@0x3350:
section3_reloc:
.Name: db '.reloc', 0, 0
.VirtualSize: dd 0  ; Process, but don't load.
.VirtualAddress: dd reloc_rva
.SizeOfRawData: dd pe.reloc.end-pe.reloc
.PointerToRawData: dd pe.reloc-file
.PointerToRelocations: dd 0
.PointerToLineNumbers: dd 0
.NumberOfRelocations: dw 0
.NumberOfLineNumbers: dw 0
.Characteristics: dd IMAGE_SCN_CNT_INITIALIZED_DATA|IMAGE_SCN_MEM_DISCARDABLE|IMAGE_SCN_MEM_READ
..@0x3378:
section_header.end:
times (file-$)&0x1ff db 0  ; Align to PE file alignment.
pe.header_section.end:
pe.text:

; ---
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
; !! Remove trailing NUL bytes.
;
; TODO(pts): Use a single section, create the PE with NASM (and 208
; relocations).
;

%macro emit_ifuncs 1
  ; !! TODO(pts): Is it OK that this is not sorted? The spec doesn't say. WLINK seems to sort it.
  ; WLINK will add even unused (i.e. no extern) import directives to the .exe, so we only list here what we really use.
  ; Corresponding WLINK .lnk directives: import '_GetStdHandle' 'kernel32.dll'.GetStdHandle
  %1 'GetStdHandle', GetStdHandle, 1  ;; HANDLE __stdcall GetStdHandle (DWORD nStdHandle);
  %1 'WriteFile', WriteFile, 0  ;; BOOL __stdcall WriteFile (HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED lpOverlapped);
  %1 'ExitProcess', ExitProcess, 0  ;; void __stdcall __noreturn ExitProcess (UINT uExitCode);
  %1 'GetFileType', GetFileType, 0  ;; DWORD __stdcall GetFileType (HANDLE hFile);
  %1 'SetFilePointer', SetFilePointer, 1  ;; DWORD __stdcall SetFilePointer (HANDLE hFile, LONG lDistanceToMove, PLONG lpDistanceToMoveHigh, DWORD dwMoveMethod);
  %1 'DeleteFileA', DeleteFileA, 0  ;; BOOL __stdcall DeleteFileA (LPCSTR lpFileName);
  %1 'SetEndOfFile', SetEndOfFile, 1  ;; BOOL __stdcall SetEndOfFile (HANDLE hFile);
  %1 'CloseHandle', CloseHandle, 0  ;; BOOL __stdcall CloseHandle (HANDLE hObject);
  %1 'MoveFileA', MoveFileA, 0  ;; BOOL __stdcall MoveFileA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName);
  %1 'SetCurrentDirectoryA', SetCurrentDirectoryA, 1  ;; BOOL __stdcall SetCurrentDirectoryA (LPCSTR lpPathName);
  %1 'GetLocalTime', GetLocalTime, 1  ;; void __stdcall GetLocalTime (LPSYSTEMTIME lpSystemTime);
  %1 'GetLastError', GetLastError, 1  ;; DWORD __stdcall GetLastError ();
  %1 'GetCurrentDirectoryA', GetCurrentDirectoryA, 1  ;; DWORD __stdcall GetCurrentDirectoryA (DWORD nBufferLength, LPSTR lpBuffer);
  %1 'GetFileAttributesA', GetFileAttributesA, 1  ;; DWORD __stdcall GetFileAttributesA (LPCSTR lpFileName);
  %1 'FindClose', FindClose, 0  ;; BOOL __stdcall FindClose (HANDLE hFindFile);
  %1 'FindFirstFileA', FindFirstFileA, 1  ;; HANDLE __stdcall FindFirstFileA (LPCSTR lpFileName, LPWIN32_FIND_DATAA lpFindFileData);
  %1 'FindNextFileA', FindNextFileA, 0  ;; BOOL __stdcall FindNextFileA (HANDLE hFindFile, LPWIN32_FIND_DATAA lpFindFileData);
  %1 'LocalFileTimeToFileTime', LocalFileTimeToFileTime, 0  ;; BOOL __stdcall LocalFileTimeToFileTime (const FILETIME *lpLocalFileTime, LPFILETIME lpFileTime);
  %1 'DosDateTimeToFileTime', DosDateTimeToFileTime, 0  ;; BOOL __stdcall DosDateTimeToFileTime (WORD wFatDate, WORD wFatTime, LPFILETIME lpFileTime);
  %1 'FileTimeToDosDateTime', FileTimeToDosDateTime, 0  ;; BOOL __stdcall FileTimeToDosDateTime (const FILETIME *lpFileTime, LPWORD lpFatDate, LPWORD lpFatTime);
  %1 'FileTimeToLocalFileTime', FileTimeToLocalFileTime, 0  ;; BOOL __stdcall FileTimeToLocalFileTime (const FILETIME *lpFileTime, LPFILETIME lpLocalFileTime);
  %1 'GetFullPathNameA', GetFullPathNameA, 1  ;; DWORD __stdcall GetFullPathNameA (LPCSTR lpFileName, DWORD nBufferLength, LPSTR lpBuffer, LPSTR *lpFilePart);
  %1 'SetFileTime', SetFileTime, 0  ;; BOOL __stdcall SetFileTime (HANDLE hFile, const FILETIME *lpCreationTime, const FILETIME *lpLastAccessTime, const FILETIME *lpLastWriteTime);
  %1 'GetFileTime', GetFileTime, 0  ;; BOOL __stdcall GetFileTime (HANDLE hFile, LPFILETIME lpCreationTime, LPFILETIME lpLastAccessTime, LPFILETIME lpLastWriteTime);
  %1 'ReadFile', ReadFile, 1  ;; BOOL __stdcall ReadFile (HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, LPOVERLAPPED lpOverlapped);
  %1 'SetConsoleMode', SetConsoleMode, 1  ;; BOOL __stdcall SetConsoleMode (HANDLE hConsoleHandle, DWORD dwMode);
  %1 'GetConsoleMode', GetConsoleMode, 1  ;; BOOL __stdcall GetConsoleMode (HANDLE hConsoleHandle, LPDWORD lpMode);
  %1 'CreateFileA', CreateFileA, 0  ;; HANDLE __stdcall CreateFileA (LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
  %1 'SetConsoleCtrlHandler', SetConsoleCtrlHandler, 0  ;; BOOL __stdcall SetConsoleCtrlHandler (PHANDLER_ROUTINE HandlerRoutine, BOOL Add);
  %1 'GetModuleFileNameA', GetModuleFileNameA, 1  ;; DWORD __stdcall GetModuleFileNameA (HMODULE hModule, LPSTR lpFilename, DWORD nSize);
  %1 'GetEnvironmentStrings', GetEnvironmentStrings, 0  ;; LPCH __stdcall GetEnvironmentStrings ();
  %1 'GetCommandLineA', GetCommandLineA, 0  ;; LPSTR __stdcall GetCommandLineA ();
  %1 'GetCPInfo', GetCPInfo, 0  ;; BOOL __stdcall GetCPInfo (UINT CodePage, LPCPINFO lpCPInfo);
  %1 'ReadConsoleInputA', ReadConsoleInputA, 0  ;; BOOL __stdcall ReadConsoleInputA (HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
  %1 'PeekConsoleInputA', PeekConsoleInputA, 0  ;; BOOL __stdcall PeekConsoleInputA (HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
  ;%1 'LocalAlloc',  LocalAlloc, 1  ;; HLOCAL __stdcall LocalAlloc (UINT uFlags, SIZE_T uBytes);
  %1 'VirtualAlloc', VirtualAlloc, 1  ;; LPVOID __stdcall VirtualAlloc(LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
%endm

STD_INPUT_HANDLE  equ -10
STD_OUTPUT_HANDLE equ -11
STD_ERROR_HANDLE  equ -12

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

pe.switch.to.text  ; section .text

; char *__usercall getenv@<eax>(const char *name@<eax>)
getenv:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		mov edi, eax
		pe.reloc 4, PE_DATAREF(wcfd32win32_env_strings), mov eax, [relval]
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

; int PrintMsg(const char *fmt, ...)
PrintMsg:
		push ebx
		push ecx
		push edx
		push esi
		push edi
		sub esp, 80h	    ; printf output buffer: 80h bytes on stack.
		lea edi, [esp-4+98h+8]
		xor ecx, ecx	    ; r_ecx
loc_410130:
		mov eax, dword [esp-4+98h+4]
		lea edx, [eax+1]
		mov dword [esp-4+98h+4], edx
		mov al, [eax]
		test al, al
		jz end_of_fmt
		xor edx, edx
		mov dl, al
		cmp edx, '%'
		jnz literal_char_in_fmt
		mov eax, dword [esp-4+98h+4]
		lea ebx, [eax+1]
		mov dword [esp-4+98h+4], ebx
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
		push 10
		pop ebx
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
		pe.reloc 4, PE_DATAREF(MsgFileHandle), mov ebx, [relval]  ; r_ebx
		mov ah, INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE  ; r_eax
		call wcfd32win32_near_syscall
		rcl eax, 1
		ror eax, 1
		add esp, 80h
pop_edi_esi_edx_ecx_ebx_ret:
		pop edi
pop_esi_edx_ecx_ebx_ret:
		pop esi
		pop edx
		pop ecx
		pop ebx
		ret

%undef  CONFIG_LOAD_FIND_CF_HEADER
%define CONFIG_LOAD_SINGLE_READ
%define CONFIG_LOAD_INT21H call wcfd32win32_near_syscall
%undef  CONFIG_LOAD_MALLOC_EAX  ; TODO(pts): Move malloc to a separate function, define this to make it shorter.
%undef  CONFIG_LOAD_CLEAR_BSS  ; VirtualAlloc(...) already returns 0 bytes.
%define CONFIG_LOAD_RELOCATED_DD pe.reloc.data.dd
%include "wcfd32load.inc.nasm"

DumpEnvironment:
		push ebx
		push edx
		pe.reloc 4, PE_DATAREF(fmt), push relval	     ; "Environment Variables:\r\n"
		call PrintMsg
		pe.reloc 4, PE_DATAREF(wcfd32win32_env_strings), mov edx, [relval]
		add esp, 4
		xor bl, bl
loc_410484:
		cmp bl, [edx]
		jz loc_410113
		push edx
		pe.reloc 4, PE_DATAREF(aS), push relval	     ; "%s\r\n"
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
loc_410113:
		pop edx
		pop ebx
		ret

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
		pe.reloc 4, PE_DATAREF(dump_filename), mov edx, relval  ; "_watcom_.dmp"
		xor ecx, ecx	    ; r_ecx
		mov ah, INT21H_FUNC_3CH_CREATE_FILE  ; r_eax
		call wcfd32win32_near_syscall
		rcl eax, 1
		ror eax, 1
		mov edx, eax
		test eax, eax
		jl error_skip_writing_dump_file
		xor eax, eax
		mov ax, dx	    ; AX := DOS filehandle.
		pe.reloc 4, PE_DATAREF(wcfd32win32_program_filename), mov edx, [relval]
		push edx
		pe.reloc 4, PE_DATAREF(aProgramS), push relval  ; "Program: %s\r\n"
		pe.reloc 4, PE_DATAREF(MsgFileHandle), mov [relval], eax
		call PrintMsg
		add esp, 8
		pe.reloc 4, PE_DATAREF(wcfd32win32_command_line), mov ecx, [relval]
		push ecx
		pe.reloc 4, PE_DATAREF(aCmdlineS), push relval  ; "CmdLine: %s\r\n"
		call PrintMsg
		add esp, 8
		mov edx, esi	    ; arg2
		mov eax, ebx	    ; arg1
		call dump_registers
		call DumpEnvironment
		pe.reloc 4, PE_DATAREF(MsgFileHandle), mov ebx, [relval]  ; r_ebx
		mov esi, 1	    ; r_esi
		mov ah, INT21H_FUNC_3EH_CLOSE_FILE  ; r_eax
		call wcfd32win32_near_syscall
		rcl eax, 1
		ror eax, 1
		pe.reloc 4, PE_DATAREF(MsgFileHandle), mov [relval], esi
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
		pe.reloc 4, PE_DATAREF(aS_0), push relval     ; "**** %s ****\r\n"
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
		pe.reloc 4, PE_BSSREF(image_base_for_debug), mov ebp, [relval]
		push ebp
		pe.reloc 4, PE_DATAREF(aOsNtBaseaddrXC), push relval  ; "OS=NT BaseAddr=%X CS:EIP=%x:%X SS:ESP=%"...
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
		pe.reloc 4, PE_DATAREF(aEaxXEbxXEcxXEd), push relval  ; "EAX=%X EBX=%X ECX=%X EDX=%X\r\n"
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
		pe.reloc 4, PE_DATAREF(aEsiXEdiXEbpXFl), push relval  ; "ESI=%X EDI=%X EBP=%X FLG=%X\r\n"
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
		pe.reloc 4, PE_DATAREF(aDsXEsXFsXGsX), push relval  ; "DS=%x ES=%x FS=%x GS=%x\r\n"
		xor ebx, ebx
		call PrintMsg
		add esp, 14h
		mov ecx, [edx+0C4h]
		mov si, [edx+0C8h]
loc_410603:
		mov gs, esi
		mov eax, [gs:ecx]
		push eax
		pe.reloc 4, PE_DATAREF(fmt_percent_hx), push relval  ; "%X "
		inc ebx
		add ecx, 4
		call PrintMsg
		add esp, 8
		test bl, 7
		jnz loc_41062C
		pe.reloc 4, PE_DATAREF(str_crlf), push relval  ; "\r\n"
		call PrintMsg
		add esp, 4
loc_41062C:
		cmp ebx, 20h  ; ' '
		jl loc_410603
		pe.reloc 4, PE_DATAREF(aCsEip), push relval   ; "CS:EIP -> "
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
		pe.reloc 4, PE_DATAREF(fmt_percent_h), push relval  ; "%h "
		inc ebx
		inc edx
		call PrintMsg
		add esp, 8
		cmp ebx, 10h
		jl loc_41064F
		pe.reloc 4, PE_DATAREF(str_crlf), push relval  ; "\r\n"
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
		pe.reloc 4, PE_BSSREF(had_ctrl_c), mov al, [relval]
		cmp eax, 1
		jz exit_eax
		mov cl, 1
		xor eax, eax
		pe.reloc 4, PE_BSSREF(had_ctrl_c), mov [relval], cl
		pop ebx
		ret 10h
abort_on_EXCEPTION_ACCESS_VIOLATION:
		pe.reloc 4, PE_DATAREF(aAccessViolatio), mov eax, relval  ; "Access violation"
		jmp loc_410720
abort_on_EXCEPTION_PRIV_INSTRUCTION:
		pe.reloc 4, PE_DATAREF(aPrivilegedInst), mov eax, relval  ; "Privileged instruction"
		jmp loc_410720
abort_on_EXCEPTION_ILLEGAL_INSTRUCTION:
		pe.reloc 4, PE_DATAREF(aIllegalInstruc), mov eax, relval  ; "Illegal instruction"
		jmp loc_410720
abort_on_EXCEPTION_INT_DIVIDE_BY_ZERO:
		pe.reloc 4, PE_DATAREF(aIntegerDivideB), mov eax, relval  ; "Integer divide by 0"
		jmp loc_410720
abort_on_EXCEPTION_STACK_OVERFLOW:
		pe.reloc 4, PE_DATAREF(aStackOverflow), mov eax, relval  ; "Stack overflow"
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
		pe.reloc 4, PE_BSSREF(had_ctrl_c), mov al, [relval]
		cmp eax, 1
		jnz loc_410777
exit_eax:
		push eax	     ; uExitCode
exit_pushed:
		pe.call.imp ExitProcess
		; Not reached.
loc_410777:
		mov ah, 1
		pe.reloc 4, PE_BSSREF(stdin_handle), mov ebx, [relval]
		pe.reloc 4, PE_BSSREF(had_ctrl_c), mov [relval], ah
loc_410785:
		lea eax, [esp+1Ch-8]
		push eax	     ; lpNumberOfEventsRead
		push 1		     ; nLength
		lea eax, [esp+24h+ -1Ch]
		push eax	     ; lpBuffer
		xor ecx, ecx
		push ebx	     ; hConsoleInput
		mov dword [esp+2Ch-8], ecx
		pe.call.imp PeekConsoleInputA
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
		pe.call.imp ReadConsoleInputA
		test eax, eax
		jnz loc_410785
loc_4107BE:
		mov eax, 1
		add esp, 18h
		pop ebx
		ret 4

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
		pe.reloc 4, PE_TEXTREF(seh_handler), mov dword [ebx+4], relval
		mov [fs:edx], eax
pop_edx_ebx_ret:
		pop edx
		pop ebx
		ret

; Attributes: noreturn
%ifdef PE
  pe_start:
%else
  global _start
  _start:
  global _mainCRTStartup
  _mainCRTStartup:
  ..start:
%endif
		sub esp, 128h  ; ESP := var_wcfd32win32_program_filename_buf. !! TODO(pts): Make it much larger than 100h, if needed, call GetCommandLineA multiple times.
		lea eax, [esp+13Ch-1Ch]  ;  frame
		call add_seh_frame
		call populate_stdio_handles
		pe.call.imp GetCommandLineA
		; !! TODO(pts): Use parse_first_arg instead, for compatibility.
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
		; !! Why does this need --mem-mb=3, but without mwperun.exe it's just --mem-mb=1? dosbox.nox.static --cmd --mem-mb=3 mwperun.exe oixrun.exe nasm.oix -O99999 -o t.bin m.nas
		pe.reloc 4, PE_DATAREF(wcfd32win32_command_line), mov [relval], eax
		;
		pe.call.imp GetEnvironmentStrings
		pe.reloc 4, PE_DATAREF(wcfd32win32_env_strings), mov [relval], eax
		;
		mov eax, esp
		push 104h	     ; nSize
		push eax	     ; lpFilename
		push 0		     ; hModule
		pe.call.imp GetModuleFileNameA
		;
		mov eax, esp	    ;  ; var_wcfd32win32_program_filename_buf.
		;call change_binnt_to_binw_in_full_pathname  ; No need to change the pathname, the program is self-contained.
		pe.reloc 4, PE_DATAREF(wcfd32win32_program_filename), mov [relval], eax
		;mov eax, esp	    ;  ; var_wcfd32win32_program_filename_buf.
		call load_wcfd32_program_image  ; Sets EAX and EDX.
		;
		cmp eax, -10
		jb .load_ok
		neg eax
		push eax  ; Save exit code for exit_pushed.
		push edx
		pe.reloc 4, PE_DATAREF(wcfd32win32_program_filename), push dword [relval]
		pe.reloc 4, PE_DATAREF(load_errors), mov eax, [relval+eax*4]  ; English.
		push eax  ; fmt.
		call PrintMsg
		add esp, 0Ch  ; Clean up arguments of PrintMsg.
		jmp exit_pushed
.load_ok:	pe.reloc 4, PE_BSSREF(image_base_for_debug), mov [relval], edx  ; Just for debugging.
		push eax  ; Save entry point address.
		push TRUE	     ; Add
		pe.reloc 4, PE_TEXTREF(ctrl_c_handler), push relval  ; HandlerRoutine
		pe.call.imp SetConsoleCtrlHandler
		;
		; Now we call the entry point.
		;
		; Input: AH: operating system (WCFD32_OS_DOS or WCFD32_OS_WIN32).
		; Input: BX: segment of the wcfd32win32_far_syscall syscall.
		; Input: EDX: offset of the wcfd32win32_far_syscall syscall.
		; Input: ECX: must be 0 (unknown parameter).
		; Input: EDI: wcfd32win32_param_struct
		; Input: dword [wcfd32win32_param_struct]: program filename (ASCIIZ)
		; Input: dword [wcfd32win32_param_struct+4]: command-line (ASCIIZ)
		; Input: dword [wcfd32win32_param_struct+8]: environment variables (each ASCIIZ, terminated by a final NUL)
		; Input: dword [wcfd32win32_param_struct+0xc]: 0 (PE_DATAREF(wcfd32win32_break_flag_ptr))
		; Input: dword [wcfd32win32_param_struct+0x10]: 0 (PE_DATAREF(wcfd32win32_copyright))
		; Input: dword [wcfd32win32_param_struct+0x14]: 0 (PE_DATAREF(wcfd32win32_is_japanese))
		; Input: dword [wcfd32win32_param_struct+0x18]: 0 (PE_DATAREF(wcfd32win32_max_handle_for_os2))
		; Call: far call.
		; Output: EAX: exit code (0 for EXIT_SUCCESS).
		pop esi  ; Entry point address.
		push 0  ; Simulate that the break flag is always 0. WLIB needs it.
		pe.reloc 4, PE_DATAREF(wcfd32win32_break_flag_ptr), mov [relval], esp
		xor ebx, ebx  ; Not needed by the ABI, just make it deterministic.
		xor eax, eax  ; Not needed by the ABI, just make it deterministic.
		xor ebp, ebp  ; Not needed by the ABI, just make it deterministic.
		sub ecx, ecx  ; This is an unknown parameter, which we always set to 0.
		pe.reloc 4, PE_TEXTREF(wcfd32win32_far_syscall), mov edx, relval
		pe.reloc 4, PE_DATAREF(wcfd32win32_param_struct), mov edi, relval
		mov bx, cs  ; Segment of wcfd32win32_far_syscall for the far call.
		mov ah, WCFD32_OS_WIN32  ; The LX program in the DOS version sets this to WCFD32_OS_DOS.
		push cs  ; For the `retf' of the far call.
		call esi
		;lea eax, [esp+13Ch-1Ch]
		;call set_seh_frame_ref  ; TODO(pts): Why is this needed near the end?
		jmp exit_eax
		; Not reached.

wcfd32win32_far_syscall:  ; proc far
		call wcfd32win32_near_syscall
		retf

; unsigned __int8 __usercall wcfd32win32_near_syscall@<cf>(unsigned int r_eax@<eax>, unsigned int r_ebx@<ebx>, unsigned int r_ecx@<ecx>, unsigned int r_edx@<edx>, unsigned int r_esi@<esi>, unsigned int  dword  8 @<edi>)
wcfd32win32_near_syscall:
		push edi  ; [esi+0x14] in wcfd32win32_near_syscall_low.
		push esi  ; [esi+0x10] in wcfd32win32_near_syscall_low.
		push edx  ; [esi+0xc] in wcfd32win32_near_syscall_low.
		push ecx  ; [esi+8] in wcfd32win32_near_syscall_low.
		push ebx  ; [esi+4] in wcfd32win32_near_syscall_low.
		push eax  ; [esi in wcfd32win32_near_syscall_low.
		mov eax, esp	    ; regs
		call wcfd32win32_near_syscall_low
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
		xor esi, esi
		xor ebx, ebx
		shl eax, 2
loc_4109E0:
		pe.reloc 4, PE_BSSREF(stdin_handle), mov ebp, [relval+ebx]
		test ebp, ebp
		jz loc_410A00
		add ebx, 4
		inc esi
		cmp ebx, other_stdio_handles.end-other_stdio_handles
		jne loc_4109E0
		pe.reloc 8, PE_BSSREF(force_last_error), mov dword [relval], ERROR_TOO_MANY_OPEN_FILES
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
		pe.call.imp CreateFileA
		cmp eax, 0FFFFFFFFh
		jz loc_4109FC
		pe.reloc 4, PE_BSSREF(stdin_handle), mov [relval+ebx], eax
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

func_INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO:
		push ebx
		push ecx
		push edx
		push esi
		sub esp, 8
		mov esi, eax
		mov eax, esp
		push eax	     ; lpMode
		pe.reloc 4, PE_BSSREF(stdin_handle), mov ebx, [relval]
		push ebx	     ; hConsoleHandle
		pe.call.imp GetConsoleMode
		push 0		     ;  dword -18h
		push ebx	     ; hConsoleHandle
		pe.call.imp SetConsoleMode
		push 0		     ; lpOverlapped
		lea eax, [esp+1Ch-14h]
		push eax	     ; lpNumberOfBytesRead
		push 1		     ; nNumberOfBytesToRead
		push esi	     ; lpBuffer
		push ebx	     ; hFile
		pe.call.imp ReadFile
		mov edx, dword [esp+18h-18h]
		push edx	     ;  dword -18h
		push ebx	     ; hConsoleHandle
		mov esi, eax
		pe.call.imp SetConsoleMode
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
		pe.reloc 4, PE_BSSREF(stdin_handle), mov edx, [relval+eax*4]
		mov eax, esp
		push eax	     ; lpLastWriteTime
		lea eax, [esp+34h+ -28h]
		push eax	     ; lpLastAccessTime
		lea eax, [esp+38h+ -20h]
		push eax	     ; lpCreationTime
		push edx	     ; hFile
		pe.call.imp GetFileTime
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
		pe.reloc 4, PE_BSSREF(stdin_handle), mov ebp, [relval+eax*4]
		mov eax, esp
		push eax	     ; lpLastWriteTime
		lea eax, [esp+34h+ -28h]
		push eax	     ; lpLastAccessTime
		lea eax, [esp+38h+ -20h]
		push eax	     ; lpCreationTime
		push ebp	     ; hFile
		pe.call.imp GetFileTime
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
		pe.call.imp SetFileTime
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
		pe.reloc 4, PE_DATAREF(aCon), mov edx, relval  ; "con"
		mov eax, [eax+0Ch]
		call strcmp
		test eax, eax
		jnz loc_410C1F
		mov eax, [ebx+4]
		pe.reloc 4, PE_DATAREF(aCon), mov ebx, dword [relval]  ; "con"
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
		pe.call.imp GetFullPathNameA
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
		pe.call.imp FileTimeToLocalFileTime
		push ebx	     ; lpFatTime
		push esi	     ; lpFatDate
		lea eax, [esp+18h-10h]
		push eax	     ; lpFileTime
		pe.call.imp FileTimeToDosDateTime
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
		pe.call.imp DosDateTimeToFileTime
		push ebx	     ; lpFileTime
		lea ebx, [esp+10h-0Ch]
		push ebx	     ; lpLocalFileTime
		pe.call.imp LocalFileTimeToFileTime
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
		pe.call.imp FindNextFileA
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
		pe.call.imp FindFirstFileA
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
		pe.call.imp FindNextFileA
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
		pe.call.imp FindClose
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
		pe.call.imp GetFileAttributesA
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
		pe.call.imp GetCurrentDirectoryA
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

; Returns flags in AH. Modifies regs in place.
; unsigned __int8 __usercall wcfd32win32_near_syscall_low@<ah>(struct dos_int21h_regs *regs@<eax>)
wcfd32win32_near_syscall_low:
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
		pe.reloc 4, PE_BSSREF(force_last_error), mov [relval], edx  ; ERROR_SUCCESS. Don't force the last error.
		pe.reloc 4, PE_DATAREF(dos_syscall_numbers), mov edi, relval
		mov al, [eax+1]
		repne scasb
		pe.reloc 4, PE_DATAREF(dos_syscall_handlers), jmp [relval+ecx*4]  ; switch 25 cases
handle_INT21H_FUNC_06H_DIRECT_CONSOLE_IO:
		push 0		     ; jumptable 00410ED7 case 1
		lea eax, [esp+34h-20h]
		push eax	     ; lpNumberOfBytesWritten
		push 1		     ; nNumberOfBytesToWrite
		lea eax, [esi+0Ch]
		push eax	     ; lpBuffer
		pe.reloc 4, PE_BSSREF(stdout_handle), mov edx, [relval]
		push edx	     ; hFile
loc_410EF3:
		pe.call.imp WriteFile
done_handling:
		mov ebp, eax  ; EBP := EAX; EAX := junk.
loc_410EFA:
		xor eax, eax  ; Set CF=0 (success) in returned flags.
		test ebp, ebp
		jnz loc_410BE9
		pe.reloc 4, PE_BSSREF(force_last_error),  mov eax, [relval]
		test eax, eax
		jnz dos_error_with_code
		pe.call.imp GetLastError
dos_error_with_code:
		mov [esi], eax  ; Return DOS error code in AX.
dos_error:
		mov eax, 100h  ; Set CF=1 (error) in returned flags.
		jmp loc_410BE9
handle_INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO:
		mov eax, esi	    ; jumptable 00410ED7 case 2
		call func_INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO
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
		pe.reloc 4, PE_BSSREF(dta_addr), mov [relval], eax
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
		pe.call.imp GetCurrentDirectoryA
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
		pe.call.imp GetLocalTime
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
		pe.call.imp GetLocalTime
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
		pe.call.imp SetCurrentDirectoryA
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
		pe.call.imp MoveFileA
		jmp done_handling
handle_INT21H_FUNC_3EH_CLOSE_FILE:
		xor eax, eax	    ; jumptable 00410ED7 case 10
		mov ax, [esi+4]
		pe.reloc 4, PE_BSSREF(stdin_handle), mov edx, [relval+eax*4]
		xor edi, edi
		push edx	     ; hObject
		pe.reloc 4, PE_BSSREF(stdin_handle), mov [relval+eax*4], edi
		pe.call.imp CloseHandle
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
		pe.reloc 4, PE_BSSREF(stdin_handle), mov eax, [relval+eax*4]
		push eax	     ; hFile
		pe.call.imp ReadFile
		jmp done_handling
handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE:
		xor eax, eax	    ; jumptable 00410ED7 case 12
		mov ax, [esi+4]
		mov edi, [esi+8]
		pe.reloc 4, PE_BSSREF(stdin_handle), mov eax, [relval+eax*4]
		test edi, edi
		jnz loc_411090
		push eax	     ; hFile
		mov [esi], edx
		pe.call.imp SetEndOfFile
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
		pe.call.imp DeleteFileA
		jmp done_handling
handle_INT21H_FUNC_42H_SEEK_IN_FILE:
		xor eax, eax	    ; jumptable 00410ED7 case 14
		mov ax, [esi+4]
		pe.reloc 4, PE_BSSREF(stdin_handle), mov ebx, [relval+eax*4]
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
		pe.call.imp SetFilePointer
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
		mov eax, [esi+4]    ; jumptable 00410ED7 case 18
		add eax,  3  ; Part of the align fix to dword.
		and eax, ~3  ; Part of the align fix to dword.
		xchg ebp, eax  ; EBP := EAX; EAX := junk.
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
		pe.call.imp LocalAlloc
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
.try_fit:	pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_base), mov eax, [relval]
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_rest), sub eax, [relval]
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_rest), sub [relval], ebp
		jc .full  ; We actually waste the rest of the current block, but for WASM it's zero waste.
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_capacity), add eax, [relval]
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
.try_alloc:	pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_base), mov eax, [relval]
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_capacity), add eax, [relval]
		push PAGE_EXECUTE_READWRITE  ; flProtect
		push MEM_COMMIT|MEM_RESERVE  ; flAllocationType
		push ebx  ; dwSize
		push eax  ; lpAddress
		pe.call.imp VirtualAlloc
		;push eax
		;push '*'
		;mov eax, esp
		;push eax
		;call PrintMsg
		;add esp, 8
		;pop eax
		test eax, eax
		jz .no_extend
		pe.reloc 5, PE_BSSREF(wcfd32win32_malloc_base), cmp dword [relval], strict byte 0
		jne .extended
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_base), mov [relval], eax
.extended:	pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_rest), add [relval], ebx
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_capacity), add [relval], ebx
		;push '#'
		;mov eax, esp
		;push eax
		;call PrintMsg
		;add esp, 8
		jmp .try_fit  ; It will fit now.
.no_extend:	xor eax, eax
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_base), cmp [relval], eax
		je .no_alloc
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_base), mov [relval], eax
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_capacity), mov [relval], eax
		pe.reloc 4, PE_BSSREF(wcfd32win32_malloc_rest), mov [relval], eax
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
		pe.reloc 4, PE_BSSREF(stdin_handle), mov eax, [relval+eax*4]
		push eax	     ; hFile
		pe.call.imp GetFileType
		cmp eax, 2
		jnz .skip
		mov dword [esi+0Ch], 80h
.skip:		xor eax, eax  ; Set CF=0 (success) in returned flags.
		jmp loc_410BE9
handle_unsupported_int21h_function:
		xor eax, eax	    ; jumptable 00410ED7 case 0
		mov al, [esi+1]
		push eax
		pe.reloc 4, PE_DATAREF(aUnsupportedInt), push relval  ; "Unsupported int 21h function AH=%h\r\n"
		call PrintMsg
		add esp, 8
		push 2
		pop eax
		jmp dos_error_with_code

populate_stdio_handles:
		push ecx
		push edx
		push STD_INPUT_HANDLE  ; nStdHandle
		pe.call.imp GetStdHandle
		push STD_OUTPUT_HANDLE  ; nStdHandle
		pe.reloc 4, PE_BSSREF(stdin_handle), mov [relval], eax
		pe.call.imp GetStdHandle
		push STD_ERROR_HANDLE  ; nStdHandle
		pe.reloc 4, PE_BSSREF(stdout_handle), mov [relval], eax
		pe.call.imp GetStdHandle
		pe.reloc 4, PE_BSSREF(stderr_handle), mov [relval], eax
		pop edx
		pop ecx
		ret

; This supports only bases 1..10.
utoa:
		push ecx
		push esi
		push edi
		push ebp
		sub esp, 28h
		mov ebp, edx
		mov edi, ebx  ; Base.
		mov esi, edx
		xor dl, dl
		lea ecx, [esp+38h-37h]
		mov byte [esp+38h-38h], dl
loc_411233:
		xor edx, edx
		div edi
		add dl, '0'  ; If larger than '9', it should be 'a' or more.
		mov [ecx], dl
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

; This supports only bases 1..10.
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

strcmp:  ; int __watcall strcmp(const void *s1, const void *s2);
		push esi
		push edi
		mov esi, eax  ; s1.
		mov edi, edx  ; s2.
.5:		lodsb
		scasb
		jne .6
		cmp al, 0
		jne .5
		xor eax, eax
		jmp short .7
.6:		sbb eax, eax
		or al, 1
.7:		pop edi
		pop esi
		ret

strncpy:  ; char* __watcall strncpy(char *dest, const char *src, size_t n);
		push ecx  ; Save.
		push edi  ; Save.
		mov edi, ebx  ; Argument dest.
		mov ecx, edx  ; Argument n.
		xchg edx, eax  ; EDX := EAX (Argument src); EAX := junk.
		push edi
.1:		test ecx, ecx
		jz short .2
		dec ecx
		mov al, [edx]
		stosb
		inc edx
		test al, al
		jnz short .1
		rep stosb  ; Fill the rest of dest with \0.
.2:		pop eax  ; Result: pointer to dest.
		pop edi  ; Restore.
		pop ecx  ; Restore.
		ret

;section .rodata  ; WLINK merges data and .rodata.
pe.switch.to.data  ; section .data

dos_syscall_numbers db 60h, 57h, 56h, 4Fh, 4Eh, 4Ch, 48h, 47h, 44h, 43h, 42h
		db 41h, 40h, 3Fh, 3Eh, 3Dh, 3Ch, 3Bh, 2Ch, 2Ah, 1Ah, 19h  ; Reverse order than dos_syscall_handlers.
		db 8, 6
		align 4
dos_syscall_handlers:
		pe.reloc.text.dd handle_unsupported_int21h_function  ; jump table for switch statement
		pe.reloc.text.dd handle_INT21H_FUNC_06H_DIRECT_CONSOLE_IO  ; jumptable 00410ED7 case 1
		pe.reloc.text.dd handle_INT21H_FUNC_08H_CONSOLE_INPUT_WITHOUT_ECHO  ; jumptable 00410ED7 case 2
		pe.reloc.text.dd handle_INT21H_FUNC_2AH_GET_CURRENT_DRIVE  ; jumptable 00410ED7 case 3
		pe.reloc.text.dd handle_INT21H_FUNC_1AH_SET_DISK_TRANSFER_ADDRESS  ; jumptable 00410ED7 case 4
		pe.reloc.text.dd handle_INT21H_FUNC_2AH_GET_DATE  ; jumptable 00410ED7 case 5
		pe.reloc.text.dd handle_INT21H_FUNC_2CH_GET_TIME  ; jumptable 00410ED7 case 6
		pe.reloc.text.dd handle_INT21H_FUNC_3BH_CHDIR  ; jumptable 00410ED7 case 7
		pe.reloc.text.dd handle_INT21H_FUNC_3CH_CREATE_FILE  ; jumptable 00410ED7 case 8
		pe.reloc.text.dd handle_INT21H_FUNC_3DH_OPEN_FILE  ; jumptable 00410ED7 case 9
		pe.reloc.text.dd handle_INT21H_FUNC_3EH_CLOSE_FILE  ; jumptable 00410ED7 case 10
		pe.reloc.text.dd handle_INT21H_FUNC_3FH_READ_FROM_FILE  ; jumptable 00410ED7 case 11
		pe.reloc.text.dd handle_INT21H_FUNC_40H_WRITE_TO_OR_TRUNCATE_FILE  ; jumptable 00410ED7 case 12
		pe.reloc.text.dd handle_INT21H_FUNC_41H_DELETE_NAMED_FILE  ; jumptable 00410ED7 case 13
		pe.reloc.text.dd handle_INT21H_FUNC_42H_SEEK_IN_FILE  ; jumptable 00410ED7 case 14
		pe.reloc.text.dd handle_INT21H_FUNC_43H_GET_OR_CHANGE_ATTRIBUTES  ; jumptable 00410ED7 case 15
		pe.reloc.text.dd handle_INT21H_FUNC_44H_IOCTL_IN_FILE  ; jumptable 00410ED7 case 16
		pe.reloc.text.dd handle_INT21H_FUNC_47H_GET_CURRENT_DIR  ; jumptable 00410ED7 case 17
		pe.reloc.text.dd handle_INT21H_FUNC_48H_ALLOCATE_MEMORY  ; jumptable 00410ED7 case 18
		pe.reloc.text.dd handle_INT21H_FUNC_4CH_EXIT_PROCESS  ; jumptable 00410ED7 case 19
		pe.reloc.text.dd handle_INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE  ; jumptable 00410ED7 case 20
		pe.reloc.text.dd handle_INT21H_FUNC_4FH_FIND_NEXT_MATCHING_FILE  ; jumptable 00410ED7 case 21
		pe.reloc.text.dd handle_INT21H_FUNC_56H_RENAME_FILE  ; jumptable 00410ED7 case 22
		pe.reloc.text.dd handle_INT21H_FUNC_57H_GET_SET_FILE_HANDLE_MTIME  ; jumptable 00410ED7 case 23
		pe.reloc.text.dd handle_INT21H_FUNC_60H_GET_FULL_FILENAME  ; jumptable 00410ED7 case 24

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
aUnsupportedInt db 'Unsupported int 21h function AH=%h'  ; Continues in str_crlf.
str_crlf	db 0Dh,0Ah  ; Continues in empty_env.
empty_env	db 0  ; Continues in empty_str.
empty_str	db 0

emit_load_errors

; unsigned int MsgFileHandle
MsgFileHandle dd FILENO_STDOUT
wcfd32win32_param_struct:  ; Contains 7 pe.reloc.data.dd fields, see below.
  wcfd32win32_program_filename pe.reloc.data.dd empty_str  ; ""
  wcfd32win32_command_line pe.reloc.data.dd empty_str  ; ""
  wcfd32win32_env_strings pe.reloc.data.dd empty_env
  wcfd32win32_break_flag_ptr dd 0  ; !! TODO(pts): Set it on Ctrl-<Break>.
  wcfd32win32_copyright dd 0
  wcfd32win32_is_japanese dd 0
  wcfd32win32_max_handle_for_os2 dd 0

pe.switch.to.bss  ; !! TODO(pts): Get rid of .bss entirely.

image_base_for_debug pe.resb 4
; HANDLE stdin_handle
stdin_handle	pe.resb 4
; HANDLE stdout_handle
stdout_handle	pe.resb 4
stderr_handle	pe.resb 4
other_stdio_handles pe.resb 4*61  ; 64 in total.
.end:
dta_addr	pe.resb 4
force_last_error pe.resb 4
wcfd32win32_malloc_base	pe.resb 4  ; Address of the currently allocated block.
wcfd32win32_malloc_capacity	pe.resb 4  ; Total number of bytes in the currently allocated block.
wcfd32win32_malloc_rest	pe.resb 4  ; Number of bytes available at the end of the currently allocated block.
had_ctrl_c	pe.resb 1

; --- Do the rest of PE generation.

%ifndef pe.switch.to.data
  pe.switch.to.data
%endif
pe.data.uend:
pe.bss.size equ 0
times (file-$)&0x1ff db 0  ; Align to PE file alignment.
pe.data.end:
pe.reloc:
..@0x4c00:
IMAGE_REL_BASED_HIGHLOW equ 3  ; 32-bit offset.
PER32 equ IMAGE_REL_BASED_HIGHLOW<<12  ; The low 12 bits is the offset.

reloc_block0: dd text_rva, .end-reloc_block0  ; Block start.
..@0x4c08:
%ifnidn (PE_RELOCS_IN_TEXT), ()
  dw PE_RELOCS_IN_TEXT
  times PE_RELOC_PADDING_IN_TEXT dw 0  ; The PE spec says that each block must start on a 4-byte boundary, so we add padding. !! TODO(pts): No end padding, just start padding.
%endif
.end:
..@0x4d5c:
reloc_block1: dd data_rva, .end-reloc_block1  ; Block start.
..@0x4d54:
%ifnidn (PE_RELOCS_IN_DATA), ()
  dw PE_RELOCS_IN_DATA
  times PE_RELOC_PADDING_IN_DATA dw 0  ; The PE spec says that each block must start on a 4-byte boundary, so we add padding. !! TODO(pts): No end padding, just start padding.
%endif
..@0x4d9c:
.end:
pe.reloc.dirend:
times (file-$)&0x1ff db 0  ; Align to PE file alignment.
pe.reloc.end:

; Check that section data isn't too long so that if fits their allocated address range.
assert_le pe.text.uend-pe.text, idata_rva-text_rva
assert_le pe.idata.dirend-pe.idata, data_rva-idata_rva
assert_le pe.data.uend-pe.data+pe.bss.size, reloc_rva-data_rva
; Check that relocations fit to a single page (their offset is 12 bits each).
assert_le pe.text.uend-pe.text, 0x1000  ; Limit imposed by reloc_block0.
assert_le pe.data.uend-pe.data, 0x1000  ; Limit imposed by reloc_block1.

; __END__
