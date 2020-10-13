#===============================================================
#
# Openmake::SnapShot.pm
#
# $Header: /CVS/openmake64/perl/lib/DEBUG/Openmake/Snapshot.pm,v 1.2 2005/06/02 16:39:44 jim Exp $
#
#==========================================================================
package Openmake::Snapshot;

BEGIN
{
 use Exporter ();
 use AutoLoader;
 use File::Find;
 use File::Spec;
 use Cwd;

 use vars qw(@ISA @EXPORT $VERSION);

 @ISA    = qw(Exporter AutoLoader);
 @EXPORT = qw( &LeftSnapshotOnly );

 my $HEADER = '$Header: /CVS/openmake64/perl/lib/DEBUG/Openmake/Snapshot.pm,v 1.2 2005/06/02 16:39:44 jim Exp $'; 
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }

}

if ( $^O =~ /os2|win|dos/i )
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
=head1 NAME

Openmake::Snapshot

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

This package will allow you to compare a directories contents before
and after a command has been issued.  The comparing of the snapshots
will make it possible to determine which files have been updated by 
a compiler.

=head1 FUNCTIONS

=head2 LeftSnapshotOnly($after_snapshot, $before_snapshot)

Returns a list of the files that have been changed between the time
the snapshots where taken.

=head1 METHODS

=head2 new(), new($directory, $file_extension)

The new method will create a snapshot of all the files in the
current directory.

The new($directory, $file_extension) method will create a snapshot
of only the $file_extension in the $directory.

=head2 get()

Returns an array of the files in the snapshot.

=head2 AutoLoading

Because not few BuildTypes use the Openmake::SnapShot module, all methods
in this module are AutoLoaded (compiled when invoked, not at run-time).

=cut

sub wanted
{
 #-- JAG 05.01.03 -- store more of 'stat' info
 my $file      = $File::Find::name;
 my @temp      = stat( $_ );
 my $tstamp    = $temp[9];
 my $size      = $temp[7];
 my $extfilter = $Openmake::Snapshot::new::extfilter;
 $file =~ s/^\.\///;

 if ( -f $_ and $_ ne '.' and $_ ne '..' )
 {

  #-- JAG 05.01.03 - $t is a reference to an anon array
  #   with timestamp and size info.
  my $t = [ $tstamp, $size ];

  if ( $extfilter ne '' )
  {

   #   push( @files, $file) if /$extfilter$/;
   if ( /$extfilter$/ )
   {
    $files{$file} = $t;
   }

  } #-- End: if ( $extfilter ne '' ...
  else
  {

   #   push (@files, $file);
   $files{$file} = $t;
  }
 } #-- End: if ( -f $_ and $_ ne '.'...
} #-- End: sub wanted

#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked
#----------------------------------------------------------------
#-- removed for DEBUG Version
#1;
#__END__


##########################
# Class functions
##########################

#----------------------------------------------------------------
sub LeftSnapshotOnly
{
 my $snap1 = shift;
 my $snap2 = shift;
 my ( @lo, $found, $f1, $f2, @aftersnap, @beforesnap );

 #replace the following with a search over the hash
 # foreach $f1 ( sort $snap1->get ) {
 #  $found =0;
 #  foreach $f2 ( sort $snap2->get ) {
 #  $found = 1, last if $f1 eq $f2;
 #  }
 #  push( @lo, $f1 )  unless $found;
 # }
 @aftersnap  = $snap1->get;
 @beforesnap = $snap2->get;
 foreach $f1 ( @aftersnap )
 {
  if ( $snap2->fileExists( $f1 ) )
  {

   #-- test if the timestamp changes
   if (
    $snap1->getFileTStamp( $f1 ) != $snap2->getFileTStamp( $f1 )
    ||
    $snap1->getFileSize( $f1 ) != $snap2->getFileSize( $f1 ) )
   {
    push @lo, $f1;
   }
  } #-- End: if ( $snap2->fileExists...
  else
  {
   push @lo, $f1;
  }
 } #-- End: foreach $f1 ( @aftersnap )
 return @lo;
} #-- End: sub LeftSnapshotOnly

# file constructor
#----------------------------------------------------------------
sub new
{
 my $proto = shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 #-- JAG 07.07.04 - Case 4799 for consistency with the previous
 #   "wanted" function this should be '.'
 # $dir = cwd() if $dir eq '';
 my $dir = shift || '.';

 #-- JAG 07.07.04 - case 4799
 $Openmake::Snapshot::new::extfilter = '';
 $Openmake::Snapshot::new::extfilter = shift;
 $Openmake::Snapshot::new::extfilter =~ s/(\W)/\\$1/g;

 my $infile = shift;

 if ( $infile )
 {
  open( FILE, "$infile" );
  my $anchor = <FILE>;
  chomp $anchor;
  $self->{ANCHOR} = $anchor;
  while ( <FILE> )
  {
   chomp;
   my ( $f, @ts ) = split /\t/;
   $self->{FILES}->{$f} = \@ts;
  }
  close FILE;

  # instantiate and return the reference
  bless( $self, $class );
  return $self;
 } #-- End: if ( $infile )

 #-- JAG - change @files to %files to store modification time
 # @files = ();
 %files = ();

 # define attributes:
 $self->{ANCHOR} = File::Spec->canonpath( $dir );

 # JAG - changed to make this a pointer to a hash, not an array
 #$self->{FILES} = [];
 $self->{FILES} = {};

 #-- JAG 07.07.04 - case 4799
 #find( \&wanted , '.' );
 find( \&wanted, $dir );

 #@{$self->{FILES}} = @files;
 %{ $self->{FILES} } = %files;
 #%temp = %{ $self->{FILES} };

 undef %files;

 # instantiate and return the reference
 bless( $self, $class );
 return $self;
} #-- End: sub new

#----------------------------------------------------------------
sub get
{
 my $self = shift;

 # return @{$self->{FILES}};
 #-- JAG - 05.01.03 fixed bug here
 # return %{$self->{FILES}};
 return keys %{ $self->{FILES} };
}

#----------------------------------------------------------------
sub getFileTStamp
{
 my $self = shift;
 my $file = shift;
 return $self->{FILES}->{$file}->[0];
}

#----------------------------------------------------------------
sub getFileSize
{
 my $self = shift;
 my $file = shift;
 return $self->{FILES}->{$file}->[1];
}

#----------------------------------------------------------------
sub fileExists
{
 my $self = shift;
 my $file = shift;
 return 1 if ( $self->{FILES}->{$file} );
 return 0;
}

#----------------------------------------------------------------
sub exportSnapShot
{
 my $self = shift;
 my $file = shift;
 open( FILE, ">$file" ) || return 0;
 print FILE $self->{ANCHOR} . "\n";
 my @files = $self->get;
 foreach my $file ( @files )
 {
  print FILE $file . "\t" . $self->getFileTStamp( $file ) . "\t" . $self->getFileSize( $file ) . "\n";
 }
 close FILE;
 return 1;
} #-- End: sub exportSnapShot

#1;
#__END__

1;
__END__
