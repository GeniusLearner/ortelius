# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 494 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\getEscapedList.al)"
#----------------------------------------------------------------
sub getEscapedList
{
 my $self = CORE::shift;
 my ( @ePaths, $ePath );
 my @searchpath = $self->_getPaths;

 foreach $ePath ( @searchpath )
 {
  $ePath =~ s|(\W)|\\$1|g;
  CORE::push( @ePaths, $ePath );
 }

 return @ePaths;
} #-- End: sub getEscapedList

# end of Openmake::SearchPath::getEscapedList
1;
