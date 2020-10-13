# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 393 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\setVolume.al)"
sub setVolume
{
 my $self = shift;
 if ( @_ ) { $self->{VOLUME} = shift }
 return $self->{VOLUME};
}

# end of Openmake::Path::setVolume
1;
