# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 574 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getQuotedRelative.al)"
#----------------------------------------------------------------
sub getQuotedRelative
{
 my $self = shift;
 return '"' . $self->getRelative . '"'
}

# end of Openmake::Path::getQuotedRelative
1;
