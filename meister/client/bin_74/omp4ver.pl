#!/usr/bin/perl
#
# omp4ver.pl Version 1.1
#
# Openmake Perforce get version information Utility
#
# Catalyst Systems Corporation 12/30/2005
#
#-- Perl wrapper to p4 that plugs into Openmake build tool
#   to provide version control information.
#

=pod

=head1 omp4ver.pl

=head1 LOCATION

<openmake clc install path>/bin

=head1 DESCRIPTION

omp4ver.pl is a perl script that "plugs-in" to om.exe
via the {-vp, -vc, -vr} command line flags. This script is used
to access version control information for items from Perforce.
It is a wrapper to the Perforce 'p4 filelog <file>' function.

The plugs into om.exe, and passes information back to om.exe via
the $VERSIONTOOL_RETURN variable.

=head1 ARGUMENTS

Since 'p4 filelog' takes few arguments, only two arguments are necessary
for omp4ver.pl, and both are added by om.exe.

=over 2

=item -h :

Prints header. Used by om.exe to determine the format of
the Bill of Materials log.

=item -f <filename>:

name of file to check. Used by om.exe.

=back

=head1 RETURN CODES

The script returns the following:

 0 : Success
 1 : File doesn't exist on file system
 2 : Could not change to directory in path part of the filename


=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. If the -h option is passed, print the header to the
    $VERSIONTOOL_RETURN variable and exit
 3. Construct the 'p4 filelog' command
 4. Execute the p4 command
 5. Set the $VERSIONTOOL_RETURN variable with the output
    from 'p4'
 6. Exit

=cut

#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN;
our @VERSIONTOOL_RETURN;
our $RC = 0;
our $File;
our $Debug = 0;
our $Format_String = "%-180.180s  %-18.18s  %-18.18s  %-18.18s";

#-- tell om that we support passing in an array of files.
our $Supports_Multifile = 1;

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls p4
#-- p4 filelog %s ,FullPath);

if ( $ARGV[0] eq '-h' )
{
 #-- return the default pre 6.2 header.
 $VERSIONTOOL_RETURN = sprintf( $Format_String, "Depot Path", "Version", "User", "Change");
}
else
{
 my @full_files = @_;
 my $verpgm = 'p4';
 my %return_hash = ();

 $verpgm = FirstFoundInPath( $verpgm );
 unless ( $verpgm )
 {
  $RC = 0;
  goto EndOfScript;
 }
 my %lists = parse_input_list( \@full_files );

 #-- for each directory for which we list files, execute the p4 command
 #   We do the general "*" command and parse the output for the files of interest
 foreach my $dir ( keys %lists )
 {
  my @cmds;
  chdir $dir;

  my $cmd = $verpgm . ' filelog "*" 2>&1 ';
  my @files = @{$lists{$dir}};
  my @cout = `$cmd`;

  my @out = parse_p4_log( \@files, \@cout);
  my $i = 0;

  #-- create a hash of files -> output so that we can put them back in the
  #   order that we received them.
  foreach my $d_file ( @files)
  {
   my $path .= $dir . "/$d_file";
   $path =~ s{\\}{/}g;
   my $o = $out[$i];
   $return_hash{$path} = $o;
   $i++;
  }
 }

 #-- sort thru in correct order now;
 foreach my $f ( @full_files )
 {
  my $d = $f;
  $d =~ s{\\}{/}g;
  push @VERSIONTOOL_RETURN, $return_hash{$d};
 }
}

#------------------------------------------------------------------
sub parse_input_list
{
 #-- subroutine to parse the input list of files to find a set of common
 #   directories to wildcard patterns.
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
sub parse_p4_log
{
 my ($fref, $oref ) = @_;
 my @lines = @{$oref};
 my $line;
 my @out;
 my $on_file = 0;
 my %p4_output;

 # Example output from p4 filelog...
 #
 # C:\builds\p4ws-hotel\JAVA-HOTELMGMT\hotel\src\hotel>p4 filelog Guest.java
 # //depot/JAVA-HOTELMGMT/hotel/src/hotel/Guest.java
 #... #3 change 9 edit on 2005/12/28 by Sean@JAVA-HOTELMGMT (text) 'needs fixing '
 #... #2 change 8 edit on 2005/12/28 by Sean@JAVA-HOTELMGMT (text) 'fixed it '
 #... #1 change 5 add on 2005/12/28 by Sean@Tatar (text) 'New application, HOTEL,added t'

 my $file;
 my ($depot_path, $version, $user, $change_list ) = ( " ", " ", " ", " " ) ;
 while ( $line = shift @lines )
 {
  chomp $line;
  if ( $line =~ m {//depot/} )
  {
   $on_file =1;
   $depot_path = $line;
   my @path = split /\//, $line;
   $file = pop @path;
  }

  if ( $on_file and $line =~ m{... #(.+?)\s+change\s+(.+?)\s+} )
  {
   #-- get only the first line
   $on_file = 0;
   $version = $1;
   $change_list = $2;

   if ( $line =~ m{by\s+(\S+?)@} )
   {
    $user = $1;
   }
   my $output = sprintf( $Format_String, $depot_path, $version, $user, $change_list );
   $p4_output{$file} = $output;
  }
  else
  {
   next;
  }
 }

 #-- sort the output the way it came in
 foreach my $f ( @{$fref} )
 {
  push @out, $p4_output{$f};
 }
 return @out;
}
