@echo off
rem This is the build script for the WCFD32 runtime system on Win32.
rem To run it, just open a Command Prompt window (by running cmd.exe), cd to
rem the directory containing this file, and then run: build.cmd
rem Alternatively, it also works in Wine: wine cmd /c build.cmd
rem On Windows 95, rename this file to build.bat before running it.
rem
rem See build.sh for explanation of the commands run.
set b=
rem Windows 95 doesn't have %OS%, Windows NT cmd.exe from 3.1 has its.
if "%OS%" == "" goto not_nt
rem set PATH=%~dp0tools;%PATH%
cd %~dp0
set b=/b 1
:not_nt
@if errorlevel 1 exit %b%
rem NASM 0.98.39 (2005-01-15) was the last version without amd64 (`bits 64') support. Integers are still 32-bit.
set nasm=tools\nasm

if "%1" == "clean" goto clean
goto compile
:clean
del oixrun oixrun.exe oixrun0 oixrun0.exe w.exe wcfd32dos.exe wcfd32dosp.exe wcfd32linux wcfd32linux.bin
del wcfd32stub wcfd32win32.exe
rem if errorlevel 1 exit %b%  -- del fails if some of the files are missing; we don't propagate this.
exit

:compile
@echo on
%nasm% -O999999999 -w+orphan-labels -f bin -o oixrun.oix oixrun.nasm
@if errorlevel 1 exit %b%
%nasm% -O999999999 -w+orphan-labels -f bin -o oixrun.exe wcfd32exe.nasm
@if errorlevel 1 exit %b%
%nasm% -O999999999 -w+orphan-labels -f bin -o wcfd32linux.bin wcfd32linux.nasm
@if errorlevel 1 exit %b%
%nasm% -O999999999 -w+orphan-labels -f bin -DLINUXPROG -o wcfd32stub wcfd32stub.nasm
@if errorlevel 1 exit %b%
%nasm% -O999999999 -w+orphan-labels -f bin -DRUNPROG -o wcfd32linux wcfd32linux.nasm
@if errorlevel 1 exit %b%
%nasm% -O999999999 -w+orphan-labels -f bin -DRUNPROG -DOIXRUN0 -o oixrun0 wcfd32linux.nasm
@if errorlevel 1 exit %b%
%nasm% -O999999999 -w+orphan-labels -f bin -DSELFPROG -DOIXRUN -o oixrun wcfd32linux.nasm
@if errorlevel 1 exit %b%

@echo off
@rem dir wcfd32stub.
dir oixrun*.*x*
if "%OS" == "" exit
echo %~nx0 OK. >&2
