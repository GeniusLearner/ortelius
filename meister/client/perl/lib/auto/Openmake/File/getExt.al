# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 389 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getExt.al)"
sub getExt
{
 my $self = shift;
 
 $_ = $self->{FILE};

 if ( /(\.[^\.]*)\s*$/ )
 {
  return $1;
 }
 else
 {
  return "";
 }
} #-- End: sub getExt

# end of Openmake::File::getExt
1;
