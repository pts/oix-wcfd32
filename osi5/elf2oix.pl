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

BEGIN { $ENV{LC_ALL} = "C" }  # For deterministic output. Typically not needed. Is it too late for Perl?
BEGIN { $ENV{TZ} = "GMT" }  # For deterministic output. Typically not needed. Perl respects it immediately.
BEGIN { $^W = 1 }  # Enable warnings.
use integer;
use strict;

my $header_type = "none";  # Default, also `--bin'.
if (@ARGV and $ARGV[0] eq "--elf") { $header_type = "elf"; shift(@ARGV) }  # Shorter ELF header (1 PT_LOAD, 0x54 bytes, like `ld -N').
elsif (@ARGV and $ARGV[0] eq "--elf2") { $header_type = "elf2"; shift(@ARGV) }  # Longer ELF header (2 PT_LOADs, 0x74 bytes, like `ld').
elsif (@ARGV and $ARGV[0] eq "--bin") { $header_type = "none"; shift(@ARGV) }
elsif (@ARGV and $ARGV[0] eq "--") { shift(@ARGV) }
die "Usage: $0 <input.elf> <output.oix>\n" if @ARGV != 2;
my($fn, $fnout) = @ARGV;

sub fnopenq($) { $_[0] =~ m@[-+.\w]@ ? $_[0] : "./" . $_[0] }
die "fatal: error opening: $fn\n" if !open(F, "< " . fnopenq($fn));
binmode(F);
# { my $oldfd = select(F); $| = 1; select($oldfd); }  # Autoflush.
my $s;
die "fatal: executable file to short: $fn\n" if (sysread(F, $s, 0x34) or 0) != 0x34;

die "fatal: not a Linux i386 ELF-32 executable: $fn\n" if 
    $s !~ m@\A\x7FELF\x01\x01\x01[\0\3]\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00\x01\x00\x00\x00@s;
my($e_entry, $e_phoff, $e_shoff, $e_flags, $e_ehsize, $e_phentsize, $e_phnum, $e_shentsize, $e_shnum, $e_shstrndx) = unpack("x24VVVVvvvvvv", $s);
die "fatal: bad ELF-32 ehdr fields: $fn\n" if $e_flags != 0 or $e_ehsize != 0x34 or $e_phentsize != 0x20 or $e_shentsize != 0x28;
die "fatal: found multipe program headers, relink with gcc -Wl,-N: $fn\n" if $e_phnum != 1;
printf STDERR "info: e_entry=0x%x e_phoff=0x%x e_shoff=0x%x e_shnum=0x%x e_shstrndx=0x%x f=%s\n", $e_entry, $e_phoff, $e_shoff, $e_shnum, $e_shstrndx, $fn;
die "fatal: error seeking to ELF-32 phdr: $fn\n" if (sysseek(F, $e_phoff, 0) or 0) != $e_phoff;
die "fatal: error reading ELF-32 phdr: $fn\n" if (sysread(F, $s, 0x20) or 0) != 0x20;
my($p_type, $p_offset, $p_vaddr, $p_paddr, $p_filesz, $p_memsz, $p_flags, $p_align) = unpack("V8", $s);
printf(STDERR "info: p_type=0x%x p_offset=0x%x p_vaddr=0x%x p_paddr=0x%x p_filesz=0x%x p_memsz=0x%x p_flags=0x%x p_align=0x%x f=%s\n",
    $p_type, $p_offset, $p_vaddr, $p_paddr, $p_filesz, $p_memsz, $p_flags, $p_align, $fn);
die "fatal: PT_LOAD phdr expected: $fn\n" if $p_type != 1;
die "fatal: p_filesz larger than p_memsz: $fn\n" if $p_filesz > $p_memsz;
die "fatal: p_offset larger than p_vaddr: $fn\n" if $p_offset > $p_vaddr;
my $p_file_vaddr_limit = $p_vaddr + $p_filesz;
die "fatal: entry point out of bounds: $fn\n" if $e_entry < $p_vaddr or $e_entry >= $p_file_vaddr_limit;
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
die "fatal: error seeking to ELF-32 image: $fn\n" if (sysseek(F, $p_offset, 0) or 0) != $p_offset;
my $data;
die "fatal: error reading ELF-32 image: $fn\n" if (sysread(F, $data, $p_filesz) or 0) != $p_filesz;
die "fatal: error seeking to ELF-32 shdr: $fn\n" if (sysseek(F, $e_shoff, 0) or 0) != $e_shoff;
die "fatal: error reading ELF-32 shdr: $fn\n" if (sysread(F, $s, $e_shnum * 0x28) or 0) != $e_shnum * 0x28;
my @relocs;
for (my $shi = 0; $shi < $e_shnum; ++$shi) {
  my($sh_name, $sh_type, $sh_flags, $sh_addr, $sh_offset, $sh_size, $sh_link, $sh_info, $sh_addralign, $sh_entsize) = unpack("V10", substr($s, $shi * 0x28, 0x28));
  #printf STDERR "info: sh_type=0x%x sh_offset=0x%x sh_size=0x%x sh_entsize=0x%x\n", $sh_type, $sh_offset, $sh_size, $sh_entsize;
  next if $sh_type != 9;  # REL.
  die "fatal: bad sh_entsize in REL section: $fn\n" if $sh_entsize != 8;
  die "fatal: bad sh_size in REL section: $fn\n" if ($sh_size & 7) != 0;
  my $rs;
  die "fatal: error seeking_to to ELF-32 relocations: $fn\n" if (sysseek(F, $sh_offset, 0) or 0) != $sh_offset;
  die "fatal: error reading ELF-32 relocations: $fn\n" if (sysread(F, $rs, $sh_size) or 0) != $sh_size;
  for (my $ri = 0; $ri << 3 < $sh_size; ++$ri) {
    my($r_offset, $r_info) = unpack("VV", substr($rs, $ri << 3, 8));
    my $r_type = $r_info & 0xff;
    my $r_sym = ($r_info >> 8) & 0xffffff;
    #printf STDERR "info: r_offset=0x%x r_sym=0x%x r_type=0x%x\n", $r_offset, $r_sym, $r_type;
    next if $r_type == 0 or $r_type == 2;  # Skip R_386_NONE and R_386_PC32.
    die sprintf("fatal: bad relocation type: r_offset=0x%x r_sym=0x%x r_type=0x%x f=%s\n", $r_offset, $r_sym, $r_type, $fn) if
        $r_type != 1;  # R_386_32.
    die sprintf("fatal: relocation offset out of bounds: r_offset=0x%x r_sym=0x%x r_type=0x%x f=%s\n", $r_offset, $r_sym, $r_type, $fn) if
        $r_offset < $p_vaddr or $r_offset + 4 > $p_file_vaddr_limit;
    push @relocs, $r_offset - $p_vaddr;
  }
}
close(F);
printf STDERR "info: reloc_count=%d\n", scalar(@relocs);
@relocs = sort { $a <=> $b } @relocs;
for (my $ri = 1; $ri < @relocs; ++$ri) {
  die "fatal: found overlapping relocations: $fn\n" if $relocs[$ri - 1] + 4 > $relocs[$ri];
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
my $rpdata = build_rpdata(0);
$rpdata = build_rpdata(length($rpdata));  # Adjust base as soon as we have the size of $rpdata.
for (my $ri = 0; $ri < @relocs; ++$ri) {
  my $value = unpack("V", substr($data, $relocs[$ri], 4));
  #printf STDERR "info: r_offset=0x%x value=0x%x\n", $p_vaddr + $relocs[$ri], $value;
  $value -= $p_vaddr;  # Reverse-apply the relocation.
  die "fatal: relocated value out of bounds: $fn\n" if $value < 0 or $value > $p_memsz;
  $value += length($rpdata);
  substr($data, $relocs[$ri], 4) = pack("V", $value);
}
die "fatal: assert: bad image size\n" if length($data) != $p_filesz;
# ($signature, $load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva).
my $cf_header = pack("a4V5", "CF", 0x18, length($rpdata) + $p_filesz, 0, length($rpdata) + $p_memsz, $e_entry - $p_vaddr + length($rpdata));
unlink($fnout);  # To avoid the `Text file busy' error.
die "fatal: error opening for write: $fnout\n" if !open(FOUT, ">" . fnopenq($fnout));
binmode(FOUT);
{ my $oldfd = select(FOUT); $| = 1; select($oldfd); }  # Autoflush.
die "fatal: error writing CF header to: $fnout\n" if (syswrite(FOUT, $cf_header, length($cf_header)) or 0) != length($cf_header);
die "fatal: error writing relocations to: $fnout\n" if (syswrite(FOUT, $rpdata, length($rpdata)) or 0) != length($rpdata);
die "fatal: error writing program image to: $fnout\n" if (syswrite(FOUT, $data, length($data)) or 0) != length($data);
close(FOUT);

__END__
