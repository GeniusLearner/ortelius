# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 526 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\getJEscapedList.al)"
#----------------------------------------------------------------
sub getJEscapedList
{
 my $self = CORE::shift;
 my ( @ePaths, $ePath );
 my @searchpath = $self->_getPaths;

 foreach $ePath ( @searchpath )
 {
  $ePath =~ s|\\|\\\\|g;
  CORE::push( @ePaths, $ePath );
 }

 return @ePaths;
} #-- End: sub getJEscapedList

# end of Openmake::SearchPath::getJEscapedList
1;
