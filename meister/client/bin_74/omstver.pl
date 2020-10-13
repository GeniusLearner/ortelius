# omstver.pl Version 1.0
#
# Openmake StarTeam version command utility
#
# Catalyst Systems Corporation          June 1, 2005
#
#-- Perl wrapper to StarTeam commands that plugs into 
#   Openmake build tool

=head1 OMSTVER.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omstver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script runs while the om.exe 
executable is running, and has access to certain Openmake-specific 
information.

This command will do a stcmd 'hist' on files in the Openmake
Search Path to determine if these files are under StarTeam Version Control.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file or the 
rules file. 
  
=over 2

=item -v <view> : 

Starteam View. Defaults to ST_VIEW

=item -pr <Starteam project> : 

Name of Starteam project. Defaults to "/<Openmake Project>". 

=item -usr <userid> :

User ID. 

=item -h : 

Prints header. Used by om.exe to determine the format of
the Bill of Materials log.
 
=item -f <filename>: 

name of file to check. Used by om.exe.

=back
 
=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. determines files in the view and project that
    match the file name.
 3. execute the 'stcmd hist' command
 4. parse the output of stcmd hist
 5. Determine if the file matches the timestamp of 
    a revision in the hist list (Status = Current).
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
our $SCMCmd  = "stcmd";
our $SCMList = "hist";
our $SCMListArg = "";


our ( $file, $project, $view, $Username, $Password, $Host, $Port, $ViewPath, $FolderPath);

#-- parse the command line
&ProcessCmdLine;
if ( $RC )
{
 $RC = 0;
 goto EndOfScript;
}

if ( $header )
{
 $VERSIONTOOL_RETURN = sprintf( "%-19.19s %-5.5s %-12.12s %-59.59s ", 
   "View", "Revision", "Author", "Filepath");
 goto EndOfScript;
}


#-- determine the file information
use Cwd;
$file =~ s/\\/\//g;

@fileparts =  split /\//, $file;
my $FileName = pop(@fileparts);
my $FilePath = join("/",@fileparts);
if ( $FolderPath )
{
$CheckFolderPath = $FolderPath;
$CheckFolderPath =~ s/\\/\//g;
$FilePath =~ s/$CheckFolderPath//i;
}

($FilePathInitial, $FilePathRest) =  split(/:\//, $FilePath);
if ($FilePathRest ne "")
{
$NewFilePath = $FilePathRest; 
}
else
{
$NewFilePath = $FilePathInitial; 
}
$NewFilePath =~ s/^$view//i;
$NewFilePath =~ s/^$ViewPath//i;

#-- look up the file 
my $SCMCmdLine = $SCMCmd . " " . $SCMList . " " . $SCMListArg;
#-- create the stcmd hist command;


$project = "/" . $OMPROJECT unless $project;

$SCMCmdLine .= qq( -p "$Username:$Password\@$Host:$Port/$project/$view/$ViewPath$NewFilePath");
$SCMCmdLine .= qq( -fp "$FolderPath") if ( $FolderPath );
$SCMCmdLine .= " -x $FileName 2>&1 ";

print $SCMCmdLine;

#-- look up the version info
my @stlog = `$SCMCmdLine`;
$RC = $?;
if ( $RC )
{
 $RC = 0;
 goto EndOfScript; #-- can't exit or die in embedded Perl;
}

my ( $rev, $author, $labels ) = &ParseVLog( @stlog);
$labels = "$NewFilePath" . "$FileName" . "$lables" ;
$VERSIONTOOL_RETURN = sprintf( "%-19.19s %-5.5s %-12.12s %-59.59s ", 
  $view, $rev, $author, $labels);

EndOfScript:
$VERSIONTOOL_RETURN;
print "\n$VERSIONTOOL_RETURN\n";
$RC;


#------------------------------------------------
sub ParseVLog
{
 # Parse VLOG
 my $WorkFile = "";
 my $InVersionList = 0;
 my $RevInNext = 0;
 my $Archive;

 my @Revisions = ();
 my @VLOGOut = @_;

 my %Month = ( Jan => 0,
               Feb => 1,
               Mar => 2,
               Apr => 3,
               May => 4,
               Jun => 5,
               Jul => 6,
               Aug => 7,
               Sep => 8,
               Oct => 9,
               Nov => 10,
               Dec => 11 );

 my $Mod = {};
 my $Author = {};
 my $Labels = {};

 my $Lines = @VLOGOut;
 foreach (my $i = 0; $i < $Lines; $i++) 
 {
  my $Line = $VLOGOut[$i];
  chomp ($Line);

  if ($InVersionList) 
  {

   if ($Line =~ /^Description/)
   {
    $InVersionList = 0;
   }
   else 
   {
    $Line =~ s/^ +//;
    my @VLabelArray = split(/=/,$Line);
    my $VLabel = shift(@VLabelArray);
    $VLabel =~ s/^\"//;
    $VLabel =~ s/\" +$//;
    my $Rev = pop(@VLabelArray);
    $Rev =~ s/^ +//;
                
    push @{$Labels->{$Rev}}, $VLabel;
   }

  } 
  elsif ($RevInNext) 
  {

   $RevInNext = 0;

   @LineParts = split /View:/, $Line;
   $RevisionPart =  shift(@LineParts);
   $RevisionPart =~ s/Revision: //;
   my $Rev = $RevisionPart;
   
   #unshift( @Revisions, $Rev);
            
   # Get times
   $i++;
   $Line = $VLOGOut[$i];
   chomp ($Line);
            
   @LineParts = split /Date:/, $Line;

   $AuthorPart = shift(@LineParts);
   $AuthorPart =~ s/^Author://;
  
   $DateTime = shift(@LineParts);
   $DateTime =~ s/^Date://;
   $DateTime =~ s/^ +//;
   
   #-- parse time into epoch
   #   Feb 13 2003 10:37:20
   my ( $datepart, $timepart ) = split / /, $DateTime;
   my ( $mon, $day, $year ) = split /\//, $datepart;
   my ( $hour, $min, $sec ) = split /:/, $timepart;
   $mon = $Month{$mon};
   #$year -= 1900;
   use Time::Local;
   my $etime = timelocal($sec,$min,$hour,$day,$mon,$year);

   $Mod->{$Rev} = $etime;
   $Author->{$Rev} = $AuthorPart;

   last;

  } 
  else 
  {  
   if ($Line =~/^Branch Revision:/) 
   {
    $InVersionList = 1;
   }

   if ($Line =~/^-----/) 
   {
    $RevInNext = 1;
   }

  }
 }
 
 #-- find our revision
 my $krev;
 my $efile = (stat($file))[9];

 foreach my $rev ( keys %{$Mod} )
 {
  $krev = $rev;
  my $etime = $Mod->{$krev};
  
  #-- determine if this is our file
  
  #-- have issues with +- one hour -- daylight savings?
  #   this isn't robust against all changes.
  last if ( $efile == $etime || $efile == $etime - 3600 || $efile == $etime + 3600 );
 }
 if ( $krev )
 {
  #$labelstr = "[" . ( join "] [", @{$Labels->{$krev}} ) . "]";
  $labelstr = "";
  return ($krev, $Author->{$krev}, $labelstr);
 }
 else 
 {
  return undef;
 }
 
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
    
   if ( $sw eq "usr" )
   {
    $Username = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $Username, "-usr requires an argument\n"));
   }
   if ( $sw eq "pwd" )
   {
    $Password = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $Password, "-pwd requires an argument\n"));
   }
   if ( $sw eq "pr" )
   {
    $project = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $project, "-pr requires a name\n"));
     }
   #-- View
   if ( $sw eq "v" )
   {
    $view  = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $view, "-v requires an argument\n"));
   }
   if ( $sw eq "ho" )
   {
    $Host = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $Host, "-ho requires a name\n"));
   }
   if ( $sw eq "po" )
   {
    $Port = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $Port, "-po requires a name\n"));
   }
   if ( $sw eq "vp" )
   {
    $ViewPath = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $ViewPath, "-vp requires a name\n"));
   }
   if ( $sw eq "fp" )
   {
    $FolderPath = shift @ARGV;
    $RC = 1, return if ( &CheckNextArg( $FolderPath, "-fp requires a name\n"));
   }
   if ( $sw eq "f" )  
   { 
    $file = shift @ARGV;
    $RC =1 , return if ( &CheckNextArg( $file, "-f requires an argument\n"));
   }
   $header = 1 if ( $sw eq "h" );

  }
 }
 $view = "\"". $ENV{ST_VIEW} . "\"" unless $view;
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
