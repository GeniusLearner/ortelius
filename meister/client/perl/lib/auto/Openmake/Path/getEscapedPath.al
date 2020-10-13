# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 510 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getEscapedPath.al)"
# methods to return weird java
# escaped information as required
# in response files on win32

#----------------------------------------------------------------
sub getEscapedPath
{
 my $self = shift;
 my $temp = $self->{PATH};

 $temp =~ s|(\W)|\\$1|g;

 return $temp;
}

# end of Openmake::Path::getEscapedPath
1;
