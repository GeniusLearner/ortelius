# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 268 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\getFileSize.al)"
#----------------------------------------------------------------
sub getFileSize
{
 my $self = shift;
 my $file = shift;
 return $self->{FILES}->{$file}->[1];
}

# end of Openmake::Snapshot::getFileSize
1;
