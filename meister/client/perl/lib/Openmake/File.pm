#==========================================================================
package Openmake::File;

BEGIN
{
 use Exporter ();

 #-- JAG - 01.16.05 - begin to use AutoLoader for 6.4
 use AutoLoader;
 use vars qw(@ISA @EXPORT $VERSION);
 use Openmake::Path;
 use Openmake::Load;
 use File::Spec;
 use Cwd;

 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/File.pm,v 1.10 2006/10/25 20:06:15 adam Exp $'; 
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }
 #-- note: since we inherit Openmake::Path, the non-autoload methods in 
 #   O::Path also have to be non-autoload here (new, set, get)
 @ISA     = qw( Exporter Openmake::Load Openmake::Path Openmake::Path::CleanPath AutoLoader );
# @EXPORT  = qw( &CleanPath );
} #-- End: BEGIN

#----------------------------------------------------------------
=head1 NAME

Openmake::File

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

Common functions to parse file names and return them in specific
formats.  This is useful for dealing with different compilers and
operating systems where the file names need to be in a particular format.

=head2 Definitions

=over 2

=item Windows

=over 2

=item Drive 

Drive letter followed by a colon.

=item Path

The path of the fully qualified name, excluding the drive letter, file, and extension.

=item File

The file portion, excluding the  drive letter, path and extension.

=item Extension 

The extension of the file name.

=item Anchor

Drive letter and directory that are used to determine the relative path of the file name.

=back

=back

=over 2

=item UNIX 

=over 2

=item Drive 

Does not exist on Unix, any references to drive are return as "".

=item Path

The path of the fully qualified name, excluding the drive letter, file, and extension.

=item File

The file portion, excluding the  drive letter, path and extension.

=item Extension 

The extension of the file name.

=item Anchor

Drive letter and directory that are used to determine the relative path of the file name.

=back 

=back 

=head1 AutoLoading

All methods in this module except for the "new" method are AutoLoaded 
(compiled when invoked, not at run-time).

=head1 METHODS

=head2 new(), new($FileName)

Handles creating the file object.  The method can be passed a string
in which it will initalize the object.

The file does not have to exist.

=head2 set($FileName)

Sets the $FileName into the object.

=head2 getExt(), getE()

Gets the extension from the file object.  It returns the extension
including the period.  

For example, 

  .cpp.

=head2 getQuoted()

Gets the fully qualified file name with quotes around it.

=head2 getEscaped()

Gets the fully qualified file name with the special perl regular
expression character escaped. 

For example, 

  c:\work\hello.cpp would be c:\\work\\hello\.cpp 

Useful for pattern matching.

=head2 getEscapedQuoted()

Gets the fully qualified file name with the special perl regular
expression character escaped and quotes around it. 

For example, 

  c:\work\hello.cpp would be "c:\\work\\hello\.cpp"

=head2 getJEscaped()

Gets the fully qualified file name with the \ translated into \\. 
 
For example, 

  c:\work\hello.cpp would be c:\\work\\hello\.cpp

=head2 getJEscapedQuoted()

Gets the fully qualified file name with the \ translated into \\ and
with quotes. 
 
For example, c:\work\hello.cpp would be "c:\\work\\hello.cpp"

=head2 setFile($FileName)

Sets the file and extension portion of the object.

=head2 getFile(), getFE()

Gets the file and extension portions of the object.

For example, 

  c:\work\hello.cpp would be hello.cpp

=head2 getF()

Gets the file portion of the object.

For example, 

  c:\work\hello.cpp would be hello

=head2 getPFE()

Gets the path,file and extension portions of the object.

For example, 
 
  c:\work\hello.cpp would be \work\hello.cpp

=head2 getDPF()

Gets the drive, path, and file portions of the object.

For example, 

  c:\work\hello.cpp would be c:\work\hello

=head2 getDPFE(), get()

Gets the drive, path,file and extension portions of the object.

For example, 
 
 c:\work\hello.cpp would be c:\work\hello.cpp

=head2 getAbsolute()

Gets the fully qualified file name.

For example, if the anchor, was set to c:\work,
 
  hello.cpp would be c:\work\hello.cpp

By default the anchor is the current working directory.

=head2 getRelative()

Gets the relative path file name.

For example, if the anchor was set to c:\work:
 
  c:\work\src\hello.cpp would be src\hello.cpp
 
By default the anchor is the current working directory.

=head1 SEE ALSO

Openmake::Path, Openmake::SearchList, Openmake::ClassPath, Openmake::FileList and File::Spec

=cut
##########################
# Class functions
##########################

##########################
# Object functions
##########################

#----------------------------------------------------------------
sub new
{
 my $proto = shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 #-- JAG - 02.12.05 - case 5496 - fix for speed improvements on UNIX
 # $self->{ANCHOR} = File::Spec->canonpath(cwd());

 # define attributes:
 if ( @_ )
 {
  my ( $dirtypath ) = @_;
  my ( $cleanpath ) = File::Spec->canonpath( $dirtypath );

  ($self->{VOLUME}, $self->{PATH}, $self->{FILE} ) = File::Spec->splitpath( $cleanpath );

  # Remove
  $self->{PATH} =~ s|\Q$DL\E$|| if $self->{PATH};

  # We want to be able to handle cases where we have a
  # drive and a relative file and also a drive and a
  # file at the root path, e.g.  c:mydir\setup.exe and
  # c:\file.a

  # Handle the case c:\file.c

  if ( !$self->{PATH} && $self->{VOLUME} && $self->{FILE} && $cleanpath =~ m|\Q$DL\E| )
  {
   $self->{PATH} = $DL;
  }

  # and c:file.c
  elsif (
   !$self->{PATH}
   #      && $self->{VOLUME}
   && $self->{FILE} )
  {
   $self->{PATH} = '.';
  }
 }    ## end if ( @_ )
 else
 {
  ( $self->{VOLUME}, $self->{PATH}, $self->{FILE} ) = ( undef, undef, undef );
 }

 # instantiate and return the reference
 bless( $self, $class );
 return $self;
}    ## end sub new

#----------------------------------------------------------------
sub set
{
 my $self = shift;
 
 if ( @_ )
 {
  my ( $dirtypath ) = @_;
  my ( $cleanpath ) = File::Spec->canonpath( $dirtypath );

  ($self->{VOLUME}, $self->{PATH}, $self->{FILE} ) = File::Spec->splitpath( $cleanpath );

  # Remove
  $self->{PATH} =~ s|\Q$DL\E$|| if $self->{PATH};

  # We want to be able to handle cases where we have a
  # drive and a relative file and also a drive and a
  # file at the root path, e.g.  c:mydir\setup.exe and
  # c:\file.a

  # Handle the case c:\file.c

  if (!$self->{PATH} && $self->{VOLUME} && $self->{FILE} && $cleanpath =~ m|\Q$DL\E| )
  {
   $self->{PATH} = $DL;
  }

  # and c:file.c
  elsif (!$self->{PATH} && $self->{VOLUME} && $self->{FILE} )
  {
   $self->{PATH} = '.';
  }
 } #-- End: if ( @_ )

 return $self->get;
} #-- End: sub set

#----------------------------------------------------------------
sub get
{
 my ( $self ) = shift;

 if ( $self->{VOLUME} && $self->{PATH} )
 {
  if ( $self->{PATH} eq $DL )
  {
   return $self->{VOLUME} . $self->{PATH} . $self->{FILE};
  }
  else
  {
   return $self->{VOLUME} . $self->{PATH} . $DL . $self->{FILE};
  }
 } #-- End: if ( $self->{VOLUME} &&...
 elsif ( $self->{PATH} )
 {
  return $self->{FILE} if $self->{PATH} eq '.';
  return $self->{PATH} . $DL . $self->{FILE};
 }
 elsif ( $self->{FILE} )
 {
  return $self->{FILE};

  #die "Unexpected error: Openmake::File::get!\n$self->{VOLUME}\n$self->{PATH}\n$self->{FILE}\n";
 }
} #-- End: sub get


#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked
#
1;
__END__

#----------------------------------------------------------------
#-- stand-ins for symbol table magic
#
sub fullfile { my $self = shift; return $self->set(@_); }
sub fullpath { my $self = shift; return $self->set(@_); }
sub getE { my $self = shift; return $self->getExt(@_); }
sub file { my $self = shift; return $self->setFile(@_); }
sub getFE { my $self = shift; return $self->getFile(@_); }
sub getDPFE { my $self = shift; return $self->get(@_); }

#----------------------------------------------------------------
sub getExt
{
 my $self = shift;
 
 $_ = $self->{FILE};

 if ( /(\.[^\.]*)\s*$/ )
 {
  return $1;
 }
 else
 {
  return "";
 }
} #-- End: sub getExt

#----------------------------------------------------------------
sub getQuoted
{
 my $self = shift;
 return "\"" . $self->get . "\"";
}

#----------------------------------------------------------------
sub getEscaped
{
 my $self = shift;
 
 my ( $temp ) = $self->get();
 $temp =~ s|(\W)|\\$1|g;

 return $temp;
}

#----------------------------------------------------------------
sub getEscapedQuoted
{
 my $self = shift;
 
 my ( $temp ) = $self->get();
 $temp =~ s|(\W)|\\$1|g;

 return "\"" . $temp . "\"";
}

#----------------------------------------------------------------
sub getJEscaped
{
 my $self = shift;
 
 my ( $temp ) = $self->get();
 $temp =~ s|\\|\\\\|g;

 return $temp;
}

#----------------------------------------------------------------
sub getJEscapedQuoted
{
 my $self = shift;
 
 my $temp = $self->get;
 $temp =~ s|\\|\\\\|g;

 return "\"" . $temp . "\"";
}

#----------------------------------------------------------------
sub setFile
{
 my $self = shift;
  
 if ( @_ ) { $self->{FILE} = File::Spec->cannonpath( shift ) }
 return $self->{FILE};
}

#----------------------------------------------------------------
sub getFile
{
 my $self = shift;
 return $self->{FILE};
}

#----------------------------------------------------------------
sub getF
{
 my $self = shift;
 $_ = $self->{FILE};
 $_ =~ s/\.[^\.]*$//;
 return $_;
}

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

#----------------------------------------------------------------
sub getDPF
{
 my $self = shift;
 my $fullpath = $self->fullpath;
 my $ext      = '\\' . $self->getExt;
 $fullpath =~ s/$ext$//;
 return $fullpath;
}

#----------------------------------------------------------------
sub getDP
{
 my $self = shift;
 if ( $self->{VOLUME} && $self->{PATH} )
 {
  return $self->{VOLUME} . $self->{PATH};
 }
 elsif ( $self->{PATH} )
 {
  return $self->{PATH};
 }
 return "";
} #-- End: sub getDP

#----------------------------------------------------------------
sub getAbsolute
{

 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 #-- JAG - 02.12.05 - case 5496 - fix for speed improvements on UNIX
 # my $Cwd = @_ ? shift : $self->{ANCHOR};
 my $Cwd = @_ ? shift : $self->getAnchor();

 if ( $self->isRelative )
 {
  return CleanPath( $Cwd . $DL . $self->getFile ) if $self->getPath eq '.';
  return CleanPath( $Cwd . $DL . $self->getPFE );
 }
 my ( $temp ) = $self->get();
 return $self->get;
} #-- End: sub getAbsolute

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

