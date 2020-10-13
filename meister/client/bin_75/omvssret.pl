#omvssret.pl Version 1.0
#
# Openmake VSS Retrieve command utility
#
# Catalyst Systems Corporation		June 23, 2003
#
#-- Perl wrapper to VSS commands that plugs into 
#   the Openmake build tool

=head1 OMVSSRET.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omvssret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific 
information.

This command can do a vss checkout or update on files from the VSS repository as
specified from arguments passed to the script via the rules or config file.

=over 4

=head1 GLOBAL ARGUMENTS: USING THE RULES FILE

Using the rules file, it is possible to add or modify global options passed to VSS.
By default a -rp calls om with a "ss get $/<vss_project> -R -I-" command.  Adding global
arguments changes the root structure of the command line call - the commands
up to and including the checkout.

The following arguments can be placed in the rules file on separate lines.

Output at command line call time is:

> <VSS> <GLOBAL ARGUMENT(S)> <CHECKOUT or UPDATE>  
 
UPDATE              : This option tells om to do an update instead of a checkout.

-ssdir <VSS repository> : This option specifies the repository, which is either an 
                      absolute pathname or a more complex expression involving a 
                      connection method, username and host, and path.  Defaults to SSDIR
                      environment setting.

-t                  : This option traces the execution of a VSS command, causing VSS to 
                      print messages showing the steps that it’s going through to 
                      complete a command.
              
-T <TEMPDIR>        : This option stores any temporary files in TEMPDIR instead of 
                      wherever VSS normally puts them (specifically, this overrides 
                      the value of the TMPDIR environment variable, if any exists). 
                      TEMPDIR should be an absolute path.

 

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the config and rules file for arguments passed to VSS.
 2. place arguments in the appropriate place.
 3. execute a "vss checkout" or "vss update" command.

=cut


#-- use declarations
use Openmake::File;
use Openmake::Log;
use File::Copy;
use File::Temp qw/ tempfile/;

#-- Openmake Variables
my $RC = 0;

#-- global variables
our $SCMTool  = "ss";
our $SCMCmd = " get";
our $SCMRules = "";
our $SCMConfig = "";

#-- process the command line
our ( $dir, $location, $group, $revision, $projects, @projects, $overwrite, $update);
our ( @files, $force, $linestart, $idpass, $workspace );

#-- local variables
#  omlogger expects the following
my $StepDescription = "";

#-- start script
&ProcessCmdLine;
if ( $RC )
{
 $RC = 1;
 goto EndOfScript;
}

#-- list versioned files, get output
#   Only need this if no external files are specified.
#unless ( @files )
#{
if ( $ParsedRules )
{
 $SCMCmdLine .= $SCMTool . $ParsedRules . $SCMCmd;
}
else
{
 $SCMCmdLine .= $SCMTool . $SCMCmd;
}

if ($project eq "")
{
 $ParsedConfig .= " $OMPROJECT";
}
else
{
 $ParsedConfig .= " $project";
}

if ( $ParsedConfig )
{
 $SCMCmdLine .= $ParsedConfig;
}
while ( @files )
{ 
 $SCMCmdLine .= " " . shift(@files);
}
if ( $^O =~ /MS|win/i )
 {
  $SCMCmdLine .= " 2>/null";
 }
 else
 {
  $SCMCmdLine .= " 2>/dev/null";
 }

 #-- use omlogger
 $StepDescription = "Executing $SCMCmdLine\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",0, $StepDescription);

 print "Setting VSS Database $VSSDB\n";
 $ENV{SSDIR} = $VSSDB;
 
 print "Setting Project $VSSDB\n";
 $ENV{SSDIR} = $VSSDB;
 
 print "Executing $SCMCmdLine\n";
 @output = `$SCMCmdLine`;
 $RC = $?;
 if ( $RC )
 {
  $StepDescription = "Failed execution $SCMCmdLine\n";
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription, @files);
  goto EndOfScript #-- can't exit or die in embedded Perl;
 }
 if ( ! @output )
 {
  $RC = 2;
  $StepDescription = "Failed execution $SCMCmdLine. No output files\n";
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC,$StepDescription);
  goto EndOfScript #-- can't exit or die in embedded Perl;
 }
  if (@output)
 { 
  $StepDescription = "Executing $SCMCmdLine\n";
  omlogger("Intermediate",$StepDescription,"ERROR:","$StepDescription succeeded.",$SCMCmdLine,"","",$RC,$StepDescription,@output); 
  goto EndOfScript; #-- can't exit or die in embedded Perl;
 }

$StepDescription = "Executing $SCMCmdLine\n";
omlogger("Intermediate",$StepDescription,"ERROR:","ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC,$StepDescription,@output), $RC = 1 if ($RC != 0);
omlogger("Intermediate",$StepDescription,"ERROR:","$StepDescription succeeded.",$SCMCmdLine,"","",$RC,$StepDescription,@output) if ($RC == 0);

EndOfScript:
unlink $tempfile;
$RC;

#------------------------------------
sub ProcessCmdLine
{

 while ( @ARGV )
 {
  my $arg = shift @ARGV;
  if ( $arg =~ /^-(\w+)/ )
  {
   my $sw = $1;
   #-- need to parse for "-rules file"
   if ( $sw eq "rules" )
   {
    #-- open up the rules file, add on
    my $rules = shift @ARGV;
    $rules =~ s/\\/\//g;
    #$RC = 1, return if ( &CheckNextArg( $rules, "-rules requires an argument\n")
       #&& ( ! -e $rules ) );fix later
    open ( RULES, "$rules");
    while ( <RULES>)
    {
     chomp;
     push @rules, $_;
    }
    close RULES;
    &ParseRules;
   }
   
   if ( $sw eq "d" )
   {
    $dir = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $dir, "-d requires an argument\n"));
    $ParsedConfig .= " $arg" . " $dir";
   }

   if ( $sw eq "pr" )
   {
    $project = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $project, "-pr requires an argument\n"));
    #$arg = $project;
    #$ParsedConfig .= " $arg";
   }

   if ( $sw eq "D" )
   { 
    $date = shift @ARGV;
    if ( $date =~ /^-/ ) #if -D does not have argument will match next -option
    {
     unshift @ARGV, $date; #in this case place back next -option
     $date = $OMVPATHNAME; #and set $date to OM Search Path name
    }
    else
    {
     $ParsedConfig .= " $arg" . " $date"; #if -r has argument use as $revision
    }
   } 
   
   if ( $sw eq "r" )
   { 
    $revision = shift @ARGV;
    if ( $revision =~ /^-/ ) #if -r does not have argument will match next -option
    {
     unshift @ARGV, $revision; #in this case place back next -option
     $revision = $OMVPATHNAME; #and set $revision to OM Search Path name
    }
    else
    {
     $ParsedConfig .= " $arg" . " $revision"; #if -r has argument use as $revision
    }
   } 
   
   $ParsedConfig .= " " . $arg if ( $sw eq "l");
   $ParsedConfig .= " " . $arg if ( $sw eq "f");  
   
   if ( $location eq "." )
   {
    use Cwd;
    $location = cwd;
   }
  }
  else
  {
   push @files, $arg;
  }
 }
}

#------------------------------------
sub ParseRules
{
while (@rules)
 { 
  my $rule = shift(@rules);
  if ( $rule =~ /^vss/i )
  {
   $SCMTool = $rule; 
  }
  if ( $rule =~ /^update/i )
  {  
   $SCMCmd = " " . $rule;
  }
  if ( $rule =~ /^-(\w+)/ )
  { 
   my $sw = $1;
   if ( $sw eq "d" )
   {
    @SplitLine = split(/\s+/,$rule);
    $repository = @SplitLine[1];
    $RC = 1, return if ( &CheckNextRule( $repository, "-d requires an argument\n"));
    #$repository = $ENV{VSSROOT} unless $repository;
    $ParsedRules .=  " " . $rule;
   }  
   if ( $sw eq "T" )
   {
    @SplitLine = split(/\s+/,$rule);
    $TempDir = @SplitLine[1];
    $RC = 1, return if ( &CheckNextRule( $TempDir, "-T requires an argument\n"));
    $ParsedRules .= " " . $rule;
   }  
   {
    $ParsedRules .= " " . $rule if ( $sw eq "t");
   }
  }  
 }
} 
#------------------------------------
sub CheckNextRule
{
 my $arg = shift;
 my $txt = shift;
 if ( $arg =~ /^\W/ )#if match on non word characters throw error.
 {
  my $StepDescription = "ERROR:Wrong arguments to omvssret: $txt\n";
  my $rc = 1;
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$rc,$StepDescription);
  return 1;
 }
 return 0;
}
#------------------------------------
sub CheckNextArg
{
 my $arg = shift;
 my $txt = shift;
 if ( $arg =~ /^-/ )
 {
  my $StepDescription = "ERROR:Wrong arguments to omvssret: $txt\n";
  my $rc = 1;
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$rc,$StepDescription);
  return 1;
 }
 return 0;
}
