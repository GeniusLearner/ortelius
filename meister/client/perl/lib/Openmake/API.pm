package Openmake::API;

use strict;
use Win32;
use Config;

BEGIN
{
 #-- if on windows, use short paths in Config
 my $perlpath = $Config{perlpath};

 my $DL;
 if ( $^O =~ /MSWin|dos/i )
 {
  $DL = ";";
  $perlpath = Win32::GetShortPathName($perlpath);
  $Config{perlpath} = $perlpath;
  print $Config{perlpath}, "\n";
 }
 else
 {
  $DL = ":";
 }
 my $newpath;
 my @paths = split /$DL/, $ENV{PATH};
 foreach my $path ( @paths )
 {
  if ( $path =~ m/openmake/i && $path =~ m/[\/\\]bin/i )
  {
   #-- make the path a win short path;
   $path = Win32::GetShortPathName($path) if ( $^O =~ /MSWin|dos/i );

   #-- slashes
   $path =~ s/\\/\//g;
   $path =~ s/\/$//g;
   #-- add to classpath
   $ENV{CLASSPATH} .= "${DL}$path/omint.jar";
  }
  $path = Win32::GetShortPathName($path) if ( $^O =~ /MSWin|dos/i );

  $newpath .= "${path}$DL";
 }
 $ENV{PATH} = $newpath;
}


print "$ENV{CLASSPATH}" , "\n";
$Inline::Java::DEBUG = 5;
use Inline Java  => 'STUDY',
           STUDY => [ 'com.openmake.integration.OMClient' ],
           DEBUG => 5;

sub new
{
 my $class = shift;
 return Openmake::API->new(@_);
}

1;
