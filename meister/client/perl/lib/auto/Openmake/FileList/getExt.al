# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 176 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getExt.al)"
#----------------------------------------------------------------
sub getExt
{
 #-- JAG - 08.25.03 - case 3533 - slowness of getExt* is caused by creating
 #                    Openmake::File objects just to get the extension.
 my $self    = shift;
 my @extList = @_;
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

 return wantarray ? $outFileList->getList : $outFileList->get
}    #-- End: sub getExt

# end of Openmake::FileList::getExt
1;
