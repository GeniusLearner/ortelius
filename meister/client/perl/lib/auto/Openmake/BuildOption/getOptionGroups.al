# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 545 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\getOptionGroups.al)"
#----------------------------------------------------------------
sub getOptionGroups
{
 my $self      = shift;
 my $buildtask = shift;

 my @optiongroups = keys %{ $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"} };

 return wantarray ? @optiongroups : \@optiongroups;
}

# end of Openmake::BuildOption::getOptionGroups
1;
