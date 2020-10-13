# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 407 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getPath.al)"
*getD = *getDrive = *getVolume;

#----------------------------------------------------------------
sub getPath
{
 my $self = shift;
 return $self->{PATH};
}

# end of Openmake::Path::getPath
1;
