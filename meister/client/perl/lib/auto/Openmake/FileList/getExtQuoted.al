# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 211 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getExtQuoted.al)"
#----------------------------------------------------------------
sub getExtQuoted
{
 my $self = shift;
 return $self->getExtCommon( 'Quoted', @_ );
}

# end of Openmake::FileList::getExtQuoted
1;
