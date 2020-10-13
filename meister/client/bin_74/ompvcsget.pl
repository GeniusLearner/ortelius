# ompvcsget.pl Version 1.1
#
# Openmake PVCS VM Retrieve command utility
#
# Catalyst Systems Corporation		April 23, 2003
#
#-- Perl wrapper to PVCS VM commands that plugs into 
#   Openmake build tool

=head1 OMPVCSGET.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

ompvcsret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific 
information.

This command will do a PVCS 'get' on files from the PVCS repository as
specified from arguments passed to the script via the config file.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file or the 
rules file. 
 
Unlike the actual PVCS commands, there must be a space between the 
switch and its argument

=over 2

=item -R <pvcs repository> : 

Location of the PVCS Repository. Defaults to PCLI_PR

=item -P <pvcs project> : 

Name of PVCS project. Defaults to "/<Openmake Project>". 
Can have multiple -P flags
                        
=item -r <label> : 

Files with this label are extracted.

=item -G <Group> : 

Files within this promotion group are extracted. 
(note: using -l and -G gives the AND of the two).
                        
If -r or -G are used, but no arguments are given, defaults to setting
both equal to the Openmake Search Path name.
                        
=item -Y : 

Force overwriting of existing files. Absence implies a PVCS "-N"
                       
=item -w <workspace> : 

workspace location

=item -l <location> :

Gets to a location that is not a workspace. Otherwise it gets to the
default workspace.
                       
=item -U : 

Update only. Files are retrieved only if they are newer in the 
repository than on the file system.
                       
=item -id <userid:pass> : 

User ID and password. Defaults to PCLI_ID;

=back
 
Anything else left on the command line will be assumed to be file names 
to be checked out. No files specified gets everything.
                        
Use a '--' to unambiguously distinguish between files and a -r or -G argument
                        
e.g.
                        
 > ompcvsret.pl -R "/opt/pvcs" -G abc
 
assumes that "abc" is the group name
 
 > ompcvsret.pl -R "/opt/pvcs" -G -- abc

passes no argument to -G and assumes that "abc" is a filename.
 
=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. list the versioned files with PCLI
 3. execute the "get" command

=cut

#-- use declarations
use Openmake::File;
use Openmake::Log;
use File::Copy;
use File::Temp qw/ tempfile/;

#-- Openmake Variables
our $RC = 0;

#-- global variables
our $SCMCmd  = "get";
our $SCMList = "pcli";
our $SCMListArg = "lvf -z -aw";

#-- process the command line
our ( $repository, $location, $group, $label, $projects, @projects, $update);
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
unless ( @files )
{
 my $SCMCmdLine = $SCMList . " " . $SCMListArg;
 $SCMCmdLine .= " -sp$workspace" if ( $workspace );
 $SCMCmdLine .= " -pr$repository";
 $SCMCmdLine .= " -id$idpass" if ( $idpass );
 $projects = "";
 foreach my $prj ( @projects )
 {
  $projects .= " $prj";
 }
 $projects = " /" . $OMPROJECT unless $projects;
 $SCMCmdLine .= "$projects ";
 #-- redirect STDERR since it has program info
 if ( $^O =~ /MS|win/i ) 
 {
  $SCMCmdLine .= " 2>/null";
 }
 else
 {
  $SCMCmdLine .= " 2>/dev/null";
 }
 
 my $SCMCmdLineClean = $SCMCmdLine;
 $SCMCmdLineClean =~ s/-id$idpass/-idXXXXXX/g;

 #-- use omlogger
 $StepDescription = "Executing $SCMCmdLineClean\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLineClean,"","",0, $StepDescription);

 @files = `$SCMCmdLine`;
 $RC = $?;
 if ( $RC )
 {
  $StepDescription = "Failed execution $SCMCmdLineClean\n";
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLineClean,"","",$RC, $StepDescription, @files);
  goto EndOfScript #-- can't exit or die in embedded Perl;
 }
 if ( ! @files )
 {
  $RC = 2;
  $StepDescription = "Failed execution $SCMCmdLineClean. No output files\n";
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC,$StepDescription);
  goto EndOfScript #-- can't exit or die in embedded Perl;
 }
 
}

#-- deal with the workspace issues
@files = &ParseFiles( @files);
if ( $RC )
{
 $StepDescription = "Failed to parse output of PCLI LVF command\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"PCLI LVF","","",$RC,$StepDescription );
 goto EndOfScript #-- can't exit or die in embedded Perl;
}

#-- output files dir to temporary file
use File::Temp qw/ tempfile/;
#-- not sure "UNLINK" works unless you die or exit
my ( $fh, $tempfile ) = tempfile( "ompvcsretXXXXXX", DIR => ".", SUFFIX => ".tmp", UNLINK => 0);
foreach ( @files )
{
 print $fh $_ . "\n";
}
close $fh;

#-- build the get command
my $SCMCmdLine = $SCMCmd ;
if ( $force )
{ 
 $SCMCmdLine .= " -Y";
}
else
{
 $SCMCmdLine .= " -N";
}
$SCMCmdLine .= " -U" if ( $update ); 
$SCMCmdLine .= " -G\"$group\"" if ( $group ); 
$SCMCmdLine .= " -r\"$label\"" if ( $label ); 
$SCMCmdLine .= " \@\"$tempfile\" 2>&1 ";
my $SCMCmdLineClean = $SCMCmdLine;
$SCMCmdLineClean =~ s/-id$idpass/-idXXXXXX/g;

my @output = `$SCMCmdLine`;
$RC = $?;
$StepDescription = "Executing $SCMCmdLineClean\n";
omlogger("Intermediate",$StepDescription,"ERROR:","ERROR: $StepDescription failed!",$SCMCmdLineClean,"","",$RC,$StepDescription,@output), $RC = 1 if ($RC != 0);
omlogger("Intermediate",$StepDescription,"ERROR:","$StepDescription succeeded.",$SCMCmdLineClean,"","",$RC,$StepDescription,@output) if ($RC == 0);

EndOfScript:
unlink $tempfile;
$RC;

#------------------------------------
sub ProcessCmdLine
{
 #-- need to add fix for command-line args that split on quotes
 my @newargv;
 my $at;
 for (my $i = 0; $i < @ARGV; $i++) 
 {
  $at .= $ARGV[$i];
  if ($at !~ /\"/ || ($at =~/\".*\"$/)) 
  {
   push(@newargv, $at);
   $at = "";
  }
  else 
  {
   $at .= " ";
  }
 }

 @ARGV = @newargv;

 while( @ARGV )
 {
  my $arg = shift @ARGV;
  if ( $arg eq "--" )
  {
   @files = @ARGV;
   last;
  }
 
  if ( $arg =~ /^-(\w+)/ )
  {
   my $sw = $1;

   #-- need to parse for "-rules"
   if ( $sw eq "rules" )
   {
    #-- open up the rules file, add on
    my $rules = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $rules, "-rules requires an argument\n")
       && ( ! -e $rules ) );
    open ( RULES, "$rules");
    while ( <RULES>)
    {
     chomp;
     push @ARGV, $_;
    }
    close RULES;
   }
   
   #-- rep
   if ( $sw eq "R" )
   {
    $repository  = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $repository, "-R requires an argument\n"));
    $repository = "\"" . $repository . "\"";
   }
   
   if ( $sw eq "P" )
   {
    my $arg = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $arg, "-P requires a name\n"));
    $arg = "\"$arg\"";
    push @projects, $arg;
   }

   if ( $sw eq "r" )
   {
    $label = shift @ARGV;
    if ( &CheckNextArg( $label, ""))
    {
     unshift @ARGV, $label;    
     $label = $OMVPATHNAME;
    }
   }
   if ( $sw eq "G" )
   {
    $group = shift @ARGV;
    if ( &CheckNextArg( $group, ""))
    {
     unshift @ARGV, $group;    
     $group = $OMVPATHNAME;
    }
   }

   $force = 1 if ( $sw eq "Y" );
   $update = 1 if ( $sw eq "U" );
   if ( $sw eq 'l' )
   {
    $location = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $workspace, "-l requires an argument\n"));
    if ( $location eq "." )
    {
     use Cwd;
     $location = cwd;
    }
   }

   if ( $sw eq 's' )
   {
    $linestart = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $linestart, "-s requires an argument\n"));
   }

   if ( $sw eq "id" )
   {
    $idpass = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $idpass, "-id requires an argument\n"));
   }

   if ( $sw eq 's' )
   {
    $workspace = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $workspace, "-w requires an argument\n"));
   }
    
  }
  else
  {
   push @files, $arg;
  }

 }
 
 $repository = "\"". $ENV{PCLI_PR} . "\"" unless $repository;
}

#------------------------------------
sub CheckNextArg
{
 my $arg = shift;
 my $txt = shift;
 if ( $arg =~ /^-/ )
 {
  my $StepDescription = "ERROR:Wrong arguments to ompvcsret: $txt\n";
  my $rc = 1;
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$rc,$StepDescription);
  return 1;
 }
 return 0;
}
 
 
#------------------------------------
sub ParseFiles
{
 #-- This subroutine parses the files return of pcli 
 #   to 
 #    1. convert "\" to "/"
 #    2. determine output location
 #    3. make necessary directories.
 #
 # output as 
 #  assumes archives are of -arc extension
 # "C:\Program Files\PVCSVM\VM\SampleDb\archives\Bingo\bingo-game\runserver.bat-arc(C:\PVCSWorkArea\Bingo\bingo-game\runserver.bat)"
 
 my @files = @_;
 foreach my $file ( @files )
 {
  my $archive;
  my $output;
  #-- switch all "\" to "/"
  $file =~ s/\\/\//g;
  if ( $file =~ /"?(.+?)(\.?-arc)\((.+)\)"?/ )
  {
   $archive = $1; #without -arc extension
   $archext = $2;
   $output = $3;
  }
  else
  {
   print "Cannot match $file to (.+)-arc\(.+\)\n";
   $RC = 1;
   return;
  }
  
  #-- parse the output location
  if ( $location )
  {
   #-- we're expected to move the file to a different location
   #   match the archive to output to get relative path
   my $relpath = "";
   my @temparc = split /\//, $archive;
   my @tempout = split /\//, $output;
   
   my $testarc = pop @temparc;
   my $testout = pop @tempout;
   my @t = ( scalar @temparc < scalar @temparc ) ? @tempout : @temparc;
   foreach ( @t )
   {
    #-- recreate the file paths from the back in
    $testarc = (pop @temparc ) . "/" . $testarc;
    $testout = (pop @tempout ) . "/" . $testout;
    
    if ( $testout eq $testarc )
    {
     $relpath = $testout;
    }
    else
    { 
     last;
    }
   }

   #-- create full output path with new location and relative path
   $output = $location . "/" . $relpath;
  
  }
  $archive .= $archext;
  
  #-- make directory
  use File::Path;
  my @temp =  split /\//, $output; 
  pop @temp;
  my $outdir = join "/", @temp;
  mkpath $outdir unless ( -d $outdir);
  
  #-- recreate files list
 
  $file = "\"" . $archive . "(" . $output . ")\"";  
 }
 return @files;
}
