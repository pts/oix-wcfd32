 #!/bin/sh --
eval 'PERL_BADLANG=x;export PERL_BADLANG;exec perl -x "$0" "$@";exit 1'
#!perl  # Start marker used by perl -x.
+0 if 0;eval("\n\n\n\n".<<'__END__');die$@if$@;__END__
#
# oix2nasm.pl: convert an OIX program to NASM source, keeping relocations
# by pts@fazekas.hu at Thu Apr 25 04:11:23 CEST 2024
#

BEGIN { $^W = 1 }
use integer;
use strict;

die "Usage: $0 <in-cf.exe> <output.nasm>\n" if @ARGV != 2;
my($fn, $fnout) = @ARGV;

sub fnopenq($) { $_[0] =~ m@[-+.\w]@ ? $_[0] : "./" . $_[0] }
die "fatal: error opening: $fn\n" if !open(F, "< " . fnopenq($fn));
binmode(F);

my $s;
die "fatal: error reading: $fn\n" if (sysread(F, $s, 0x200) or 0) <= 0;
my $ofs;
my $hdrsize;
if (length($s) >= 0x38 and substr($s, 0x20, 4) eq "CF\0\0") {
  $ofs = 0x20;
} elsif (length($s) >= 10 and
         length($s) >= (($hdrsize = unpack("v", substr($s, 8, 2))) << 4) + 0x18 and
         substr($s, $hdrsize << 4, 4) eq "CF\0\0") {
  $ofs = $hdrsize << 4;
} else {
  die "fatal: CF header not found: $fn\n";
}
my($load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva) = unpack("V5", substr($s, $ofs + 4, 0x14));
printf(STDERR "info: load_fofs=0x%x load_size=0x%x reloc_rva=0x%x mem_size=0x%x entry_rva=0x%x f=%s\n",
    $load_fofs, $load_size, $reloc_rva, $mem_size, $entry_rva, $fn);
sub M31() { 0x7fffffff }
die "fatal: numbers too large: $fn\n" if $load_fofs & ~M31 or $load_size & ~M31 or $reloc_rva & ~M31 or $mem_size & ~M31 or $entry_rva & ~M31;
die "fatal: reloc_rva too large: $fn\n" if $reloc_rva + 2 > $load_size;
die "fatal: load_size larger than mem_size: $fn\n" if $load_size > $mem_size;
die "fatal: entry_rva not smaller than load_size: $fn\n" if $entry_rva >= $load_size;
die "fatal: error seeking to fofs: $fn\n" if (sysseek(F, $load_fofs, 0) or 0) != $load_fofs;
$s = "";
die "fatal: error reading image: $fn\n" if (sysread(F, $s, $load_size) or 0) != $load_size;
close(F);

$ofs = $reloc_rva;
my @reloc_rvas;
my $reloc_block_count = 0;
for (;;) {
  die "fatal: EOF in reloc count\n" if $ofs + 2 > length($s);
  last if substr($s, $ofs, 2) eq "\0\0";
  die "fatal: EOF in reloc block start\n" if $ofs + 6 > length($s);
  my($count, $hi, $rva) = unpack("v3", substr($s, $ofs, 6));
  #print STDERR "info: reloc block size: $count\n";
  $ofs += 6;
  die "fatal: EOF in reloc block\n" if $ofs + ($count << 1) - 2 > length($s);
  $rva |= $hi << 16;
  ++$reloc_block_count;
  for (;;) {
    die "fatal: reloc RVA too large\n" if $rva & ~M31 or $rva > $load_size - 4;
    push @reloc_rvas, $rva;
    last if !--$count;
    $rva += unpack("v", substr($s, $ofs, 2));
    $ofs += 2;
  }
}
# !! Remove trailing NUL and unrelocated bytes.
$ofs += 2;
substr($s, $reloc_rva, $ofs - $reloc_rva) = "\0" x ($ofs - $reloc_rva);
printf STDERR "info: found %d reloc(s) in %d block(s)\n", scalar(@reloc_rvas), $reloc_block_count;
@reloc_rvas = sort { $a <=> $b } @reloc_rvas;
for (my $i = 1; $i < @reloc_rvas; ++$i) {
  die "fatal: reloc overlap\n" if $reloc_rvas[$i - 1] + 4 > $reloc_rvas[$i];
}

die "fatal: error opening: $fnout\n" if !open(FOUT, ">" . fnopenq($fnout));
binmode(FOUT);
print FOUT "; Autogenerated by $0\n";
my $fnoutsq = $fnout;
$fnoutsq =~ s@'@'\\''@g;
print FOUT "; Compile with: nasm -O0 -f elf -o '$fnoutsq.o' '$fnoutsq'\n\n";
print FOUT "section .text align=1 write\n";
printf FOUT "global _start\n_start equ \$\$+0x%x\n", $entry_rva;
my $ri;
for ($ofs = $ri = 0; $ofs < $load_size;) {
  my $count = $load_size - $ofs;
  $count = 16 if $count > 16;
  $count = $reloc_rvas[$ri] - $ofs if $ri < @reloc_rvas and $ofs + $count > $reloc_rvas[$ri];
  if ($count) {
    my $sh = unpack("H*", substr($s, $ofs, $count));
    $sh =~ s@(..)@0x$1, @sg;
    substr($sh, -2, 2) = sprintf("  ; \@0x%x\n", $ofs);
    print FOUT "db ", $sh;
    $ofs += $count;
  }
  for (; $ri < @reloc_rvas and $reloc_rvas[$ri] == $ofs; ++$ri, $ofs += 4) {
    printf FOUT "dd \$\$+0x%x  ; \@0x%x\n", unpack("V", substr($s, $ofs, 4)), $ofs;
  }
}
die "fatal: assert: relocs remaining\n" if $ri != @reloc_rvas;
print FOUT "section .bss align=1\n";
printf FOUT "resb 0x%x\n", $mem_size - $load_size;
die "fatal: error closing: $fnout\n" if !close(FOUT);

__END__