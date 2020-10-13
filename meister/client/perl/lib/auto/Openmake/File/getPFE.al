# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::File;

#line 481 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/File.pm (autosplit into perl\lib\auto\Openmake\File\getPFE.al)"
#----------------------------------------------------------------
sub getPFE
{
 my $self = shift;
  
 my $drive    = $self->drive;
 my $fullpath = $self->get;
 my $PFE      = $fullpath;
 $PFE =~ s/^$drive//;
 return $PFE;
}

# end of Openmake::File::getPFE
1;
