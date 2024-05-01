#! /bin/sh --
set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

unset WATCOM WLANG INCLUDE  # For wlink.

(cd run1 && . ./build.sh) || exit "$?"
rm -f wcfd32stub oixrun0.exe oixrun0 oixrun.oix oixrun
cp -a run1/wcfd32stub run1/oixrun0.exe run1/oixrun0 run1/oixrun.oix run1/oixrun ./

nasm=run1/tools/nasm  # NASM 0.98.39 (2005-01-15) was the last version without amd64 (`bits 64') support. Integers are still 32-bit.

# Example OIX exit(42) program.
"$nasm" -O999999999 -w+orphan-labels -f bin -o answer42.oix answer42.nasm

# Example OIX hello-world program.
"$nasm" -O999999999 -w+orphan-labels -f bin -o hello.oix hello.nasm

# Example OIX program which prints its command line and environment.
"$nasm" -O999999999 -w+orphan-labels -f bin -o example.oix example.nasm

#"$nasm" -O999999999 -w+orphan-labels -f bin -o wasm106.exe wasm106.nasm
# Don't do it for oixrun.oix, because that would spoil the CF header in `oixrun'.
for f in answer42.oix hello.oix example.oix wasmx100a.exe wasmx105.exe wasmx106.exe wasmx110b.exe wlibx105.exe wlibx106.exe wlibx110b.exe; do
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
