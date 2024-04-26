#! /bin/sh --
set -ex
test "${0%/*}" = "$0" || cd "${0%/*}"

#unset WATCOM WLANG INCLUDE  # For wlink.

#wasm -zq -d2 int21win.asm
#wasm -zq dpmildr.asm
#wasm -zq loader16.asm
#wlink system dos name os2stub file loader16,dpmildr,int21win option quiet
wasm -zq -mf cstrtosi.asm
owcc -bwin386 -D__OSI__ -I. -fnostdlib -fno-stack-check -Os -s -march=i386 -Wall -Wextra -Werror -o example.rex example.c cstrtosi.o
owcc -blinux -Os -s -march=i386 -I"$WATCOM/lh" -Wall -Wextra -o w32bind w32bind.c
#./w32bind example.rex example.exe os2stub.exe  # Crashes at exit in DOSBox. It also has many NUL bytes emitted.
#./w32bind example.rex example.exe w32stub.exe  # Good.
./w32bind example.rex example.exe ../wcfd32dos.exe
if test "$(type dosbox.nox.static 2>/dev/null)"; then
  exit_code=0
  dosbox.nox.static --cmd --mem-mb=3 --env=foo=bar example.exe hi there || exit_code="$?"
  test "$exit_code" = 42
fi

: "$0" OK.
