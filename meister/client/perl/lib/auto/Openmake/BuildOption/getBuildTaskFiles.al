# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 556 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\getBuildTaskFiles.al)"
#----------------------------------------------------------------
sub getBuildTaskFiles
{
 my $self        = shift;
 my $buildtask   = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;
 my $all         = shift;

 my @files   = ();
 my @options = ();
 my $ref     = $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"}->{$optiongroup};

 return ( undef, undef ) unless ( $ref );

 foreach my $file ( keys %{ $ref->{"Files"} } )
 {
  if ( !$all )
  {
   next if ( $ref->{"Files"}->{$file}->{FileType} != 1 );
  }

  if ( ref $ref->{"Files"}->{$file} )
  {
   push @files, $file;

   #-- JAG - 12.28.05 - case 6290 - if the file is in 2 option groups
   #   need to get the correct one.
   my $option = $self->{"Files"}->{$file}->{$optiongroup};
   push @options, EvalEnvironment($option);
  }

 } #-- End: foreach my $file ( keys %{ ...

 return ( \@files, \@options );
} #-- End: sub getBuildTaskFiles

# end of Openmake::BuildOption::getBuildTaskFiles
1;
