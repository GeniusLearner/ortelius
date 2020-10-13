# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 217 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getExtQuotedList.al)"
#----------------------------------------------------------------
sub getExtQuotedList
{
 my $self = shift;
 return $self->getExtCommon( 'QuotedList', @_ );
}

# end of Openmake::FileList::getExtQuotedList
1;
