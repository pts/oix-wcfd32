#! /bin/sh --
#
# build.sh: build script for the WCFD32 runtime system on Win32
# by pts@fazekas.hu at Wed May  1 03:26:19 CEST 2024
#
# To run it, just open a termainal, cd to the directory containing this
# file, and then run: sh build.sh
#
# This build script works on Linux i386 and amd64, because it uses the
# tools/wlink (WLINK: OpenWatcom Linker 1.4) and tools/nasm (NASM: Netwide
# Assembler 0.98.39) executable programs, which are compiled for Linux i386.
# However, if you can get these two tools running on your Unix system, the
# build will work, because it uses cross compilation.
#
# This build:
#
# * is reproducible: it produces identical files as output when run again.
# * is multi-target: it builds for all targets (operating systems)
# * uses cross-compilation: it doesn't run any program it builds on the
#   build host system, it runs nasm and wlink only
#
# Output files of this build:
#
# * oixrun and oixrun0: OIX program runners for Linux. It will be made work on
#   FreeBSD as well later
# * oixrun.oix: OIX program runner for OIX. Most people don't need it, it's
#   a nice meta touch: `oixrun oixrun.oix oixrun.oix oixrun.oix hello.oix`.
# * oixrun.exe and oixrun0.exe: OIX program runner for Win32 and 32-bit DOS.
#   It is self-contained, even the DOS extender PMODE/W 1.33 is included.
# * wcfd32stub: preliminary OIX converter which can convert an .oix program
#   file to a self-contained Linux i386 executable program or a
#   self-contained Win32--DOS program .exe. Eventually this will be replaced
#   with oixconv, oixconv.exe and oixconv.oix.
#
# TODO(pts): Add build.cmd for building on Win32.
# TODO(pts): Rebuild oixrun from oixrun.nasm instead as an OIX program (ELF-flavored OIX), using NASM. oixrun0: native Linux implementation; oixrun: ELF-flavored OIX implementation; oixrun1: prelinked ELF
# TODO(pts): Add usage message for oixstub.
# TODO(pts): Build oixstub.exe and oixstub, using NASM, from new OIX oixstub.nasm sources.
# TODO(pts): Make the relocation `dw 0' in oixrun.nasm 1 byte shorter by moving it (but not into the CF header, to save memory).
# TODO(pts): (v2) Drop WLINK as a build dependency, use NASM only. For that we need to build the PE executable with NASM (hard).
# TODO(pts): (v3) Replace NASM with nasm0.oix, oixrun0 and oixrun0.exe for the build.
# TODO(pts): (v4) Add compressed nasm0.oix (upxbc --elftiny).
# TODO(pts): (v6) Add missing non-time syscalls.
# TODO(pts): (v7) Add time, stat and utime syscalls.
# TODO(pts): (v8) Add FreeBSD compatibility, and this will make the build system work.
#

set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

unset WATCOM WLANG INCLUDE  # For wlink.
unset LANG LANGUAGE LC_ALL LC_CTYPE LC_MESSAGES LC_NUMERIC LC_TIME TZ  # For reproducible results.
export LC_ALL=C TZ=GMT  # For reproducible results.

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
rm -f oixrun0  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DRUNPROG -DOIXRUN0 -o oixrun0 wcfd32linux.nasm
chmod +x oixrun0  # Final output: oixrun0 i386 executable program.
rm -f oixrun  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DRUNPROG -DOIXRUN -o oixrun wcfd32linux.nasm
chmod +x oixrun  # Final output: oixrun i386 executable program.
"$nasm" -O999999999 -w+orphan-labels -f bin -o oixrun.oix oixrun.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -o oixrun0.exe -DOIXRUN0 oixrunexe.nasm  # -DOIXRUN0 doesn't make a difference, it's precompiled.
"$nasm" -O999999999 -w+orphan-labels -f bin -o oixrun.exe -DOIXRUN oixrunexe.nasm

ls -l oixrun0.exe oixrun.exe oixrun0 oixrun oixrun.oix wcfd32stub

: "$0" OK.
