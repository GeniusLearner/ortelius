# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 597 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getAbsolute.al)"
#----------------------------------------------------------------
sub getAbsolute
{

 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 #-- JAG - case 5263 - use getAnchor method
 my $Cwd = @_ ? shift : $self->getAnchor();

 if ( $self->isRelative )
 {
  return CleanPath( $Cwd ) if $self->getPath eq '.';
  return CleanPath( $Cwd . $DL . $self->getPath );
 }

 return $self->get;
} #-- End: sub getAbsolute

# end of Openmake::Path::getAbsolute
1;
