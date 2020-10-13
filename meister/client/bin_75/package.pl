use Digest::MD5;

$pkgfile = shift @ARGV;
$loc = shift @ARGV;
@flist = @ARGV;

 open(FP,"<" . $pkgfile);
 @lines = <FP>;
 close(FP);


 foreach $line (@lines)
 {
  $line =~ s/\n//g;
  if ($line =~ /;/)
  {
   @parts = split(/;/,$line);
   $deps{$parts[0]} = $parts[1];
  }
 }

foreach $infile (@flist)
{
 if ($infile =~ /\.classpath/)
 {
  open(FP,"<$infile");
  @lines2 = <FP>;
  close(FP);
  $line = shift @lines2;
  $line =~ s/\n//g;
  @lines2 = split(/;/,$line);
  foreach $infile (@lines2)
  {
   if ($infile ne ".")
   {
   open(FILE, $infile);
   binmode(FILE);
   $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
   close(FILE);
   $JHOME = $ENV{JAVA_HOME};
   $jloc = substr($infile,length($JHOME));
   $jloc =~ s/\\/\//g;
   
   $deps{'${JAVA_HOME}' . $jloc} = $md5;
   }
  }
 }
}
 
foreach $infile (@flist)
{
 if ($infile !~ /\.classpath/)
 {
  $new_in = $infile;
  my $loc_var = $1 if ($loc =~ /^\$\{(.*)?\}/);
  $new_in =~ s/\Q$ENV{$loc_var}\E// if ($loc_var);
  
  open(FILE, $infile);
  binmode(FILE);
  $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
  close(FILE);
  
  if ($new_in ne $infile)
  {
   $infile = $new_in;
   $deps{$loc . $infile} = $md5;
  }
  else
  {
   $deps{$loc . "\\" . $infile} = $md5;
  }
 }
}

open(FP,">" . $pkgfile);

@k = sort(keys %deps);

foreach $file (@k)
{
 print FP $file . ";" . $deps{$file} . "\n";
}

close(FP);
