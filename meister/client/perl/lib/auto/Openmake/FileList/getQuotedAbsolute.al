# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 283 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getQuotedAbsolute.al)"
#----------------------------------------------------------------
sub getQuotedAbsolute
{
 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 my $anchor = shift if @_;
 my $file;
 my $outFileList = Openmake::FileList->new;
 my $oFile       = Openmake::File->new;
 1;
 foreach $file ( $self->getList )
 {
  $oFile->set( $file );
  $oFile->setAnchor( $anchor ) if $anchor;
  $outFileList->push( $oFile->getAbsolute );
 }
 return $outFileList->getQuoted;
} #-- End: sub getQuotedAbsolute

#1;
#__END__

1;
# end of Openmake::FileList::getQuotedAbsolute
