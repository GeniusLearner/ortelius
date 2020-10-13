# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 303 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\new.al)"
#----------------------------------------------------------------
sub new
{
 my $class   = shift;
 my $hashref = shift;
 #my $class   = ref( $proto ) || $proto;
 my $self    = {};

 #-- need to define everything for strict
 $self->{"Build Tasks"} = ();
 $self->{"Files"}       = ();

 bless( $self, $class );

 #-- if $hashref is passed, update with the dude.
 if ( ref $hashref eq "HASH" )
 {
  $self->update( $hashref );
 }

 return $self;
} #-- End: sub new

# end of Openmake::BuildOption::new
1;
