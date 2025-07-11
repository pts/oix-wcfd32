#! /bin/sh --
#
# build.sh: build script for the WCFD32 runtime system on Linux
# by pts@fazekas.hu at Wed May  1 03:26:19 CEST 2024
#
# To run it, just open a terminal, cd to the directory containing this
# file, and then run: sh build.sh
#
# See also the equivalent build script build.cmd, which runs on Win32
# (Windows NT or newer). The commands in these two scripts are kept in sync
# manually.
#
# This build script works on Linux i386 and amd64, because it uses the
# tools/nasm (NASM: Netwide Assembler 0.98.39) executable programs, which
# are compiled for Linux i386. However, if you can get these two tools
# running on your Unix system, the build will work, because it uses cross
# compilation.
#
# This build:
#
# * is reproducible: it produces identical files as output when run again.
# * is multi-target: it builds for all targets (operating systems)
# * uses cross-compilation: it doesn't run any program it builds on the
#   build host system, it runs nasm only
#
# Output files of this build:
#
# * oixrun and oixrun0: OIX program runners for Linux i386. It will be made
#   work on FreeBSD i386 as well later. As a nice meta touch, *oixrun* is
#   not only Linux i386 program, but also an OIX program, so it can run
#   itself: `./oixrun oixrun oixrun oixrun hello.oix`.
# * oixrun.oix: OIX program runner for OIX. Most people don't need it, it's
#   a nice meta touch: `./oixrun oixrun.oix oixrun.oix oixrun.oix hello.oix`.
# * oixrun.exe and oixrun0.exe: OIX program runner for Win32 and 32-bit DOS.
#   It is self-contained, even the DOS extender PMODE/W 1.33 is included.
#   As a nice meta touch, it's also an OIX program, so it can run itself, even
#   when combined with *oixrun* (the runner for Linux i386):
#   `oixrun oixrun.exe oixrun oixrun.exe hello.oix`.
# * wcfd32stub: preliminary OIX converter which can convert an .oix program
#   file to a self-contained Linux i386 executable program or a
#   self-contained Win32--DOS program .exe. Eventually this will be replaced
#   with oixconv, oixconv.exe and oixconv.oix.
#
# TODO(pts): $ dosbox.nox.static --cmd --mem-mb=2 oixrun.exe wasmx106.exe  -->  Error: could not open message resource file.
# TODO(pts): In `-DLINUXPROG -o wcfd32stub', include oixstub.exe, a version of oixrun.exe which doesn't contain oixrun.oix.
# TODO(pts): Really fix oixrun.oix parse_first_arg argument parsing bug triggered by wcfd32win32.nasm.
# TODO(pts): Add usage message for oixconv.
# TODO(pts): Build oixconv.exe and oixconv, using NASM, from new OIX oixconv.nasm sources. Port the Linux-only code in wcfd32stub.nasm to OIX.
# TODO(pts): (v3) Replace NASM with nasmb.oix, oixrunb and oixrunb.exe for the build.
# TODO(pts): (v3) Add build.bat, with shorter filenames, for DOS.
# TODO(pts): (v4) Add compressed nasmb.oix (upxbc --elftiny).
# TODO(pts): (v6) Add missing non-time syscalls.
# TODO(pts): (v7) Add time, stat and utime syscalls.
# TODO(pts): (v8) Add FreeBSD compatibility for oixrun0, and this will make the build system work.
# TODO(pts): Better error reporting (with at least filename displayed) for oixrun.
# TODO(pts): Make oixconv/wcfd32stub be able to create non-prelinked ELF programs (without too much bloat?).
# TODO(pts): Make oixconv/wcfd32stub be able to create prelinked ELF programs with the CFP header.
# TODO(pts): Make oixconv/wcfd32stub be able to create OIX programs (without ELF or MZ flavor).
# TODO(pts): Make oixconv/wcfd32stub be able to create OIX programs even from prelinked ELF programs with the CFP header.
# TODO(pts): Build oixrun1 (prelinked ELF) with NASM. This is just an excersize, it's not useful.
# TODO(pts): Provide more reliable operating system indication, especially Linux and FreeBSD. Which Watcom programs are affected?
# TODO(pts): Make wcfd32linux.nasm autodetect and run on FreeBSD i386 (like https://github.com/pts/pts-pngout-20150319-i386/).
# TODO(pts): Do an automatic `rm` (unlink) and `chmod +x` for ELF executable output.
# TODO(pts): Preload oixrun.oix to wcfd32win32.exe, don't let oixrun.exe contain `Memory allocation failed' 2 times, just once. This is possible by overlapping the end of the LE image with the beginning of the PE image. the winning is 211 file bytes, and the loss is more virtual memory usage.
# TODO(pts): Make the size of the command-line unlimited on Windows, currently it's 0x100 bytes.
# TODO(pts): INT21H_FUNC_4EH_FIND_FIRST_MATCHING_FILE makes mwperun.exe crash DOSBox (even if there are no wildcards in the filename) in: dosbox.nox.static --cmd --mem-mb=3 ~/prg/mwpestub/mwperun.exe run1/oixrun.exe wl.exe t.lib rex2oix.o
# TODO(pts): size optimization: make ../run[12]/pmodew133.exe smaller by removing features
#

set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

unset LANG LANGUAGE LC_ALL LC_CTYPE LC_MESSAGES LC_NUMERIC LC_TIME TZ  # For reproducible results.
export LC_ALL=C TZ=GMT  # For reproducible results.

if test "$1" = clean; then
  exec rm -f oixrun oixrun.exe oixrun0 oixrun0.exe w.exe wcfd32dos.exe wcfd32dosp.exe wcfd32linux wcfd32linux.bin wcfd32stub wcfd32win32.exe
fi

nasm=tools/nasm    # NASM 0.98.39 (2005-01-15) was the last version without amd64 (`bits 64') support. Integers are still 32-bit.

"$nasm" -O999999999 -w+orphan-labels -f bin -o oixrun.oix oixrun.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -DSELF1 -o oixrun1.oix oixrun.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -o oixrun.exe wcfd32exe.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -DEPLSTUB -o wcfd32linuxepl.bin wcfd32linux.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -DELFSTUB -o wcfd32linuxelf.bin wcfd32linux.nasm
rm -f wcfd32stub  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DLINUXPROG -o wcfd32stub wcfd32stub.nasm  # incbin: wcfd32linuxepl.bin, wcfd32linuxelf.bin, oixrun.exe.
chmod +x wcfd32stub  # Final output: wcfd32stub Linux i386 executable program.
rm -f oixrun0  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DRUNPROG -o oixrun0 wcfd32linux.nasm  # Native Linux i386 implementation.
chmod +x oixrun0  # Final output: oixrun0 i386 executable program.
rm -f oixrun  # For correct permissions below.
"$nasm" -O999999999 -w+orphan-labels -f bin -DSELFPROG -o oixrun wcfd32linux.nasm  # ELF-flavored OIX implementation using oixrun.oix, containing the relocation code twice. -DOIXRUN doesn't make a difference, oixrun.oix is precompiled.
chmod +x oixrun  # Final output: oixrun i386 executable program.
# TODO(pts): Sync changes from build.sh to build.cmd.
ls -l oixrun.exe oixrun0 oixrun oixrun.oix wcfd32stub

: "$0" OK.
