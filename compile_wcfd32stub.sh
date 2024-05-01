#! /bin/sh --
set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

unset WATCOM WLANG INCLUDE  # For wlink.

(cd run1 && . ./build.sh) || exit "$?"
rm -f wcfd32stub oixrun0.exe oixrun0 oixrun.oix oixrun
cp -a run1/wcfd32stub run1/oixrun0.exe run1/oixrun0 run1/oixrun.oix run1/oixrun ./

nasm=run1/tools/nasm  # NASM 0.98.39 (2005-01-15) was the last version without amd64 (`bits 64') support. Integers are still 32-bit.

"$nasm" -O999999999 -w+orphan-labels -f bin -o asm_demo/answer42.oix asm_demo/answer42.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -o asm_demo/hello.oix    asm_demo/hello.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -o asm_demo/example.oix  asm_demo/example.nasm
"$nasm" -O999999999 -w+orphan-labels -f bin -o asm_demo/talk.oix     asm_demo/talk.nasm

#"$nasm" -O999999999 -w+orphan-labels -f bin -o wasm106.exe wasm106.nasm
# Don't do it for oixrun.oix, because that would spoil the CF header in `oixrun'.
for f in asm_demo/*.oix wasmx100a.exe wasmx105.exe wasmx106.exe wasmx110b.exe wlibx105.exe wlibx106.exe wlibx110b.exe; do
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
