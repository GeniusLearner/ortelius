# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 405 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getQuoted.al)"
#----------------------------------------------------------------
sub getQuoted
{
 my $self = shift;
 return "\"" . $self->get . "\"";
}

# end of Openmake::File::getQuoted
1;
