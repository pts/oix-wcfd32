;
; wcfd32dosexe.nasm: generates an LE executable with an MZ stub at the beginning
; by pts@fazekas.hu at Tue Apr 30 04:49:07 CEST 2024
;
; This is a manual replacement for: wlink form os2 le op stub=pmodew133.exe op q n w.exe f wcfd32dos.obj
;
; doc: https://faydoc.tripod.com/formats/exe-LE.htm
; doc: (documents both LX and LE, there is little difference.): https://github.com/yetmorecode/lxedit/blob/main/lx.h
;
; The .exe file was created by OpenWatcom 1.4 WLINK.
;

bits 32
cpu 386

%macro assert_at 1
  times  (%1)-($-$$) db 0
  times -(%1)+($-$$) db 0
%endm

%macro assert_eq 2
  times  (%1)-(%2) times 0 db 0
  times -(%1)+(%2) times 0 db 0
%endm

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
%macro relocated_le.bss 2+
  %define relval (%1)-le.bss
  %2
  le_set_fixup_at le_found_reloc_count, objid_le.bss, relval
  %undef relval
  %assign le_found_reloc_count le_found_reloc_count+1
%endm
%assign le_reloc_count 0
%macro le_add_fixup 1  ; %1 is le_reloc_count
  fixup_o32_int le_ary_reloc_at_ %+ %1, le_ary_reloc_obj_ %+ %1, le_ary_reloc_val_ %+ %1  ; All values will be defined later, by `relocated_le.text' and `relocated_le.bss'.
  %assign le_reloc_count %1+1
%endm
%macro le_fixups 1
  %rep %1
    le_add_fixup le_reloc_count
  %endrep
%endm

section .le.bss align=1 nobits
le.bss:
section .le.text align=1

file:
mz_header:
.signature:	db 'MZ'
.lastsize:	dw (dos_stub_end-file)&0x1ff
.nblocks:	dw (dos_stub_end-file+0x1ff)>>9
.nreloc:	dw 0
.hdrsize:	dw (dos_image-file)>>4
assert_at 0xa
%ifdef PE
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
  cf_header:
  .signature: dd 'CF', 0, 0, 0, 0  ; To be filled with the CF header later.
  assert_at 0x38
  le_ofs:
  ..@0x0038: dd le_header-file
  pe_ofs:
  ..@0x003c: dd pe_header-file
  assert_at 0x40
  times (file-$)&(0x10-1) db 0  ; dos_image must be aligned to 0x10.
  dos_image:
  assert_at 0x40
  incbin 'pmodew133.exe', 0x20, 0x2e-0x20  ; Copy the DOS stub image.
  db 0  ; Disable displaying of PMODE/W copyright message.
  incbin 'pmodew133.exe', 0x2f, 0x1ee3-0x2f ; Copy the DOS stub image.
  db le_ofs-file  ; Change the file offset from 0x3c to 0x38 at which PMODE/W looks for the LE header offset. This changes the compressed stream. Fortunately it doesn't affect subsequent repeat copies in this case.
  incbin 'pmodew133.exe', 0x1ee4 ; Copy the DOS stub image.
%else
  ;dw 'MZ', 0xfc&0x1ff, 0x17, 0, 4
  incbin 'pmodew133.exe', 0xa, 0x18-0xa
  dw 0x40  ; WLINK changed 0x3a to 0x40.
  incbin 'pmodew133.exe', 0x1a, 0x20-0x1a
  dd 0, 0, 0, 0, 0, 0, 0  ; To be filled with the CF header later.
  ;incbin 'le.bin.golden', 0, 0x3c
  ..@0x003c: dd le_header-file
  assert_at 0x40
  dos_image:
  ;incbin 'le.bin.golden', 0, 0x38
  ;..@0x0038: dd le_header-$$  ; Typically this is at @0x003c rather than @0x0038.
  ;incbin 'le.bin.golden', 0x3c, 4
  ;incbin 'le.bin.golden', 0x40, le_header_pre-file-0x40  ; Copy the DOS stub image.
  ;incbin 'le.bin.golden', 0x40, 0x2d00-0x40  ; Copy the DOS stub image.
  incbin 'pmodew133.exe', 0x20  ; Copy the DOS stub image.
%endif
dos_stub_end:
times (file-$)&(0x10-1) db 0  ; Align to 0x10. This padding is not part of pmodew133.exe, WLINK adds it in later phases for aligning the LE header after it.
assert_at 0x2d00
le_header:
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
dd (le.text_end-le.text+0xfff)>>12  ; 1. num_pages. Number of memory pages.
dd objid_le.text  ; Initial object CS number.
dd le.start-le.text  ; Initial EIP. Entry point.
..@0x2d20:
dd objid_stack  ; Initial object SS number.
dd stack_size  ; Initial ESP.
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
dd objid_le.bss  ; Automatic data (autodata) object.
dd 0  ; Debug information offset.
dd 0  ; Debug information length.
..@0x2da0:
dd 0  ; Preload instance pages number.
dd 0  ; Demand instance pages number.
dd 0  ; Extra heap allocation.
dd stack_size  ; Stack size. PMODE/W seems to ignore this field.
..@0x2db0:
times 5 dd 0  ; Windows VxD fields, we don't need them with PMODE/W.  https://github.com/yetmorecode/lxedit/blob/09de1f3d253cc9123b8392db1d466e586416fb33/lx.h#L102-L106
le_header_end:
..@0x2bc4:
assert_at le_header-$$+0xc4
object_table:
object_table_le.text:
objid_le.text equ ($-object_table)/0x18+1
.byte_size: dd le.text_end-le.text
.relocation_base: dd 0x10000  ; !! What does it mean?
OBJ_READABLE equ 1
OBJ_WRITEABLE equ 2
OBJ_EXECUTABLE equ 4
OBJ_BIG equ 0x2000
.object_flags: dd OBJ_BIG|OBJ_READABLE|OBJ_EXECUTABLE  ; PMODE/W maps it to read-write-execute anyway.
.page_map_index: dd 1
.page_map_entries: dd 1
.unknown: dd 0
object_table_le.bss:
objid_le.bss equ ($-object_table)/0x18+1
..@0x2ddc:
.byte_size: dd le.bss_end-le.bss
.relocation_base: dd 0x20000  ; !! What does it mean?
.object_flags: dd OBJ_BIG|OBJ_READABLE|OBJ_WRITEABLE
.page_map_index: dd 2
.page_map_entries: dd 0
.unknown: dd 0
object_table_stack:  ; !! Is the stack section needed at all? We could save 0x18 bytes. PMODE/W seems to crash DOSBox if we remove it (and all objid references). Why?
objid_stack equ ($-object_table)/0x18+1
..@0x2df4:
stack_size equ 0x1000  ; !! TODO(pts): Is this enough for a real-world program?
.byte_size: dd stack_size  ; Does PMODE/W respect it?
.relocation_base: dd 0x30000  ; !! What does it mean?
.object_flags: dd OBJ_BIG|OBJ_READABLE|OBJ_WRITEABLE  ; Same as in .le.bss.
.pakge_map_idx: dd 2
.page_mape_entries: dd 0
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
assert_at 0x2e1e
; TODO(pts): Move the fixups after le.text_end, thus we know their count.
le_fixups 22  ; There will be this many relocation, sets le_reloc_count.
fixup_record_table_end:
assert_at 0x2eb8
imported_modules_name_table:
imported_procedures_name_table:
..@0x2eb8: dd 0
assert_at 0x2ebc
data_pages:
le.text:
%include 'wcfd32dos.nasm'
le.bss_end:
section .le.text
le.text_end:
times 0x1000-($-le.text) times 0 db 0; Check that .le.text size is at most 0x1000 bytes (single page).
assert_eq le_reloc_count, le_found_reloc_count  ; Upon a difference, update the value of `le_fixups'.

section .le.text

%ifdef PE
times (file-$)&(0x10-1) db 0  ; Align to 0x10. This padding is not part of wcfd32dos.exe, it's added in later phases for aligning the PE header after it. !! Align only to 4.
..@0x31e0:
assert_at 0x31e0
pe_header:
incbin 'lepe.bin.golden', 0x31e0  ; PE header follows after further processing.
%endif
