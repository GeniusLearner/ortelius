# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 249 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\get.al)"
#----------------------------------------------------------------
sub get
{
 my $self = shift;

 # return @{$self->{FILES}};
 #-- JAG - 05.01.03 fixed bug here
 # return %{$self->{FILES}};
 return keys %{ $self->{FILES} };
}

# end of Openmake::Snapshot::get
1;
