# $Header: /CVS/openmake64/shared/omtfsver.pl,v 1.2 2007/11/28 15:41:07 jim Exp $
#
# Openmake Microsoft TFS version command utility
#

=head1 omtfsver.pl

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omcvsver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script while the om.exe
executable is running, and has access to certain Openmake-specific
information.

This command will do a Team Foundation "tf properties" files in the Openmake
Search Path to determine if these files are under Team Foundation Version Control.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file or the
rules file.

There must be a space between the switch and its argument

-h                      : print header.

-f <fullpath>/filename  : name of file to check.

=cut


#=====================================
#Main


#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN = "                                                                     ";
our @VERSIONTOOL_RETURN;
our $RC                 = 0;
our $File;
our $Debug = 0;

#-- tell om that we support passing in an array of files.
#   Comment this out if you want to run CVS file by file
our $Supports_Multifile = 1;
our $Format_String = "%-160.160s  %-20.20s  %-20.20s  %-20.20s";
my @output = ();

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls svn

if ( $ARGV[0] eq '-h' )
{
 #-- return the default pre 6.2 header.
 $VERSIONTOOL_RETURN = sprintf( $Format_String, 'Server Path', 'Change Set', 'Change', 'Server Change Set' );
}
else
{
 my @full_files = @_;
 my $verpgm = "tf";
 my %return_hash = ();

 $verpgm = FirstFoundInPath( $verpgm );
 unless ( $verpgm)
 {
  $verpm = 'tf.cmd';
 }
 unless ( $verpgm )
 {
  $RC                 = 0;
  goto EndOfScript;
 }

 my %full_out = ();

 my $max_length = 512;
 my %lists = parse_input_list( \@full_files );

 foreach my $dir ( keys %lists )
 {
  my $cmd = $verpgm . qq{ properties "$dir" /recursive /noprompt};
  my @files = @{$lists{$dir}};
  my @cout = `$cmd`;

  my %out = parse_vlog( \@files, \@cout);
  foreach my $d_file ( @files)
  {
   my $path .= $dir . "/$d_file";
   $path =~ s{\\}{/}g;
   if ( $^O =~ m{MSWin|DOS}i )
   {
    $path = uc $path;
   }
   my $o = $out{$path};
   $full_out{$path} = $o;
   #push @VERSIONTOOL_RETURN, $out{$path};
   #$i++;
  }
 }

 #-- now push it in the correct order
 foreach my $path ( @full_files )
 {
  $path =~ s{\\}{/}g;
  if ( $^O =~ m{MSWin|DOS}i )
  {
   $path = uc $path;
  }
  push @VERSIONTOOL_RETURN, $full_out{$path};
 }
}


EndOfScript:
$RC;

#foreach my $o ( @VERSIONTOOL_RETURN ) { print $o, "\n"; }

#------------------------------------------------------------------
sub parse_input_list
{
 #-- subroutine to parse the input list of files to find a set of common
 #   directories to wildcard patterns. This is because CVS doesn't like
 #   absolute paths!
 #
 #   Don't do anything fancy. Just look at the directory alone
 my $ref = shift;
 my %paths;
 foreach my $file_path ( @{$ref} )
 {
  my $dir  = Openmake::File->new($file_path)->getDP();
  my $file = Openmake::File->new($file_path)->getFE();

  push @{$paths{$dir}}, $file;
 }
 return %paths;
}

#------------------------------------------------------------------
sub parse_vlog
{
 my ($fref, $oref ) = @_;
 my @lines = @{$oref};
 my $line;
 my @out;

#Local information:
#  Local path:  C:\Work\Catalyst\Demo\TFS\AdventureWorks\adventureworks\adventure
#  Server path: $/Adventureworks/adventureworks/adventureworks/images/Trans1x1.gi
#  Changeset:   530
#  Change:      none
#  Type:        file
#Server information:
#  Server path:   $/Adventureworks/adventureworks/adventureworks/images/Trans1x1.
#  Changeset:     530
#  Deletion ID:   0
#  Lock:          none
#  Lock owner:
#  Last modified: 31-Jul-2007 10:31:32 AM
#  Type:          file
#  File type:     binary
#  Size:          42

 my %ver_hash;
 my $path;
 my $server_path = '';
 my $change_set = 0;
 my $server_change_set = 0;
 my $seen_server_info = 0;
 my $change = '';
 while ( $line = shift @lines )
 {
  chomp $line;
  if ( $line =~ s{^\s*Local path\s*?:\s+}{}i )
  {
   $path = $line;
   $path =~ s{\\}{/}g;
   $server_path = '';
   $change = '';
   $change_set = 0;
   $server_change_set = 0;
   $seen_server_info = 0;
   next;
  }
  next unless $path;

  if ( $line =~ m{^\s*Server information} )
  {
   $seen_server_info++;
   next;
  }
  if ( $line =~ s{^\s*Change\s*?:\s*}{})
  {
   $change = $line;
   next;
  }

  if ( $line =~ s{^\s*Server path\s*?:\s*}{}i )
  {
   $server_path = $line;
   next;
  }

  if ( $line =~ s{^\s*Changeset\s*?:\s*}{}i )
  {
   if ( ! $seen_server_info )
   {
    $change_set = $line;
   }
   else
   {
    $server_change_set = $line;
    #-- this is the last thing we need, write it out
    if ( $^O =~ m{MSWin|DOS}i )
    {
     $path = uc $path;
    }
    $ver_hash{$path} = sprintf( $Format_String, $server_path, $change_set, $change, $server_change_set);
   }
  }

 }


 return %ver_hash;
}

