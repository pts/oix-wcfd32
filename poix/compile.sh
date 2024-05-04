#! /bin/sh --
# by pts@fazekas.hu at Sat May  4 01:49:08 CEST 2024
set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

CC="${CC:-gcc}"
NASM="${NASM:-nasm-0.98.39}"

"$NASM" -O999999999 -w+orphan-labels -f bin -o tramp.bin tramp.nasm
perl -0777 -ne 's@(.)@sprintf("\\%03o", ord($1))@ges; print qq(const char tramp386[] = "$_";\n)' <tramp.bin >tramp.h
# This works, no segfault: CC="$HOME"/prg/trusty.i386.dir/tmp/minilibc686/pathbin/minicc ./compile.sh --diet && ./oixrun; echo $?
"$CC" -s -O2 -W -Wall -m32 "$@" -o oixrun oixrun.c

: "$0" OK.
