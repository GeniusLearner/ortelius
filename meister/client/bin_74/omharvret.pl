# omharvret.pl Version 1.4
#
# Openmake Harvest Retrieve command utility
#
# Catalyst Systems Corporation  July 1st, 2003
#
#-- Perl wrapper to Harvest commands that plugs into
#   Openmake build tool

=head1 OMHARVRET.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omharvret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific
information. The script "retrieves" code from Harvest by executing
a 'hco' check out for browse.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file.
There has been an attempt for these arguments to match as close
as possible to the Harvest hco command arguments.

=over 2

=item -b <Harvest Broker>

The name of the Harvest broker. Required

=item -en <Harvest environment>:

Name of the Harvest environment. Defaults to the Openmake Project
Name ($OMPROJECT).

=item -st <Harvest State>:

Name of the Harvest State. Defaults to the Openmake Search Path
Name ($OMSEARCHPATH).

=item -vp <Harvest Viewpath> :

Location of the Harvest repository Viewpath. Defaults to
"\<Openmake Project Name>".

=item -cp <Harvest Client Path> :

Location where to do the check-out. Defaults to the local
working directory.

=item -p <Harvest Package> :

Name of the Harvest Package from which to check-out code.
By default, the script checks out all code in an Environment/
State/Viewpath.

=item -ss <Harvest SnapShot> :

Name of the Harvest Snapshot from which to check-out code.

=item -br :

Checkout out mode - Browse

=item -sy :

Checkout out mode - Synchronize

=item -usr <User> :

Username to do checkout

=item -pwd <Password> :

password for user doing checkout

=back

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. Construct the 'hco' command
 3. Execute the hco command

=cut

#-- use declarations
use Openmake::Log;
use Cwd;

#-- Openmake Variables
my $RC = 0;

#-- global variables
our ( $Broker, $Project, $State, $SnapShot, $Package, $ViewPath,
      $ClientPath, $User, $Password, $StepDescription,
      $SCMCmdLine );

#-- Get the arguments from the command line
#   The following sticks all of the options into the hash arguments
#   indexed by argument letter. We then stick it into each specific
#   variable
#
use Getopt::Long;
&Getopt::Long::Configure("bundling_override", "pass_through");
&GetOptions( "en=s" => \$Project,
             "st=s" => \$State,
             "vp=s" => \$ViewPath,
             "cp=s" => \$ClientPath,
             "b=s"  => \$Broker,
             "p=s"  => \$Package,
             "ss=s" => \$SnapShot,
             "usr=s" => \$User,
             "pwd=s" => \$Password,
             "sy" => \$Checkout_Synch_Option,
             "br" => \$Checkout_Browse_Option,
             "d" => \$Debug_Option
           );
           
#This section added for debugging - SD 
if ( $Debug_Option )
{
 print "Project                = $Project \n";
 print "State                  = $State \n";
 print "ViewPath               = $ViewPath \n";
 print "ClientPath             = $ClientPath \n";
 print "Broker                 = $Broker \n";
 print "Package                = $Package \n";
 print "SnapShot               = $SnapShot \n";
 print "User                   = $User \n";
# print "Password               = $Password \n";
 print "Checkout_Synch_Option  = $Checkout_Synch_Option \n";
 print "Checkout_Browse_Option = $Checkout_Browse_Option \n";
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
$State ||= $OMSEARCHPATH;
$ViewPath ||= "\\" . $OMPROJECT;
$ClientPath ||= cwd();
$ClientPath =~ s/\//\\/g if ( $^O =~ /win|MS/i );

#-- parse the input
unless ( defined $Broker )
{
 $RC = 1;
 #-- omlogger
 $StepDescription = "OMHARVRET: Must specify the Broker\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- SD case 5495 -  check for password  - if password is not supplied hco waits for the password and it will appear to hang 
#-- parse the input
unless ( defined $Password )
{
 $RC = 1;
 #-- omlogger
 $StepDescription = "OMHARVRET: Must specify Password\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- SD -  check for Checkout Option 
if (( !$Checkout_Synch_Option ) && ( !$Checkout_Browse_Option ))
{
 $RC = 1;
 #-- omlogger
 $StepDescription = "OMHARVRET: Must specify Checkout Option (-br or -sy) \n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- SD case 5495 and merge JAG's 5200 changes into the latest version
#Figure out the checkout option - If both -br and -sy are supplied it will use the -br option
#                                 and note that if none are supplied it would be caught in validation above
$Checkout_Option = "-sy" if ($Checkout_Synch_Option);
$Checkout_Option = "-br"  if ($Checkout_Browse_Option);


#-- create the hco command;
$SCMCmdLine  = qq(hco -b $Broker -en "$Project" -st "$State" -vp "$ViewPath");
$SCMCmdLine .= qq( -cp "$ClientPath");
$SCMCmdLine .= qq( -p "$Package") if ( $Package);
$SCMCmdLine .= qq( -ss "$SnapShot") if ($SnapShot);
$SCMCmdLine .= qq( -usr "$User") if ( $User);
$SCMCmdLine .= qq( -pw "$Password") if ( $Password);


#-- add in the defaults
#-- JAG case 5200 - this doesn't work
#$SCMCmdLine .= qq( -sy -br -op pc 2>&1 );

#-- add in the defaults
$SCMCmdLine .= qq( $Checkout_Option -op pc -s "*" );

#-- add remaining arguments
if ( $remain_args )
{
 #-- omlogger
 $StepDescription = "OMHARVRET: Adding remaining arguments '$remain_args'\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",0, $StepDescription);
 $SCMCmdLine .= " " . $remain_args;
}
$SCMCmdLine .= qq( 2>&1 );

#-- print what we are executing
my $xxxSCMCmdLine = $SCMCmdLine;
#-- SD case 5495 - Do not mask the User
#$xxxSCMCmdLine =~ s/-usr "\Q$User\E"/-usr XXXXXX/ if ( $User );
$xxxSCMCmdLine =~ s/-pw "\Q$Password\E"/-pw XXXXXX/ if ( $Password );

$StepDescription = "OMHARVRET: Executing '$xxxSCMCmdLine'\n";
#$StepDescription = "OMHARVRET: Executing '$SCMCmdLine'\n";
&omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",0, $StepDescription);

#-- execute the command line
if ( $Debug_Option )
{
  print "\n Executing $xxxSCMCmdLine \n";
}
my @output = `$SCMCmdLine`;
$RC = ($? >> 8 );

#-- log the output
$StepDescription = "OMHARVRET: Executing hco\n";
&omlogger("Intermediate",$StepDescription,"ERROR:","OMHARVRET: ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC,"OMHARVRET: ERROR: $StepDescription failed\n",@output), $RC = 1 if ($RC != 0);
&omlogger("Intermediate",$StepDescription,"ERROR:","OMHARVRET: $StepDescription succeeded.",$SCMCmdLine,"","",$RC,"OMHARVRET: $StepDescription succeeded\n",@output) if ($RC == 0);

#-- end of script
EndOfScript:
$RC;


