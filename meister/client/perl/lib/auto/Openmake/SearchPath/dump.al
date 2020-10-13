# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 560 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\dump.al)"
####################
# Diagnostic object methods
####################

#----------------------------------------------------------------
sub dump
{
 my $self = CORE::shift;

 print "SearchPath: \n" . $self->get() . "\n\n";
 my ( @eList ) = $self->getEscapedList();
 print "escapedList: \n@eList\n\n";
 @eList = $self->getQuotedList();
 print "quotedList: \n@eList\n\n";
 @eList = $self->getEscapedQuotedList();
 print "escapedQuotedList: \n@eList\n";
} #-- End: sub dump

# The very important positive return result
#1;
#__END__

1;
# end of Openmake::SearchPath::dump
