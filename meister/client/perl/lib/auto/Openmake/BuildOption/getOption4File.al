# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 592 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\getOption4File.al)"
#----------------------------------------------------------------
sub getOption4File
{
 my $self        = shift;
 my $file        = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;

 $file =~ s/\\/\//g;

 #-- JAG - case 5172, expand envs
 return EvalEnvironment($self->{"Files"}->{$file}->{$optiongroup});

} ## end sub getOption4File

# end of Openmake::BuildOption::getOption4File
1;
