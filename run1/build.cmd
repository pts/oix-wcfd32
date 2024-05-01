@echo off
rem This is the build script for the WCFD32 runtime system on Win32.
rem To run it, just open a Command Prompt window (by running cmd.exe), cd to
rem the directory containing this file, and then run: build.cmd
rem Alternatively, it also works in Wine: wine cmd /c build.cmd
rem
rem See build.sh for explanation of the commands run.
set PATH=%~dp0tools;%PATH%
cd %~dp0
@if errorlevel 1 exit /b 1
rem Make sure the system Watcom files are not used by WLINK.
set WATCOM=
set WLANG=
set INCLUDE=
rem OpenWatcom 1.4 (2005-11-15) was the first one with a Linux binary release.
set wlink=tools\wlink
rem NASM 0.98.39 (2005-01-15) was the last version without amd64 (`bits 64') support. Integers are still 32-bit.
set nasm=tools\nasm
@echo on

%nasm% -O999999999 -w+orphan-labels -f obj -o wcfd32dos.obj wcfd32dos.nasm
@if errorlevel 1 exit /b 1
%wlink% form os2 le op stub=pmodew133.exe op q n w.exe f wcfd32dos.obj
@if errorlevel 1 exit /b 1
%nasm% -O0 -w+orphan-labels -f bin -o wcfd32dos.exe wcfd32ibw.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -o wcfd32dosp.exe wcfd32dosp.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f obj -o wcfd32win32.obj wcfd32win32.nasm
@if errorlevel 1 exit /b 1
%wlink% form win nt ru con=3.10 op stub=wcfd32dosp.exe op q op d op h=1 com h=0 n wcfd32win32.exe f wcfd32win32.obj
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -o wcfd32stub.bin wcfd32stub.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -o wcfd32linux.bin wcfd32linux.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -DLINUXPROG -o wcfd32stub wcfd32stub.nasm
@if errorlevel 1 exit /b 1
del wcfd32win32.exe
%nasm% -O999999999 -w+orphan-labels -f bin -DRUNPROG -o wcfd32linux wcfd32linux.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -DRUNPROG -DOIXRUN0 -o oixrun0 wcfd32linux.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -DRUNPROG -DOIXRUN -o oixrun wcfd32linux.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -o oixrun.oix oixrun.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -o oixrun0.exe -DOIXRUN0 oixrunexe.nasm
@if errorlevel 1 exit /b 1
%nasm% -O999999999 -w+orphan-labels -f bin -o oixrun.exe -DOIXRUN oixrunexe.nasm
@if errorlevel 1 exit /b 1

@echo off
dir oixrun0.exe oixrun.exe oixrun0 oixrun oixrun.oix wcfd32stub
echo %~nx0 OK. >&2
