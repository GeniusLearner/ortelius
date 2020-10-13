#==========================================================================
package Openmake::SearchPath;

#-- JAG - 03.25.04 - reworked the structure of the class. Instead of
#                      SEARCHPATH => @<array of directories>
#                    we have a hash
#                      SEARCHPATH => %<hash of directories>
#                    The hash values are the order in the array
#                    Reworked the following methods
#
#

BEGIN
{
 use Exporter ();
 use File::Spec;
 use Openmake::Load;

 use vars qw(@ISA @EXPORT $VERSION);

 @ISA     = qw(Exporter Openmake::Load);
 @EXPORT  = qw($PathDL $DL $eDL);
 @EXPORT_OK = qw{ RelPath2AbsPath };

 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/SearchPath.pm,v 1.14 2008/11/04 18:02:50 sean Exp $';
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }

 if ( $^O =~ /MSWin|dos/i)
 {
  $DL     = '\\';
  $eDL    = '\\\\';
  $PathDL = ';';
 }
 else
 {
  $eDL = $DL = '/';
  $PathDL = ':';
 }

}

#------------------------------------------------------------------
sub RelPath2AbsPath
{
 my ( $relPath, $absPath ) = @_;
 my %map;

 my @relDeps = $relPath->getList();
 my @absDeps = $absPath->getList();

 if ( length @relDeps != length @absDeps )
 {
  return %map;
 }

 my $i = 0;
 foreach my $rDep ( @relDeps )
 {
  my $sRDep = $rDep;
  $sRDep =~ s{\\}{/}g;

  my $aDep = $absDeps[$i];
  if ( $aDep )
  {
   my $sADep = $aDep;
   $sADep =~ s{\\}{/}g;

   $map{$rDep} = $aDep;
   $map{$sRDep} = $sADep;
  }
  else
  {
   $map{$rDep} = $rDep;
   $map{$sRDep} = $sRDep;
  }

  #--

  $i++;
 }

 return %map;
}
#----------------------------------------------------------------
sub CleanSearchPath(@)
{
 my ( @paths ) = @_;
 my ( @cleanpaths, $path );

 foreach $path ( @paths )
 {
  $path =~ s|\n$||;
  $path =~ s|^\"||g;    #"
  $path =~ s|\"$||g;    #"
  $path = File::Spec->canonpath( $path );
  push( @cleanpaths, $path )
    unless $path =~ /^\s*$/;
 }

 return @cleanpaths;
} #-- End: sub CleanSearchPath(@)

#----------------------------------------------------------------
sub new
{
 my $proto = shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 # instantiate
 bless( $self, $class );

 #-- add the SEARCHPATH as a hash
 # SBT 02.11.08 - Update for performance
 $self->{SEARCHPATH} = ();

 # define attributes:
 if ( @_ )
 {
  # call the 'other' constructor if it looks like we were passed a
  # string that is a set of paths joined by the OS's path delimiter
  # or a simple '|' character

  my @paths = ();
  if ( scalar( @_ ) == 1 && $_[0] =~ /$PathDL|;|\|/ )
  {
   my $temp = shift;

   # added workaround for om - sends ; as path delimiter on UNIX
   @paths = CleanSearchPath( split( /$PathDL|;|\|/, $temp ) );
  }
  else
  {
   # no? then this is a list of paths, perhaps with only one element
   @paths = CleanSearchPath( @_ );
  }

  $self->_newPaths( @paths );
 } #-- End: if ( @_ )

 return $self;
} #-- End: sub new

#----------------------------------------------------------------
# SBT 02.11.08 - Update for performance
sub _newPaths
{
 my $self = shift;

 #-- clear the path list
 $self->{SEARCHPATH} = ();

 #-- add these paths
 $self->_addPaths( @_ );
 return $self;
} #-- End: sub _newPaths

#----------------------------------------------------------------
# SBT 02.11.08 - Update for performance
# JAG - 04.09.08 - case IUD-134
sub _addPaths
{
 my $self = shift;

 my %saw = () ;
 @saw{@{$self->{'SEARCHPATH'}}} = () if ( defined $self->{'SEARCHPATH'});
 foreach my $p ( @_ )
 {
  push @{$self->{SEARCHPATH}}, $p unless exists $saw{$p};
 }
 return $self;
} #-- End: sub _addPaths

#----------------------------------------------------------------
sub set
{
 #-- allow for setfromscalar
 my $self  = shift;
 my @paths = ();
 if ( scalar( @_ ) == 1 )
 {
  my ( $temp ) = shift;
  $temp =~ s/\;/\|/g;
  $temp =~ s/\:/\|/g;
  @paths = CleanSearchPath( split( /$PathDL|\|/, $temp ) );
 }
 else
 {
  @paths = CleanSearchPath( @_ );
 }

 if ( @paths )
 {
  $self->_newPaths( @paths );
 }
 else
 {
  $self->{SEARCHPATH} = ();
 }
 return $self->get
} #-- End: sub set

*setFromScalar = *set;
*searchpath    = *set;

#----------------------------------------------------------------
# SBT 02.11.08 - Update for performance
sub _getPaths
{
 my $self = shift;

 return @{$self->{SEARCHPATH}};
} #-- End: sub _getPaths

#----------------------------------------------------------------
sub get
{
 my $self = shift;
 my @paths = $self->_getPaths;

 return wantarray ? @paths : join( $PathDL, @paths );
}
*getList = *get;

#sub getList {
# my $self = shift;
# return @{$self->{SEARCHPATH}}
#}

#----------------------------------------------------------------
sub getString
{
 my ( $self, $pre, $post ) = @_;
 my @paths = $self->_getPaths;
 return $pre . join( $post . $pre, @paths ) . $post
   if $#paths > -1;
}

#----------------------------------------------------------------
sub count
{
# SBT 02.11.08 - Update for performance
 my $self = shift;
 my $count = scalar @{$self->{SEARCHPATH}};
}

#----------------------------------------------------------------
sub push
{
 my $self = shift;
 #-- since we use push all the time to load objects, don't have it autoload again.
 #   prevents recursion.
 #$self->Load;
 if ( @_ )
 {
  my ( @newdirs ) = @_;
  $self->_addPaths( @newdirs );
 }
}

#----------------------------------------------------------------
sub pop
{

 #-- pop is trickier, since we have to recreate the hash
 my $self  = shift;
 my @paths = $self->_getPaths;
 my $dir   = pop @paths;

 #-- recreate the hash
 $self->_newPaths( @paths );
 return $dir;
} #-- End: sub pop

#----------------------------------------------------------------
sub mkdirs
{
 my $self = shift;
 my $dir  = Openmake::Path->new;

 foreach my $temp ( $self->getList )
 {
  $dir->set( $temp );
  $dir->mkdir;
 }
} #-- End: sub mkdirs

#----------------------------------------------------------------
sub unshift
{
 my $self = shift;
 if ( @_ )
 {
  my ( @newdirs ) = @_;
  my @oldpaths = $self->_getPaths;
  foreach ( @newdirs )
  {
   $_ = File::Spec->canonpath( $_ );
  }
  my @fullpaths = ( @newdirs, @oldpaths );
  $self->_newPaths( @fullpaths );
 } #-- End: if ( @_ )
 return $self;
} #-- End: sub unshift

#----------------------------------------------------------------
sub shift
{
 my $self = shift;
 my @paths = $self->_getPaths;
 my $dir   = shift @paths;

 $self->_newPaths( @paths );
 return $dir;
}

#----------------------------------------------------------------
sub in
{
 my $self = CORE::shift;
 my $path = CORE::shift;

 ( my $path_fs = $path ) =~ s/\\/\//g ;
 ( my $path_bs = $path ) =~ s/\//\\/g ;

 return 1 if ( grep {m{$path_fs}} @{$self->{'SEARCHPATH'}} );
 return 1 if ( grep {m{\Q$path_bs\E}} @{$self->{'SEARCHPATH'}} );

 ##return 1 if ( defined $self->{SEARCHPATH}->{$path_fs} );
 ##/return 1 if ( defined $self->{SEARCHPATH}->{$path_bs} );

 return 0;
}

#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked
#
#----------------------------------------------------------------
#-- stand-ins for symbol table magic
#
sub getQuotedList
{
 my $self = CORE::shift; return $self->getQuoted( @_);
}
sub getQuotedEscapedList
{
 my $self = CORE::shift; return $self->getEscapedQuotedList( @_);
}
sub getJavacEscapedList
{
 my $self = CORE::shift; return $self->getJEscapedList( @_);
}
sub getJavacEscapedQuotedList
{
 my $self = CORE::shift; return $self->getJEscapedQuotedList( @_);
}

#1;
#__END__

#----------------------------------------------------------------
sub newFromScalar
{
 my $proto = CORE::shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 $self->{SEARCHPATH} = {};

 # instantiate the object
 bless( $self, $class );

 # define attributes:
 if ( @_ )
 {
  my $temp = CORE::shift;
  my @paths = CleanSearchPath( split( /$PathDL|\|/, $temp ) );
  $self->_newPaths( @paths );
 }

 # return the reference
 return $self;
} #-- End: sub newFromScalar

#----------------------------------------------------------------
sub getQuoted
{
 my $self = CORE::shift;
 my ( $path, @quotedList );
 my @paths = $self->_getPaths;
 foreach $path ( @paths )
 {
  #$path =~ s|^\"||g; #"
  #$path =~ s|\"$||g; #"
  CORE::push( @quotedList, "\"$path\"" );
 }
 return wantarray ? @quotedList : join( $PathDL, @quotedList );
} #-- End: sub getQuoted

#----------------------------------------------------------------
sub getEscapedList
{
 my $self = CORE::shift;
 my ( @ePaths, $ePath );
 my @searchpath = $self->_getPaths;

 foreach $ePath ( @searchpath )
 {
  $ePath =~ s|(\W)|\\$1|g;
  CORE::push( @ePaths, $ePath );
 }

 return @ePaths;
} #-- End: sub getEscapedList

#----------------------------------------------------------------
sub getEscapedQuotedList
{
 my $self = CORE::shift;
 my ( $path, @eqList );
 my @searchpath = $self->_getPaths;

 foreach $path ( @searchpath )
 {
  $path =~ s|(\W)|\\$1|g;
  CORE::push( @eqList, "\"$path\"" );
 }

 return @eqList;
} #-- End: sub getEscapedQuotedList

#----------------------------------------------------------------
sub getJEscapedList
{
 my $self = CORE::shift;
 my ( @ePaths, $ePath );
 my @searchpath = $self->_getPaths;

 foreach $ePath ( @searchpath )
 {
  $ePath =~ s|\\|\\\\|g;
  CORE::push( @ePaths, $ePath );
 }

 return @ePaths;
} #-- End: sub getJEscapedList

#----------------------------------------------------------------
sub getJEscapedQuotedList
{
 my $self = CORE::shift;
 my ( $path, @eqList );
 my @searchpath = @{ $self->{SEARCHPATH} };

 foreach $path ( @searchpath )
 {
  $path =~ s|\\|\\\\|g;
  CORE::push( @eqList, "\"$path\"" );
 }

 return @eqList;
} #-- End: sub getJEscapedQuotedList



####################
# Diagnostic object methods
####################

#----------------------------------------------------------------
sub dump
{
 my $self = CORE::shift;

 print "SearchPath: \n" . $self->get() . "\n\n";
 my ( @eList ) = $self->getEscapedList();
 print "escapedList: \n@eList\n\n";
 @eList = $self->getQuotedList();
 print "quotedList: \n@eList\n\n";
 @eList = $self->getEscapedQuotedList();
 print "escapedQuotedList: \n@eList\n";
} #-- End: sub dump

# The very important positive return result
1;
__END__

#----------------------------------------------------------------
=head1 NAME

Openmake::SearchPath

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

Package to manage an Openmake Search Path independent of operating system.

It provides functions to return the Search Path in different formats.

=head1 FUNCTIONS

=head2 CleanSearchPath(@list_of_directories)

Returns a list of directories that have been cleaned by
removing unnecessary characters such a \\, // or ./

=head1 METHODS

=head2 new(@list_of_directories), new($string_of_directories)

This method creates a new object based upon the list of directories
or string of directories seperated by the operating system delimiter.

=head2 newFromScalar($string_of_directories)

This method creates a new object based a string of directories
seperated by the operating system delimiter.

=head2 set(), set(@list_of_directories)

This updates the object with the list of directories passed.  If set
is called with no parameters then it will reset the object to be
empty.

=head2 setFromScalar(), setFromScalar($string_of_directories)

This updates the object with the string of directories seperated
by the operating system delimiter.

If set is called with no parameters then it will reset the object
to be empty.

=head2 get()

Returns a string of Search Path directories, seperated by the operating
system delimiter.

=head2 getList()

Returns an array of Search Path directories.

=head2 getString($PreText,$PostText)

Returns an string of Search Path directories with the PreText before each
directory and PostText after each directory.

=head2 count()

Returns the number directories in the SearchPath object.

=head2 getQuoted()

Returns a string of the directories with each directory quoted and
seperated by the operating system delimiter.

=head2 getQuotedList()

Returns an array of the directories with each directory quoted.

=head2 getEscapedList()

Returns an array of the directories with each directory that has the
Perl special characters escaped.

=head2 getEscapedQuotedList(), getQuotedEscapedList()

Returns an array of the directories with each directory quoted and has the
Perl special characters escaped

=head2 getJEscapedList(), getJavaEscapedList()

Returns an array of the directories with each directory \ and / escaped.

=head2 getJEscapedQuotedList(), getJavacEscapedQuotedList()

Returns an array of the directories with each directory quoted and \
and / escaped.

=head2 push($dir)

Adds a directory to the end of the SearchPath.

=head2 pop()

Removes and returns the first directory from the SearchPath.

=head2 mkdirs()

Creates the subdirectories for each directory listed in the SearchPath.

=head2 unshift($dir)

Prepends the $dir to the beginning of the SearchPath.

=head2 shift()

Removes and returns the last directory in the SearchPath.

=cut

