# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 223 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getExtCommon.al)"
# Private function called by the getExt family.  This
# was intended to be a nice way to use a common function,
# but really it is more confusing.

#----------------------------------------------------------------
sub getExtCommon
{
 my ( $self, $which, @extList ) = @_;
 my $file;
 my $outFileList = Openmake::FileList->new;

 foreach $file ( $self->getList )
 {
  #my $oFile = Openmake::File->new($file);
  #my $ext = '\\' . $oFile->getE;
  #$ext = "\.NOEXT" if ($oFile->getE eq "");
  my $ext = "\\.NOEXT";
  if ( $file =~ /(\.[^\.]*)\s*$/ )
  {
   $ext = "\\" . $1;
  }

  #$outFileList->push($oFile->get)  if( grep(/^$ext$/i,@extList) );
  $outFileList->push( $file ) if ( grep( /^$ext$/i, @extList ) );
 } #-- End: foreach $file ( $self->getList...

 return $outFileList->getQuotedList if $which =~ /quotedList/;
 return $outFileList->getQuoted     if $which =~ /Quoted/;
 return $outFileList->getList       if $which =~ /List/;
 return $outFileList->getList;
}    #-- End: sub getExtCommon

# end of Openmake::FileList::getExtCommon
1;
