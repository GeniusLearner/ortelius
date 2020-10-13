#omcvsret.pl Version 1.0
#
# Openmake CVS Retrieve command utility
#
# Catalyst Systems Corporation		June 23, 2003
#
#-- Perl wrapper to CVS commands that plugs into 
#   Openmake build tool

=head1 OMCVSRET.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omcvsret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific 
information.

This command can do a cvs checkout or update on files from the CVS repository as
specified from arguments passed to the script via the rules or config file.

=over 4

=head1 GLOBAL ARGUMENTS: USING THE RULES FILE

Using the rules file, it is possible to add or modify global options passed to CVS.
By default a -rp calls om with a "CVS CHECKOUT <OMPROJECT>" command.  Adding global
arguments changes the root structure of the command line call - the commands
up to and including the checkout.

The following arguments can be placed in the rules file on separate lines.

Output at command line call time is:

> <CVS> <GLOBAL ARGUMENT(S)> <CHECKOUT or UPDATE>  
 
CVSXXX	            : This option tells om to use another CVS executable name.

UPDATE              : This option tells om to do an update instead of a checkout.

-d <CVS repository> : This option specifies the repository, which is either an 
                      absolute pathname or a more complex expression involving a 
                      connection method, username and host, and path.  Defaults to CVSROOT
                      environment setting.

-t                  : This option traces the execution of a CVS command, causing CVS to 
                      print messages showing the steps that it’s going through to 
                      complete a command.
              
-T <TEMPDIR>        : This option stores any temporary files in TEMPDIR instead of 
                      wherever CVS normally puts them (specifically, this overrides 
                      the value of the TMPDIR environment variable, if any exists). 
                      TEMPDIR should be an absolute path.

 
=head1 ARGUMENTS TO CVS CHECKOUT 

With the exception of the '-pr' project argument, all other arguments should be 
entered in the config file exactly as if executed with CVS. All options should be 
placed on separate lines in the rules file.

The following arguments can be placed in the config file to execute a 'CVS checkout'.


-pr <PROJECT(S)>    : Checks out specific project(s) from the CVS Repository. If no
                      argument is specified, this value defaults to the value of
                      $OMPROJECT.

-D <DATE>           : Checks out to the most recent revisions no later than DATE.

-r <REV>            : Checks out to revision REV. If -r is specfied but no parameter 
                      is provided, defaults to $OMVPATHNAME. 

-d <DIR>            : Creates the working copy in a directory named DIR, instead of 
                      creating a directory with the same name as the checked-out module. 
                      
-l                  : Checks out the top-level directory of the project only. Does not 
                      process subdirectories.

-f                  : Forces checkout of the head revision if CVS does not find the 
                      specified tag or date.
                       
Anything else placed in the rules files and subsequently left on the command line will 
be assumed to be file names to be checked out explicitely. No files specified gets 
everything in the project.
                        

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the config and rules file for arguments passed to CVS.
 2. place arguments in the appropriate place.
 3. execute a "cvs checkout" or "cvs update" command.

=cut


#-- use declarations
use Openmake::File;
use Openmake::Log;
use File::Copy;
use File::Temp qw/ tempfile/;

#-- Openmake Variables
my $RC = 0;

#-- global variables
our $SCMTool  = "cvs";
our $SCMCmd = " checkout";
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
  if ( $rule =~ /^cvs/i )
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
    #$repository = $ENV{CVSROOT} unless $repository;
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
  my $StepDescription = "ERROR:Wrong arguments to omcvsret: $txt\n";
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
  my $StepDescription = "ERROR:Wrong arguments to omcvsret: $txt\n";
  my $rc = 1;
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$rc,$StepDescription);
  return 1;
 }
 return 0;
}