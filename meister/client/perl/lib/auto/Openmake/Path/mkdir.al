# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 623 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\mkdir.al)"
#############################################

#----------------------------------------------------------------
sub mkdir
{
 my $self = shift;

 my ( @Dirs, $Dir, $newdir );

 $newdir = '';

 # return 1 if -d $self->getPath || $self->getPath eq '.';

 @Dirs = split( /$eDL/, $self->getDP );

 foreach $Dir ( @Dirs )
 {

  $newdir .= $Dir;

  # Works with unix slashes for all os's
  mkdir $newdir, 0777;
  $newdir .= '/';
 }
} #-- End: sub mkdir

# end of Openmake::Path::mkdir
1;
