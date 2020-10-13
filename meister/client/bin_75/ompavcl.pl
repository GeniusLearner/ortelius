
$files = $ARGV[0];
@lines = `pavcl -nob -auto \"$files\"`;
$rc = 0;
foreach $line (@lines)
{
 if ($line =~ /files infected/ || $line =~ /suspicious files/ )
 {
  @parts = split(/:/,$line);
  $rc += $parts[1];
 }
 print $line;
 exit(1) if ($line =~ /Attention /);
 
}

exit($rc);