# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::PrePost;

#line 393 "C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\PrePost\getOMLogURI.al)"
#======================================================
# Email functions
sub getOMLogURI
{
 my $argsRef = shift;
 my $job     = $argsRef->{lj};
 my $user    = $argsRef->{lo};
 my $date    = $argsRef->{ld};
 my $machine = $argsRef->{lm};

 my $omserver = $ENV{OPENMAKE_SERVER};
 $omserver =~ s/\/openmake$//;
 my $uri = $omserver . "/servlet/OMDisplayLog?";
 $uri .= "BuildJobName=$job" . '&';
 $uri .= "Machine=$machine" . '&';
 $uri .= "DateTime=$date" . '&';
 $uri .= "UserName=$user" . '&';
 $uri .= "PublicBuildJob=true";
 $uri =~ s/\s+/%20/g;

 return $uri;
}

#########################################
#-- A class has to be a separate package
package Openmake::ParseBOM;

BEGIN
{
 use Exporter ();
 use AutoLoader;
 use vars qw(@ISA @EXPORT $VERSION);

 $VERSION = 6.400;
 @ISA    = qw(Exporter AutoLoader);
 @EXPORT = qw( &new
   &getFiles
   &getSize
   &getTimeStamp
   &getVersionInfo
   );
} #-- End: BEGIN

# end of Openmake::ParseBOM::getOMLogURI
1;
