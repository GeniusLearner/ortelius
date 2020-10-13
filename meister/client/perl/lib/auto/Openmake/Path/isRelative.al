# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 581 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\isRelative.al)"
#----------------------------------------------------------------
sub isRelative
{
 my $self = shift;
 return 1 unless $self->getPath =~ /^$eDL/;
 return 0
}

# end of Openmake::Path::isRelative
1;
