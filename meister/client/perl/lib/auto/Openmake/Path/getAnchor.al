# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Path;

#line 525 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Path.pm (autosplit into perl\lib\auto\Openmake\Path\getAnchor.al)"
# Routines to manipulate the path relative to
# an anchor path

#----------------------------------------------------------------
sub getAnchor
{
 my $self = shift;
 #-- JAG - case 5263 - set Anchor here unless already set
 $self->setAnchor() unless ( $self->{ANCHOR} );
 return $self->{ANCHOR};
}

# end of Openmake::Path::getAnchor
1;
