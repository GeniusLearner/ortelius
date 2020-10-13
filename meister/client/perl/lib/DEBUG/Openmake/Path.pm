#==========================================================================
package Openmake::Path;

BEGIN
{
 use Exporter ();
 use AutoLoader;
 use Openmake::Load;
 use File::Spec;
 use Cwd;
 use vars qw(@ISA @EXPORT $VERSION);

 @ISA     = qw(Exporter AutoLoader Openmake::Load);
 @EXPORT  = qw( &CleanPath $DL $eDL $insensitive $VERSION);
 my $HEADER = '$Header: /CVS/openmake64/perl/lib/DEBUG/Openmake/Path.pm,v 1.2 2005/06/13 19:56:49 jim Exp $'; 
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }
} #-- End: BEGIN

#----------------------------------------------------------------
=head1 NAME

Openmake::Path

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

Common functions to parse file paths and return them in specific
formats.  This is useful for dealing with different compilers and
operating systems where the file paths need to be in a particular format.

=head2 Definitions

=over 2

=item Windows

=over 2

=item Drive 

Is a drive letter followed by a colon.

=item Path

The path of the fully qualified name, excluding the drive letter, file, and extension.

=item Anchor

Is a drive letter and directory that are used to determine the relative path of the file name.

=back

=back

=over 2

=item UNIX 

=over 2

=item Drive 

Does not exist on Unix, any references to drive are return as "".

=item Path

The path of the fully qualified name, excluding the drive letter, file, and extension.

=item Anchor

Is a drive letter and directory that are used to determine the relative path of the file name.

=back 

=back 

=head1 AutoLoad

Only "new", "get", and "set" are compiled by default. All other methods are 
Autoloaded and compiled when invoked by the Build Type.

=head1 METHODS

Methods not requiring an anchor: 

  new
  get
  set
  getVolume
  setVolume
  getPath
  setPath
  getQuoted
  getEscaped
  getEscapedPath
  getJavacEscaped 
  getQuotedJavacEscaped
  getPerlEscaped
  getQuotedEscaped 

Methods making use of an anchor:

  getAnchor
  setAnchor
  isRelative
  getRelative
  getAbsolute
  getQuotedAbsolute

=head2 new(), new($full_path_string)

Called as C<< $path=Openmake::Path->new >> or 
C<< $path=Openmake::Path->new('c:\hi\there') >> this instantiates the
path object.

=head2 get(), getDP()

This method returns the drive and path of the path object, 
delimited appropriately for the current operating system.  

=head2 setVolume( $drive ), setDrive( $drive )

Sets or changes the drive part of path object.  On Windows, the drive
should contain the colon.

=head2 getVolume(), getDrive(), getD()

Returns the Drive letter part of the path object. On Unix, it will return "".

=head2 setPath ( $path_string )

Sets the Path part of the path object.

=head2 set( $path_string )

Explicitly sets the drive and path of the object.

=head2 getPath(), getP()

Returns only the path part of object.

=head2 getQuoted()

Returns the drive and path enclosed in double quotes.

=head2 getEscaped()

Returns the drive and path with escaped non-word characters according
to Perl's \W. 

=head2 getEscapedQuoted()

Returns a double-quoted version of getEscaped().

=head2 getJavacEscaped(), getJEscaped()

Returns the drive and path with escaped \ characters.

=head2 getQuotedJavacEscaped(), getJEscapedQuoted()

Returns getJavacEscaped() enclosed with double quotes.

=head2 getEscapedPath()

Returns the path with escaped non-word characters according to Perl's \W.

=head2 getPerlFileEscaped(), getPerlified()

Returns the drive and path with \ changed to /.

=head2 getAnchor()

Returns the current anchor. The default anchor is the current working
directory.

=head2 setAnchor(), setAnchor( $full_path_string )

Sets the anchor to the value of $path_string.  

Any future calls to getRelative or isRelative will interpret what is 
relative according to this new value.  

If called with no argument, the anchor will be reset to the current working directory according to Perl.

Warning: There is no check to see if $full_path_string is itsef an
absolute path.

=head2 getRelative()

Retuns the relative path of the object.  The relative path is derived
from the current anchor value. 

=head2 getQuotedRelative()

Returns the value of getRelative() enclosed in double quotes.

=head2 isRelative()

Returns 1 if the path is a relative path, 0 if it is an absolute path.  

On UNIX, this simply means that if the path begins with a '/' then it
is absolute.

On Windows, 'c:\johnson.txt' is considered absolute, but
'c:johnson.txt' is considered relative. 

=head2 isAbsolute()

Returns 1 if the path is a absolute path, 0 if it is an relative path.  

On UNIX, this simply means that if the path begins with a '/' then it
is absolute.

On Windows, 'c:\johnson.txt' is considered absolute, but
'c:johnson.txt' is considered relative. 

=head2 getAbsolute()

Returns the absolute form of the path, drive and path.  The anchor
value will be used to derive the value.  

=head2 getQuotedAbsolute()

Same as B<getAbsolute> but the return string is enclosed in double quotes.

=head2 mkdir()

Calls Perl's mkdir function recursively from the top down so that the
full path will exist on the operating system.  

Currently the mkdir calls use permission 0777.

=head2 CleanPath($)

Returns the path with unnecessary "\\", ".\" and "//" removed from the
path unless $path is equal to '.', in which case it returns '.'.

=head1 SEE ALSO

Openmake::File, Openmake::SearchList, Openmake::ClassPath,
Openmake::FileList and File::Spec 

=cut
if ( $^O =~ /os2|win/i )
{

 # Win-like
 $DL = $eDL = '\\';
 $eDL =~ s/(\W)/\\$1/g;
 $insensitive = 1;    # define insensitive
}
else
{

 # Assume UNIX-like
 $DL = $eDL = '/';
 $eDL =~ s/(\W)/\\$1/g;
 $insensitive = 0;
}

#----------------------------------------------------------------
sub new
{
 # file constructor
 my $proto = shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 # define attributes:
 #-- JAG - case 5263 - this is brutally slow on UNIX. See fix to getAnchor
 #$self->{ANCHOR} = File::Spec->canonpath(cwd());

 if ( @_ )
 {
  my $dirtypath = shift @_;
  my $cleanpath = File::Spec->canonpath( $dirtypath );

  ($self->{VOLUME}, $self->{PATH} ) = File::Spec->splitpath( $cleanpath, 1 );

  # Remove trailing delimiter, if any
  $self->{PATH} =~ s|\Q$DL\E$|| if $self->{PATH};

  # We want to be able to handle cases where we have a
  # drive and a relative file and also a drive and a
  # file at the root path, e.g.  c:mydir\setup.exe and
  # c:\file.a

  # Handle the case c:\

  if ( !$self->{PATH} && $self->{VOLUME} && $cleanpath =~ m|\Q$DL\E| )
  {
   $self->{PATH} = $DL;
  }

  # and c:dir
  elsif ( !$self->{PATH} )
  {
   $self->{PATH} = '.';
  }

 } #-- End: if ( @_ )
 else
 {
  ($self->{VOLUME}, $self->{PATH} ) = ( undef, undef );
 }

 # instantiate and return the reference
 bless( $self, $class );
 return $self;
} #-- End: sub new

# methods to get basic information out about
# the path object

#----------------------------------------------------------------
sub get
{
 # The main full path return routine
 my $self = shift;

 if ( $self->{VOLUME} and $self->{PATH} )
 {
  return $self->{VOLUME} . $self->{PATH};
 }
 elsif ( $self->{VOLUME} )
 {
  return $self->{VOLUME};
 }
 else
 {
  return $self->{PATH};
 }
} #-- End: sub get

*getDP = *path = *get;

#----------------------------------------------------------------
sub set
{
 # Set the full path
 my $self = shift;

 if ( @_ )
 {
  my ( $dirtypath ) = @_;
  my ( $cleanpath ) = File::Spec->canonpath( $dirtypath );

  ($self->{VOLUME}, $self->{PATH} ) = File::Spec->splitpath( $cleanpath, 1 );
 }
 else
 {
  warn "Openmake::Path->set called with no argument.";
 }

 return $self->get;
} #-- End: sub set

#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked
#
#           Symbol table magic. Don't know if this works
#-- removed for DEBUG Version
#1;
#__END__

#----------------------------------------------------------------
#-- stand-ins for symbol table magic
#
sub setDrive { my $self = shift; return $self->setVolume( @_); }
sub drive { my $self = shift; return $self->setVolume( @_); }
sub volume { my $self = shift; return $self->setVolume( @_); }
sub getD { my $self = shift; return $self->getVolume( @_); }
sub getDrive { my $self = shift; return $self->getVolume( @_); }
sub getP { my $self = shift; return $self->getPath( @_); }
sub getJavacEscaped { my $self = shift; return $self->getJEscaped( @_); }
sub getQuotedJavacEscaped { my $self = shift; return $self->getJEscaped( @_); }
sub getPerlFileEscaped { my $self = shift; return $self->getPerlified( @_); }
sub anchor { my $self = shift; return $self->getAnchor( @_); }
sub relative { my $self = shift; return $self->getRelative( @_); }

#----------------------------------------------------------------
sub setVolume
{
 my $self = shift;
 if ( @_ ) { $self->{VOLUME} = shift }
 return $self->{VOLUME};
}

#----------------------------------------------------------------
sub getVolume
{
 my $self = shift;
 $self->volume();
}

*getD = *getDrive = *getVolume;

#----------------------------------------------------------------
sub getPath
{
 my $self = shift;
 return $self->{PATH};
}

*getP = *getPath;

#----------------------------------------------------------------
sub getJEscaped
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|\\|\\\\|g;
 return $path
}

*getJavacEscaped = *getJEscaped;

#----------------------------------------------------------------
sub getJEscapedQuoted
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|\\|\\\\|g;
 return "\"" . $path . "\"";
}

*getQuotedJavacEscaped = *getJEscapedQuoted;

#----------------------------------------------------------------
sub getPerlified
{
 my $self = shift;

 my ( $temp ) = $self->get();
 $temp =~ s|\\|\/|g;

 return $temp;
}

*getPerlFileEscaped = *getPerlified;

#----------------------------------------------------------------
sub setPath
{
 my $self = shift;
 if ( @_ )
 {
  my $dirtypath = @_;
  my $cleanpath = File::Spec->canonpath( $dirtypath );

  (my $vol, $self->{PATH} ) = File::Spec->splitpath( $cleanpath, 1 );

  # Remove any trailing delimiter
  $self->{PATH} =~ s|\Q$DL\E$|| if $self->{PATH};

  # Handle the case c:\
  if ( !$self->{PATH} && $self->{VOLUME} && $cleanpath =~ m|\Q$DL\E| )
  {
   $self->{PATH} = $DL;
  }

  # and c:dir
  elsif ( !$self->{PATH} )
  {
   $self->{PATH} = '.';
  }
 } #-- End: if ( @_ )
 return $self->get;
} #-- End: sub setPath

#----------------------------------------------------------------
sub getQuoted
{
 my $self = shift;
 return "\"" . $self->get . "\""
}

# methods to return standard regex
# escaped information

#----------------------------------------------------------------
sub getEscaped
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|(\W)|\\$1|g;
 return $path
}

#----------------------------------------------------------------
sub getEscapedQuoted
{
 my $self = shift;
 my $path = $self->get;
 $path =~ s|(\W)|\\$1|g;
 return "\"" . $path . "\"";
}

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


#----------------------------------------------------------------
sub setAnchor
{
 my $self = shift;
 if ( @_ )
 {
  $self->{ANCHOR} = File::Spec->canonpath( shift );
 }
 else
 {
  $self->{ANCHOR} = File::Spec->canonpath( cwd() );
 }

 return $self->{ANCHOR};
} #-- End: sub setAnchor

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

#----------------------------------------------------------------
sub getQuotedRelative
{
 my $self = shift;
 return '"' . $self->getRelative . '"'
}

#----------------------------------------------------------------
sub isRelative
{
 my $self = shift;
 return 1 unless $self->getPath =~ /^$eDL/;
 return 0
}

#----------------------------------------------------------------
sub isAbsolute
{
 my $self = shift;
 return 1 if $self->getPath =~ /^$eDL/;
 return 0
}

#----------------------------------------------------------------
sub getAbsolute
{

 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 #-- JAG - case 5263 - use getAnchor method
 my $Cwd = @_ ? shift : $self->getAnchor();

 if ( $self->isRelative )
 {
  return CleanPath( $Cwd ) if $self->getPath eq '.';
  return CleanPath( $Cwd . $DL . $self->getPath );
 }

 return $self->get;
} #-- End: sub getAbsolute

#----------------------------------------------------------------
sub getQuotedAbsolute
{
 my $self = shift;
 return '"' . $self->getAbsolute . '"'
}

#############################################

#----------------------------------------------------------------
sub mkdir
{
 my $self = shift;

 my ( @Dirs, $Dir, $newdir );

 $newdir = '';

 # return 1 if -d $self->getPath || $self->getPath eq '.';

 @Dirs = split( /$eDL/, $self->getDP );

 foreach $Dir ( @Dirs )
 {

  $newdir .= $Dir;

  # Works with unix slashes for all os's
  mkdir $newdir, 0777;
  $newdir .= '/';
 }
} #-- End: sub mkdir

##########################
# Class functions
##########################

#----------------------------------------------------------------
sub CleanPath
{
 my ( $path ) = shift;
 if ( $path eq '.' )
 {
  return '.';
 }
 else
 {
  return File::Spec->canonpath( $path );
 }
} #-- End: sub CleanPath($)

#1;
##__END__

1;
__END__
