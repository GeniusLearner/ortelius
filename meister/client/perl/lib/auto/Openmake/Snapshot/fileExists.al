# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 276 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\fileExists.al)"
#----------------------------------------------------------------
sub fileExists
{
 my $self = shift;
 my $file = shift;
 return 1 if ( $self->{FILES}->{$file} );
 return 0;
}

# end of Openmake::Snapshot::fileExists
1;
