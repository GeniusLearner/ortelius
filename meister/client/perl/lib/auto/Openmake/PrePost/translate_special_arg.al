# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::PrePost;

#line 384 "C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\PrePost\translate_special_arg.al)"
#----------------------------------------------------------------
sub translate_special_arg
{
 foreach my $arg ( @ARGV )
 {
  $arg =~ s/<BR>/\n/gi;
 }
}

#======================================================
# Email functions

1;


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

# end of Openmake::ParseBOM::translate_special_arg
1;
