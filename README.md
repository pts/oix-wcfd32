# oix-wcfd32: revival of OIX, the Watcom i386 operating-system-independent target

oix-wcfd32 contains development tools, loaders, converters and
documentation for OIX, the Watcom i386 operating-system-independent target.
One goal is porting, i.e. to make it possible to run some old Watcom
programs (WASM and WLINK) using this target on more systems such as Linux
i386 and FreeBSD i386, as well as making it more convenient to run them on
32-bit DOS and Win32. Another goal is helping to write new C and assembly
programs for this target by providing development tools and documentation.

WCFD32 is additional, free and open source software (with development
starting in 2024-04) for OIX. It's independent work not affiliated with Watcom
or its successors. It is based on free software only (mostly OpenWatcom 1.0
and PMODE/W 1.33). It uses the OIX design invented by Watcom in 1994. The
undocumented parts (most of it) have been reverse engineered.

To see source code of simple programs written for OSI, look at
*cf/example.c* and *example.nasm* in this Git repository. The compilation
scripts (running on Linux i386) are also provided.

Original OIX does, but WFCD32 doesn't support 32-bit OS/2 2.x and 32-bit
Windows 3.x as operating systems on which OIX programs can be run. WFCD32
adds new operating systems: Linux i386 (partial but works) and FreeBSD i386
(not started yet).

The license of WCFD32 is GNU GPL v2. All the source code is provided as part
of the Git repository, and it is derived from free software (mostly
OpenWatcom 1.0).

Limitations of OIX (as introduced by Watcom in 1994):

* Only text-mode, noninteractive console programs are supported. (No GUI
  support, no cursor positioning or color support, no text line editing
  support.)
* Only the 32-bit protected mode Intel i386 architecture is supported. Thus
  Intel CPUs earlier than the 80386 (e.g. 8086) are not supported, and the
  64-bit (long) mode of newer Intel x86 CPUs is also not supported. Other
  architectures such as ARM or RISC-V aren't supported either.
* All code and data (.text, .rodata, .data, .bss and .stack sections) is
  read-write-execute.
* It's not possible to return unused memory to the operating system.
* It suppots only file seek offsets less than 2 GiB.
* Watcom hasn't released any official documentation.
* Watcom hasn't made available development tools (such as assemblers, C
  compilers) neither as proprietary nor free software, so it wasn't easy for
  anyone outside Watcom to write programs for it. (This project is an
  attempt to change this, and provide at least some tools.)

In the name WCFD32:

* W stands for Watcom.
* CF stands for the signature in the CF header describing the program image.
* D stands for DOS, because the syscall numbers are the same as in DOS.
* 32 stands for 32-bit protected mode on i386.

The name OIX is an abvreviation of Operating-system-Independent-eXecutable.
the filename extension is also `.oix`.

Some specific goals of WCFD32 (not all of them has been achieved):

* Make it possible to run the precompiled old Watcom tools WASM and WLIB
  (none of them free or open source) on more operating systems such as Linux
  i386 or FreeBSD i386, without virtualization (such as DOSBox or QEMU) or
  heavy and slow-to-start dependencies (such as Wine).
* Make it easier to run the precompiled old Watcom tools on 32-bit DOS and
  Win32.
* Make it possible to write new OIX programs in NASM and WASM assembly language.
* Make it possible and easy to write new OIX programs in C, compiled with
  modern OpenWatcom v2.
* Make it possible write new OIX programs in C using GCC and Clang.
* Make it possible to port existing programs written in C (i.e. with C
  source available) to OIX.

## History of the Watcom i386 operating-system-independent target

The Watcom i386 operating-system-independent target (abbreviated as
`__OSI__` by Watcom coming from `#if defined(__OSI__)`,
also abbreviated here as OIX) is an executable file format
and ABI for 32-bit i386 console programs introduced by Watcom in Watcom
C/C++ 10.0 (in 1994). By writing a C or assembly program once and compiling
it for this target, it is possible to run the same binary program on 32-bit
DOS, 32-bit Windows 3.x
([Win386](https://www.os2museum.com/wp/watcom-win386/), also invented by
Watcom), 32-bit OS/2 2.x, and Win32 (Windows NT and later, Windows 95 and
later). Some of these are supported natively, some are supported with helper
.exe programs (such as *w32run.exe*) put next to the
.exe program file.

These are the programs officially released by Watcom (as part of Watcom
C/C++ 10.x and 11.x) which use OIX:

* WASM (Watcom Assembler) *binw/wasm.exe* in 10.0a, 10.5, 10.6, 11.0b, 11.c.
* WLIB (Watcom Library Manager) *binw/wlib.exe* in 10.5, 10.6 and 11.0b,
  11.c. (In 10.0a, it was a 16-bit DOS program.)
* WLINK (Watcom Linker) *binw/wlink.exe* has never used OIX, it had its own
  DOS extender built in. Likewise, the Watcom C and C++ had their own DOS
  extender unrelated to OIX.

Since these old Watcom programs are not free software, they are not
distributed with WCFD32. If you want to run them, you need to purchase a copy.

Watcom hasn't released development tools (such as as assemblers and C
compilers) for writing programs targeting OIX. By looking at the disassembly
of the programs they released, it looks like they were using the Watcom
C/C++ compiler and WASM (Watcom Assembler) to create those programs, and
also some unreleased custom tools and config files. Some files have been
released as part of OpenWatcom, e.g. the source files for building the
loaders are in the *bld/w32loadr* directory of
[https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip](open_watcom_1.0.0-src.zip)
(2003-01-24).
Also the same source archive contains some C source files with `#if
defined(__OSI__)` indicating that those sources have been compiled for OIX.
The archive also contains *bld/clib/startup/a/cstrtosi.asm*, which is the
entry point (containing the *_cstart_*) function for C programs compiled
with the Watcom C compiler targeting OIX.

However, the compilation scripts and the documentation are not provided, and
it looks like many of the files are missing.

The source code for the loaders (the native program which loads and executes
the OIX program) has been released in the *bld/w32loadr* directory above,
but the source of the DOS extender (needed for building *w32run.exe*) is
missing, and it's not possible to reproduce working binaries with modern
OpenWatcom v2.

Required components (but unreleased by Watcom) for building and running new
software targeting OIX.

* The C runtime library (libc): There are no
  functions like *write(...)*, *printf(...)* or *strlen(...)*. It would be
  possible to build the Watcom C runtime library for the OS-independent
  target, and Watcom developers surely did it for *binw/wasm.exe* and
  *binw/wlib.exe*, but they haven't made it available for others.

  We can work this around for small programs by copying a few source files
  from OpenWatcom: *bld/clib/startup/a/cstrtosi.asm*,
  *bld/watcom/h/watcom.h* and *bld/watcom/h/tinyio.h*.

  *tinyio.h* contains a very small libc, whose functions were used by the
  Watcom tools *binw/wasm.exe* and binw/wlib.exe*, but it is incomplete,
  for example it doesn't have printf(...)* or *strlen(...)*, so apparently
  the Watcom tools used other libs (parts of the Watcom C runtime library).

* The DOS extender and OSI implementation for 32-bit DOS in *w32run.exe*.
  This has never been part of OpenWatcom even though it is mentioned in the
  OpenWatcom 1.0 sources. It was part of Watcom C/C++ 10.0b, but not 10.0c.
  Apparently lots of the source code of the DOS extender is available in
  OpenWatcom 1.0 *bld/w32loadr*: *loader.c* (for *x32run.obj*), *cmain32.asm*,
  *x32start.asm*, but the *x32fix* program is not provided.

  We can work this around by using PMODE/W 1.33 and *wcfd32dos.exe* instead.

* The OSI implementation for OS/2 and DOS loader (which loads *w32run.exe*):
  It can be grabbed from the first 0x2800 bytes of *binw/wasm.exe* and
  *binw/wlib.exe* (in Watcom C/C++ 10.x and 11.x). It looks like it's
  possible to build this from sources: *loader16.asm*, *dpmildr.asm*,
  *int21win.asm* in OpeNWatcom *bld/w32loadr*. But unfortunately the built
  program crashes upon exit on DOSBox.

  We don't need this, all functionality is included in *wcfd32dos.exe*
  above.

* The *w32bind* tool, part of the build process: It's not part of OpenWatcom
  (old or new).

  We work this around by modifying *bld/w32loadr/w32bind.c* in OpenWatcom
  1.0 slightly, and compiling it.

* Documentation of the build process.

  I managed to figure it out by looking at the files in *bld/w32loadr* in
  OpenWatcom 1.0.

## Porting tools in WCFD32

WCFD32 provides the runner program *oixrun*, which can find the OIX program
headers in a program file, load the OIX program image and execute it.
*oixrun* is implemented for Linux i386 (it runs with both 32-bit and 64-bit
Linux kernels), 32-bit DOS and Win32 (it runs on both 32-bit and 64-bit
Windows). It will be implemented for FreeBSD i386.

WCFD32 provides the converter program *wcfd32stub* (currently it runs only
on Linux i386) which can extract the OIX program headers and image from a
program file (typically an .exe, such as
*binw/wasm.exe*), and build new program files by adding a different loader.

WCFD32 provides the following loaders (and *wcfd32stub* can add them):

* The MZ-flavored loader is an .exe program which works on both 32-bit DOS
  (including emulators such as DOSBox) and Win32 (buth 32-bit and 64-bit
  Windows). It has very little memory overhead, and on DOS it can use all
  available conventional and high memory (transparently). The program file is
  self-contained: with the loader and OIX program combined to a single .exe
  file, no other files are needed on the target system to run the program.
  The memory overhead is very small, only about 64 KiB.

* The ELF-flavored loader is a Linux i386 executable program (running on
  32-bit and 64-bit Linux kernels). In the future the same program will run
  on FreeBSD i386 as well. The program file is self-contained: with the
  loader and OIX program combined to a single, statically linked ELF
  executable file, no other files are needed on the target system to run the
  program. *qemu-i386* can be used to run it on non-x86 Linux systems.

## Building OIX programs from NASM assembly source

You can use the *hello.nasm*, *example.nasm* and *oixrun.nasm* NASM assembly
source files in the Git repository can be used as tutorials and reference
implementations to write your own programs.

Please note that NASM (just like other assemblers if a linker is not
involved) is not able to generate relocation entries, so these programs are
written as position-independent code (PIC). Currently this means that one
register (EBP) is used to hold the program base address, and thus it cannot
be used for other purposes at the same time.

The *compile_wcfd32stub.sh* shell script builds these programs (both with
the MZ-flavored loader and the ELF-flavored loader) automatically.

## Building OIX programs from C source

This is very experimental, but it works for a few test programs including
the assembler [mininasm](https://github.com/pts/mininasm). The most severe
limitation is that the libc (C runtime library) is very small, only a
few dozen functions are implemented.

Only the OpenWatcom v2 C compiler (with the *owcc* frontend) can be used for
compilation, and compilation only works on Linux i386. You have to install
OpenWatcom v2 and set your `$PATH` and `$WATCOM` environment variables.

There is an example program source *cf/example2.c*, you can compile it to a
OIX program by running the command `osi/osicc cf/example2.c` on Linux i386.
It generates the file `cf/example2.oix` (and a few intermediate files as
well), Which you can run with `./oixrun cf/example2.oix`. If you don't have
the *oixrun* program yet, run `./compile_wcfd32stub.sh` to build it.

You can then use *wcfd32stub* to create executable programs from
*cf/example2.oix*. `./wcfd32stub cf/example2.oix cf/example2.exe` creates
the program with the MZ-flavored loader, and `./wcfd32stub cf/example2.oux
cf/example2` creates a Linux i386 executable. Run `chmod +x cf/example2`,
and then you can run it as `cf/example2`.

The *osicc* libc is based on the following files:

* *osi/osi_start.c* (program entry point written in assembler, it sets some
  variables and prepares argv and environ) is based on
  *bld/clib/startup/a/cstrtosi.asm* in OpenWatcom 1.0.

* The I/O function implementations (e.g. *write(...)*, *exit(...)* and
  **malloc(...)*) in *osi/__os__.h* are based on bld/watcom/h/tinyio.h*
  in OpenWatcom 1.0. Only a tiny fraction of *tinyio.h* was used.

* Other functions (such as *strlen(...)*) are based on earlier work of the
  author of WCFD32.

* *osi/rex2oix.c* (relocatable executable file format converter) is based on
  *bld/w32loadr/w32bind.c* in OpenWatcom 1.0.

The build process of an OIX program from C source:

* The OpenWatcom v2 C compiler *wcc386* is used to convert the C sources
  (program and libc) to OMF .obj files (with the `.o` extension).

* The OpenWatcom v2 linker WLINK is used to convert the OMF .obj files
  to a Pharlap relocatable executable .rex file. The required directives
  are *system win386* or *format pharlap rex*. The filename extension
  is `.rex`.

* The custom tool *rex2oix* (source code in *osi/rex2oix.c*) is used to
  convert the Pharalap relocatable executable to a OIX program.

* Up to this point everything is automated by *osi/osicc*.

* The OIX program can be run with *oixrun* or converted to combined 32-bit
  DOS and Win32 .exe program with MZ-flavored loader or to Linux i386
  executable (of ELF format), both using the *wcfd32stub* tool.
