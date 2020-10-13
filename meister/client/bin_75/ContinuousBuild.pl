use Digest::MD5;

$sleep_time =$ARGV[0];
$cfg = $ARGV[1];

if ($sleep_time eq "" || $cfg eq  "")
{
 print "Usage: ContinousBuild <Check Interval> <Config File>\n";
 print "\tCheck Interval: Number of seconds to wait between checks\n";
 print "\tConfig File: Name of the configuration file\n";
 exit(1);
}

open (FP,"<$cfg") || die("Could not open $cfg");
@lines = <FP>;
close(FP);

$name="";
$SCMCmd="";
$MD5ResultsFile="";
$BuildCmd="";
$Dir="";

foreach $line (@lines)
{
 $line =~ s/^ //g;
 $line =~ s/\n//g;
 next if ($line =~ /^#/);
 next if ($line eq "");
 
 if ($line =~ /Name=/i)
 {
  $line =~ s/Name=//;
  $name = $line;
 }
 
 if ($line =~ /SCMCmd=/i)
 {
  $line =~ s/SCMCmd=//;
  $SCMCmd = $line;
 }
 
  if ($line =~ /MD5ResultsFile=/i)
 {
  $line =~ s/MD5ResultsFile=//;
  $MD5ResultsFile = $line;
 }
 
  if ($line =~ /BuildCmd=/i)
 {
  $line =~ s/BuildCmd=//;
  $BuildCmd = $line;
 }
 
 if ($line =~ /Dir=/i)
 {
   $line =~ s/Dir=//;
   $Dir = $line;
 }
 
 if ($name ne "" && $SCMCmd ne "" && $MD5ResultsFile ne "" && $BuildCmd ne "")
 {
  push(@records, [$name,$SCMCmd,$MD5ResultsFile,$BuildCmd,$Dir]);
  
  $name="";
$SCMCmd="";
$MD5ResultsFile="";
$BuildCmd="";
$Dir="";
 }
}

while (1)
{
for $aref (@records)
{
 ($name, $SCMCmd,$MD5ResultsFile,$BuildCmd,$Dir) = @$aref;
 
 print "\nProcessing $name\n";
 chdir($Dir) if ($Dir ne "");
 
 @results = `$SCMCmd 2>&1`;
 
 open(FP,"<$MD5ResultsFile");
 $oldMD5 = <FP>;
 $oldMD5 =~ s/\n//g;
 close(FP);
 

 $newMD5 = GetMD5(@results);
 
 if ($newMD5 ne $oldMD5)
 {
 # print "@results";
  open(FP,">$MD5ResultsFile");
  print FP "$newMD5\n";
  close(FP);
  print "Executing $BuildCmd\n";
  print `$BuildCmd 2>&1`;
  
 }
}
sleep($sleep_time);
}

sub GetMD5()
{
 @results = @_;
 $md5 = Digest::MD5->new;
	 
 foreach $line (@results)
 {
    $md5->add($line);
 }
 $digest = $md5->hexdigest;
    
 return $digest;
}