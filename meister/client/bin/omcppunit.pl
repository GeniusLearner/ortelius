$pgm = shift @ARGV;

$RC = 0;
foreach $cpptest (@ARGV)
{
 if (length($cpptest) > 0)
 {	
  print "$pgm $cpptest\n";
  @lines = `$pgm $cpptest 2>&1`;
  
 foreach (@lines)
  {
   s/</&lt;/g;
   s/>/&gt;/g;
   s/\^/&#96;/g;
   s/~/&#126;/g;
   s/`/&#96;/g;
   print $_;
  }

  $RC += $?;
 }
}

exit ($RC);

