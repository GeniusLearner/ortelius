# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 649 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\CleanPath.al)"
##########################
# Class functions
##########################

#----------------------------------------------------------------
sub CleanPath
{
 my ( $path ) = shift;
 if ( $path eq '.' )
 {
  return '.';
 }
 else
 {
  return File::Spec->canonpath( $path );
 }
} #-- End: sub CleanPath($)

#1;
##__END__

1;
# end of Openmake::Path::CleanPath
