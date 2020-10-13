# omaccuver.pl
#
# $Header: /CVS/openmake64/shared/omaccuver.pl,v 1.2 2006/08/02 15:46:01 jim Exp $
# Openmake AccuRev version command utility
#
# Catalyst Systems Corporation          April 11, 2006
#
#-- Perl wrapper to AccuRev commands that plugs into
#   Openmake build tool
#

=head1 OMACCUVER.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omaccuver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script runs while the
om.exe executable is running, and has access to certain Openmake-specific
information.

The following arguments can be placed in the configuration file.

=over 2

=item -h:

print out the header for the Version information. This is

"name of element" "virtual version" "(real version)" "status indicators"

This is used by om.exe to format the bill of materials report

=item -f <file> :

The filename to consider

=back

Other arguments will be ignored.

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. print out a header if necessary
 3. get the status for the file by calling
    'accurev stat -f <File>'
 4. Parse the status output to return

=cut

#-- use declarations
use Cwd;
use Getopt::Long;
use Openmake::File;

package main;

our $FORMAT_STRING = "%-62.62s  %-20.20s  %-20.20s  %-20.20s";

#-- don't support multi-file yet
#our $Supports_Multifile = 1;

#-- Openmake Variables
our $RC = 0;
our $VERSIONTOOL_RETURN = sprintf( $FORMAT_STRING, "", "", "", "" );

#-- Script Variables
our ( $File, $Header);

#-- parse the options
&Getopt::Long::Configure("bundling","pass_through");
&GetOptions( "h"   => \$Header,
             "f=s" => \$File
           );

#-- see if we have the correct arguments
if ( $Header )
{
 #-- print out the header info
 #$VERSIONTOOL_RETURN = "Name;Virtual Version;(Real Version);Status Indicators";
 $VERSIONTOOL_RETURN = sprintf( $FORMAT_STRING, "Name", "Virtual Version", "(Real Version)", "Status Indicators" );
 goto EndOfScript;
}


#-- test scenario
#if ( $File !~ m{\.jar$} )
#{
# $VERSIONTOOL_RETURN = sprintf( $FORMAT_STRING,
#                                 $File,  'Minibank\1',  '(2\1)', "(kept) (backed)" );
#}
#goto EndOfScript;

#-- determine the file information
$File =~ s{/}{\\}g;

#-- since accurev has to be in workspace, do a CD
my $f = Openmake::File->new( $File);

my $path = $f->getDP();
my $file = $f->getFE();

my $cwd = cwd();
chdir $path;

my $arcmd = qq( accurev stat "$file" 2>&1 );
my @arout = `$arcmd`;
my $arerr = $?;
chdir $cwd;

#-- determine what information we want stored.
$VERSIONTOOL_RETURN  = AccuParse( @arout );

EndOfScript:
$VERSIONTOOL_RETURN;

#print $VERSIONTOOL_RETURN , "\n";

#------------------------------------------------------------------
sub AccuParse
{
 my $line = shift; #-- only first line concerns us here
 my ( $name, $v_version, $r_version, $status);

 #\.\MinibankEJB\ejbModule\com\ibm\ejs\container\_EJSWrapper_Stub.java  Minibank\1 (2\1) (kept) (backed)
 #-- need to get last () sets, then 'real version' then file.

 chomp $line;
 if ( $line =~ m{You are not in a directory associated with a workspace})
 {
  return " ; ; ; ";
 }

 while ( $line =~ s{\(([\w\\]+?)\)\s*$}{} )
 {
  my $bracket = $1;
  if ( $bracket =~ m{^(\w+)$} )
  {
   my $word = $1;
   $status = $status . " ($word)";
  }
  else
  {
   $r_version = "($bracket)";
  }
 }

 #-- now line should be <file> <real version>. assume <real version> doesn't have spaces.
 #   Actually, split on 2 spaces
 ( $name, $v_version ) = split /  /, $line;

 my $str = sprintf( $FORMAT_STRING, $name, $v_version, $r_version, $status);
 return $str;
}
