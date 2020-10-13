# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 141 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\LeftSnapshotOnly.al)"
##########################
# Class functions
##########################

#----------------------------------------------------------------
sub LeftSnapshotOnly
{
 my $snap1 = shift;
 my $snap2 = shift;
 my ( @lo, $found, $f1, $f2, @aftersnap, @beforesnap );

 #replace the following with a search over the hash
 # foreach $f1 ( sort $snap1->get ) {
 #  $found =0;
 #  foreach $f2 ( sort $snap2->get ) {
 #  $found = 1, last if $f1 eq $f2;
 #  }
 #  push( @lo, $f1 )  unless $found;
 # }
 @aftersnap  = $snap1->get;
 @beforesnap = $snap2->get;
 foreach $f1 ( @aftersnap )
 {
  if ( $snap2->fileExists( $f1 ) )
  {

   #-- test if the timestamp changes
   if (
    $snap1->getFileTStamp( $f1 ) != $snap2->getFileTStamp( $f1 )
    ||
    $snap1->getFileSize( $f1 ) != $snap2->getFileSize( $f1 ) )
   {
    push @lo, $f1;
   }
  } #-- End: if ( $snap2->fileExists...
  else
  {
   push @lo, $f1;
  }
 } #-- End: foreach $f1 ( @aftersnap )
 return @lo;
} #-- End: sub LeftSnapshotOnly

# end of Openmake::Snapshot::LeftSnapshotOnly
1;
