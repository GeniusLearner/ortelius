# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 518 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getAbsolute.al)"
#----------------------------------------------------------------
sub getAbsolute
{

 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 #-- JAG - 02.12.05 - case 5496 - fix for speed improvements on UNIX
 # my $Cwd = @_ ? shift : $self->{ANCHOR};
 my $Cwd = @_ ? shift : $self->getAnchor();

 if ( $self->isRelative )
 {
  return CleanPath( $Cwd . $DL . $self->getFile ) if $self->getPath eq '.';
  return CleanPath( $Cwd . $DL . $self->getPFE );
 }
 my ( $temp ) = $self->get();
 return $self->get;
} #-- End: sub getAbsolute

# end of Openmake::File::getAbsolute
1;
