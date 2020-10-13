# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 427 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getJEscapedQuoted.al)"
*getJavacEscaped = *getJEscaped;

#----------------------------------------------------------------
sub getJEscapedQuoted
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|\\|\\\\|g;
 return "\"" . $path . "\"";
}

# end of Openmake::Path::getJEscapedQuoted
1;
