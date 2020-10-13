# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 438 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getPerlified.al)"
*getQuotedJavacEscaped = *getJEscapedQuoted;

#----------------------------------------------------------------
sub getPerlified
{
 my $self = shift;

 my ( $temp ) = $self->get();
 $temp =~ s|\\|\/|g;

 return $temp;
}

# end of Openmake::Path::getPerlified
1;
