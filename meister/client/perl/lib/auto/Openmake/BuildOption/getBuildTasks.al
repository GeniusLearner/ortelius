# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 537 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\getBuildTasks.al)"
#----------------------------------------------------------------
sub getBuildTasks
{
 my $self       = shift;
 my @buildtasks = keys %{ $self->{"Build Tasks"} };
 return wantarray ? @buildtasks : \@buildtasks;
}

# end of Openmake::BuildOption::getBuildTasks
1;
