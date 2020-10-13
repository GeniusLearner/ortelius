# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 489 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getEscaped.al)"
# methods to return standard regex
# escaped information

#----------------------------------------------------------------
sub getEscaped
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|(\W)|\\$1|g;
 return $path
}

# end of Openmake::Path::getEscaped
1;
