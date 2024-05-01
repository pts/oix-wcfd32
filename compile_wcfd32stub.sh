#! /bin/sh --
set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

unset WATCOM WLANG INCLUDE  # For wlink.

# OpenWatcom 1.7 linker also works.
wlink=wlink  # OpenWatcom 2.0 linker generates the smallest allocp.exe: 24 bytes smaller than the others.
wlink=tools/wlink-ow17
wlink=tools/wlink-ow16
wlink=tools/wlink-ow15
wlink=tools/wlink-ow14  # OpenWatcom 1.4 (2005-11-15) was the first one with a Linux binary release.

#wasm -q -fo=allocd.obj allocd.asm
nasm-0.98.39 -O999999999 -w+orphan-labels -f obj -o wcfd32dos.obj wcfd32dos.nasm
# Unfortunately the format LE 4 KiB of alignment between .code and .data, no
# way to make it smaller, but PMODE/W supports LE only.
#
# Using the output name w.exe because WLiNK inserts the output filename
# (without the .exe extension) to the program, and we want it short.
"$wlink" form os2 le op stub=pmodew133.exe op q n w.exe f wcfd32dos.obj
mv w.exe wcfd32dos.exe

#dosbox.nox.static --cmd pmwsetup.exe /B0 wcfd32dos.exe  # Disable copyright message. wcfd32stub.nasm already does that.

# Same size, but mz_header image size is based on file size, and the file size is aligned to 4. That's for WLINK below.
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o wcfd32dosp.exe wcfd32dosp.nasm

nasm-0.98.39 -O999999999 -w+orphan-labels -f obj -o wcfd32win32.obj wcfd32win32.nasm
# `option heapsize=' is ignored by WLINK, SizeOfHeapReserve will always be
# 0. `commit heap=' is saved to SizeOfHeapCommit. SizeOfHeapCommit matters
# for mwpestub LocalAlloc and HeapAlloc. It's not needed by Win32
# LocalAlloc or mwpestub VirtualAlloc.
"$wlink" form win nt ru con=3.10 op stub=wcfd32dosp.exe op q op d op h=1 com h=0 n wcfd32win32.exe f wcfd32win32.obj
rm -f wcfd32stub  # For correct permissions.
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -DLINUXPROG -o wcfd32stub wcfd32stub.nasm
chmod +x wcfd32stub
# Final output: wcfd32stub Linux i386 executable program.
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o wcfd32stub.bin wcfd32stub.nasm
# Final output: wcfd32stub.bin.

rm -f wcfd32linux  # For correct permissions.
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -DRUNPROG -o wcfd32linux wcfd32linux.nasm
chmod +x wcfd32linux
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o wcfd32linux.bin wcfd32linux.nasm

# Example OIX hello-world program.
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o hello.oix hello.nasm

# Example OIX program which prints its command line and environment.
nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o example.oix example.nasm

nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o oixrun.oix oixrun.nasm

#nasm-0.98.39 -O999999999 -w+orphan-labels -f bin -o wasm106.exe wasm106.nasm
for f in hello.oix example.oix oixrun.oix wasmx100a.exe wasmx105.exe wasmx106.exe wasmx110b.exe wlibx105.exe wlibx106.exe wlibx110b.exe; do
  if test -f "$f"; then
    if test "${f%.oix}" = "$f"; then
      head="${f%x*.exe}"
      tail="${f#${head}x}"
    else
      head="${f%.oix}"
      tail=.exe
    fi
    ./wcfd32stub "$f" "$head$tail"
    rm -f "$head${tail%.exe}"  # For correct permissions and avoiding cache problems.
    ./wcfd32stub "$f" "$head${tail%.*}" elf
    chmod +x "$head${tail%.*}"
  fi
done

: "$0" OK.
