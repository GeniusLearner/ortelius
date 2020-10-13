# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 542 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\getJEscapedQuotedList.al)"
#----------------------------------------------------------------
sub getJEscapedQuotedList
{
 my $self = CORE::shift;
 my ( $path, @eqList );
 my @searchpath = @{ $self->{SEARCHPATH} };

 foreach $path ( @searchpath )
 {
  $path =~ s|\\|\\\\|g;
  CORE::push( @eqList, "\"$path\"" );
 }

 return @eqList;
} #-- End: sub getJEscapedQuotedList

# end of Openmake::SearchPath::getJEscapedQuotedList
1;
