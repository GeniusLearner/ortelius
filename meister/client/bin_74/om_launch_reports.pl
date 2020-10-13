use warnings;
use strict;

my $omenv = FindOMEnv();
my $openmake_server = OpenmakeServer($omenv);
my $url = $openmake_server . '/index.html';

#-- launch the url
exec( "start $url");

#------------------------------------------------------------------
sub FindOMEnv
{
 my $omenv = $ENV{'APPDATA'} . '/openmake/omenvironment.properties';
 if ( ! -e $omenv)
 {
  $omenv = $ENV{'ProgramFiles'} . '/openmake/client/bin/omenvironment.properties';
 }

 $omenv = undef unless ( -e $omenv );
 return $omenv;
}

#------------------------------------------------------------------
sub OpenmakeServer
{
 local $_;
 my $file = shift;
 my $kb;
 if ( open ( my $oe, '<', $file ) )
 {
  while ( <$oe> )
  {
   chomp;
   my ( $key, @val) = split m{=};
   if ( $key eq 'OPENMAKE_SERVER')
   {
    $kb = join '=', @val;
    last;
   }
  }
  close $oe;
 }
 return $kb || $ENV{'OPENMAKE_SERVER'} ;
}
