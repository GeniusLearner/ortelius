#==========================================================================
package Openmake::FileList;

BEGIN
{
 use Openmake::SearchPath;
 use AutoLoader;
 use File::Spec;
 use Openmake::File;
 use Openmake::Load;
 use Exporter ();
 use vars qw(@ISA @EXPORT $VERSION);

 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/FileList.pm,v 1.7 2008/04/09 21:52:47 jim Exp $'; 
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }
 #-- note: since we inherit Openmake::SearchPath, the non-autoload methods in 
 #   O::SearchPath also have to be non-autoload here (new, set, get)
 @ISA     = qw(Exporter Openmake::Load Openmake::SearchPath AutoLoader);
 @EXPORT  = qw($PathDL $eDL $DL );
} #-- End: BEGIN

#----------------------------------------------------------------
=head1 NAME

Openmake::FileList

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

Common file list functions to handle list of files independent of
operating system.  

Openmake::FileList uses Openmake::SearchPath, which in turn uses
Openmake::Path.

=head1 AutoLoading

All methods in this module except for the "new" method are AutoLoaded 
(compiled when invoked, not at run-time).

=head1 METHODS

=head2 Inherited Methods

The following useful methods are inherited from Openmake::SearchPath:
new, get, getList, getQuotedList, set, getString, getQuoted, getEscaped,
getQuotedEscaped, getQuotedEscapedList, getJavacEscaped, getJavacEscapedList,
count, push, pop, shift, unshift

See L<Openmake::SearchPath>

=head2 new, new( @list_of_files )

The constructor creates an object containing a list of files.  
It is currently inherited directly from Openmake::SearchPath.

=begin text

  use Openmake::FileList;
  $fl = Openmake::FileList->new( qw( file.c file.o /usr/include/stdio.h ));

=end text

=head2 getExtension()

Returns a list of extensions found in the list of files.

=head2 getExt( @ExtensionList )

Returns a list of files whose extensions match the list of patterns
supplied as an argument.

The return value can be a scalar or an array.  

For example,

C<< $str = $flist->getExt( qw( .c .o ) ) >>

The return value will look like
C<< file.c;file.o >> on Windows type systems and 
C<< file.c:file.o >> on UNIX type systems.

=head2 getExtList( @ExtensionList)

Returns a list of files whose extensions match the list of patterns supplied as an argument.

The return value will be an array.

C<< @files = $flist->getExtList( qw( .c .o ) ) >>

=head2 getExtQuoted( @ExtensionList )

Like getExtList, except the individual elements are double quoted in the array.

The return value will be a scalar:

C<< "file.c";"file.o" >> on Windows.
C<< "file.c":"file.o" >> on UNIX systems.

=head2 getExtQuotedList

Like getExtList, except the individual elements are double quoted.

The return value will be an array:

C<< ('"file.c"','"file.o"') >> on Windows and UNIX type systems.

=head2 getAbsolute, getAbsolute($anchor_dir)

Returns a scalar string containing the absolute path 
of each individual file separated by the operating system's path delimiter.
Files that exist as relative are made absolute according to an 'anchor'.
For example,

=begin text

  use Openmake::FileList;
  $fl = Openmake::FileList->new(qw( file.c file.o /usr/include/stdio.h );
  print $fl->getAbsolute( '/home/sean/work');

=end text

executed on a UNIX machine, prints out

C<< /home/sean/work:/home/sean/file.o:/usr/include/stdio.h >>

=head2 getAbsoluteList, getAbsoluteList($anchor_dir)

Like C<< getAbsolute >>, however, this returns an array of the absolute 
paths+filenames of each individual file.

=head2 getQuotedAbsolute, getQuotedAbsolute( $anchor_dir )

Like getQuotedAbsolute but the individual items are double-quoted.

=cut

#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked
#
#           Symbol table magic. Don't know if this works
#1;
#__END__
#----------------------------------------------------------------
#-- stand-ins for symbol table magic
#
#sub getAbsoluteList { my $self = shift; my @t = $self->getAbsolute(@_); return @t; }

#----------------------------------------------------------------
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

#----------------------------------------------------------------
sub getExt
{
 #-- JAG - 08.25.03 - case 3533 - slowness of getExt* is caused by creating
 #                    Openmake::File objects just to get the extension.
 my $self    = shift;
 my @extList = @_;
 my $file;
 my $outFileList = Openmake::FileList->new;

 foreach $file ( $self->getList )
 {

  #my $oFile = Openmake::File->new($file);
  #my $ext = '\\' . $oFile->getE;
  #$ext = "\.NOEXT" if ($oFile->getE eq "");
  my $ext = "\\.NOEXT";
  if ( $file =~ /(\.[^\.\\\/]*)\s*$/ )
  {
   $ext = "\\" . $1;
  }

  #$outFileList->push($oFile->get)  if( grep(/^$ext$/i,@extList) );
  $outFileList->push( $file ) if ( grep( /^$ext$/i, @extList ) );
 } #-- End: foreach $file ( $self->getList...

 return wantarray ? $outFileList->getList : $outFileList->get
}    #-- End: sub getExt

#----------------------------------------------------------------
sub getExtList
{
 my $self = shift;
 return $self->getExtCommon( 'List', @_ );
}
#----------------------------------------------------------------
sub getExtQuoted
{
 my $self = shift;
 return $self->getExtCommon( 'Quoted', @_ );
}
#----------------------------------------------------------------
sub getExtQuotedList
{
 my $self = shift;
 return $self->getExtCommon( 'QuotedList', @_ );
}
# Private function called by the getExt family.  This
# was intended to be a nice way to use a common function,
# but really it is more confusing.

#----------------------------------------------------------------
sub getExtCommon
{
 my ( $self, $which, @extList ) = @_;
 my $file;
 my $outFileList = Openmake::FileList->new;

 foreach $file ( $self->getList )
 {
  #my $oFile = Openmake::File->new($file);
  #my $ext = '\\' . $oFile->getE;
  #$ext = "\.NOEXT" if ($oFile->getE eq "");
  my $ext = "\\.NOEXT";
  if ( $file =~ /(\.[^\.\\\/]*)\s*$/ )
  {
   $ext = "\\" . $1;
  }

  #$outFileList->push($oFile->get)  if( grep(/^$ext$/i,@extList) );
  $outFileList->push( $file ) if ( grep( /^$ext$/i, @extList ) );
 } #-- End: foreach $file ( $self->getList...

 return $outFileList->getQuotedList if $which =~ /quotedList/;
 return $outFileList->getQuoted     if $which =~ /Quoted/;
 return $outFileList->getList       if $which =~ /List/;
 return $outFileList->getList;
}    #-- End: sub getExtCommon

#----------------------------------------------------------------
sub getAbsolute
{
 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 my $anchor = shift if @_;
 my $file;
 my $outFileList = Openmake::FileList->new;
 my $oFile       = Openmake::File->new;

 foreach $file ( $self->getList )
 {
  $oFile->set( $file );
  $oFile->setAnchor( $anchor ) if $anchor;
  $outFileList->push( $oFile->getAbsolute );
 }
 return wantarray ? $outFileList->getList : $outFileList->get;
} #-- End: sub getAbsolute

#----------------------------------------------------------------
sub getAbsoluteList
{
 my $self = shift;
 my @array = $self->getAbsolute(@_);
 return @array;
}

#----------------------------------------------------------------
sub getQuotedAbsolute
{
 # Won't switch drives. Acts like default
 # behavior of dos 'cd'
 my $self = shift;
 my $anchor = shift if @_;
 my $file;
 my $outFileList = Openmake::FileList->new;
 my $oFile       = Openmake::File->new;
 1;
 foreach $file ( $self->getList )
 {
  $oFile->set( $file );
  $oFile->setAnchor( $anchor ) if $anchor;
  $outFileList->push( $oFile->getAbsolute );
 }
 return $outFileList->getQuoted;
} #-- End: sub getQuotedAbsolute

1;
__END__

