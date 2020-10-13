# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 479 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\getQuoted.al)"
#----------------------------------------------------------------
sub getQuoted
{
 my $self = CORE::shift;
 my ( $path, @quotedList );
 my @paths = $self->_getPaths;
 foreach $path ( @paths )
 {
  #$path =~ s|^\"||g; #"
  #$path =~ s|\"$||g; #"
  CORE::push( @quotedList, "\"$path\"" );
 }
 return wantarray ? @quotedList : join( $PathDL, @quotedList );
} #-- End: sub getQuoted

# end of Openmake::SearchPath::getQuoted
1;
