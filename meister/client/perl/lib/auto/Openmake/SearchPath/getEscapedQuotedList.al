# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 510 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\getEscapedQuotedList.al)"
#----------------------------------------------------------------
sub getEscapedQuotedList
{
 my $self = CORE::shift;
 my ( $path, @eqList );
 my @searchpath = $self->_getPaths;

 foreach $path ( @searchpath )
 {
  $path =~ s|(\W)|\\$1|g;
  CORE::push( @eqList, "\"$path\"" );
 }

 return @eqList;
} #-- End: sub getEscapedQuotedList

# end of Openmake::SearchPath::getEscapedQuotedList
1;
