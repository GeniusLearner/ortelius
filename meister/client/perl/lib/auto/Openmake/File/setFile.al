# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 456 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\setFile.al)"
#----------------------------------------------------------------
sub setFile
{
 my $self = shift;
  
 if ( @_ ) { $self->{FILE} = File::Spec->cannonpath( shift ) }
 return $self->{FILE};
}

# end of Openmake::File::setFile
1;
