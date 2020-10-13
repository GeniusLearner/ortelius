use Openmake;
use Cwd;
use File::Touch;

 
$url = $ARGV[0];
$bcf = $ARGV[1];

open(FP,"<$bcf");
@lines = <FP>;
close(FP);

$MyUserPath = "";

foreach $line (@lines)
{
 if ($line =~ /^VPATH/)
 {
  $VPath = substr($line,6);
  @dirs = split(/\;/,$VPath);
  $MyUserPath = Openmake::SearchPath->new(@dirs);
 }
 if ($line =~ /\.jar \\/)
 {
  if ($line =~ /:/)
  {
   @parts = split(/:/,$line);
   $jar = $parts[1];
  }
  else
  {
   $jar = $line;
  }
  $jar =~ s/^\s+//;
  $jar =~ s/\\//g;
  $jar =~ s/\s+$//;
  push(@jars, $jar);
 }
 
 if ($line =~ /\.jar :/)
 {
   @parts = split(/:/,$line);
   $tjar = $parts[0];
  $tjar =~ s/^\s+//;
  $tjar =~ s/\s+$//;  
  $targets{$tjar} = $tjar;
 }
}

foreach $jar (@jars)
{
 $origjar = $jar;
 if ($targets{$jar} ne $jar && $jar =~ /-/)
 {
  if ($jar =~ /\//)
  {
   $pos = rindex($jar,"/");
   $jar = substr($jar,$pos+1);
  }
  
  $jar =~ s/\.jar//;
  $pos = rindex($jar,"-");
  $module = substr($jar,0,$pos);
  $ver = substr($jar,$pos+1);
  if ($module =~ /-/)
  {
   $pos = index($module,"-");
   $group = substr($module,0,$pos);
  }
  else
  {
   $group = $module;
  }

   $cwd = cwd();
    if ($origjar =~ /\//)
    {
     $pos = rindex($origjar,"/");
     $jardir = substr($origjar,0, $pos);
     $origjar = substr($origjar,$pos +1);
     

     $vpath = Openmake::SearchPath->new();
     foreach $dir ($MyUserPath->getList)
     {
      $vpath->push($dir . "/" . $jardir); 
     }
     $FoundFile = FirstFoundInPath( $origjar, $vpath );
     mkdir($jardir);
     chdir($jardir);
    }
    else
    { 
     $vpath = $MyUserPath;
      $FoundFile = FirstFoundInPath( $origjar, $vpath );
    }
    
 
  if ($FoundFile eq "")
  {

  
   print `wget $url/$group/$module/$ver/$jar.jar` ;
   my @files = ("$jar.jar");
   my $count = touch(@files);
   
   chdir($cwd);
  }
 }
}