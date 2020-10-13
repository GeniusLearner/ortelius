# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 482 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getQuoted.al)"
#----------------------------------------------------------------
sub getQuoted
{
 my $self = shift;
 return "\"" . $self->get . "\""
}

# end of Openmake::Path::getQuoted
1;
