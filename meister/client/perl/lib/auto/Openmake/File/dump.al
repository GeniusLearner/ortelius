# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 562 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\dump.al)"
#----------------------------------------------------------------
sub dump
{
 my ( $obj ) = shift;

 print "fullfile: " . $obj->fullfile() . "\n";
 print "get: " . $obj->get . "\n";
 print "drive: " . $obj->drive . "\n";
 print "file: " . $obj->file . "\n";
 print "path: " . $obj->getPath . "\n";
 print "anchor: " . $obj->getAnchor . "\n";
 print "getRelative: " . $obj->getRelative . "\n";
 print "isRelative: " . $obj->isRelative . "\n";
 print "getAbsolute: " . $obj->getAbsolute . "\n";
} #-- End: sub dump

#1;
#__END__

1;
# end of Openmake::File::dump
