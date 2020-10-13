# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::ParseBOM;

#line 900 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\ParseBOM\getVersionInfo.al)"
#----------------------------------------------------------------
sub getVersionInfo
{
 my $self = shift;
 my $file = shift;
 return $self->{$file}->{VInfo};
}

##1;
#__END__

1;
# end of Openmake::ParseBOM::getVersionInfo
