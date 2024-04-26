# wcfd32-port: a port of old Watcom WASM and WLIB to Linux, Win32 and 32-bit DOS

wcfd32-port is a port of old Watcom development tools WASM (Watcom
Assembler) and WLIB (Watcom Library Manager) to Linux, Win32 and 32-bit DOS.
For each tool, an .exe is provided which works on Win32 and 32-bit DOS, and
a Linux i386 executable program is also provided. For copyright reasons, the
programs are not distributed, but a converter is provided which converts
*binw/wasm.exe* and *binw/wlib.exe* to those ported exectables. The converter
runs on Linux i386.

This port is made possible by the the OS-independent
(operating-system-independent) target (OSI, `#if defined(__OSI__)') of the
Watcom C/C++ compiler, still supported by OpenWatcom 1.0. The official
binary releases of binw/wasm.exe and binw/wasm.exe in Watcom C/C++ 10.x and
11.x contain a stub and and a program image. wcfd32-port provides stubs each
3 supported operating system, and it provies a converter (*wcfd32stub*)
which runs Linux i386, can extract the program image from the .exe files,
and generate the two programs (one .exe for Win32 and 32-bit DOS, and a
Linux i386 executable program) by combining the wcfd32-port stubs with the
Watcom images.

WCFD32 is the unofficial name used in wcfd32-port for the OS-independent
target of the Watcom C/C++ compiler. It is an ABI for i386 32-bit protected
mode programs. It was used by some tools in Watcom C/C++ compiler (WASM and
WLIB), and the corresponding DOS extender was implemented in
binw/w32run.exe. Watcom versions using WCFD32:

* binw/wasm.exe in 10.0a, 10.5, 10.6, 11.0b, 11.c.
* binw/wlib.exe in 10.5, 10.6 and 11.0b, 11.c. (In 10.0a, it was a 16-bit
  DOS program.)
* binw/wlink.exe never used WCFD32, it had its own DOS extender built in.

In the name WCFD32:

* W stands for Watcom.
* CF stands for the signature of CF header describing the program image.
* D stands for DOS, because the syscall numbers are the same as in DOS.
* 32 stands for 32-bit protected mode on i386.

## Archeology of the Watcom OS-independent target

Building executables for the OS-independent target is mostly undocumented in
Watcom C/C++ and OpenWatcom. Thus there is no easy or documented way to
rebuild the Watcom tools *binw/wasm.exe* or *binw/wlib.exe* using the
OS-independent target.

The source files for building the stubs are in the `bld/w32loadr` directory
of
[https://openwatcom.org/ftp/source/open_watcom_1.0.0-src.zip](open_watcom_1.0.0-src.zip).
However, some key components are missing:

* The C runtime library (libc): There are no
  functions like *write(...)*, *printf(...)* or *strlen(...)*. It would be
  possible to build the Watcom C runtime library for the OS-independent
  target, and Watcom developers surely did it for *binw/wasm.exe* and
  *binw/wlib.exe*, but they haven't made it available for others.

  We can work this around for small programs by copying a few source files
  from OpenWatcom.h: *bld/clib/startup/a/cstrtosi.asm*,
  *bld/watcom/h/watcom.h* and bld/watcom/h/tinyio.h*.

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

  We can work this around by using PMODE/W 1.33 and *wcfd32dos.exe* from
  wcfd32-port instead.

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

The build process is automated in the *cf/compile.sh* shell script in
wcfd32-port. It uses modern OpenWatcom v2 tools and source files from
OpenWatcom 1.0 (2003-01-24). Its outline:

* Build *wcfd32dos.exe*.

* Compile *cstrtosi.asm* with modern OpenWatcom v2 WASM.

* Compile *example.c* with modern OpenWatcom v2 *owcc*. It uses code in
  *tinyio.h* and *watcom.h*. *example.c* also contains the required
  scaffolding missing from *cstrtosi.asm*. Otherwise it just prints its
  command-line arguments and environment variables.

* Link *cstrtosi.o* and *example.o* together using WLINK *system win386*
  (which uses *format pharlap rex*), producing .rex (Pharlap relocatable
  executable) file *example.rex*.

* Compile the modified *w32bind.c* for the host system to the *w32bind*
  program with modern OpenWatcom v2 *owcc*.

* Run *w32bind* to generate *example.exe* from *example.rex* (containing the
  WCFD32 program image in a different format) and *wcfd32dos.exe*
  (containing the DOS extender and the OSI implementation for 32-bit DOS).

The generated *example.exe* can be run on DOS and 32-bit i386 Windows
systems or DOS emulators such as DOSBox. It's self-contained, it doesn't
need any other files to run. It doesn't need much memory: only about 64 KiB
more than its file size. It can run in conventional memory (no need for high
memory). But of course it needs a 386 or newer CPU.

wcfd32-port can port not only the Watcom tools, but *example.exe* (and other
OSI programs) as well: just run *wcfd32stub* on it to generate an .exe which
works on both 32-bit DOS and Win32, and also the generate a Linux i386
executable program.
