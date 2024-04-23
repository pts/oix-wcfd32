bits 16
cpu 8086

mz_header:
dw 'MZ', (file_end-mz_header)&0x1ff, (file_end-mz_header+0x1ff)>>9
incbin 'wcfd32dos.exe', 6
times (mz_header-$)&0xf db 0  ; Align to multiple of 0x10, WLINK aligns the PE header like this.
file_end:
