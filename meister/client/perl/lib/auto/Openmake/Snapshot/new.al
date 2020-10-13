# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::Snapshot;

#line 184 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/Snapshot.pm (autosplit into perl\lib\auto\Openmake\Snapshot\new.al)"
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

# end of Openmake::Snapshot::new
1;
