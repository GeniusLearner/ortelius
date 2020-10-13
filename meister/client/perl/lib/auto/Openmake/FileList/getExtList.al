# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 205 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getExtList.al)"
#----------------------------------------------------------------
sub getExtList
{
 my $self = shift;
 return $self->getExtCommon( 'List', @_ );
}

# end of Openmake::FileList::getExtList
1;
