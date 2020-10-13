# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 275 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getAbsoluteList.al)"
#----------------------------------------------------------------
sub getAbsoluteList
{
 my $self = shift;
 my @array = $self->getAbsolute(@_);
 return @array;
}

# end of Openmake::FileList::getAbsoluteList
1;
