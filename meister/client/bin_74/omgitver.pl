# omsvnver.pl Version 1.0
#
# Openmake Subversion version command utility
#
# Catalyst Systems Corporation          Dec 30, 2005
#
#-- Perl wrapper to Subversion commands that plugs into
#   Openmake build tool

=head1 omsvnver.pl

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omsvnver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script while the om.exe
executable is running, and has access to certain Openmake-specific
information.

This command will do a SVN 'log' on files in the Openmake
Search Path to determine if these files are under SVN Version Control.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file or the
rules file.

There must be a space between the switch and its argument


-h                      : print header.

-f <fullpath>/filename  : name of file to check.

=cut


#=====================================
#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN = "                                                                     ";
our @VERSIONTOOL_RETURN;
our $RC = 0;
our $File;
our $Debug = 0;
our $Format_String = "%-10.10s;  %-10.10s;";
our $Max_Cmd_Length = 512; #-- max length of the command line to run

#-- tell om that we support passing in an array of files.
our $Supports_Multifile = 1;

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls svn

if ( $ARGV[0] eq '-h' )
{
 $VERSIONTOOL_RETURN = sprintf( $Format_String, "Commit   Last Change User");
}
else
{
 my @full_files = @ARGV; # @_;
 my $verpgm = "git";
 my %return_hash = ();

 $verpgm = FirstFoundInPath( $verpgm );
 unless ( $verpgm )
 {
  $RC                 = 0;
  goto EndOfScript;
 }
 
foreach my $file ( @full_files )
 {
  my $cmd = $verpgm . ' log --format="%h:%cn" -1 ' . $file;
  my @cout = `$cmd`;
  my $line = shift @cout;
  $line =~ s/\n//g;
  print $file . ":" . $line . "\n";
  push @VERSIONTOOL_RETURN, $file . ":" . $line;
 }
}

EndOfScript:
$RC;

