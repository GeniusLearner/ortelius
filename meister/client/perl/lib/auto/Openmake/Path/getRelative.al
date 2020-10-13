# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 554 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getRelative.al)"
# Return the part of the path that
# is relative to the anchor
#----------------------------------------------------------------
sub getRelative
{
 my $self = shift;
 my $fullpath = $self->get;
 #-- JAG - case 5263 - use getAnchor method
 my $patt = $self->getAnchor() . $DL;
 $patt =~ s/(\W)/\\$1/g;

 # generate a perl program
 my $regx = '$fullpath =~ s/^$patt//';
 $regx .= 'i' if $insensitive;

 eval( $regx );    # and execute it

 return $fullpath;
} #-- End: sub getRelative

# end of Openmake::Path::getRelative
1;
