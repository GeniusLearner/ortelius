# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 493 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getDPF.al)"
#----------------------------------------------------------------
sub getDPF
{
 my $self = shift;
 my $fullpath = $self->fullpath;
 my $ext      = '\\' . $self->getExt;
 $fullpath =~ s/$ext$//;
 return $fullpath;
}

# end of Openmake::File::getDPF
1;
