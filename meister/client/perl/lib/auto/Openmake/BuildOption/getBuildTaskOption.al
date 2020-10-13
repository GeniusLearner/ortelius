# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 606 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\getBuildTaskOption.al)"
#----------------------------------------------------------------
sub getBuildTaskOption
{
 my $self        = shift;
 my $option      = shift;
 my $buildtask   = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;

 my $option_type = 1;    #-- equals construction
 $option_type = 2 if ( $option =~ /^\-/ );    #-- dash construction

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

 #-- find the option that matches, ie. manifest= or webxml=
 my $optionvalue = $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"}->{$optiongroup}->{"Options"};

 #-- match like moduledir in Openmake.pm, loop over each to find our guy
 my @optionvalues = &Openmake::SmartSplit( $optionvalue );

 my $i = 0;
 foreach my $opt ( @optionvalues )
 {
  $i++;    #-- increment here so we get the next one as our value
  if ( $option_type == 1 )
  {
   if ( $opt =~ /^$option=(.+)/ )
   {
    $optionvalue = $1;
    return EvalEnvironment($optionvalue);
   }
  }
  else     #-- dash notation
  {
   if ( $opt eq $option )
   {
    $optionvalue = $optionvalues[$i];
    return EvalEnvironment($optionvalue);
   }
  }
 } #-- End: foreach my $opt ( @optionvalues...

 return undef;
} #-- End: sub getBuildTaskOption

# end of Openmake::BuildOption::getBuildTaskOption
1;
