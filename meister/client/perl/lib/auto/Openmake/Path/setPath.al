# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 451 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\setPath.al)"
*getPerlFileEscaped = *getPerlified;

#----------------------------------------------------------------
sub setPath
{
 my $self = shift;
 if ( @_ )
 {
  my $dirtypath = @_;
  my $cleanpath = File::Spec->canonpath( $dirtypath );

  (my $vol, $self->{PATH} ) = File::Spec->splitpath( $cleanpath, 1 );

  # Remove any trailing delimiter
  $self->{PATH} =~ s|\Q$DL\E$|| if $self->{PATH};

  # Handle the case c:\
  if ( !$self->{PATH} && $self->{VOLUME} && $cleanpath =~ m|\Q$DL\E| )
  {
   $self->{PATH} = $DL;
  }

  # and c:dir
  elsif ( !$self->{PATH} )
  {
   $self->{PATH} = '.';
  }
 } #-- End: if ( @_ )
 return $self->get;
} #-- End: sub setPath

# end of Openmake::Path::setPath
1;
