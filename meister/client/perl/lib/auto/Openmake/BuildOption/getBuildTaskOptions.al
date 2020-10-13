# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 662 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\getBuildTaskOptions.al)"
#----------------------------------------------------------------
sub getBuildTaskOptions
{
 my $self        = shift;
 my $buildtask   = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;

 my $ref = $self->{"Build Tasks"};
 if ( !$buildtask )
 {
  if ( scalar( keys %{$ref} ) == 1 && !$buildtask )
  {
   my @t = keys %{$ref};
   $buildtask = $t[0];
  }
  else
  {
   return undef;
  }
 } #-- End: if ( !$buildtask )

 my $optionvalue = $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"}->{$optiongroup}->{"Options"} || undef;

 #-- see if we want to split this up
 $optionvalue = EvalEnvironment($optionvalue);
 my @optionvalues = Openmake::SmartSplit( $optionvalue );

 return wantarray ? @optionvalues : $optionvalue;

} #-- End: sub getBuildTaskOptions

#1;
#__END__
1;
# end of Openmake::BuildOption::getBuildTaskOptions
