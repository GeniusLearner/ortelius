# omsieever.pl Version 1.1
#
# Openmake MKS Source Integrity version command utility
#
# Catalyst Systems Corporation          June 17, 2003
#
#-- Perl wrapper to SIEE commands that plugs into
#   Openmake build tool
#
# 01.22.04 - fix bug with $File variable prepending cwd()

=head1 OMSIEEVER.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omsieever.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script runs while the
om.exe executable is running, and has access to certain Openmake-specific
information.

The following arguments can be placed in the configuration file.

=over 2

=item -U <User> :

Username to do checkout

=item -P <Password> :

password for user doing checkout

=item -h:

print out the header for the Version information. This is

"Project Revision Author  Labels"

This is used by om.exe to format the bill of materials report

=item -f <file> :

The filename to consider

=back

Other arguments will be ignored.

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. print out a header if necessary
 3. get the memberinfo for the file by calling
    'si memberinfo --batch --user=<User> --password=<Password> <File>
 4. Parse the memberinfo output to return
    a. project
    b. revision
    c. author
    d. labels

=cut

#-- use declarations
use Cwd;
use Getopt::Long;

package main;

#-- Openmake Variables
our $RC = 0;
our $VERSIONTOOL_RETURN = "";

#-- Script Variables
our ( $User, $Password, $File, $Header);

#-- parse the options
&Getopt::Long::Configure("bundling","pass_through");
&GetOptions( "U=s" => \$User,
             "P=s" => \$Password,
             "h"   => \$Header,
             "f=s" => \$File
           );

#-- see if we have the correct arguments
if ( $Header )
{
 #-- print out the header info
 $VERSIONTOOL_RETURN = sprintf( "\"%-148.148s %-10.10s %-10.10s %-49.49s\"",
   "Project", "Revision", "Author", "Labels");
 goto EndOfScript;
}

#-- bail unless we have User and password info
my $siuserpass = "";
if ( $User && $Password )
{
 $siuserpass = " --user=$User --password=\"$Password\" ";
}
goto EndOfScript unless ( $siuserpass );

#-- determine the file information
use Cwd;
$File =~ s/\\/\//g;
#$File = cwd . "/" . $File unless ( $File =~ /\// );

my $sicmd = qq( si memberinfo --batch $siuserpass "$File" 2>&1 );
my @siout = `$sicmd`;
my $sierr = $?;

#-- determine what information we want stored.
my ( $project, $revision, $author, $labels ) = &SIMemberParse( $siuserpass, @siout);

#-- if we are doing the build in a sandbox, it's possible
#   intermediate objects (eg. bingo-client.javac) are in the
#   sandbox, but not registered
if ( $project )
{
 $VERSIONTOOL_RETURN = sprintf( "\"%-148.148s %-10.10s %-10.10s %-49.49s\"",
  $project, $revision, $author, $labels );
}
else
{
 $VERSIONTOOL_RETURN = sprintf( "\"%-148.148s %-10.10s %-10.10s %-49.49s\"",
  "", "", "", "" );
}

EndOfScript:
$VERSIONTOOL_RETURN;
$RC;

sub SIMemberParse
{
 my ( $siuserpass, @si) = @_;

 my ( $project, $revision, $author, $label );

 #Member Name: bingo-client.jar.tgt
 #Sandbox Name: c:/MKS Workspace/MKS Projects/bingo-game/Bingo.pj
 #Development Branch: 1
 #Member Revision: 1.1
 #    Created By: jim on Feb 6, 2003 - 11:26 AM
 #    Locked By: jim on Feb 6, 2003 - 11:40 AM
 #    State: Exp
 #    Revision Description:
 #        Initial revision
 #        Member added to project c:/MKS Workspace/MKS
 #        Projects/bingo-game/Bingo.pj
 #    Labels:
 #        Release 1.1
 #    Change Package:
 #        No Change Package Information Available
 #Attributes: none

 my $line = join "", @si;
 if ( $line =~ /\s*Member Revision:\s*(.+)/ )
 {
  $revision = $1;
 }
 if ( $line =~ /\s*Labels:\s+(.+)/m  )
 {
  $label = $1;
 }
 if ( $line =~ /\s*Created By:\s+(.+?)\s+on/m  )
 {
  $author = $1;
 }
 if ( $line =~ /\s*Sandbox Name:\s+(.+?\.pj)\s+/ )
 {
  my $sandbox = $1;
  my $sicmd = qq(si sandboxinfo --batch --sandbox="$sandbox" $siuserpass 2>&1 );
  my @siout = `$sicmd`;
  my $sierr = $?;
  $project = &SISandboxParse( @siout);
 }

 return ( $project, $revision, $author, $label);

}

sub SISandboxParse
{
 my @si = @_;

 my ( $project );

 #Variant Sandbox Name: c:\MKS Workspace\MKS Sandboxes\Bingo\1.5-variant\Bingo.pj
 #Project Name: c:/MKS Workspace/MKS Projects/bingo-game/Bingo.pj
 #Server: etchasketch:7001
 #Development Path: 1.5-variant
 #Revision: 1.5
 #Last Checkpoint: Feb 19, 2003 - 5:56 PM
 #Sparse
 #Members: 59
 #Subsandboxes: 0
 #Project Description:
 #Project Attributes: none

 while ( @si )
 {
  $_ = shift @si;
  if ( /^\s*Project Name:\s*(.+)/ )
  {
   $project = $1;
   last;
  }
 }
 return $project;

}
