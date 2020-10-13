# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 260 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\getFileTStamp.al)"
#----------------------------------------------------------------
sub getFileTStamp
{
 my $self = shift;
 my $file = shift;
 return $self->{FILES}->{$file}->[0];
}

# end of Openmake::Snapshot::getFileTStamp
1;
