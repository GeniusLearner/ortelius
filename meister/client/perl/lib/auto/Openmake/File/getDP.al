# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 503 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getDP.al)"
#----------------------------------------------------------------
sub getDP
{
 my $self = shift;
 if ( $self->{VOLUME} && $self->{PATH} )
 {
  return $self->{VOLUME} . $self->{PATH};
 }
 elsif ( $self->{PATH} )
 {
  return $self->{PATH};
 }
 return "";
} #-- End: sub getDP

# end of Openmake::File::getDP
1;
