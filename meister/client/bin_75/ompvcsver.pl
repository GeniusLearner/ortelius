# ompvcsver.pl Version 1.0
#
# Openmake PVCS VM version command utility
#
# Catalyst Systems Corporation          April 23, 2003
#
#-- Perl wrapper to PVCS VM commands that plugs into 
#   Openmake build tool

=head1 OMPVCSVER.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

ompvcsver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script runs while the om.exe 
executable is running, and has access to certain Openmake-specific 
information.

This command will do a PVCS 'pcli lvf' and 'vlog' on files in the Openmake
Search Path to determine if these files are under PVCS Version Control.

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

=item -id <userid:pass> :

User ID and password. Defaults to PCLI_ID

=item -h : 

Prints header. Used by om.exe to determine the format of
the Bill of Materials log.
 
=item -f <filename>: 

name of file to check. Used by om.exe.

=back
 
=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. determines files in the repository and project that
    match to the file name.
 3. execute the 'vlog' command
 4. parse the output of vlog
 5. Determine if the file matches the timestamp of 
    a revision in the vlog list.
 6. If so, save the version information to the $VERSIONTOOL_RETURN
    variable (read by Om.exe).

=cut

 
#=====================================
#Main


#-- use declarations

#-- Openmake Variables
our $RC = 0;
our $VERSIONTOOL_RETURN = "";

#-- global variables
#had to change the command to use pcli vlog rather than just vlog ADG 12.5.07
our $SCMCmd  = "pcli listrevision";
our $SCMList = "pcli";
our $SCMListArg = "lvf -z -w";

our ( $pvcsfile, $file, $projectpath, $repository, $idpass, $relpath, $workspace);

#-- parse the command line
&ProcessCmdLine;
if ( $RC )
{
 $RC = 0;
 goto EndOfScript;
}

# Customer only requires the Project Path and Revision fields, not author or label. Passing in empty columns for the 3rd and 4th to maintain formatting
if ( $header )
{
 $VERSIONTOOL_RETURN = "Revision;PVCS File Location";
 goto EndOfScript;
}

#-- determine the file information
use Cwd;
$file =~ s/\\/\//g;

#if the .log dir does not exist, create it for placing our rev and archive logs for this build
if (!-d ".log")
{
 `md .log`;
}

#Add special logic for handling ../ path references in file.
#need to correctly restructure the path reference so that ../'s are removed while maintaining
#the correct file system location for later pattern matching. ADG 12.5.07
if ($file =~ /\.\.\//)
{
 my @PathParts;
 my @PathCleaned;
 @PathParts = split(/\//, $file);
 foreach (@PathParts)
 {
  if ($_ =~ /\.\./)
  {
   pop @PathCleaned;
   next;
  }
  else
  {
   push @PathCleaned, $_;
  }
 }
 $file = join "/", @PathCleaned;
}
$file = cwd . "/" . $file unless ( $file =~ /\// );
#--need relpath for later matching, strip off root part up to project
$relpath = $file;
$relpath =~ s|.*?$projectpath|$projectpath|i;

# If this is the first time through Main, force pcli commands to run
our $index;
$index++;

#-- If version is HEAD, look up the file 

if ($ENV{PVCS_VER_LABEL} eq "HEAD")
{
 my $SCMCmdLine = $SCMList . " " . $SCMListArg;
 $SCMCmdLine .= " -sp$workspace" if ( $workspace );
 $SCMCmdLine .= " -pr$repository";
 $SCMCmdLine .= " -id$idpass" if ( $idpass );
 $projectpath = "/" . $OMPROJECT unless $projectpath;
 $SCMCmdLine .= " -pp\"$projectpath\" 2>&1 ";
 if ($index < 2)
 {
  @lvf_files = `$SCMCmdLine`;
  open (LVF_LOG, ">.log\\om_pcli_lvf.log");
  foreach (@lvf_files)
  {
   print LVF_LOG $_;
  }
  close LVF_LOG;
 }
 else
 {
  open LVF_LOG, "<.log\\om_pcli_lvf.log";
  @lvf_files = <LVF_LOG>;
  close LVF_LOG;
 }
 $RC = $?;
 if ( $RC )
 {
  $RC = 0;
  goto EndOfScript #-- can't exit or die in embedded Perl;
 }

 #-- now match @lvf_files to input file
 my $output = "";
 $matchfile = $file;
 $matchfile =~ s/\\/\//g;

 foreach my $lvf_file ( @lvf_files )
 {
  chomp $lvf_file;
  $lvf_file =~ s/\\/\//g;
  if ( $matchfile =~ /^$lvf_file$/i )
  {
   $output = $file;
   last;
  }
 } 
}


##if a revision was not found, assume file is not in PVCS - set $projectpath param to message
#unless ( $output )
#{
# goto EndOfScript;
#}

$pvcs_label = $ENV{PVCS_VER_LABEL};

#-- look up the version info
$quoted_projectpath = "\"" . $projectpath . "\"";
$SCMCmdLine = $SCMCmd . " -pr$repository -pp$quoted_projectpath ";
$SCMCmdLine .= " -id$idpass" if ( $idpass );
$SCMCmdLine .= " -v" . $pvcs_label unless ($ENV{PVCS_VER_LABEL} eq "HEAD");
$SCMCmdLine .= " -z * 2>&1";
if ($index < 2)
{
  @vlog = `$SCMCmdLine`;
  open REV_LOG, "> .log\\om_pcli_listrevision.log";
  foreach (@vlog)
  {
   print REV_LOG $_;
  }
  close REV_LOG;
}
else
{
 open REV_LOG, "<.log\\om_pcli_listrevision.log";
 @vlog = <REV_LOG>;
 close REV_LOG;
}

$RC = $?;
if ( $RC )
{
 $RC = 0;
 goto EndOfScript; #-- can't exit or die in embedded Perl;
}

($pvcsfile, $rev) = &ParseVLog( @vlog);
#if a revision was not found, assume file is not in PVCS - set $pvcsfile param to message
if (!$rev)
{
  $pvcsfile = "Not Found in PVCS";
  $rev = "N/A"
}

$pvcsfile =~ s/ $//g;
$rev =~ s/ //g;
$rev .= ';';
# Customer only requires the Project Path and Revision fields, not author or label. Passing in empty columns for the 3rd and 4th to maintain formatting
$VERSIONTOOL_RETURN = sprintf( "%s%s", $rev, $pvcsfile);
#$VERSIONTOOL_RETURN = "";

EndOfScript:

$VERSIONTOOL_RETURN;
$RC;


#------------------------------------------------
sub ParseVLog
{
 # Parse VLOG
 my @VLOGOut = @_;
 my $Lines = @VLOGOut;
 for ($i = 0; $i < $Lines; $i++) 
 {
  my $Line = $VLOGOut[$i];
  chomp ($Line);
  if ($ENV{PVCS_VER_LABEL} eq "HEAD")
  {
   if ($Line =~ /^($relpath)\s+DefaultVersion:=(.*)/)
   {
    return ($1, $2);
   }
  }
  else
  {
  if ($Line =~ /^($relpath)\s+$pvcs_label:=(.*)/)
  {
   return ($1, $2);
  }
 }
 }
 return undef;
}
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
	$repository =~ s|\\|/|g;
    $RC = 1, return if ( &CheckNextArg( $repository, "-R requires an argument\n"));
    $repository = "\"" . $repository . "\"";
   }
   
   if ( $sw eq "P" )
   {
    $projectpath = shift @ARGV;
	$projectpath =~ s|\\|/|g;
    $RC = 1, return if ( &CheckNextArg( $projectpath, "-P requires a name\n"));
   }

   $header = 1 if ( $sw eq "h" );
   if ( $sw eq "id" )
   {
    $idpass = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $idpass, "-id requires an argument\n"));
   }
   if ( $sw eq "f" )
   {
    $file = shift @ARGV;
    $RC =1 , return if ( &CheckNextArg( $idpass, "-f requires an argument\n"));
   }
   if ( $sw eq "w" )
   {
    $workspace = shift @ARGV;
    $RC =1 , return if ( &CheckNextArg( $idpass, "-w requires an argument\n"));
   }
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
  print $txt;
  return 1;
 }
 return 0;
}
