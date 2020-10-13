# omsieeret.pl Version 1.0
#
# Openmake MKS Source Integrity Enterprise Edition Retrieve command utility
#
# Catalyst Systems Corporation		June 16, 2003
#
#-- Perl wrapper to SIEE commands that plugs into
#   Openmake build tool

=head1 OMSIEERET.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omsieeret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific
information.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file.

=over 2

=item -p <SIEE Project>:

Name of the SIEE project. Defaults to the Openmake Project Name

=item -s <SIEE Sandbox Location>:

Location of the SIEE Sandbox location where code is
to be checked out. Defaults to $SANDBOX_LOCAL

=item -b :

Flag to indicate that this is to be a build sandbox

=item -r <Revision> :

If this is a build sandbox, this is the revision of the project

=item -U <User> :

Username to do checkout

=item -P <Password> :

password for user doing checkout

=back

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. determine if the sandbox exists, and if it's normal or build
 3. Drop the sandbox if it is of the wrong type
    a. It's normal and we want a build sandbox
    b. It's a build sandbox and
       i. we want a normal sandbox
       ii. it's for the wrong revision
 4. Create the sandbox if necessary
 5. Resync the sandbox if necessary

=cut

#-- use declarations
use Openmake::File;
use Openmake::Log;
use Getopt::Long;

#-- Openmake Variables
our $RC = 0;

#-- global variables
our ( $Project, $SandboxLocation, $BuildSandbox,
      $Revision, $User, $Password, $StepDescription,
      $SCMCmdLine );
$Project = '';
$SandboxLocation = '';
$Revision = '';
$BuildSandbox = 0;
$User = '';
$Password = '';
$SCMCmdLine = "";

#-- Get the arguments from the command line
#
&Getopt::Long::Configure("bundling","pass_through");
&GetOptions( "p=s" => \$Project,
             "s=s" => \$SandboxLocation,
             "r=s" => \$Revision,
             "b"   => \$BuildSandbox,
             "U=s" => \$User,
             "P=s" => \$Password
           );
#-- determine user and password to pass to si
my $siuserpass = "";
if ( $User && $Password )
{
 $siuserpass = " --user=$User --password=\"$Password\" ";
}

#-- use the environment variable if not
#   specified in the command line
$SandboxLocation ||= $ENV{SANDBOX_LOCAL};
$Project ||= $OMPROJECT;

unless ($Project && $SandboxLocation )
{
 $RC = 1;
 #-- use omlogger
 $StepDescription = "OMSIEERET: Must specify Project and Sandbox Location\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

if ( $BuildSandbox && ! $Revision )
{
 $RC = 1;
 #-- use omlogger
 $StepDescription = "OMSIEERET: Must specify Revision if using a build sandbox\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- convert back to forward slashes
$SandboxLocation =~ s/\\/\//g;
$Project =~ s/\\/\//g;

#-- grab the project name from the full path.
my @project = split /\//, $Project;
my $projectname = pop @project;
my $sandbox = $SandboxLocation . "/" . $projectname;

#-- check to see that build sandbox exists:
$SCMCmdLine = qq( si sandboxinfo --batch --sandbox="$sandbox" $siuserpass 2>&1 );

my @output = `$SCMCmdLine`;
my $siret = ($? >> 8 );

#-- parse the output
my $sb_exists_normal = grep /^Sandbox Name/, @output;
my $sb_exists_build  = grep /^Build Sandbox Name/, @output;
my $sb_exists = $sb_exists_normal || $sb_exists_build;

#-- if we have to drop a sandbox, do it here
my @sb_revision = grep /^Revision/, @output;
$sb_revision[0] =~ /^Revision:\s+(.+)\s+$/;
my $sb_revision = $1;

my $sb_dropped = 0;

#-- see if we must drop the sandbox.
#   we drop the sandbox in three cases
#   1. We want a build sandbox, and either:
#       a. the revision of the current Build sandbox is wrong
#       b. the sandbox exists as a normal sandbox
#   2. We want a normal sandbox, and the sandbox exists as a
#      build sandbox
#
if ( ($BuildSandbox && (( $sb_revision != $Revision )
     || $sb_exists_normal ) )
       || ! $BuildSandbox && $sb_exists_build )
{
 my $StepDescription = "";
 if ( $sb_exists_normal )
 {
  $StepDescription = "Drop normal to create build sandbox";
 }
 elsif ( ! $BuildSandbox && $sb_exists_build )
 {
  $StepDescription = "Drop build to create normal sandbox";
 }
 else
 {
  $StepDescription = "Drop build revision sandbox";
 }

 #-- si command
 $SCMCmdLine = qq( si dropsandbox --batch --noconfirm --delete=members --yes "$sandbox" 2>&1 );
 @output = `$SCMCmdLine`;
 $RC = ($? >> 8 );
 if ( $RC )
 {
  &omlogger("Intermediate",$StepDescription,"FAILED","OMSIEERET: ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC, @output);
  goto EndOfScript;
 }
 else
 {
  &omlogger("Intermediate",$StepDescription,"","OMSIEERET: $StepDescription succeeded!",$SCMCmdLine,"","",0, @output);
 }

 $sb_dropped = 1;
}

#-- create the sandbox and populate it with the
#   members.
if ( $sb_dropped || ( ! $sb_exists) )
{
 $StepDescription = "Creating Sandbox $SandboxLocation";

 if ( $BuildSandbox )
 {
  $SCMCmdLine = qq( si createsandbox --batch --yes --project="$Project" --projectRevision=$Revision --populate $siuserpass "$SandboxLocation" 2>&1 );
 }
 else
 {
  $SCMCmdLine = qq( si createsandbox --batch --yes --project="$Project" --populate $siuserpass "$SandboxLocation" 2>&1 );
 }
 @output = `$SCMCmdLine`;
 $RC = ($? >> 8 );
 if ( $RC )
 {
  &omlogger("Intermediate",$StepDescription,"FAILED","OMSIEERET: ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC, @output);
  goto EndOfScript;
 }
 else
 {
  &omlogger("Intermediate",$StepDescription,"","OMSIEERET: $StepDescription succeeded",$SCMCmdLine,"","",0, @output);
 }

}
else
{
 #-- resync the default sandbox
 $StepDescription = "Resynchronizing Sandbox $SandboxLocation";
 #-- si command

 $SCMCmdLine = qq( si resync --batch --yes --overwriteChanged --sandbox="$sandbox" $siuserpass 2>&1 );
 @output = `$SCMCmdLine`;
 $RC = ($? >> 8 );

 omlogger("Intermediate",$StepDescription,"ERROR:","OMSIEERET: ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC,"OMSIEERET: ERROR: $StepDescription failed\n",@output), $RC = 1 if ($RC != 0);
 omlogger("Intermediate",$StepDescription,"ERROR:","OMSIEERET: $StepDescription succeeded.",$SCMCmdLine,"","",$RC,"OMSIEERET: $StepDescription succeeded\n",@output) if ($RC == 0);
}

EndOfScript:
$RC;