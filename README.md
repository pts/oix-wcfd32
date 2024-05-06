# oix-wcfd32: revival of OIX, the Watcom i386 operating-system-independent target

oix-wcfd32 contains development tools, runners, converters and
documentation for OIX, the Watcom i386 operating-system-independent target.
One goal is porting, i.e. to make it possible to run some old Watcom
programs (WASM and WLIB) using this target on more systems such as Linux
i386 and FreeBSD i386, as well as making it more convenient to run them on
32-bit DOS and Win32. Another goal is helping to write new C and assembly
programs for this target by providing development tools and documentation.

WCFD32 is additional, free and open source software (with development
starting in 2024-04) for OIX. It's independent work not affiliated with Watcom
or its successors. It is based on free software only (mostly OpenWatcom 1.0
and PMODE/W 1.33). It uses the OIX design invented by Watcom in 1994. The
undocumented parts (most of it) have been reverse engineered.

To see source code of simple programs written for OIX, look at
*osi4/hello.c*, *osi4/talk.c* and *asm\_demo/hello.nasm* in this Git
repository. The compilation scripts (running on Linux i386) are also
provided.

In addition to the targets 32-bit DOS, Win32 and OS/2 2.0+ supported by W32,
the original Watcom implementation of OIX, WCFD32 also supports Linux i386
and FreeBSD i386 (coming soon). For OS/2 2.0+ support, the *poix/oixrun.c*
source file has to be compiled by the OpenWatcom v2 compiler. For 32-bit
DOS, Win32, Linux i386 and FreeBSD i386, a pure assembly implementation is
provided in NASM syntax (it's called the WCFD32 runtime system), and the
conversion tool *oixconv* is also provided to convert OIX programs to native
programs (for operating systems supported by the WCFD32 runtime system).

The license of WCFD32 is GNU GPL v2. All the source code is provided as part
of the Git repository, and it is derived from free software (mostly
OpenWatcom 1.0 and PMODE/W 1.33).

Limitations of OIX (as introduced by Watcom in 1994):

* Only text-mode, noninteractive console programs are supported. (No GUI
  support, no cursor positioning or color support, no text line editing
  support.)
* Only the 32-bit protected mode Intel i386 architecture is supported. Thus
  Intel CPUs earlier than the 80386 (e.g. 8086) are not supported, and the
  64-bit (long) mode of newer Intel x86 CPUs is also not supported. Other
  architectures such as ARM or RISC-V aren't supported either.
* All code and data (.text, .rodata, .data, .bss and .stack sections) is
  read-write-execute. This makes it an easer target for hackers.
* It's not possible to return unused memory to the operating system.
* It suppots only file seek offsets less than 2 GiB.
* Debugging is not supported. There is no symbol table or other debug info.
* Networking is not supported.
* Multihreaded programs are not supported.
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

Some specific goals of WCFD32 (not all of them has been achieved yet):

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
Watcom), 32-bit OS/2 2.0+, and Win32 (Windows NT and later, Windows 95 and
later). Some of these are supported natively, some are supported with helper
.exe programs (such as *w32run.exe*) put next to the
.exe program file.

These are the programs officially released by Watcom (as part of Watcom
C/C++ 10.x and 11.x) which use OIX:

* WASM (Watcom Assembler) *binw/wasm.exe* in 10.0a (1994-09-01), 10.5
  (1995-07-11), 10.6 (1996-02-29), 11.0b (1998-02-24, 11.0c (2002-08-27).
* WLIB (Watcom Library Manager) *binw/wlib.exe* in 10.5, 10.6 and 11.0b,
  11.0c. (In 10.0a, it was a 16-bit DOS program.)
* WLINK (Watcom Linker) *binw/wlink.exe* has never used OIX, it had its own
  DOS extender built in. Likewise, the Watcom C and C++ compilers had their
  own DOS extender unrelated to OIX.

Since these old Watcom programs are not free software, they are not
distributed with WCFD32. If you want to run them, you need to obtain a copy
separately.

Watcom hasn't released development tools (such as as assemblers and C
compilers) for writing programs targeting OIX. By looking at the disassembly
of the programs they released, it looks like they were using the Watcom
C/C++ compiler and WASM (Watcom Assembler) to create those programs, and
also some unreleased custom tools and config files. Some files have been
released as part of OpenWatcom, e.g. the source files for building the
runners (loaders) are in the *bld/w32loadr* directory of
[open_watcom_1.0.0-src.zip](https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip)
(2003-01-24).
Also the same source archive contains some C source files with `#if
defined(__OSI__)` indicating that those sources have been compiled for OIX.
The archive also contains *bld/clib/startup/a/cstrtosi.asm*, which is the
entry point (containing the *_cstart_*) function for C programs compiled
with the Watcom C compiler targeting OIX.

However, the compilation scripts and the documentation are not provided, and
it looks like many of the files are missing.

The source code for the runners (the native program which loads and executes
the OIX program) has been released in the *bld/w32loadr* directory above,
but the source of the DOS extender (needed for building *w32run.exe*) is
missing, and it's not possible to reproduce working binaries with modern
OpenWatcom v2.

Required components (but unreleased by Watcom) for building and running new
software targeting OIX:

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

* The DOS extender and OIX implementation for 32-bit DOS in *w32run.exe*.
  This has never been part of OpenWatcom even though it is mentioned in the
  OpenWatcom 1.0 sources. It was part of Watcom C/C++ 11.0b, but not 11.0c.
  Apparently lots of the source code of the DOS extender is available in
  OpenWatcom 1.0 *bld/w32loadr*: *loader.c* (for *x32run.obj*), *cmain32.asm*,
  *x32start.asm*, but the *x32fix* program is not provided.

  We can work this around by using PMODE/W 1.33 and *wcfd32dos.exe* instead.

* The OIX implementation for OS/2 2.0+ and DOS runner (which loads
  *w32run.exe*): It can be grabbed from the first 0x2800 bytes of
  *binw/wasm.exe* and
  *binw/wlib.exe* (in Watcom C/C++ 10.x and 11.x). It looks like it's
  possible to build this from sources: *loader16.asm*, *dpmildr.asm*,
  *int21win.asm* in OpeNWatcom *bld/w32loadr*. But unfortunately the built
  program crashes upon exit on DOSBox.

  We don't need this, all functionality is included in *wcfd32dos.exe*
  above.

* The *w32bind* tool, part of the build process: The precompiled .exe is not
  part of OpenWatcom (old or new).

  We work this around by modifying *bld/w32loadr/w32bind.c* in OpenWatcom
  1.0 slightly, and compiling it.

* Documentation of the build process.

  I managed to figure it out by looking at the files in *bld/w32loadr* in
  OpenWatcom 1.0.

## The OIX executable file format

Most of this has been reverse engineered for WCFD32. Source code of some
relevant runners and tools have been studied in the *bld/w32loadr* directory
of the OpenWatcom 1.0 sources.

The OIX program file may contain additional data and code alongside the OIX
program. The OIX program conists of the 0x18-byte CF header (with 4 bytes of
signature: `"CF\0\0"`), a read-write-execute image byte array, and a
relocation table (part of the image). The memory size can be larger than the
load size, to accommodate zero-initialized BSS.

The CF header can be in the beginning of the program file, or near the
beginning (fitting to the first 0x200 bytes), with some within-file pointers
describing how to find it. The Watcom tools (e.g. *w32run.exe*) were able to
find it only at one location, the WCFD32 runtime system can find it at
multiple additional locations, including the beginning of the file.

The CF header consits of 6 dwords, each dword being a little-endian 32-bit
number (indicated as `dd` below):

```
struct cf_header {  /* 0x18 bytes. */
  uint32_t signature;  /* "CF\0\0"; 'C'|'F'<<8. */
  uint32_t load_fofs;  /* Start reading the image at this file offset. */
  uint32_t load_size;  /* Load that many image bytes. */
  uint32_t reloc_rva;  /* Apply relocations starting in the file at load_fofs+reloc_rva. */
  uint32_t mem_size;   /* Preallocate this many bytes of memory for the image. Fill the bytes between load_size and mem_size with NUL (0 byte). */
  uint32_t entry_rva;  /* To start the program, do a far call to this many bytes after the allocated memory region. */
};
```

OIX programs don't have a section table (everything is .text), and they
don't have debug info. But they have a header, an image (containing .text
and relocations) and .bss (zero-initialized program data).

This is how the Watcom tools (such as *w32run.exe*) find the CF header: get
16-bit little-endian integer at file offset 8 (DOS .exe .hdrsize), maximum
allowed value 0x1e, multiply it by 0x10, check that the CF signature (4
bytes: `"CF\0\0"`) is there at that file offset.

The *oixrun* and *oixconv* tools in WCFD32 runtime system find the CF
header like this (compatible with the Watcom tools), in this order:

* If the file starts with the CF signature (4 bytes: `"CF\0\0"`), then it's
  there (at file offset 0).

* If the file starts with the ELF signature (4 bytes: `"\x7f""ELF"`), and
  there is a CF signature at file offset 0x54 (that's right after the ELF-32
  ehdr and a single phdr), then it's there.

* If the file has the CF signature at file offset 0x20, then it's there.

* This is the as the Watcom tools do it: get 16-bit little-endian integer at
  file offset 8 (DOS .exe .hdrsize), maximum allowed value 0x1e, multiply it
  by 0x10 (maximum allowed value 0x1e0), check that the CF signature (4 bytes:
  `"CF\0\0"`) is there at that file offset, then it's there.

Here is how an OIX runner loads and runs an OIX program:

* Open the program file, find and read the CF header (see above).

* Allocate cf_header.mem_size bytes of memory, aligned to a multiple of 4
  bytes. Remember the starting address as image_base.

* Read cf_header.load_size bytes from the program file, starting at file
  offset cf_header.load_fofs to memory address image_base.

* Apply relocations starting at image_base + cf_header.reloc_rva.

* Prepare the registers and the stack, and do a far call to image_base +
  cf_header.entry_rva.

* When the far call returns, use the value of register AL as process exit
  code, and exit.

The relocation table is an array of 16-bit little-endian integers. It
consists of 0 or more nonempty blocks and then a terminating 0 integer. An
empty relocation table is just the terminating 2 zero bytes. Most of the
relocations take only 2 bytes (a single integer). This is rather nicely
packed, like Win32 PE relocations. LE relocations are longer, they take at
least 7 bytes.

Here is how to apply the relocations:

* Start reading relocation table starting at image_base +
  cf_header.reloc_rva, process each nonempty block, stop at the terminating
  0 integer. More details below.

* First read the next integer as block_size, then repeat this while
  block_size is nonzero:

  * Read 2 integers (high first, low second!), and build the address as
    `image_base + (high << 16 | low)`.

  * Repeat this block_size times:

    * Apply a single relocation at the address: load a 32-bit little-endian
      integer from 4 memory bytes at the address, add the image_base to the
      integer, and save the result to the 4 memory bytes at the address.

    * Read an integer, and add it to the address.

  * Use the last integer read as the block_size of the next block.

Some of the Watcom tools load Watcom resource data from the file near its
the end (after the OIX image). However, this is unrelated to OIX executable
file format, they do the same for DOS .exe, Win32 PE .exe and Linux i386
ELF-32 file formats. The *oixconv* tool copies this resource data by just
copying everything after the OIX image.

Here is the initial register setup of the OIX program entry point (based on
*bld/clib/startup/a/cstrtosi.asm* in OpenWatcom 1.0 sources):

* ESP is set to the far return address: dword \[esp\] is the return offset
  and dword \[esp+4\] is the return segment. Upon return, the OIX program
  should set AL to the program exit code.
* AH is set to the operating_system identifier. The rest of EAX is uninitialized.
* ECX is set to the stack low pointer (or NULL if unknown) to indicate the
  stack size available for the OIX program. The stack is between ECX and ESP.
* BX is set to the segment of the syscall handler (\_\_Int21) callback
  provided by the runtime, with which the OIX program can initiate I/O. The
  rest of EBX is uninitialized.
* EDX is set to the offset of the syscall handler callback.
* ESI is uninitialized.
* EBP is uninitialized.
* EFLAGS is uninitialized.
* EDI points to the beginning of the info struct:
  ```
  struct pgmparms {
    char *program_filename;
    char *command_line;
    char *env_strings;
    unsigned *break_flag_ptr;
    char *copyright;
    unsigned is_japanese;
    unsigned max_handle_for_os2;
  };
  ```
* program_filename contains argv[0], and is NUL-terminated. It can be used
  to open the program file and read e.g. resource data.
* command_line contains arg[1:], whitespace-separated, NUL-terminated.
* env_strings contains each envionment string as *KEY=VALUE* and it
  NUL-terminated. It has an extra NUL indicating the end.
* break_flag_ptr is a pointer to break flag which the runner can set to
  nonzero to indicate break (SIGINT, Ctrl-*C*).
* copyright is a NUL-terminated copyright message of the runner, typically
  NULL. WCFD32 sets it to NULL.
* is_japanese indicates non-English locale (isDBCS). WCFD32 sets it to NULL.
* max_handle_for_os2: maximum number of filehandles for OS/2 2.0+. WCFDS32
  sets it to 0 except on OS/2 2.0+.
* BSS is not initlizated with 0 bytes. (But the WCFD32 runtime system and
  *oixrun.c* do it.)

TODO(pts): Write about the syscall (\_\_Int21) ABI.

## Executable file format debugging

The OpenWatcom *wdump* tool can be used to display headers, relocation data,
debug info etc. about DOS MZ .exe programs , Win32 PE .exe programs, OS/2
2.0+ or DOS extender LX/LE .exe programs, Pharlap relocatable executable
.rex files, but unfortunately it doesn't support OIX programs, not even
those which were shipped by Watcom.

## The WCFD32 runtime system

The WCFD32 runtime system (in short: the runtime) is a set of tools for
running and converting OIX programs. There are separate developer tools and
documentation for writing new OIX programs, see them elsewhere in this
document.

**TL;DR** The WCFD32 runtime system contains the runner program *oixrun*,
which can find the OIX program headers in a program file, load the OIX
program image and execute it.
*oixrun* is implemented for Linux i386 (it runs with both 32-bit and 64-bit
Linux kernels), 32-bit DOS and Win32 (it runs on both 32-bit and 64-bit
Windows). It will be implemented for FreeBSD i386.

If you only have the runtime, but no OIX programs, you can try the runtime
with the following command: *./oixrun oixrun.oix*. This will display usage
information. If you don't even have the runtime, then get it by cloning the
https://github.com/pts/oix-wcfd32 sources, and running *sh compile.sh* (on
Linux) or *compile.cmd* (on Win32) in the *run1* subdirectory. This will
generate files *oixrun*, *oixrun.exe*, *oixrun.oix* and others.

The runtime consists of the following programs:

* *oixrun*: This is the runner command-line tool, which can run an OIX
  program file. It works like this: `./oixrun <prog.oix> <arg1> <arg2> ...`.
  Not all OIX programs have an
  .oix extension, for example the Watcom tools *binw/wasm.exe* and
  *binw/wlib.exe* have the .exe extension. The runtime doesn't care about
  the filename or extension, it finds the and runs the OIX program within
  those files as well.

  *oixrun* has been ported to multiple operating systems, and all of them
  are built from source as port of the WCFD32 runtime build process (see
  below). The build process generates *oixrun.exe* which works on Win32 and
  32-bit DOS, and and the *oixrun* executable program, which works on Linux
  i386 (and it will also work on FreeBSD i386). Other operating systems
  (such as OS/2 2.0+ or macOS 10.14 Mojave or earlier) are supported by the
  C reference implemention *poix/oixrun.c* instead, and such such support is
  not compiled into this implementation of the WCFD32 runtime system.

* *oixconv*: A command-line tool which can convert OIX program files. One
  possible conversion is converting an OIX program (.oix, .exe etc.) to a
  self-contained native executable program, embedding *oixrun*, so that it
  doesn't need an external *oixrun* program to run. Conversions targets:

  * an .exe which works on both Win32 (including 64-bit Windows systems,
    also including emulators like Wine) and 32-bit DOS (including emulators
    like DOSBox). Do the conversion like this: `./oixconv <prog.oix>
    <prog.exe> exe`. The output file still contains the OIX program, and can
    be converted further later. The output file is also called MZ-flavored,
    named after the MZ .exe header.

    The output .exe file has very little memory overhead (less than 64 KiB
    on DOS), and on DOS it can use all available conventional and high
    memory (transparently). The program file is self-contained: with the
    runner and OIX program combined to a single .exe file, no other files
    are needed on the target system to run the program.

  * an i386 ELF-32 executable program which runs on Linux i386 (and amd64)
    and FreeBSD i386 (and amd64) systems. Do the conversion like this:
    `./oixconv <prog.oix> <prog> elf`, and then `chmod +x prog`.  The output
    file still contains the OIX program, and can be converted further later.
    The output file is also called ELF-flavored, named after the ELF-32
    (native) executable file format it uses.

    The output program file is self-contained: with the runner and OIX
    program combined to a single, statically linked ELF executable file, no
    other files are needed on the target system to run the program.
    *qemu-i386* can be used to run it on non-x86 Linux systems.

  * an i386 ELF-32 executable program which runs on Linux i386 (and amd64)
    and FreeBSD i386 (and amd64) systems, which is pre-relocated, so it a
    bit faster to start up, but it is not an OIX program anymore.
    *oixconv* can still convert it back to an OIX program later. Do the
    conversion like this: `./oixconv <prog.oix> <prog> epl`.

  * just an OIX program file (.oix), without any other (native)
    functionality. It needs *oixrun* to run.

  With these conversions, it's trivial to port a OIX program to many target:
  just compile it to an OIX program, and then run *oixconv* to generate the
  target-specific executables.

  *oixconv* is not implemented yet, currently a temporary stop-gap tool
  *wcfd32stub* is provided instead (as part of the runtime), and it runs on
  Linux i386 only. *wcfd32stub* can:

  * create the Win32--DOS dual .exe: *./wcfd32stub <prog.oix> <prog.exe>*

  * create a pre-relocated Linux i386 executable (which cannot be converted
    back to an OIX program file): *./wcfd32stub <prog.oix> <prog> epl*.

The runtime is able to run the Watcom tools such as *binw/wasm.exe* and
*binw/wlib.exe*, released between 1994 and 2002, see above which Watcom
C/C++ version had them. For example, run `./oixrun wasm.exe testprog.asm`.
The Watcom tools are not distributed together with the runtime (because they
are neither open source nor free software, because they were released before
OpenWatcom), you need to obteain them separately.

The development of the runtime started in 2024-04 by studying the
*bld/w32loadr* directory of
[open_watcom_1.0.0-src.zip](https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip)
(2003-01-24), and reverse engineering some Watcom tools. The initial goal
for this development was running the Watcom tools on Linux i386. This has
been achieved by writing a brand new runtime implementation targeting Linux.
Since then the runtime has been implemented for 32-bit DOS and also Win32.
The latter was heavily based on the runner found in the *bld/w32loadr*
directory of the OpenWatcom 1.0 sources. The runtime, having reached its
original goal, is still under development.

The runtime is free and open source software (GNU GPL v2), it is written in
[NASM (Netwide Assembler)](https://www.nasm.us/) assembly language, using
NASM 0.98.39 (2005-01-15) for reproducible builds, but newer versions of
NASM are also able to compile it. A copy of NASM 0.98.39 precompiled for
Linux i386 and Win32 is bundled with the runtime sources. In addition to
NASM, the runtime also uses the WLINK (OpenWatcom Linker) tool for linking,
from [OpenWatcom
1.4](http://openwatcom.org/ftp/archive/open-watcom-c-win32-1.4.exe)
(2005-11-15). Newer versions of WLINK are also able to link it. A copy of
WLINK 1.4 precompiled for Linux i386 and Win32 is bundled with the runtime
sources. The runtime uses the DOS extender
[PMODE/W](http://www.sid6581.net/pmodew/) 1.33 (1997-01-01, open sourced in
2023-07 under the MIT license) as the DOS stub, a copy of *pmodew.exe* is
bundled with the runtime sources.

It's possible to build the runtime on any system which has NASM and WLINK
installed, but it's most convenient to do so on Linux i386 (or amd64) or
Win32 (including 64-bit x86 Windows) systems, for which build automation is
provided and the tools NASM and WLINK are precompiled and bundled. For
version 1, the automation for Linux is the simple and short shell script
[build.sh](https://github.com/pts/oix-wcfd32/blob/master/run1/build.sh) (run
it as `sh build.sh` after cloning the Git repository), and for Win32 is the
simple and short .cmd script
[build.cmd](https://github.com/pts/oix-wcfd32/blob/master/run1/build.cmd)
(run it as `build.cmd` from within the cmd.exe Command Prompt window after
cloning the Git repository). (On Windows 95, copy or rename *build.cmd* to
*build.bat*, and then run it.) (The minimum version of Windows which can run
*build.cmd* is Windows NT 3.5, because earlier Windows versions didn't have
long filename support. Please note that Windows Nt 3.5 can't exit early on
failure.) It's also possible to run *build.cmd* in Wine, like this `wine cmd
/c build.cmd`. As of the writing of this paragraph, the build automation
script runs NASM 13 times and WLINK 2 times, producing multiple temporary
files and final output files. It all happens in less than a second on a
modern system.

The build process of the runtime:

* is reproducible: it produces identical files as output when run again on
  the same sources.
* is multi-target: it builds for all targets (operating systems). Currently
  this is Win32, 32-bit DOS and Linux. FreeBSD is planned.
* uses only cross-compilation: it doesn't run any program it builds on the
  build host system, it runs NASM and WLINK only. (Thus it's possible to
  build the runtime even on non-i386 systems, if NASM and WLINK are built
  from source first for the host system.)
* is non-incremental: the build automation script does a full build each
  time it is run. This is OK, because it's still fast enough.

It is planned to drop the build dependency of the runtime on WLINK, by
recreating the linker functionality in pure NASM (with `nasm -f bin`). This
will be possible, but it is especially tricky for LE (32-bit DOS) and PE
(Win32) executables with relocation. After that point building the runtime
will depend on NASM only.

## The C reference implementation

The file *poix/oixrun.c* is a reference implementation of the *oixrun*
runner tool, written in C. It supports the following targets:

* Any Unix system with a C compiler (tested on Linux with GCC and Clang)
  targeting i386. It uses the POSIX library functions (open(2), lseek(2),
  ftruncate(2), read(2), write(2), isatty(2), close(2), mmap(2), sbrk(2),
  exit(2), rename(2), unlink(2)) and global variables (errno and environ)
  and libc string funcions (memcpy(3) and strlen(2)). By default it uses
  mmap(2) for memory allocation (specify `-DUSE_SBRK` to use sbrk(2)
  instead), because that's the reliable way to get read-write-execute pages
  needed by OIX programs.

* Win32 (tested with the OpenWatcom v2 C compiler and the [Digital Mars C
  compiler](https://www.digitalmars.com/download/freecompiler.html)). It
  uses VirtualAlloc(...) for memory allocation. It uses chsize(...), because
  ftruncate(...) is not available.

* OS/2 2.0+ (tested with the OpenWatcom v2 C compiler). It uses
  DosAllocMem(...) for memory allocation. It uses chsize(...), because
  ftruncate(...) is not available.

It doesn't do any CPU emulation, so it works only if the target uses the
i386 CPU in 32-bit protected mode.

It is written in C89 (ANSI C), except that ot uses a short trampoline
function implemented in NASM assembly. The trampoline function is neede to
translate between real and far calls, and to work with any C calling
convention.

## Watcom resource data

Some Watcom program files (such as WASM, WLIB and WLINK, but not *wcc* or
*wcc386*) contain resource data. The program opens its own program file,
finds, reads and uses the resource data. Most of the resource data content
is error messages.

When converting Watcom OIX program files, the resource data must be kept
intact. Since it is at the end of the program file, *oixconv* keeps it
by just copying everything after the OIX image.

Here is some more info about about the Watcom resource data format. There
are two headers: the debug header (*struct dbgheader*) and the resource
header (*struct WResHeader*). The program first loads the debug header from
the very end of the file. The debug header is 14 bytes long, it starts with
a 2-byte signature (`"\x02\x83", named *WAT\_RES\_SIG*), and it ends with
the *debug\_size* field (32-bit little endian integer). Subtracting the
*debug\_size* value from the file size, the program gets the offset of the
start of the resource data, starting with the resource header, starting with
8 bytes of signature (`"\xd7\xc1\xd4\xc3\xcf\xcd\xd2\xc3\x8c", named
*WRESMAGIC0* and *WRESMAGIC1*`).

## Building OIX programs from NASM assembly source

You can use the *asm\_demo/answer42.nasm*, *asm\_demo/hello.nasm*,
*asm\_demo/example.nasm*, *asm\_demo/talk.nasm* and
*run1/oixrun.nasm* NASM assembly source files
in the Git repository as tutorials and reference implementations to write
your own programs.

Please note that NASM (just like other assemblers if a linker is not
involved) is not able to generate relocation entries, so these programs are
written as position-independent code (PIC). Currently this means that one
register (EBP) is used to hold the program base address, and thus it cannot
be used for other purposes at the same time. An alternative, with relocation
support, would be similar to version 4 of the C source design (see below),
which would involve NASM + WLINK + *rex2oix*, but no examples are provided
for that.

The *compile\_wcfd32stub.sh* shell script builds these programs (both with
the MZ-flavored runner and the ELF-flavored runner) automatically.

## Building OIX programs from C source

### Version 3: with manual wrapping of global variables

This is very rough, and it needs substantial changes to the C source,
but it at least works for a few test programs and also *osi4/rex2oix.c*
(which is a bit more complex than a test program, and it was surprisingly
easy to convert). The most important limitation that each global variable
and string literal access must be wrapped in the source code, because of the
lack of relocation support in the compiler + linker. The second most severe
limitation is that the libc (C runtime library) is very small, only a
few dozen functions are implemented.

Most of the issues below (e.g. floating point, string literals, function
pointers, global variables) are because in this compilation mode (Watcom C
compiler + WLINK *format raw bin* directive) doesn't support relocations,
and global variables (including string constants) require relocations. The
convenient workaround for other compilers would be position-independent code
(e.g. *gcc -fpic*), but the Watcom C compiler doesn't support that either.
So the solution here is manually wrapping each global variable in the source
code to instruct the program to calculating the address of the variable at
runtime.

More details:

* See *osi3/answer42.c*, *osi3/hello.c*, *osi3/talk.c*, *osi3/global.c* and
  *osi4/osi2rex.c* as example programs of increasing complexity.
* See *osi3/answer42.c*, *osi3/hello.c*, *osi3/talk.c* and *os3/global.c* as
  example programs of increasing complexity.
* Only Linux is supported as a host for compiling. The target is OIX, which
  implies the i386 ISA (32-bit Intel x86) in 32-bit protected mode.
* Use `./osicc prog.c helper1.c helper1` helper script to compile the program.
* The helper script runs the Watcom C Compiler. Have the *wcc386* and
  *wlink* commands on your path. A recent [OpenWatcom v2
  release](https://github.com/open-watcom/open-watcom-v2/releases) will work
  fine. The earliest one I could find was from
  [2020-09-08](https://github.com/open-watcom/open-watcom-v2/releases/tag/2020-09-08-Build).
  The first version of WLINK which supports *format raw bin* came with
  OpenWatcom 1.9 (2010-05-25), but that was buggy when calculating symbol
  offsets (probably because of miscalculating the alignment). Maybe earlier
  versions of OpenWatcom v2 were already good, but I wasn't able to find any
  to try.
  Put the *binl* directory to your `$PATH`. No need to set the
  `$WATCOM` or `$INCLUDE` environment variables.
* You can define your main function as: any of:
  ```C
  int main(void) { ... }
  int main(int argc) { ... }
  int main(int argc, char **argv) { ... }
  int main(int argc, char **argv, char **envp) { ... }
  ```
* In your main source file, put the main(...) function last, and don't
  declare any non-const static global variable within the function. If you
  do so, some runners will fail to load the program because of load_size
  alignment issues.
* Don't do any floating-point calculations. If you do so, the Watcom C
  compiler may put some of your constants to global variables, and your
  program will crash.
* You must wrap string literals ("...") within S(...) before use,
  otherwise your program will crash. Each such wrapping does a quick
  function call, which increased your code size, and it makes it slower.
* You must wrap function pointers within S(...) before use
  otherwise your program will crash. Each such wrapping does a quick
  function call, which increased your code size, and it makes it slower.
  Example: change `cmp_func` to `S(cmp_func)` in
  `qsort(array, count, sizeof(array[0]), cmp_func)`.
* There is no need to `#include` any header files (and you get a compiler
  error if you try), all the standard library is preincluded.
* There is no *errno*, it's impossible to tell what the error was.
* If you want to use global variables other than *environ*, you need to wrap
  them to global structs. See `GSTRUCT` in global.c* for how. Without that,
  your program will crash. Each use does a quick function call, which
  increased your code size, and it makes it slower.
* The standard library (libc) is included, but it is very limited. For
  example, all `<stdio.h>` functionality is missing (including *printf* and
  *scanf*). For file I/O, there is *open*, *creat*, *read*, *write*, *lseek*
  (int32_t offsets, maximum file size is 2 GiB - 1 byte) and *close*.
* *open* doesn't support file creation. Create (or truncate) files with
  *creat* instead.
* *malloc* is available for allocating (heap, dynamic) memory. It will align
  the returned pointer to 4 bytes. You can allocate small or large blocks,
  or mixed. There is no *free*, *realloc* or *calloc.
* There is a small code generation bloat, so your final executable will be a
  bit larger than a perfectly optimized one could be.
* By adding a few `#define`s and `#include`s to the top of your C code (see
  the example .c files), it's possible to make them work both with `__OSI__`
  target and as regular C programs.
* All I/O is binary. For DOS compatibility, you should explicitly write
  `"\r\n"` as line terminator for DOS compatibility. This works on Linux and
  Windows as well. If you don't want the `"\r"` (CR) in files, then check
  `isatty(STDOUT_FILENO)`, and write only if it's true.
* There is no code run at program startup or exit, and you can't register
  any code to be run.
* Global variables must be unininitialized (will be zero-initialized) or
  they must be initialized to compile-time (or link-time) constants.

It was a miracle that creating OIX executables (including the header) and
doing manual relocations was possible from Watcom C, without writing any
part of the code as a separate assembly file. (There is quite a lot of
inline assembly though in *osi3/\_\_osi\_\_.h*.)

The build process is automated by the  *osi3/osicc* shell script, which runs
on Linux. The generated OIX program file can be run with *oixrun* or
converted to combined 32-bit DOS and Win32 .exe program with MZ-flavored
runner or to Linux i386 executable (of ELF format), both using the
*wcfd32stub* tool.

### Version 4: with automatic relocations

This works for a few test programs including
the assembler [mininasm](https://github.com/pts/mininasm). The most severe
limitation is that the libc (C runtime library) is very small, only a few
dozen functions are implemented. The `<stdio.h>` functions (such as *printf*
and *scanf*) are all missing. The function coverage is the same is in
version 3, but this version has full support for global variables without
wrapping. This is achieved by a multi-step process involving the Pharlap
relocatable executable (.rex) format, see below.

See *osi4/answer42.c*, *osi4/hello.c*, *osi4/talk.c*, *osi4/global.c* and
*osi4/osi2rex.c* as example programs of increasing complexity.

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
the program with the MZ-flavored runner, and `./wcfd32stub cf/example2.oux
cf/example2` creates a Linux i386 executable. Run `chmod +x cf/example2`,
and then you can run it as `cf/example2`.

The *osicc* libc is based on the following files:

* *osi4/osi_start.c* (program entry point written in assembler, it sets some
  variables and prepares argv and environ) is based on
  *bld/clib/startup/a/cstrtosi.asm* in OpenWatcom 1.0.

* The I/O function implementations (e.g. *write(...)*, *exit(...)* and
  **malloc(...)*) in *os4i/\_\_osi\_\_.h* are based on bld/watcom/h/tinyio.h*
  in OpenWatcom 1.0. Only a tiny fraction of *tinyio.h* was used. This is
  unchanged since version 3 above. It has been extended since OpenWatcom 1.0,
  and error returns were improved.

* The non-I/O functions (such as *strlen(...)*) are based on earlier work of
  the author of WCFD32. It even includes a decent *qsort(...)*
  implementation based on [heap
  sort](https://github.com/pts/minilibc686/blob/master/fyi/c_qsort_fast.c).

* *osi/rex2oix.c* (relocatable executable file format converter) is based on
  *bld/w32loadr/w32bind.c* in OpenWatcom 1.0. Mostly compression support has
  been removed and C language portability has been improved, including the
  global variable mappings for \_\_OSI\_\_ version 3 above (not necessary
  for version 4 anymore).

The build process of an OIX program from C source:

* The OpenWatcom v2 C compiler *wcc386* is used to convert the C sources
  (program and libc) to OMF .obj files (with the `.o` extension).

* The OpenWatcom v2 linker WLINK is used to convert the OMF .obj files
  to a Pharlap relocatable executable .rex file. The required directives
  are *system win386* or *format pharlap rex*. The filename extension
  is `.rex`.

* The custom tool *osi4/rex2oix* (source code in *osi4/rex2oix.c*) is used
  to convert the Pharalap relocatable executable to a OIX program.

* Up to this point everything is automated by the *osi4/osicc* shell
  script.

* The OIX program can be run with *oixrun* or converted to combined 32-bit
  DOS and Win32 .exe program with MZ-flavored runner or to Linux i386
  executable (of ELF format), both using the *wcfd32stub* tool.

It looks like this build process (with *oix2rex*) is very similary to what
could have been used by Watcom to produce their OIX programs. The notable
difference is the libc: Watcom used their own libc, while this design has a
tiny libc embedded.

### Version 5: with convenient libc functions available

This is brand new, independent implementation supporting multiple C
compilers. It's based on the *minicc* tool in
[minilibc686](https://github.com/minilibc686). The most important benefit is
that it uses part of the *minilibc686* libc with more than 140 functions,
finally including *printf* (but no *scanf* yet). It is finally able to
compile NASM 0.98.39 (2005-01-15) after applying a few small patches.

See *osi5/answer42.c*, *osi5/hello.c*, *osi5/talk.c*, *osi5/global.c* and
*osi4/osi2rex.c* as example programs of increasing complexity.

This is very experimental and not yet productionized. Eventually it will be
merged to *minilibc386*, and building OIX programs will be as easy as
running `minicc --oix prog.c`.

It is not an immediate goal here to use the OpenWatcom v2 libc, because the
others are simpler to port to OIX, they are less bloated, and with *minicc*
it's possible to use different C compilers (including Watcom C).

Eventually not only *minilibc386*, but also *diet libc* (with many more
functions) will be supported, and the compilation command will be as easy
simple as `minicc --oix --diet prog.c`. This will add more than 930
functions (but many of them are Linux-specific I/O functions, thus useless
for OIX).

The build process of an OIX program from C source:

* The *minicc* driver script is run with any C compiler it supports (Watcom
  C by default, but GCC, Clang, TinyCC and PCC are also supported) and the
  *minilibc686* libc (using 386 instructions only). A modified *libc.a* is
  used with the Linux-specific functions (such as system call wrappers like
  write(2)) removed.

* The entry point function (*_start*), the exit functions (*exit*, *_exit*),
  the malloc helper function (*mini_malloc_simple_unaligned*) and the I/O
  functions (*open*, *creat*, *close*, *read*, *write*, *lseek*, *isatty*,
  *remove*, *unlink*, *ftruncate_here*, *ftruncate*) are implemented in
  assembly in *osi5/osi5_start.nasm*, which is also compiled. Dummy
  replacements are also provided for *time* and *strerror*.

* GNU ld(1) is run (as driven by *minicc*) for linking compiled user code,
  system-independent libc code and the reimplemented libc functions above to
  an i386 ELF-32 executable program. The linker flag *ld -q* is used to keep
  all relocations in the program file. Please note that this ELF-32 program
  doesn't run on Linux, because the Linux-specific I/O functions (e.g.
  *write*) have been replaced by OIX-specific ones.

* A custom tool, the Perl script *osi5/elf2oix.pl* is run to convert the
  ELF-32 program file to an OIX program. It copies and converts relocations
  as well. This Perl script can be reimplemented in C (or even in assembly)
  in the future.

* The *osi5/osicc* shell script automates the build process all above. It's
  not fully automated yet, some direcory names (e.g. to *minicc*) may have
  to changed by editing the script.

* The OIX program can be run with *oixrun* or converted to combined 32-bit
  DOS and Win32 .exe program with MZ-flavored runner or to Linux i386
  executable (of ELF format), both using the *wcfd32stub* tool.

## Running OIX programs on Linux directly

The *binfmt_misc* Linux kernel module makes the kernel able to run any
program files, by using a configured set of userspace helpers. On
Debian-based Linux distributions it's possible to use the *update-binfmts*
program to configure the Linux kernel to run OIX programs directly. Do it
like this:

* Run `./compile_wcfd32stub.sh`. It generates the *oixrun* ELF executable
  program.

* Run `sudo chown root. oixrun`, and then run `sudo mv oixrun
  /usr/local/bin/`.

* Run: `sudo update-binfmts --install oixcf /usr/local/bin/oixrun --magic 'CF\x00\x00'`

* Run: `sudo update-binfmts --install oixmz /usr/local/bin/oixrun --magic 'MZ\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00CF\x00\x00' --mask '\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff'`
