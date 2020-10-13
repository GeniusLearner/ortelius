# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 501 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getEscapedQuoted.al)"
#----------------------------------------------------------------
sub getEscapedQuoted
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|(\W)|\\$1|g;
 return "\"" . $path . "\"";
}

# end of Openmake::Path::getEscapedQuoted
1;
