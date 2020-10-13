use Digest::MD5;
use Cwd;

use File::Find;

my $dirname =$ARGV[0];
my $file_pattern  =$ARGV[1];

sub wanted;
# Traverse desired filesystems
@filelist = ();
File::Find::find({wanted => \&wanted, no_chdir => 1}, $dirname);

@sorted_list = sort @filelist;
foreach $filename (@sorted_list)
{
 $md5 = GetMD5($filename) ;
 print "$filename $md5\n";
}
exit;

sub wanted {
  $filename = $File::Find::name;
  
  if ($file_pattern ne "")
  {
   return  unless $filename =~ /$file_pattern/;
  }
   $filename =~ s/\//\\/g if ($^O =~ /win32/i);
   
   return if (-d $filename);
   
   push(@filelist,$filename);
}
 
sub GetMD5()
{
  my $file = shift;
  
  open(FILE, "<$file") or return "";
  binmode(FILE);

  $md5 = Digest::MD5->new;
  while (<FILE>) {
        $md5->add($_);
    }
  close(FILE);
 $digest = $md5->hexdigest;
 
 return $digest;
}