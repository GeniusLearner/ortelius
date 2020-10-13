use POSIX;
use Getopt::Long;
use Pod::Usage;
use Digest::MD5; #-- should be available via Openmake install
use File::Copy;
use File::Path;

my $Help = 0;
my $Version = 641;
my @Exes = ();
my $To_Path;
my $Meister_To_Path = 'X:/installers/DIRECT/70\\';
my $Meister_Path = 'G:\catalyst\om_build\700\winxp-lionel\java\build\RELEASE\java\\';
my $From_Path;
my $Build_Path;
my $Build_Number;
my @Eclipse_Platforms = ( 'aix.motif.ppc', 'hpux.motif.ia64_32', 'hpux.motif.PA_RISC', 'linux.gtk.ia64', 'linux.gtk.ppc', 'linux.gtk.x86', 'linux.gtk.x86_64', 'linux.motif.x86', 'solaris.gtk.sparc', 'solaris.motif.sparc', 'win32.win32.x86', 'macosx.carbon.ppc');
my %machine_map = ( 'tonka'     => 'aix51',
                    'skateboard' => 'aix52',
                    'tinker'    => 'hp1100',
                    'buzz'      => 'sun8',
                    'redhat71'  => 'rh71',
                    'redhat73'  => 'rh73',
                    'potatohead'  => 'rh71',
                    'slinky'    => 'rh73',
                    'rh-es4'    => 'rh73',
                    'rocket'    => 'rh73',
                    'w2k-build' => 'w2000',
                    'lionel' => 'winxp'
                    );
my     %mak_map = ( 'tonka'     => 'aix.mak',
                    'skateboard' => 'aix.mak',
                    'tinker'    => 'hp-ux.mak',
                    'buzz'      => 'solaris.mak',
                    'redhat71'  => 'linux.mak',
                    'redhat73'  => 'linux.mak',
                    'potatohead'  => 'linux.mak',
                    'slinky'  => 'linux.mak',
                    'rh-es4'  => 'linux.mak',
                    'rocket'  => 'linux.mak',
                    'w2k-build' => 'windows.mak',
                    'lionel' => 'windows.mak'
                    );

GetOptions(
 'help|h'      => \$Help,
 'exe|e=s'     => \@Exes,
 'version|v=i' => \$Version,
 'to|t=s'      => \$To_Path,
 'from|f=s'    => \$From_Path,
 'path|p=s'    => \$Build_Path,
 'number|n=i'  => \$Build_Number
) or pod2usage( -verbose => 1) && exit;

pod2usage( -verbose => 1 ) if ( $Help );

#-- setup defaults
#   1. Set Version
$Version = 641 unless $Version;
$Build_Path = $Version unless $Build_Path;
if ( $^O =~ m{MSwin|dos}i )
{
 $To_Path = 'X:\catalyst\om_build\\' . $Build_Path unless $To_Path;

 #-- copy meister/mojo
 if ( $Build_Number )
 {
  foreach $platform (@Eclipse_Platforms)
  {
   copy ( $Meister_Path . $platform . '/mojo.zip', $Meister_To_Path . $platform . '/mojo-7.4-' . $platform . '-build' . $Build_Number . '.zip');
   copy ( $Meister_Path . $platform . '/meister.zip', $Meister_To_Path . $platform . '/meister-7.4-' . $platform . '-build' . $Build_Number . '.zip');
  }
 }
}
else
{
 $To_Path = '/shared/catalyst/om_build/' . $Build_Path unless $To_Path;
}

#   2. get machine
my $machine;
if ( $^O =~ m{MSWin|DOS}i)
{
 $machine = lc $ENV{'COMPUTERNAME'};
}
else
{
 $machine = `hostname`;
 $machine = lc $machine;
}
chomp $machine;

$machine =~ s{(\w+?)\.(.+)}{$1};

my $os = $machine_map{$machine};
die "Cannot determine machine!" unless $os;
my $Machine_Path = $os . '-' . $machine;

$From_Path = '.' unless ( $From_Path);

#-- get exes
@Exes = _getExes( $mak_map{$machine}) unless ( @Exes );

#-- Determine which are new exes via MD5?
foreach my $file ( @Exes )
{
 #-- convert to canonical form
 my @files = _getFiles( $file, $Machine_Path);

 foreach my $f ( @files )
 {
  #-- see if this is different than the one in tofile
  my $to_md5 = Digest::MD5->new();
  my $from_md5 = Digest::MD5->new();
  my ($to_md5_hex, $from_md5_hex);

  my $t = $f; #-- to file retains linux71
  $f =~ s{linux71}{linux}g; #-- from doesn't

  my $To_File = $To_Path . '/' . $t ;
  $To_File =~ s{\\}{/}g;
  my $From_File = $From_Path . '/' . $f;
  $From_File =~ s{\\}{/}g;

  print "$From_File -> $To_File\n";

  if ( -e $To_File )
  {
   open ( TO, '<', $To_File ) || die "Cannot open '$To_File': $!";
   binmode( TO );
   $to_md5_hex = $to_md5->addfile(*TO)->hexdigest();
   close TO;
  }

  if ( -e $From_File)
  {
   open ( FROM, '<', $From_File) || die "Cannot open '$From_File': $!";
   binmode( FROM );
   $from_md5_hex = $from_md5->addfile(*FROM)->hexdigest();
   close FROM;

   if ( $to_md5_hex ne $from_md5_hex )
   {
    print "Copying '$From_File' -> '$To_File'\n";
    #-- mkdirs
    $To_File =~ s{\\}{/}g;
    my @p = split /\//, $To_File;
    pop @p;
    my $m_path = join '/', @p;
    mkpath( [$m_path], 0, 0711);
    #-- copy
    copy ( $From_File, $To_File);
   }
  }
 }
}

#------------------------------------------------------------------
sub _getFiles
{
 my $file    = shift;
 my $machine = shift;
 my @files   = ();

 #-- map of os -> type
 my %os_map = (
                'aix51'  => 'aix',
                'aix52'  => 'aix',
                'hp1100' => 'hp',
                'sun8'   => 'sun',
                'rh71'   => 'linux71',
                'rh73'   => 'linux',
                'w2000'  => 'win32',
                'winxp'  => 'win32'
              );

 my ( $os, @rest ) = split /-/, $machine;
 my $machine_name = join '-', @rest;

 if ( $os eq 'w2000' )
 {
  #-- add .exe or .dll by grepping windows.mak
  open ( MAK, '<', 'windows.mak');
  my $in_all ;
  while ( <MAK> )
  {
   if ( m{\s*all :})
   {
    $in_all = 1;
   }
   if ( $in_all and m{$file(\.exe|\.dll)})
   {
    $file .= $1;
    last;
   }
  }
  close MAK;
 }

 foreach ( 'DEBUG', 'RELEASE' )
 {
  push @files, $_ . '/' . $os_map{$os} . '/' . $file if ($file !~ /VERSION/);
 }
 return @files;
}

#------------------------------------------------------------------
sub _getExes
{
 my $mak = shift;
 my @exes;
 open ( MAK, '<', $mak) || return;

 my $in_all ;
 while ( <MAK> )
 {
  chomp;
  if ( s{^\s*all :\s*}{}g )
  {
   $in_all = 1;
  }
  if ( $in_all )
  {
   if ( m{^--Start:})
   {
    last;
   }
   unless ( m{(REL|DEB)OPTIONS})
   {
    s{^\s+}{};
    s{\s*\\s*$}{};
    next unless ( $_ );
    my @p = split /\//;
    my $f = pop @p;
    push @exes, $f
   }
  }
 }
 close MAK;
 return @exes;
}

__END__

=pod

=head1 NAME

om_copy_exes.pl ? Copy build output to staging directory

=head1 VERSION

This document describes om_copy_exes.pl version 0.0.1

=head1 SYNOPSIS

     > om_copy_exes.pl [options]

     > om_copy_exes.pl -t '/shared/catalyst/om_build/641' -f '.' -e om

=head1 OPTIONS

=over 4

=item help|h

Print help

=item exe|e

list of executable files to copy. Defaults to parsing "<os>.mak"
for the 'all' key

=item version|v

Version number. Defaults to '641'

=item to|t

To Path. Defaults to '/shared/catalyst/om_build/' . $Version;

=item from|f

From Path. Defaults to '.'

=head1 CONFIGURATION AND ENVIRONMENT

om_copy_exes.pl requires no configuration files or environment variables.

=head1 DEPENDENCIES

=over 4

=item C<POSIX>

=item C<Getopt::Long>

=item C<Pos::Usage>

=item C<Digest::MD5>

=item C<File::Copy>

=item C<File::Path>

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jim Graham

=head1 LICENCE AND COPYRIGHT

Copyright(c) 2006, Catalyst Systems Corp

This module is unpublished proprietary software; you cannot redistribute it
outside of Catalyst Systems Corp.

=cut
