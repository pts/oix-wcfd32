# wcfd32-port: a port of old Watcom WASM and WLIB to Linux, Win32 and 32-bit DOS

wcfd32-port is a port of old Watcom development tools WASM (Watcom
Assembler) and WLIB (Watcom Library Manager) to Linux, Win32 and 32-bit DOS.
For each tool, an .exe is provided which works on Win32 and 32-bit DOS, and
a Linux i386 executable program is also provided. For copyright reasons, the
programs are not distributed, but a converter is provided which converts
binw/wasm.exe and binw/wlib.exe to those ported exectables. The converter
runs on Linux i386.

This port is made possible by the the operating-system-independent target
(`#if defined(__OSI__)') of the Watcom C/C++ compiler, still supported by
OpenWatcom 1.0. The official binary releases of binw/wasm.exe and
binw/wasm.exe in Watcom C/C++ 10.x and 11.x contain a stub and and a program
image. wcfd32-port provides stubs each 3 supported operating system, and it
provies a converter (*wcfd32stub*) which runs Linux i386, can extract the
program image from the .exe files, and generate the two programs (one .exe
for Win32 and 32-bit DOS, and a Linux i386 executable program) by combining
the wcfd32-port stubs with the Watcom images.

WCFD32 is the unofficial name used in wcfd32-port for the
operating-system-independent target of the Watcom C/C++ compiler. It is an
ABI for i386 32-bit protected mode programs. It was used by some tools in
Watcom C/C++ compiler (WASM and WLIB), and the corresponding DOS extender
was implemented in binw/w32run.exe. Watcom versions using WCFD32:

* binw/wasm.exe in 10.0a, 10.5, 10.6, 11.0b, 11.c.
* binw/wlib.exe in 10.5, 10.6 and 11.0b, 11.c. (In 10.0a, it was a 16-bit
  DOS program.)
* binw/wlink.exe never used WCFD32, it had its own DOS extender built in.

In the name WCFD32:

* W stands for Watcom.
* CF stands for the signature of CF header describing the program image.
* D stands for DOS, because the syscall numbers are the same as in DOS.
* 32 stands for 32-bit protected mode on i386.
