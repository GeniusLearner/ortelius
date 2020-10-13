# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 285 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\exportSnapShot.al)"
#----------------------------------------------------------------
sub exportSnapShot
{
 my $self = shift;
 my $file = shift;
 open( FILE, ">$file" ) || return 0;
 print FILE $self->{ANCHOR} . "\n";
 my @files = $self->get;
 foreach my $file ( @files )
 {
  print FILE $file . "\t" . $self->getFileTStamp( $file ) . "\t" . $self->getFileSize( $file ) . "\n";
 }
 close FILE;
 return 1;
} #-- End: sub exportSnapShot

#1;
#__END__

1;
# end of Openmake::Snapshot::exportSnapShot
