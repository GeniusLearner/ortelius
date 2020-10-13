# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 538 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getRelative.al)"
#----------------------------------------------------------------
sub getRelative
{

 # Return the part of the path that
 # is relative to the anchor
 my $self     = shift;
 my $fullpath = $self->getAbsolute;
 my $patt = $self->getAnchor() . $DL;

 $patt =~ s/\\/\\\\/g;
 $patt =~ s/\//\\\//g;

 # generate a perl program
 my $regx = '$fullpath =~ s/^$patt//';
 $regx .= 'i' if $insensitive;

 eval( $regx );

 # print "fullpath: $patt $fullpath\n";

 return File::Spec->canonpath( $fullpath );
} #-- End: sub getRelative

# end of Openmake::File::getRelative
1;
