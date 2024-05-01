;
; oixrunexe.nasm: manually bind the MZ-flavored stub to oixrun.oix, creating oixrun.exe
; by pts@fazekas.hu at Wed May  1 05:35:43 CEST 2024
;
; This can be done later using the oixstub tool, but as part of the build
; process of the WCFD32 runtime system, by principle, we run NASM and WLINK
; only.
;

mz_header:
incbin 'wcfd32stub.bin', 0, 0x20
cf_header:
dd 'CF', oix_image-mz_header
incbin 'oixrun.oix', 8, 0x18-8
cf_header_end:
incbin 'wcfd32stub.bin', 0x38
oix_image:
incbin 'oixrun.oix', 0x18
