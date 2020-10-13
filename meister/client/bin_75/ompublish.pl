use LWP::UserAgent;
use HTTP::Request::Common;
use Digest::MD5;
use Openmake;
use File::Glob ':glob';

if (scalar @ARGV < 4)
{
 print "Usage: ompublish.pl <Project> <LogURL> <Build Number> <FileName1> <FileName2>...<FileNameN>\n";
 print "  if the <FileName1> ends with .mak then the Target Names will be derived from that Build Control file\n";
 exit(1);	
}

$KBS = $ENV{OPENMAKE_SERVER};
$KBS .= "/reports/FilePublish.jsp";
$Project = shift @ARGV;
$logURL = shift @ARGV;
$BuildNum = shift @ARGV;

@newargs = ();

foreach $a (@ARGV)
{
 if ($a =~ /\.mak/i)
 {
  $file = $a;
  open(FP,"<$file");
  @lines = <FP>;
  close(FP);
 
  @ftlines = grep(/FINALTARGET/,@lines);

  foreach $line (@ftlines)
  {
   $line =~ s/\s*FINALTARGET //;
   $line =~ s/[\n|\r]//g;
   $line = ExpandEnv($line);
   print "$line ";
   push(@newargs,$line);
  }	
 }
 else
 {
  print "$a ";
  push(@newargs,$a);
 }
}
print "\n\n";

@ARGV = sort(unique(@newargs));

foreach $gfile (@ARGV)
{
 if ($gfile =~ /\*/)
 {
  @src = bsd_glob($gfile);
 }
 else
 {
  @src = ($gfile);
 }
 
 
 foreach $file (@src)
 {

 if (!open(FILE, $file))
 {
   print "Can't open '$file'\n";
 }
 else
 {
  print "Publishing $file ";
  binmode(FILE);
  $md5string = Digest::MD5->new->addfile(*FILE)->hexdigest;
  close(FILE);
  
  ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $filesize, $atime, $filedatetime, $ctime, $blksize, $blocks) = stat $file;
  $filedatetime *= 1000;
  $ua = LWP::UserAgent->new;
  $res = $ua->request(POST $KBS, Content_Type => 'form-data', Content => [ project => $Project,  md5 => $md5string, logurl => $logURL, buildnumber => $BuildNum, filename => $file, filesize => $filesize, filedatetime => $filedatetime, file => [$file]]);
  
  if ($res->is_success)
  {
   print " ...Complete\n";
#  print $res->content;
  }
  else
  {
   print " ...Error\n";
   print "Error: " . $res->status_line . "\n" . $res->content . "\n";
  }   
 }
 }
}
