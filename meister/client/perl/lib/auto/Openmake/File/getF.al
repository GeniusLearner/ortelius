# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 472 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getF.al)"
#----------------------------------------------------------------
sub getF
{
 my $self = shift;
 $_ = $self->{FILE};
 $_ =~ s/\.[^\.]*$//;
 return $_;
}

# end of Openmake::File::getF
1;
