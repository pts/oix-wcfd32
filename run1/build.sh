#! /bin/sh --
# by pts@fazekas.hu at Wed May  1 03:26:19 CEST 2024
set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

unset WATCOM WLANG INCLUDE  # For wlink.

wlink=tools/wlink  # OpenWatcom 1.4 (2005-11-15) was the first one with a Linux binary release.
nasm=tools/nasm    # NASM 0.98.39 (2005-01-15) was the last version without amd64 (`bits 64') support. Integers are still 32-bit.

"$nasm" -O999999999 -w+orphan-labels -f obj -o wcfd32dos.obj wcfd32dos.nasm
# Using the output name w.exe because WLiNK inserts the output filename
# (without the .exe extension) to the program, and we want it short.
"$wlink" form os2 le op stub=pmodew133.exe op q n w.exe f wcfd32dos.obj
"$nasm" -O0 -w+orphan-labels -f bin -o wcfd32dos.exe wcfd32ibw.nasm  # Copies w.exe to wcfd32dos.exe.
# Same size, but mz_header image size is based on file size, and the file size is aligned to 4. That's for WLINK below.
"$nasm" -O999999999 -w+orphan-labels -f bin -o wcfd32dosp.exe wcfd32dosp.nasm
"$nasm" -O999999999 -w+orphan-labels -f obj -o wcfd32win32.obj wcfd32win32.nasm
# `option heapsize=' is ignored by WLINK, SizeOfHeapReserve will always be
# 0. `commit heap=' is saved to SizeOfHeapCommit. SizeOfHeapCommit matters
# for mwpestub LocalAlloc and HeapAlloc. It's not needed by Win32
# LocalAlloc or mwpestub VirtualAlloc.
#
# This file is not reproducible (but wcfd32stub.bin and wcfd32stub are), because wlink
# inserts the current build timestamp to the PE header.
#"$wlink" @wcfd32import.lnk form win nt ru con=3.10 op stub=wcfd32dosp.exe op q op d op h=1 com h=0 n wcfd32win32.exe f wcfd32win32.obj
"$wlink" form win nt ru con=3.10 op stub=wcfd32dosp.exe op q op d op h=1 com h=0 n wcfd32win32.exe f wcfd32win32.obj
"$nasm" -O999999999 -w+orphan-labels -f bin -o wcfd32stub.bin wcfd32stub.nasm  # Final output: wcfd32stub.bin.  # incbin: wcfd32dos.exe, wcfd32dosp.exe, wcfd32win32.exe
"$nasm" -O999999999 -w+orphan-labels -f bin -o wcfd32linux.bin wcfd32linux.nasm
rm -f wcfd32stub  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DLINUXPROG -o wcfd32stub wcfd32stub.nasm  # incbin: wcfd32linux.bin, wcfd32dos.exe, wcfd32dosp.exe, wcfd32win32.exe
chmod +x wcfd32stub  # Final output: wcfd32stub Linux i386 executable program.
rm -f wcfd32win32.exe  # Get rid of non-reproducible file.
rm -f wcfd32linux  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DRUNPROG -o wcfd32linux wcfd32linux.nasm
chmod +x wcfd32linux  # Final output wcfd32linux i386 executable program.
rm -f oixrun  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DRUNPROG -DOIXRUN -o oixrun wcfd32linux.nasm
chmod +x oixrun  # Final output: oixrun i386 executable program.
# TODO(pts): Rebuild oixrun from oixrun.nasm instead as an OIX program, and keep the previous oixrun as oixrun0.
# TODO(pts): Build oixrun.exe for DOS and Win32 directly, using NASM.
# TODO(pts): Build oixstub.exe and oixstub, using NASM, from new OIX oixstub.nasm sources.
# TODO(pts): Add usage message for oixstub.
# TODO(pts): (v2) Drop WLINK as a build dependency, use NASM only.
# TODO(pts): (v3) Replace NASM with nasm0.oix, oixrun0 and oixrun0.exe for the build.
# TODO(pts): (v4) Add compressed nasm0.oix (upxbc --elftiny).

: "$0" OK.
