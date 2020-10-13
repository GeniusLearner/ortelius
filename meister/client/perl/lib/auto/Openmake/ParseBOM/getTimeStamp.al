# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::ParseBOM;

#line 892 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\ParseBOM\getTimeStamp.al)"
#----------------------------------------------------------------
sub getTimeStamp
{
 my $self = shift;
 my $file = shift;
 return $self->{$file}->{TStamp};
}

# end of Openmake::ParseBOM::getTimeStamp
1;
