# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 616 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getQuotedAbsolute.al)"
#----------------------------------------------------------------
sub getQuotedAbsolute
{
 my $self = shift;
 return '"' . $self->getAbsolute . '"'
}

# end of Openmake::Path::getQuotedAbsolute
1;
