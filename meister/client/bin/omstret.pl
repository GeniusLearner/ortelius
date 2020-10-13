# omstret.pl Version 1.0
#
# Openmake StarTeam Retrieve command utility
#
# Catalyst Systems Corporation  June 1st, 2005
#
#-- Perl wrapper to StarTeam commands that plugs into
#   Openmake build tool

=head1 OMSTRET.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omstret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific
information. The script "retrieves" code from Starteam by executing
a 'stcmd co' check out for browse.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file.
There has been an attempt for these arguments to match as close
as possible to the Starteam stcmd co command arguments.

=over 2

=item -pr <Project>

The name of the project. Required

=item -fp <Folder Path> :

Location where to do the check-out. Defaults to the local
working directory.

=item -usr <User> :

Username to do checkout

=item -pwd <Password> :

password for user doing checkout

=back

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. Construct the 'stcmd co' command
 3. Execute the command

=cut

#-- use declarations
use Openmake::Log;
use Cwd;

#-- Openmake Variables
my $RC = 0;

#-- global variables
our (  $Batchmode, $Compress, $Host, $Port, $Project, $ViewPath, $FolderPath,$Recurse, $StoponError,
$User, $Password, $Verbose, $View, $StepDescription,$SCMCmdLine );

#-- Get the arguments from the command line
#   The following sticks all of the options into the hash arguments
#   indexed by argument letter. We then stick it into each specific
#   variable
#
use Getopt::Long;
&Getopt::Long::Configure("bundling_override", "pass_through");
&GetOptions( "b=s" => \$Batchmode,
             "c=s" => \$Compress,
             "ho=s" => \$Host,
             "po=s" => \$Port,
             "pr=s" => \$Project,
             "vp=s" => \$ViewPath,
             "fp=s" => \$FolderPath,
             "v=s" => \$View,
             "usr=s" => \$User,
             "pwd=s" => \$Password,
             "d" => \$Debug_Option
           );
           
#This section added for debugging - SD 
if ( $Debug_Option )
{
 print "Project                = $Project \n";
 print "ViewPath               = $ViewPath \n";
 print "FolderPath             = $FolderPath \n";
 print "User                   = $User \n";
# print "Password              = $Password \n";
}

#-- if we have ARGV remaining, add it to list
my $remain_args = "";
foreach (@ARGV)
{
 if ( $_ =~ /^-/ )
 {
  $remain_args .= "$_ ";
 }
 else
 {
  $remain_args .= "\"$_\" ";
 }
}

#-- create defaults
$Project ||= $OMPROJECT;
$ViewPath ||= "\\" . $OMPROJECT;
$ClientPath ||= cwd();
$ClientPath =~ s/\//\\/g if ( $^O =~ /MSWin|dos/i );

#-- parse the input
unless ( defined $Project )
{
 $RC = 1;
 #-- omlogger
 $StepDescription = "OMSTRET: Must specify the Project\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- check for password  
unless ( defined $Password )
{
 $RC = 1;
 #-- omlogger
 $StepDescription = "OMSTRET: Must specify Password\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- create the stcmd co command;
$SCMCmdLine  = qq(stcmd co -p "$User:$Password\@$Host:$Port/$Project/$View/$ViewPath");
$SCMCmdLine .= qq( -fp "$FolderPath");

#-- add in the defaults
$SCMCmdLine .= qq( -u -o -x -is "*" );

#-- add remaining arguments
if ( $remain_args )
{
 #-- omlogger
 $StepDescription = "OMSTRET: Adding remaining arguments '$remain_args'\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",0, $StepDescription);
 $SCMCmdLine .= " " . $remain_args;
}
#$SCMCmdLine .= qq( 2>&1 );

#-- print what we are executing
my $xxxSCMCmdLine = $SCMCmdLine;
#-- SD case 5495 - Do not mask the User
#$xxxSCMCmdLine =~ s/-usr "\Q$User\E"/-usr XXXXXX/ if ( $User );
$xxxSCMCmdLine =~ s/-pw "\Q$Password\E"/-pw XXXXXX/ if ( $Password );

$StepDescription = "OMSTRET: Executing '$xxxSCMCmdLine'\n";
#$StepDescription = "OMSTRET: Executing '$SCMCmdLine'\n";
&omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",0, $StepDescription);

#-- execute the command line
if ( $Debug_Option )
{
  print "\n Executing $xxxSCMCmdLine \n";
}
my @output = `$SCMCmdLine`;
$RC = ($? >> 8 );

#-- log the output
$StepDescription = "OMSTRET: Executing stcmd co\n";
&omlogger("Intermediate",$StepDescription,"ERROR:","OMSTRET: ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC,"OMSTRET: ERROR: $StepDescription failed\n",@output), $RC = 1 if ($RC != 0);
&omlogger("Intermediate",$StepDescription,"ERROR:","OMSTRET: $StepDescription succeeded.",$SCMCmdLine,"","",$RC,"OMSTRET: $StepDescription succeeded\n",@output) if ($RC == 0);

#-- end of script
EndOfScript:
$RC;


