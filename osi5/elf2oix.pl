#!/bin/sh --
eval 'PERL_BADLANG=x;export PERL_BADLANG;exec perl -x "$0" "$@";exit 1'
#!perl  # Start marker used by perl -x.
+0 if 0;eval("\n\n\n\n".<<'__END__');die$@if$@;__END__

#
# elf2oix.pl: convert a simple Linux i386 ELF-32 executable program to an OIX programs
# by pts@fazekas.hu at Sun Apr 28 03:26:17 CEST 2024
#
# This script works with Perl 5.004.04 (1997-10-15) or later.
#
# TODO(pts): Add support for reading an ELF-32 object (relocatable) file created by NASM.
# TODO(pts): Add support for reading a simple OMF .obj object file.
#

BEGIN { $ENV{LC_ALL} = "C" }  # For deterministic output. Typically not needed. Is it too late for Perl?
BEGIN { $ENV{TZ} = "GMT" }  # For deterministic output. Typically not needed. Perl respects it immediately.
BEGIN { $^W = 1 }  # Enable warnings.
use integer;
use strict;

my $infn;
my $outfn;
# A non-compressible OIX program (default) has the following properties:
#
# * Order: CF header, relocations, code, data, BSS.
# * No additional setup code added.
# * The OIX runner applies the relocations.
# * While the program is running, relocation data consumes memory uselessly.
# * Any subsequent compression has to be aware of relocations and their
#   serialization format.
#
# A compressible OIX program has the following properties:
#
# * Order: CF header, code, data, relocations, rest of BSS.
# * Relocations and BSS overlap in memory, thus it uses less memory than a
#   non-compressible OIX program. (This is even true if it's not compressed.)
# * Setup code of size 22, 26 or 62 bytes is added (typically the largest).
# * Setup code (rather than the OIX runner) applies the relocations and then
#   fills relocation data with NULs.
# * Subsequent flat executable compression can be applied, which doesn't
#   know about relocations (but it has to understand and increment the BSS
#   size and the BSS fill byte count).
# * As a future work, more efficient relocation packing can be used, and the
#   setup code can be adjusted.
my $is_compressible = 0;
die("Usage: $0 [--compressible] <input.elf> <output.oix>\n") if !@ARGV or $ARGV[0] eq '--help';
{ my $i;
  for ($i = 0; $i < @ARGV; ++$i) {
    my $arg = $ARGV[$i];
    if ($arg eq "--") { ++$i; last }
    elsif ($arg eq "-" or $arg !~ m@^-@) { last }
    elsif ($arg eq "--compressible") { $is_compressible = 1 }
    elsif ($arg eq "--no-compressible") { $is_compressible = 0 }
    elsif ($arg eq "-o" and $i < @ARGV - 1) { $outfn = $ARGV[++$i] }
    else { die "fatal: unknown command-line flag: $arg\n" }
  }
  die("fatal: missing input filename\n") if $i >= @ARGV;
  $infn = $ARGV[$i++];
  $outfn = $ARGV[$i++] if $i < @ARGV and !defined($outfn);
  die("fatal: too many command-line arguments\n") if $i < @ARGV;
}
die("fatal: missing output filename\n") if !defined($outfn);

sub fnopenq($) { $_[0] =~ m@[-+.\w]@ ? $_[0] : "./" . $_[0] }
die "fatal: error opening: $infn\n" if !open(F, "< " . fnopenq($infn));
binmode(F);
# { my $oldfd = select(F); $| = 1; select($oldfd); }  # Autoflush.
my $s;
die "fatal: executable file to short: $infn\n" if (sysread(F, $s, 0x34) or 0) != 0x34;

die("fatal: not an i386 ELF-32 executable: $infn\n") if
    $s !~ m@\A\x7FELF\x01\x01\x01.\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00\x01\x00\x00\x00@s;
my $ei_osabi = vec($s, 7, 8);
sub ELFOSABI_SYSV()  { 0 }  # GNU ld(1) default.
sub ELFOSABI_LINUX() { 3 }  # Changed by some build tools from ELFOSABI_SYSV on Linux.
sub ELFOSABI_IRIX()  { 8 }  # Recommended. Fake IRIX value used by `minicc -boix' and `minicc -bosi' in https://github.com/pts/minilibc686 to specify OIX.
die("fatal: unexpected EI_OSABI value $ei_osabi in i386 ELF-32 executable: $infn\n") if
    $ei_osabi != ELFOSABI_SYSV and $ei_osabi != ELFOSABI_LINUX and $ei_osabi != ELFOSABI_IRIX;
my($e_entry, $e_phoff, $e_shoff, $e_flags, $e_ehsize, $e_phentsize, $e_phnum, $e_shentsize, $e_shnum, $e_shstrndx) = unpack("x24VVVVvvvvvv", $s);
die "fatal: bad ELF-32 ehdr fields: $infn\n" if $e_flags != 0 or $e_ehsize != 0x34 or $e_phentsize != 0x20 or $e_shentsize != 0x28;
die "fatal: found multipe program headers, relink with gcc -Wl,-N: $infn\n" if $e_phnum != 1;
printf STDERR "info: e_entry=0x%x e_phoff=0x%x e_shoff=0x%x e_shnum=0x%x e_shstrndx=0x%x f=%s\n", $e_entry, $e_phoff, $e_shoff, $e_shnum, $e_shstrndx, $infn;
die "fatal: error seeking to ELF-32 phdr: $infn\n" if (sysseek(F, $e_phoff, 0) or 0) != $e_phoff;
die "fatal: error reading ELF-32 phdr: $infn\n" if (sysread(F, $s, 0x20) or 0) != 0x20;
my($p_type, $p_offset, $p_vaddr, $p_paddr, $p_filesz, $p_memsz, $p_flags, $p_align) = unpack("V8", $s);
printf(STDERR "info: p_type=0x%x p_offset=0x%x p_vaddr=0x%x p_paddr=0x%x p_filesz=0x%x p_memsz=0x%x p_flags=0x%x p_align=0x%x f=%s\n",
    $p_type, $p_offset, $p_vaddr, $p_paddr, $p_filesz, $p_memsz, $p_flags, $p_align, $infn);
die "fatal: PT_LOAD phdr expected: $infn\n" if $p_type != 1;
die "fatal: p_filesz larger than p_memsz: $infn\n" if $p_filesz > $p_memsz;
die "fatal: p_offset larger than p_vaddr: $infn\n" if $p_offset > $p_vaddr;
my $p_file_vaddr_limit = $p_vaddr + $p_filesz;
my $p_mem_vaddr_limit = $p_vaddr + $p_memsz;
die "fatal: entry point out of bounds: $infn\n" if $e_entry < $p_vaddr or $e_entry >= $p_file_vaddr_limit;
if ($p_offset == 0) {  # Exclude the ELF-32 ehdr and phdr from the image.
  my $skip = 0x34;
  $skip += 0x20 if $e_phoff == 0x34;
  if ($p_filesz >= $skip and $e_entry - $p_vaddr >= $skip) {
    $p_offset += $skip;
    $p_vaddr += $skip;
    $p_paddr += $skip;
    $p_filesz -= $skip;
    $p_memsz -= $skip;
  }
}
die "fatal: error seeking to ELF-32 image: $infn\n" if (sysseek(F, $p_offset, 0) or 0) != $p_offset;
my $data;
die "fatal: error reading ELF-32 image: $infn\n" if (sysread(F, $data, $p_filesz) or 0) != $p_filesz;
die "fatal: error seeking to ELF-32 shdr: $infn\n" if (sysseek(F, $e_shoff, 0) or 0) != $e_shoff;
die "fatal: error reading ELF-32 shdr: $infn\n" if (sysread(F, $s, $e_shnum * 0x28) or 0) != $e_shnum * 0x28;
--$p_filesz while $p_filesz > 0 and !vec($data, $p_filesz - 1, 8);  # Move trailing NUL bytes to BSS.
substr($data, $p_filesz) = "";
my $min_p_filesz_for_relocs = 0;
my @relocs;
for (my $shi = 0; $shi < $e_shnum; ++$shi) {
  my($sh_name, $sh_type, $sh_flags, $sh_addr, $sh_offset, $sh_size, $sh_link, $sh_info, $sh_addralign, $sh_entsize) = unpack("V10", substr($s, $shi * 0x28, 0x28));
  #printf STDERR "info: sh_type=0x%x sh_offset=0x%x sh_size=0x%x sh_entsize=0x%x\n", $sh_type, $sh_offset, $sh_size, $sh_entsize;
  next if $sh_type != 9;  # REL.
  die "fatal: bad sh_entsize in REL section: $infn\n" if $sh_entsize != 8;
  die "fatal: bad sh_size in REL section: $infn\n" if ($sh_size & 7) != 0;
  my $rs;
  die "fatal: error seeking_to to ELF-32 relocations: $infn\n" if (sysseek(F, $sh_offset, 0) or 0) != $sh_offset;
  die "fatal: error reading ELF-32 relocations: $infn\n" if (sysread(F, $rs, $sh_size) or 0) != $sh_size;
  for (my $ri = 0; $ri << 3 < $sh_size; ++$ri) {
    my($r_offset, $r_info) = unpack("VV", substr($rs, $ri << 3, 8));
    my $r_type = $r_info & 0xff;
    my $r_sym = ($r_info >> 8) & 0xffffff;
    #printf STDERR "info: r_offset=0x%x r_sym=0x%x r_type=0x%x\n", $r_offset, $r_sym, $r_type;
    next if $r_type == 0 or $r_type == 2;  # Skip R_386_NONE and R_386_PC32.
    die sprintf("fatal: bad relocation type: r_offset=0x%x r_sym=0x%x r_type=0x%x f=%s\n", $r_offset, $r_sym, $r_type, $infn) if
        $r_type != 1;  # R_386_32.
    die sprintf("fatal: relocation offset out of bounds: r_offset=0x%x r_sym=0x%x r_type=0x%x f=%s\n", $r_offset, $r_sym, $r_type, $infn) if
        $r_offset < $p_vaddr or $r_offset + 4 > $p_mem_vaddr_limit;
    $min_p_filesz_for_relocs = $r_offset + 4 - $p_vaddr if $r_offset + 4 - $p_vaddr > $min_p_filesz_for_relocs;
    push @relocs, $r_offset - $p_vaddr;
  }
}
close(F);
printf STDERR "info: reloc_count=%d\n", scalar(@relocs);
@relocs = sort { $a <=> $b } @relocs;
for (my $ri = 1; $ri < @relocs; ++$ri) {
  die "fatal: found overlapping relocations: $infn\n" if $relocs[$ri - 1] + 4 > $relocs[$ri];
}
# Now pack the relocations: most packed entries take only 2 bytes.
sub build_rpdata($) {  # Build string containing packed relocations.
  my $rpbase = $_[0];
  my $rpdata = "";
  my $prev_rv;
  my $rrun = "";
  for (my $ri = 0; $ri < @relocs; ++$ri) {
    my $rv = $relocs[$ri] + $rpbase;
    if (!length($rrun)) {
      $rrun = pack("vv", $rv >> 16, $rv & 0xffff);
    } else {
      if ($rv - $prev_rv > 0xffff or length($rrun) == 0x20000) {
        $rpdata .= pack("v", (length($rrun) - 2) >> 1);
        $rpdata .= $rrun;
        $rrun = pack("vv", $rv >> 16, $rv & 0xffff);
      } else {
        $rrun .= pack("v", $rv - $prev_rv);
      }
    }
    $prev_rv = $rv;
  }
  if (length($rrun)) {  # Flush the last run.
    $rpdata .= pack("v", (length($rrun) - 2) >> 1);
    $rpdata .= $rrun;
  }
  $rpdata .= "\0\0";  # Terminator.
  $rpdata .= "\0" x (-length($rpdata) & 3);  # Align it to a multiple of 4. For good program image alignment.
  $rpdata
}
my($cf_header, $rpdata, $code_prefix);
die("fatal: assert: bad image size\n") if length($data) != $p_filesz;
sub apply_reloc_delta($) {
  my $base = $_[0];
  for (my $ri = 0; $ri < @relocs; ++$ri) {
    my $rofs = $relocs[$ri];
    die("fatal: assert: reloc after BSS: $infn\n") if $p_memsz < $rofs + 4;
    my $value = unpack("V", length($data) >= $rofs + 4 ? substr($data, $rofs, 4) : length($data) > $rofs ? substr($data, $rofs, 4) . "\0\0\0" : "\0\0\0\0");
    #printf STDERR "info: r_offset=0x%x value=0x%x\n", $p_vaddr + $rofs, $value;
    $value -= $p_vaddr;  # Reverse-apply the relocation.
    die "fatal: relocated value out of bounds ($value): $infn\n" if $value < 0 or $value > $p_memsz;
    substr($data, $rofs, 4) = pack("V", $value + $base);
  }
}
if (!$is_compressible and !@relocs) {
  $code_prefix = "";
  $rpdata = "";
  $p_memsz = length($data) + 2 if $p_memsz < length($data) + 2;  # Ensure that there is `dw 0' (2 NUL bytes) at .reloc_rva == length($data).
  # ($signature, $load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva).
  $cf_header = pack("a4V5", "CF", 0x18, length($data), length($data), $p_memsz, $e_entry - $p_vaddr);
} elsif (!$is_compressible) {
  $code_prefix = "";
  $rpdata = build_rpdata(0);
  my $base = length($rpdata);
  $rpdata = build_rpdata($base);  # Adjust base as soon as we have the size of $rpdata.
  apply_reloc_delta($base);
  # ($signature, $load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva).
  $cf_header = pack("a4V5", "CF", 0x18, length($rpdata) + length($data), 0, length($rpdata) + $p_memsz, $e_entry - $p_vaddr + length($rpdata));
} elsif (!@relocs) {  # Compressible, without relocations.
  my $code_prefix_size;
  if ($e_entry == $p_vaddr) {  # Size optimization for _start at the beginning. Based on elf2oix_mode1.nasm.
    $code_prefix_size = 0x18;
    $code_prefix = pack("a*Va*Va*", "\x60\xe8\0\0\0\0\x5f\x8d\xbf", $code_prefix_size + length($data) - 6, "\xb9", 0, "\x31\xc0\xf3\xaa\x61\x90");
  } else {  # Based on elf2oix_mode0.nasm.
    $code_prefix_size = 0x1c;
    my $prog_entry_rva = $e_entry - $p_vaddr + $code_prefix_size;
    $code_prefix = pack("a*Va*Va*V", "\x60\xe8\0\0\0\0\x5f\x8d\xbf", $code_prefix_size + length($data) - 6, "\xb9", 0, "\x31\xc0\xf3\xaa\x61\xe9", $prog_entry_rva - 0x1c);
  }
  die("fatal: assert: bad size of code prefix\n") if length($code_prefix) != $code_prefix_size;
  $p_memsz = $code_prefix_size + length($data) + 2 if $p_memsz < $code_prefix_size + length($data) + 2;  # Ensure that there is `dw 0' (2 NUL bytes) at .reloc_rva == length($data).
  # ($signature, $load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva).
  $cf_header = pack("a4V5", "CF", 0x18, $code_prefix_size + length($data), $code_prefix_size + length($data), $p_memsz, 0);
} else {  # Compressible, with relocations.
  $data .= "\0" x ($min_p_filesz_for_relocs - length($data)) if length($data) < $min_p_filesz_for_relocs;  # Make sure $rofs is not within BSS. Otherwise it would overlap with $rpdata at startup time.
  $data .= "\0" if length($data) & 1;  # Make even alignment for packed relocations. Not strictly necessary, but speeds up decoding a bit.
  my $code_prefix_size = 0x3c;
  my $reloc_rva_all = $code_prefix_size + length($data);
  $rpdata = build_rpdata($code_prefix_size);
  die("fatal: assert bad packed relocations\n") if length($rpdata) < 2 or substr($rpdata, -2) ne "\0\0";
  my $reloc_rva_eof = $code_prefix_size + length($data) + length($rpdata) - 2;
  apply_reloc_delta($code_prefix_size);
  my $prog_entry_rva = $e_entry - $p_vaddr + $code_prefix_size;
  my $rpsize = length($rpdata) - 2;
  --$rpsize while $rpsize and !vec($rpdata, $rpsize - 1, 8);  # Remove trailing NULs (at least 2) from $rpdata.
  $code_prefix = pack(  # i386 machine code which applies the relocations at $reloc_rva_all, overwrites the relocation data with NULs, then jumps to $prog_entry_rva. Based on elf2oix_mode0.nasm.
      "a*Va*Va*Va*", "\x60\xe8\0\0\0\0\x5f\x8d\x7f\xfa\x8d\xb7", $reloc_rva_all,
      "\x56\x31\xc0\x66\xad\x89\xc1\xe3\x13\x66\xad\x89\xc3\xc1\xe3\x10\x01\xfb\x66\xad\x01\xc3\x01\x3b\xe2\xf8\xeb\xe7\x5f\xb9", $rpsize,
      "\xf3\xaa\x61\xe9", $prog_entry_rva - 0x3a, "\x90\x90");  # The last \0x90 bytes are for alignment to dword (4 bytes).
  die("fatal: assert: bad size of code prefix\n") if length($code_prefix) != $code_prefix_size;
  my $mem_size = $code_prefix_size + $p_memsz;
  $p_memsz = $code_prefix_size + length($data) + length($rpdata) if $code_prefix_size + length($data) + length($rpdata) > $p_memsz;
  # ($signature, $load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva).
  $cf_header = pack("a4V5", "CF", 0x18, $code_prefix_size + length($data) + $rpsize, $reloc_rva_eof, $mem_size, 0);
  substr($rpdata, $rpsize) = "";
}
unlink($outfn);  # To avoid the `Text file busy' error.
die "fatal: error opening for write: $outfn\n" if !open(FOUT, ">" . fnopenq($outfn));
binmode(FOUT);
{ my $oldfd = select(FOUT); $| = 1; select($oldfd); }  # Autoflush.
die "fatal: error writing CF header to: $outfn\n" if (syswrite(FOUT, $cf_header, length($cf_header)) or 0) != length($cf_header);
die "fatal: error writing code prefix to: $outfn\n" if length($code_prefix) and (syswrite(FOUT, $code_prefix, length($code_prefix)) or 0) != length($code_prefix);
die "fatal: error writing relocations to: $outfn\n" if !$is_compressible and (syswrite(FOUT, $rpdata, length($rpdata)) or 0) != length($rpdata);
die "fatal: error writing program image to: $outfn\n" if (syswrite(FOUT, $data, length($data)) or 0) != length($data);
die "fatal: error writing relocations to: $outfn\n" if $is_compressible and (syswrite(FOUT, $rpdata, length($rpdata)) or 0) != length($rpdata);

#close(FOUT);  # Not needed, the operating system closes it upon process exit.

__END__
