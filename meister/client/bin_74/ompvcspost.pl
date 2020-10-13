# ompvcspost.pl Version 1.0
#
# Openmake PVCS VM post command utility
#
# Catalyst Systems Corporation          April 23, 2003
#
#-- Perl wrapper to PVCS VM commands that plugs into 
#   Openmake build tool

=head1 OMPVCSPOST.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

ompvcspost.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-ap, -ac, -ar} command line flags. This script executes after
the executable runs, and has access to certain Openmake-specific 
information.

This command will read the Openmake Bill of Material report, and determine
which files to label. It will then use the VCS command to label the files.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file.

Unlike the actual PVCS commands, there must be a space between the 
switch and its argument

=over 2

=item -R <pvcs repository> : 

Location of the PVCS Repository. Defaults to PCLI_PR

=item -P <pvcs project>: 

Name of PVCS project. Defaults to "/<Openmake Project>". 
Can have multiple -P flags
                        
=item -id <userid:pass> : 

User ID and password. Defaults to PCLI_ID

=item -p "<put command>" :

If present, put the built objects into PVCS.

=item -l <label> : 

Label to apply to files used in the build. If <label> is of the 
form <str>"%DATE", the label will have YYMMDD appended to it. 
So <label> = BUILD_%DATE% => BUILD_030429

=back

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. Parse the Bill of Materials report for a list of files 
    to label
 3. Use the VCS command to label these files.
 
=head1 FUTURE WORK

It would be useful if this routine could check in built files from the
build directory. Unsure how to proceed with that, given that we may need
a snapshot of the build directory from a 'pre' script that says what was
present before the build took place.

=cut

 
#=====================================
#-- use declarations
use Openmake::PrePost;
use Openmake::Snapshot;
use Openmake::Log;

#-- Openmake Variables
our $RC = 0;
my @argvl = @ARGV;

#-- global variables
our $SCMCmd  = "vcs";
our $SCMList = "pcli";
our $SCMListArg = "lvf -z -aw";

our ( $project, $repository, $idpass, $label);

my $StepDescription;

#-- parse the command line
&ProcessCmdLine;
if ( $RC )
{
 $StepDescription = "Error: ompvcspost: Failed to parse commandline @argvl\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$RC, $StepDescription);
 goto EndOfScript;
}

#-- unless we ask to label something, leave
goto EndOfScript unless ( $label);

#-- parse the BillOfMaterials
unless ( -e $OMBOMRPT )
{
 $StepDescription = "Error: ompvcspost: Cannot find OMBOMRPT $OMBOMRPT\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",1, $StepDescription);
 goto EndOfScript;
}
my $ombom = Openmake::ParseBOM->new($OMBOMRPT);

#-- use tempfile
use File::Temp qw/ tempfile /;
#-- not sure "UNLINK" works unless you die or exit
my ( $fh, $tempfile ) = tempfile( "ompvcspostXXXXXX", DIR => ".", SUFFIX => ".tmp", UNLINK => 0);

#-- grab a list of all the archives to memory.
my $SCMCmdLine = $SCMList . " " . $SCMListArg;
$SCMCmdLine .= " -sp$workspace" if ( $workspace );
$SCMCmdLine .= " -pr$repository";
$SCMCmdLine .= " -id$idpass" if ( $idpass );
$project = "/" . $OMPROJECT unless $project;
$SCMCmdLine .= " -pp\"$project\" 2>&1 ";
my @archives = `$SCMCmdLine`;
$RC = $?;
if ( $RC )
{
 $StepDescription = "Error: ompvcspost: Failed to execute PCLI LVF\n";
 &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$RC, $StepDescription);
 goto EndOfScript #-- can't exit or die in embedded Perl;
}

@archives = grep { $_ =~ s/\\/\//g } @archives;

#-- get list of files in BOM
my @files = $ombom->getFiles;

#-- loop over files, find revision info and archive info
foreach my $file ( @files )
{
 my $vertool = $ombom->getVersionInfo( $file);
 $vertool =~ s/^\s+//;
 $vertool =~ s/\s+$//;
 #-- split this up.
 my ( $project, $rev, $author, @labels ) = split /\s+/, $vertool;

 $file =~ s/\\/\//g;
 if ( $rev )
 {
  #-- determine the archive for the given file in the 
  #   workspace.
  my $arc = "";
  my @temp = grep { $_ =~ /"?(.+-arc)\($file\)"?/ } @archives ;
  if ( $temp[0] =~ /"?(.+-arc)\($file\)"?/ )
  {
   $arc = $1;
  }
  if ( $arc )
  {
   #-- output this to the temp file
   print $fh "\"" . $arc . "\"\n";
  }
 }
}
close $fh;

#-- label this revision
$SCMCmdLine = $SCMCmd . " -Y -V\"$label\" \@\"$tempfile\"";
$SCMCmdLine .= " -id$idpass" if $idpass;
$SCMCmdLine .= " 2>&1";

my @out = `$SCMCmdLine`;
$RC = $?;
$StepDescription = "Executing vcs\n";
omlogger("Intermediate",$StepDescription,"ERROR:","ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC,"",$StepDescription, @out), $RC = 1 if ($RC != 0);
omlogger("Intermediate",$StepDescription,"ERROR:","$StepDescription succeeded.",$SCMCmdLine,"","",$RC,"",$StepDescription, @out) if ($RC == 0);

EndOfScript:
unlink $tempfile;
$RC;

#------------------------------------
sub ProcessCmdLine
{

 while( @ARGV )
 {
  my $arg = shift @ARGV;
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
    $project = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $project, "-P requires a name\n"));
   }

   if ( $sw eq "id" )
   {
    $idpass = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $idpass, "-id requires an argument\n"));
   }

   if ( $sw eq "l" )
   {
    $label = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $label, "-l requires an argument\n"));
    if ( $label =~ s/%DATE$// )
    {
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); 
     $year -= 100; 
     $label = sprintf ( "%s%2.2d%2.2d%2.2d", $label, $year, $mon+1, $mday);
    }
   }
  }
  else
  {
   last;
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
  my $StepDescription = "ERROR:Wrong arguments to ompvcspost: $txt\n";
  my $rc = 1;
  &omlogger("Intermediate",$StepDescription,"FAILED",$StepDescription,"","","",$rc,$StepDescription);
  return 1;
 }
 return 0;
}
