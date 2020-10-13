# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::FileList;

#line 162 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/FileList.pm (autosplit into perl\lib\auto\Openmake\FileList\getExtensions.al)"
sub getExtensions
{
 my $self = shift;
 my @exts;

 foreach ( $self->getList )
 {
  /(\.[^.]+)$/;
  push( @exts, $1 ) if $1
 }

 return wantarray ? @exts : "@exts"
} #-- End: sub getExtensions

# end of Openmake::FileList::getExtensions
1;
