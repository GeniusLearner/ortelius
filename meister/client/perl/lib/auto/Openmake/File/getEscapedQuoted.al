# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 423 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getEscapedQuoted.al)"
#----------------------------------------------------------------
sub getEscapedQuoted
{
 my $self = shift;
 
 my ( $temp ) = $self->get();
 $temp =~ s|(\W)|\\$1|g;

 return "\"" . $temp . "\"";
}

# end of Openmake::File::getEscapedQuoted
1;
