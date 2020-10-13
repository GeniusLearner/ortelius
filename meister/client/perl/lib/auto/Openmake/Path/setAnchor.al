# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 538 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\setAnchor.al)"
#----------------------------------------------------------------
sub setAnchor
{
 my $self = shift;
 if ( @_ )
 {
  $self->{ANCHOR} = File::Spec->canonpath( shift );
 }
 else
 {
  $self->{ANCHOR} = File::Spec->canonpath( cwd() );
 }

 return $self->{ANCHOR};
} #-- End: sub setAnchor

# end of Openmake::Path::setAnchor
1;
