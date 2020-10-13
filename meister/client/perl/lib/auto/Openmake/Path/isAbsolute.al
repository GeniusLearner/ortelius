# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 589 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\isAbsolute.al)"
#----------------------------------------------------------------
sub isAbsolute
{
 my $self = shift;
 return 1 if $self->getPath =~ /^$eDL/;
 return 0
}

# end of Openmake::Path::isAbsolute
1;
