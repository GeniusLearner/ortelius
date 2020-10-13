# NOTE: Derived from lib\Openmake\SearchPath.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::SearchPath;

#line 457 "lib\Openmake\SearchPath.pm (autosplit into lib\auto\Openmake\SearchPath\newFromScalar.al)"
#----------------------------------------------------------------
sub newFromScalar
{
 my $proto = CORE::shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 $self->{SEARCHPATH} = {};

 # define attributes:
 if ( @_ )
 {
  my $temp = CORE::shift;
  my @paths = CleanSearchPath( split( /$PathDL|\|/, $temp ) );
  $self->_newPaths( @paths );
 }

 # instantiate and return the reference
 bless( $self, $class );
 return $self;
} #-- End: sub newFromScalar

# end of Openmake::SearchPath::newFromScalar
1;
