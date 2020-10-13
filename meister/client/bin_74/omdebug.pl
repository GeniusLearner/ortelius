###########################################
# This script will print multiple types of Debug
# Logs into a debug directory under the build directory
# and then create a zip file for sending to support.
# ADG 9.29.05
###########################################

################################################################################
# Modified script for Meister 7.3 - LRL 3.19.10
# * Updated for 7.3 client architecture
#
# - workflow debug:
# 	* gather submit.db, omsubmit.log, .rsp .bat/.sh and buildserver/logs/*.log
# - build server debug:
# 	* gather rbs_startup.xml, 
################################################################################


################################################################################
# todo:
#
# * create friendlier verbage for build that doesn't have BCF files
# * delete submit.db files routine
# * omsubmit -K
# * create more independent/reusable method for finding client location
#
################################################################################

use File::Find;
use File::stat;
#use strict;
eval "use Cwd";
eval "use Arhive::Zip";
eval "use Archive::Zip::Tree";


my @LogTxt;

my $DateName = "omDebug_" . scalar localtime();
$DateName =~ s/\s/_/g;
$DateName =~ s/:/_/g;
chomp $DateName;

my $errors;
my $warnings;
my $events;
my %omEnvVarHash;
my $regex;
my @fileTestResults; # used for file test routine &dirFileTest
my $noMAKFile;

my $OMBaseCommandLine = 'om -ov -a -ks clean all';
# Add any additional process calls that you want executed. Will loop through array of calls and generate a log with
# the corresponding output to the debug folder (naming conventions: joined arguments.log)
my @AdditionalProcessCalls =( 
	'om -ph',
	'om -pt'
	);
my $DebugLog = "$DateName$DL" . 'omDebug.log';
my $EnvLog = "$DateName$DL" . 'omEnv.log';
my $DebugZipName = "$DateName" . '.zip';
my $CompleteSemaphore = '.om_complete';
my $SleepInterval = 10; #interval for checking to see if submitted post 6.3 builds are complete
my $TimeOut = 3600; #If post6.3 om does not finish before 1 hour, exit out.

my $ZipObj = Archive::Zip->new() if ($isWin);
my $Project;
my $SearchPath;
my $CaseSensitive;
my $DebugDir = $DateName;
my $BuildDir = `pwd` if ($isUnix);
my $BuildDir = cwd() if ($isWin);
my $ContainsJava;
my $Version;
my $useJavaMake;
my $Post63Version;
my $OMStatus = 0; #0 for success, 1 for error
my $NoSubmit = 0;
my $Message;

my $clientLocation;
my $perlLib;
my $openmakeServer;
my $javaHome; 
my $CPCmd;
my $MDCmd;
my $CATCmd;
my $DELCmd;
my $cleanSubmitDB;

if ($^O =~ /win/i)
{
 $isWin = 1;
 $DL = "\\";
 $scExt = ".bat";
 $CPCmd = "copy";
 $MDCmd = "md";
 $CATCmd = "type";
 $DELCmd = "del";
}
else
{
 $isUnix = 1;
 $DL = "/";
 $scExt = ".sh";
 $CPCmd = "cp";
 $MDCmd = "mkdir";
 $CATCmd = "cat";
 $DELCmd = "rm";
}

########
# MAIN #
########

&omdebugArgs; # get a list of arguments passed to omdebug
chomp $DebugDir;
print "CREATING DEBUG DIR: $DebugDir\n";
`$MDCmd \"$DebugDir\" 2>&1 &`; #create debug directory for storing all logs
unless (open(DEBUG_LOG, ">$DebugLog"))
{
 print "Could Not Open $DebugLog! Make Sure You Have Write Access";
}
WriteDebug("********************* Openmake om Build Debug Output Log *********************\n");
WriteDebug("OS: $^O");
WriteDebug("BUILD DIRECTORY: $BuildDir");
WriteDebug("WRITING DEBUG INFO TO LOG: $DebugLog");
$OMVersion = CheckEnvironment($DebugDir);
$OMCommandLine = FormOMCommand($DebugDir, $OMVersion);
$OMJoinedLogName = $OMCommandLine;
$OMJoinedLogName =~ s/\s/_/g;
$OMJoinedLogName =~ s/\"//g;
my $OMLog = "$DateName$DL$OMJoinedLogName" . '.log';
unless (open(OM_LOG, ">$OMLog"))
{
 WriteDebug("Could Not Open $OMLog! Make Sure You Have Write Access");
}

if ($OMCommandLine != 1)
{
	($OMStatus, @OMLogLines) = ExecuteOM($OMCommandLine);
	&ProcessOMLog($OMStatus, @OMLogLines);
	&ExecuteAdditionalProcesses(@AdditionalProcessCalls) if @AdditionalProcessCalls;
}

&gatherWorkflowFiles();


&WrapUp($DebugDir, $DebugZipName);

#########
# /MAIN #
#########
sub usage
{
	print "omdebug utility v.\nperl -S omdebug.pl <options>\n\n";
	print "Options:\n\n\t-? or -help\t\tdisplay this message\n\t-cleanDB\t\tdelete submit.db files";
	exit;
}

########################
sub omdebugArgs
{
	&usage if(grep (/-help/, @ARGV) || grep (/-\?/, @ARGV));
	$cleanSubmitDB = 1 if (grep (/\-cleanDB/, @ARGV));
}

########################
sub CheckEnvironment
{
 my $OutDir = shift;
 my $EnvLog = $OutDir . "/env\.log";
 my $CLCRoot;
 my $Version;
 my $ManifestFile;
 
 WriteDebug("Checking Openmake Environment...");
 unless (open(ENV_LOG, ">$EnvLog"))
 {
  WriteDebug("Could Not Open $EnvLog! Make Sure You Have Write Access");
 }
 WriteDebug("WRITING ENVIRONMENT VARIABLES TO: $EnvLog");
 print ENV_LOG "\n*********************  ENVIRONMENT VARIABLES *********************\n";
 print ENV_LOG `set 2>&1` if $isWin; 
 print ENV_LOG `env 2>&1` if $isUnix;
 
 ################################################
 # Modify to include omenvironment.properties test
 ################################################
 $clientFound = &findClientDir;
 if ($clientFound == 1)
 {
	WriteDebug("************************************************************************");
 	WriteDebug("!! ERROR: Could not find the location of the Meister command line client executables. omdebug will exit now. Before running omdebug again, please make sure that the omenvironment.properties file is in the expected location, or that the client location is listed in your PATH environment variable, and that OPENMAKE_SERVER, and PERLLIB are set.");
	WriteDebug("************************************************************************");
 	exit;
 }
 else
 {
 	$clientLocation = $omEnvVarHash['OPENMAKE_HOME'];
 	$perlLib = $omEnvVarHash['PERL_LIB'];
 	$openmakeServer = $omEnvVarHash['OPENMAKE_SERVER'];
 	$javaHome = $omEnvVarHash['JAVA_HOME'];
 }

$CLCRoot = $clientLocation;
$OMPath = $CLCRoot . $DL . "bin" . $DL . "om";

 
 $Message = `$OMPath -v 2>&1`;
 WriteDebug($Message);
 if ($Message =~ /V\d\.(\d)/)
 {
  $Version = $1;
 }
 else
 {
  WriteDebug("!! OM VERSION NOT DETECTED !!");
 }
 
 WriteDebug("Checking Perl Environment...");
 
if ($perlLib eq "X_NOTFOUND_X")
{
 if ($ENV{PERLLIB})
 {
  WriteDebug("PERLLIB SET TO: $ENV{PERLLIB}");
 }
 else
 {
  WriteDebug("!! PERLLIB NOT SET !!");
 }
}
else
{
	WriteDebug("PERLLIB SET TO: $perlLib");
}
 WriteDebug("WRITING PERL VERSION INFO TO: $EnvLog");

 print ENV_LOG "\n*********************  PERL VERSION INFO *********************\n";
 print ENV_LOG "perl -v OUTPUT:\n";
 print ENV_LOG `perl -v 2>&1`;
 print ENV_LOG "perl -V OUTPUT:\n";
 print ENV_LOG `perl -V 2>&1`;
 return $Version;
}

########################
sub FormOMCommand
{
 my $OutDir = shift;
 my $OMVersion = shift;
 opendir(DIR, ".");
 @MakeFiles = grep{/\.mak$/} readdir(DIR);
 closedir DIR;
 if (!@MakeFiles)
 {
  $noMAKFile = 1;
  WriteDebug("************************************************************************");
  WriteDebug("!! WARNING: No Build Control Files were found. If you are debugging a workflow that contains a Meister Build Task, please generate a Build Control File (.mak) using the bldmake command:\n
  bldmake <\"YOUR PROJECT NAME\"> <\"YOUR SEARCH PATH NAME\">\n\nNote: For case sensitive builds, such as Java and .NET, also pass the -s option to your bldmake command.\n
  The omdebug program will continue gathering workflow logs and .rsp files, but will not capture any Meister Build information.\n");
  WriteDebug("************************************************************************");
  return 1;
  #exit;
 }
 else
 {
  foreach (@MakeFiles)
  {
   $Message = "COPYING BUILD CONTROL FILE $_ TO $OutDir\n";
   $Message .= `copy $_ \"$OutDir\" 2>&1` if $isWin;
   $Message .= `cp $_ \"$OutDir\" 2>&1` if $isUnix;
   WriteDebug("$Message");
  }
 }
 if($noMAKFile != 1)
 {
 	if (grep(/java\.mak/, @MakeFiles) && scalar(@MakeFiles > 1))
 	{
 		$ContainsJava = 1;
 		@MakeFiles = grep($_ !~ /java\.mak/, @MakeFiles);
 	}
 	
 	if (grep(/windows\.mak/, @MakeFiles) && scalar(@MakeFiles > 1) && $isWin)
 	{
 		@WinMake = grep(/windows\.mak/, @MakeFiles);
 		$MakeFile = shift @WinMake;
 	}
 	else
 	{
 		$MakeFile = shift @MakeFiles;
 	}
 	
 	WriteDebug("Evaluating Build Control File $MakeFile\.\.\.");
 	unless (open ( MAKEFILE, "$MakeFile"))
 	{
 		WriteDebug("Could Not Open $MakeFile! Make Sure You Have Read Access");
 	}
 	my @MakeLines = <MAKEFILE>;
 	close MAKEFILE;
 	$AppString = shift @MakeLines;
 	$StageString = shift @MakeLines;
 	@AppParts = split /\=/, $AppString;
 	$Project = pop @AppParts;
 	@StageParts = split /\=/, $StageString;
 	$SearchPath = pop @StageParts;
 	chomp $Project;
	
 	chomp $SearchPath;
 	WriteDebug("PROJECT: \<$Project\>");
 	WriteDebug("SEARCH PATH: \<$SearchPath\>");
 	if (@omdebugArgs) #if special flags passed in from command line, don't form om command line
 	{
 	 foreach (@omdebugArgs)
 	 {
 	  $NoSubmit = 1 if ($_ == -l);
 	 }  
 	 $omFlags = join " ", @omdebugArgs;
 	 $OMBaseCommandLine = "om $omFlags";
 	}
 	elsif (grep(/OSNAME Java/, @MakeLines) || $ContainsJava == 1) # additional check - look through the make file to see if Java is incorporated
 	{
 	 WriteDebug("Detected Java Components");
 	 if($javaHome == 1)
 	 {
 	 	if ($ENV{JAVA_HOME})
 	 	{
 	 	 WriteDebug("ENVIRONMENT VARIABLE JAVA_HOME SET TO: $ENV{JAVA_HOME}");
 	 	}
 	 	else
 	 	{
 	 	 WriteDebug("!! ENVIRONMENT VARIABLE JAVA_HOME NOT SET !!");
 	 	}
 	 }
 	 else
 	 {
 	 	WriteDebug("ENVIRONMENT VARIABLE JAVA_HOME SET TO: $javaHome");
 	 }
 	 $ContainsJava = 1;
 	 $OMBaseCommandLine .= ' -j';
 	 if ($MakeFile =~ /java\.mak/)
 	 {
 	  $useJavaMake = 1;
 	  $OMBaseCommandLine .= ' -f java.mak';
 	 }
 	}
 	else
 	{
 	 return $OMBaseCommandLine;
 	}
 	return $OMBaseCommandLine;
	}
	else
	{
		return 1;
	}
}

########################
sub ProcessOMLog
{
 my $OMStatus = shift;
 my @LogLines = @_;
 print OM_LOG @LogLines;

 WriteDebug("Parsing $OMLog...");
 if($OMStatus == 0)
 {
  WriteDebug("OM STEP FINISHED SUCCESSFULLY");
 }
 else
 {
  WriteDebug("OM STEP FINISHED WITH ERRORS");
 }
 foreach $LogLine (@LogLines)
 {
  if ($LogLine =~ /\s*Temporary script (.*) kept/)
  {
   $Message = "FOUND TEMPORARY SCRIPT: $1\n";
   $Message .= "COPYING $1 TO $DebugDir\n";
   $Message .= `$CPCmd \"$DebugDir\" 2>&1`;
   WriteDebug("$Message");
  }
  if ($LogLine =~ /\s*Buildfile: (.*\.xml)/ && $ContainsJava)
  {
   $Message = "FOUND BUILD\.XML FILE: $1\n";
   $Message .= "COPYING $1 TO $DebugDir\n";
   $Message .= `copy $1 \"$DebugDir\" 2>&1` if $isWin;
   $Message .= `cp $1 \"$DebugDir\" 2>&1` if $isUnix;   
   WriteDebug("$Message");
  }
 }
}
########################
sub ExecuteOM
{
 my $OMCommand = shift;
 my $LogOutput;
 my $startTime;
 my $OMStatus = 0;

 WriteDebug("Executing om Command $OMCommandLine\.\.\.");
 @LogOutput = `$OMCommandLine 2>&1`;
 @RevLogOutput = reverse(@LogOutput);
 if ($NoSubmit == 0)
 {
  WriteDebug("OM PROCESS SUBMITTED\.");
  {
   if (!-e $CompleteSemaphore && ($SleepTime < $TimeOut))
   {
    sleep($SleepInterval);
    $SleepTime += $SleepInterval; # if time lasts more than 3600 seconds, one hour, we will time out the build.
    WriteDebug("Waited $SleepTime Seconds For om Completion...");
    #if error is detected no .om_complete is created. In this case we need to stop waiting
    unless (open(OMSUBMITLOG, "\.log" . "$DL" . "omsubmit\.log"))
    {
     WriteDebug("Could Not Open \.log" . "$DL" . "omsubmit\.log! Make Sure You Have Write Access");
     die;
    }
    @SubmitLogOutput = <OMSUBMITLOG>;
    close OMSUBMITLOG;
    if (pop(@SubmitLogOutput) !~ /Skipping om complete due to error/) #Check omsubmit.log for error messages
    {
     redo; #redo condition check if error message not detected
    }
    else
    {
     $OMStatus = 1;
    }
   }
  }
  WriteDebug("OM PROCESS COMPLETE\.");
  if ($isWin)
  {
   $Message = "MAKING DIRECTORY \"$DebugDir\\.log\"";
   $Message .= `md \"$DebugDir\\.log\"`;
   WriteDebug("$Message");
   $Message = "COPYING \.log TO \"$DebugDir\\.log\"\n";
   $Message .= `copy .log \"$DebugDir\\.log\"`;
   WriteDebug("$Message");
   $Message = "MAKING DIRECTORY \"$DebugDir\\.submit\"";
   $Message .= `md \"$DebugDir\\.submit\"`;
   WriteDebug("$Message");
   $Message = "COPYING \.submit TO \"$DebugDir\\.submit\"\n";
   $Message .= `copy .submit \"$DebugDir\\.submit\"`;
   WriteDebug("$Message");
   $Message = "COPYING $CompleteSemaphore TO \"$DebugDir\"\n";
   $Message .= `copy $CompleteSemaphore \"$DebugDir\"`;
   WriteDebug("$Message");
  }
  else
  {
   $Message = "COPYING \.log TO \"$DebugDir/\.log\"\n";
   $Message .= `cp -R .log \"$DebugDir\"`;
   WriteDebug("$Message");
   $Message = "COPYING \.submit TO \"$DebugDir/\.submit\"\n";
   $Message .= `cp -R .submit \"$DebugDir\"`; 
   WriteDebug("$Message");
   $Message = "COPYING $CompleteSemaphore TO \"$DebugDir\"\n";
   $Message .= `cp $CompleteSemaphore \"$DebugDir\"`;
   WriteDebug("$Message");
  }
  unless (open(OMLOG, "$DebugDir$DL\.log" . "$DL" . "om\.log"))
  {
   WriteDebug("Could Not Open $DebugDir$DL\.log" . "$DL" . "om\.log! Make Sure You Have Write Access");
  }
  @OMLogOutput = <OMLOG>;
  push(@LogOutput, @OMLogOutput);
  close OMLOG;
  push(@LogOutput, "\n************************************************************\n");
  push(@LogOutput, "* om submission completed. Below log output\n");
  push(@LogOutput, "* taken from joined together om logs.\n");
  push(@LogOutput, "************************************************************\n");
  foreach $LogLine (@LogOutput)
  {
   if ($LogLine =~ /\s*Temporary script .*\.submit(.*)\.pl kept/)
   {
    $LogPartName = "$DL\.log$1\.log" if $isWin;
    $LogPartName = "$DL\.submit$1\.log" if $isUnix;
    
    unless (open(LOG_PARTS, "$DebugDir$LogPartName"))
    {
     WriteDebug("Could Not Open $DebugDir$LogPartName! Make Sure You Have Write Access");
    }
    @LogPart = <LOG_PARTS>;
    close LOG_PARTS;
    push @LogOutput, @LogPart;
   }
  }
 }
 elsif (@RevLogOutput[0] =~ /om.*with errors/)
 {
  $OMStatus = 1;
 }
 WriteDebug("SAVED LOG TO: $OMLog");
 return $OMStatus, @LogOutput;
}
#######################
sub dirFileTest
{
	# tests to see if files matching a regular expression exist in a directory.
	# populates @fileTestResults with any found files
	# returns a code of 1 if files matching regex pattern were found
	# returns a code of 0 if files matching regex pattern were not found
	# regex pattern should be created using qw( )

	$regex = shift;
	my $dir = shift;	
	
	@fileTestResults = (); # set result array to empty
	find(\&wantedFiles,$dir);
	
	$results = @fileTestResults; # test for length of results array
	
	if ($results > 0)
	{
		return 1;
	}	
	else
	{
		return 0;
	}
}
######################
sub wantedFiles
{
	if ($_ =~ m{$regex})
	{
		my $fileToCopy = $File::Find::name;
		$fileToCopy =~ s{/}{$DL}g if ($isWin == 1);
		$fileToCopy =~ s{\\}{$DL}g if ($isUnix == 1);
		push @fileTestResults, $fileToCopy;
	}
}

#######################
sub gatherWorkflowFiles
{
	my $localMode;
	if ($omEnvVarHash{'OPENMAKE_HOME'} =~ m{\w+}) #$clientLoc
	{
		$localMode = &queryRBS($omEnvVarHash{'OPENMAKE_HOME'}); #$clientLoc
	}
	my $submitDBLoc;
	my $jobsCPDir;
	my $buildServerCPDir;
	my $tmpDir;
	
	$tmpDir = $ENV{'TEMP'} if $isWin;
	$submitDBLoc = $tmpDir . $DL . "openmake" if $isWin;
	
	if ($isUnix)
	{
		# 4 possibilities for temp directory on UNIX
		$tmpDir = $ENV{'TMP'} if ($ENV{'TMP'} =~ m{\w+});
		$tmpDir = $ENV{'TEMP'} if ($ENV{'TEMP'} =~ m{\w+} && $tmpDir !~ m{\w+});
		$tmpDir = $ENV{'TMPDIR'} if ($ENV{'TMPDIR'} =~ m{\w+} && $tmpDir !~ m{\w+});
		$tmpDir = $DL . "tmp" if ($tmpDir !~ m{\w+});
		$submitDBLoc = $tmpDir . $DL . "openmake";
	}
	
	unless (-e $submitDBLoc)
	{
		WriteDebug("!! WARNING !! Cannot find \"openmake\" directory in TEMP. Will not package submit.db files as part of debug.");
		$noSubmitLoc;
	}
			
	$buildServerCPDir = $DebugDir . $DL . "buildserver";
	$jobsCPDir = $DebugDir . $DL . "jobs";
	$submitCPDir = $DebugDir . $DL . "submitdb";
	
	if($localMode =~ m{true}i)
	{
		$jobsDir = $tmpDir;	
		$hasRSP = &dirFileTest(qw(omtemp_[0-9]+\.rsp),$jobsDir);
	}
	elsif ($localMode =~ m{false}i)
	{
		$jobsDir = $omEnvVarHash{'OPENMAKE_HOME'} . $DL . "buildserver" . $DL . "jobs";
		$hasRSP = &dirFileTest(qw(omtemp_[0-9]+\.rsp),$jobsDir);
	}	
	elsif ($localMode == 1) # couldn't determine if local or not.
	{
		WriteDebug("Couldn't find rbs_startup.xml. Best guess to location of .rsp and .bat files.\n");
	
		$jobsDir = $omEnvVarHash{'OPENMAKE_HOME'} . $DL . "buildserver" . $DL . "jobs";
		
		$hasRSP = &dirFileTest(qw(omtemp_[0-9]+\.rsp),$jobsDir);
		$jobsDir = $tmpDir;
		$hasRSP = &dirFileTest(qw(omtemp_[0-9]+\.rsp),$jobsDir) if ($hasRSP == 1);
	}

	if ($hasRSP == 0)
	{
		WriteDebug("!! WARNING !! Couldn't find any .rsp files in $jobsDir . .rsp files will not be copied over.");
	}
	else
	{
		`$MDCmd \"$jobsCPDir\" 2>&1`; #create debug directory for storing job rsp files
		foreach $fileToCopy(@fileTestResults)
		{
			`$CPCmd \"$fileToCopy\" \"$jobsCPDir\" 2>&1`;
			if ($? == 0)
			{
				WriteDebug("COPIED $fileToCopy to $jobsCPDir");
			}
			else
			{
				WriteDebug("!! Error copying over $fileToCopy");
			}
		}
	}
	

	$logsDir = $omEnvVarHash{'OPENMAKE_HOME'} . $DL . "buildserver" . $DL . "logs";

	my $hasLogs = &dirFileTest(qw(\.log),$logsDir);
	if ($hasLogs == 0)
	{
		WriteDebug("!! WARNING !! Couldn't find any logs files in $logsDir . Logs will not be copied over.");
	}
	else
	{
		`$MDCmd \"$buildServerCPDir\" 2>&1`; #create debug directory for storing buildserver logs
		foreach $fileToCopy(@fileTestResults)
		{
			`$CPCmd \"$fileToCopy\" \"$buildServerCPDir\" 2>&1`;

			if ($? == 0)
			{
				WriteDebug("COPIED $fileToCopy to $buildServerCPDir");
			}
			else
			{
				WriteDebug("!! Error copying over $fileToCopy");
			}
			
		}
	}
	
	if($noSubmitLoc != 1)
	{
		$hasSubmitDB = &dirFileTest(qw(submit.db),$submitDBLoc);
		if ($hasSubmitDB == 1)
		{
			`$MDCmd \"$submitCPDir\" 2>&1`; #create debug directory for storing submit.db files
			foreach $fileToCopy(@fileTestResults)
			{
				$reldir = $fileToCopy;
				$reldir =~ s{\\}{/}g if $isWin == 1;
				$submitDBLoc =~ s{\\}{/}g if $isWin == 1;
				$reldir =~ s{$submitDBLoc}{}g;
				$reldir =~ s{submit\.db$}{}g;
				$reldir =~ s{$DL$}{}g;
				$reldir =~ s{/}{\\}g if $isWin == 1;
				$reldir = $DL . $reldir if (($reldir !~ m{^\\} && $isWin == 1) || ($reldir !~ m{^/} && $isUnix == 1));
				$submitRelCPDir = $submitCPDir . $reldir;
				`$MDCmd \"$submitRelCPDir\" 2>&1` if $isWin;
				`$MDCmd -p \"$submitRelCPDir\" 2>&1` if $isUnix;
				`$CPCmd \"$fileToCopy\" \"$submitRelCPDir\" 2>&1`;
				if ($? != 0)
				{
					WriteDebug("!! Error copying over $fileToCopy .");
					WriteDebug("$fileToCopy will not be deleted. ") if ($cleanSubmitDB == 1);
				}
				else
				{
					if ($cleanSubmitDB == 1)
					{
						$omsubmitCMD = $omEnvVarHash{'OPENMAKE_HOME'} . $DL . "bin" . $DL . "omsubmit -K";
						$ENV{'OPENMAKE_SERVER'} = $omEnvVarHash{'OPENMAKE_SERVER'} if ($ENV{'OPENMAKE_SERVER'} !~ m{\w+});
						@omsubOP = `$omsubmitCMD 2>&1`;						
						WriteDebug("Attempting to shut down omsubmit");
						@output = `$DELCmd \"$fileToCopy\" 2>&1`;
						WriteDebug("Deleting $fileToCopy. ") if ($? == 0);
						WriteDebug("Could not delete $fileToCopy. Please kill any running omsubmit processes, and remove these files manually.") if(-e $fileToCopy);
					}
				}
			}
		}
		else
		{
			WriteDebug("!! WARNING !! Couldn't find any submit.db files in $submitDBLoc . Submit.db files will not be copied over.");
		}
	}
}

#######################
sub ExecuteAdditionalProcesses
{
 	my @AdditionalProcs = @_;
 	my $Command;
 	my $ProcLog;
 	WriteDebug("Detected Additional Process Calls");
 	foreach $Command (@AdditionalProcs)
 	{
 	 	if ($Command =~ /^om\s/ && $NoSubmit == 1)
 	 	{
 	 	 	$Command .= " -l"; #if -l was passed into main om command, pass it to others as well for > 6.3
 	 	}
 	 	$ProcLog = "$DebugDir$DL$Command\.log";
 	 	$ProcLog =~ s/\s/_/g;
 	 	WriteDebug("Excuting External Process: $Command\.\.\.");
 	 	`$Command 2>&1 1>$ProcLog &`;
 	 	if ($Command =~ /^om\s/ && $NoSubmit == 0)
 	 	{
 	 	 	WriteDebug("Waiting $SleepInterval Seconds For Additional Processes To Complete\.");
 	 	 	sleep($SleepInterval);
 	 	 	`type .log\\om\.log >> \"$ProcLog\" 2>&1` if $isWin;
 	 	 	`cat .log\\om\.log >> \"$ProcLog\" 2>&1` if $isUnix;
 	 	}
 	 	WriteDebug("LOG SAVED TO: $ProcLog");
 	}
}
########################
sub WriteDebug
{
 $DebugLine =  shift;
 chomp $DebugLine;
 print "$DebugLine\n\n";
 print DEBUG_LOG "$DebugLine\n\n";
}

########################
sub WrapUp
{
 close ENV_LOG;
 close OM_LOG;
 if ($isWin)
 {
  my $ZipDir = shift;
  my $ZipFile = shift; 
  WriteDebug("********************* Debug Process Completed *********************");
  close DEBUG_LOG;
  print "\nAttempting to create $ZipFile...\n";
  print "\nzip file created successfully. Please send $DebugZipName to your support representative.\n";
  $ZipObj->addTree($ZipDir,$ZipDir);
  $ZipObj->writeToFileNamed($ZipFile);
  exit;
 }
 else #Try tar and jar. Zip module does not exist on Unix.
 {
  my $DebugTarName = $DebugZipName;
  $DebugTarName =~ s/\.zip$/\.tar/;
  my $DebugJarName = $DebugZipName;
  $DebugJarName =~ s/\.zip$/\.jar/;
  WriteDebug("********************* Debug Process Completed *********************");
  close DEBUG_LOG;
  print "\nAttempting to create $DebugTarName...\n";
  `tar -cvf $DebugTarName $DebugDir`;
  if (-e $DebugTarName)
  {
   print "\ntar file created successfully. Please send $DebugTarName to your support representative.\n";
   exit;
  }
  else
  {
   print "\nCould not create a tar file. Attempting to create $DebugJarName...\n";
   `jar -cvf $DebugJarName $DebugDir`;
   if (-e $DebugJarName)
   {
    print "\njar file created successfully. Please send $DebugJarName to your support representative.\n";
    exit;
   }
   else
   {
    print "\nNo archives could be created. Please send $DebugDir to your support representative.\n";
    exit;
   }
  }
 }
}
########################################
sub queryRBS
{
	# QueryRBS parses the <CLIENT>/buildserver/rbs_startup.xml to find if 
	# the Remote Build Server is running in local mode, or not.
	# returns local=true/false value
	my $clientDir = shift;
	my $buildServerDir = $clientDir . $DL . "buildserver";
	my $rbsxml = $buildServerDir . $DL . "rbs_startup.xml";
	my $localMode;
	
	if (-e $rbsxml)
	{
		# pass
	}
	else
	{
		WriteDebug("!!WARNING !! Cannot find $rbsxml. Workflow .rsp and $scExt files will not be included in .zip");
		return 1;
	}
	
	open RBSXML, "$rbsxml" || die "Can't open $rbsxml";
	@RBSLines = <RBSXML>;
	close RBSXML;
	
	foreach $rbsline(@RBSLines)
	{
		$localMode = $rbsline;
		$kbsServer = $rbsline;
		$kbPort = $rbsline;
		if($rbsline =~ m{-localMode})
		{
			$localMode =~ s{.+>-localMode</param-name><param-value>([^<]+)</param-value>.+}{$1};
		}
		if($rbsline =~ m{-kbHost})
		{
			$kbServer =~ s{>-kbHost</param-name><param-value>([^<]+)</param-value>.+}{$1};
		}
		if($rbsline =~ m{-kbPort})
		{
			$kbPort =~ s{>-kbPort</param-name><param-value>([^<]+)</param-value>.+}{$1};
			$omEnvVarHash{'OPENMAKE_SERVER'} = "http://" + $kbServer + ":" + $kbPort + "/openmake" if ($kbPort =~ m{\w+});
		}
	}
	return $localMode;
}

########################################
sub findClientDir
{
	# findClientDir parses the omenvironment.properties file if it exists, 
	# and populates a hash with client location, perl lib, and openmake server info
	# if omenvironment.properties does not exist, we check to see if client executables
	# exist in the path
	# findClientDir returns error if om executable cannot be found


	my $foundClientLoc;
	my $PathDL;
	my $omExe;
	my @omLocs;
	
	$PathDL = ";" if $isWin;
	$PathDL = ":" if $isUnix;
	$omExe = "om.exe" if $isWin;
	$omExe = "om" if $isUnix;
	
	my $omEnvFile = $DL . "omenvironment.properties";
	my $omEnvDir;
	
	if($isWin == 1)
	{
		$omEnvDir = $ENV{'APPDATA'} . $DL . "openmake";
	}
	else
	{
		$omEnvDir = $ENV{'HOME'} . $DL . ".openmake";
	}

	$omEnvFile = $omEnvDir . $omEnvFile;
	
	if (-e $omEnvFile)
	{
		open OMENV, "$omEnvFile";
		@omenvLines = <OMENV>;
		close OMENV;
		
		foreach $line(@omenvLines)
		{
			chomp($line);
			my @arr = split('=',$line);
			$omEnvVarHash{@arr[0]} = @arr[1]
		}
		return 0;
	}
	else
	{
		WriteDebug("WARNING: Could not find omenvironment.properties file. Checking path. \n");
		my @omLocs;
		
		############
		# 1st alternate method: which
		##############
		@OMPath = `which $omExe 2>&1`;
		foreach $omPathLine(@OMPath)
		{
			if($omPathLine =~ m{command not found}i || $OMPath =~ m{not recognized}i)
			{
				# either which isn't found in path, or the executable was not found
			}
			else
			{
				if ($omPathLine =~ m{$DL$omExe})
				{
					$OMPath = $omPathLine;
					chomp($OMPath);
					push @omLocs, $OMPath;
					$foundClientLoc = 1;
				}
			}
		}
		$omNewest = checkVersion(@omLocs);
		#}
		##############
		# 2nd alternate method: PATH
		##############
		if ($foundClientLoc != 1)
		{
			$sysPath = $ENV{'PATH'};
			@sysPaths = split(/$PathDL/,$sysPath);

			foreach $pathPart(@sysPaths)
			{
				$testPath = $pathPart . $DL . $omExe;
				$clientLoc = $pathPart if (-e $testPath);
				push @omLocs, $testPath;
				$foundClientLoc = 1;
			}
			
			$omNewest = checkVersion(@omLocs) if($foundClientLoc == 1);
		}

		
		if($foundClientLoc == 1)
		{
			chomp($clientLoc = $omNewest);
						
			$clientLoc =~ s{\\bin\\om\.exe}{}g if $isWin;
			$clientLoc =~ s{/bin/om}{}g if $isUnix;
			$perlLib = $clientLoc . $DL . "perl" . $DL . "lib";
			$omEnvVarHash{'OPENMAKE_HOME'} = $clientLoc;
			$omEnvVarHash{'PERL_LIB'} = $perlLib;
			$omEnvVarHash{'OPENMAKE_SERVER'} = "X_NOTFOUND_X";
			$omEnvVarHash{'JAVA_HOME'} = "X_NOTFOUND_X";
			
		}
		elsif ($foundClientLoc != 1)
		{
			WriteDebug("!! ERROR: Could not find client directory in Path. Will not be able to run workflows or builds.\n");
			$omEnvVarHash{'OPENMAKE_HOME'} = "X_NOTFOUND_X";
			$omEnvVarHash{'PERL_LIB'} = "X_NOTFOUND_X";
			$omEnvVarHash{'OPENMAKE_SERVER'} = "X_NOTFOUND_X";
			$omEnvVarHash{'JAVA_HOME'} = "X_NOTFOUND_X";
			return 1
		}
	}
}

sub checkVersion
{
	@omLocs = @_;
	my $totalLocs = 0;
	my $rank;
	foreach $omLoc(@omLocs)
	{
		@versionNum = `$omLoc -v 2>&1`;
		foreach $line(@versionNum)
		{
			if ($line =~ m{Openmake\(R\)})
			{
				my $version = $line;
				$version =~ s{Openmake\(R\) V([0-9]+)\.([0-9]+) Build ([0-9]{2})([0-9]{2})([0-9]{2}),.+}{$1-$2-$3-$4-$5};
				@versionParts = split(/-/,$version);
				
				if (@versionParts[0] == 7)
				{
					$rank = (@versionParts[4]*365) + (@versionParts[2]*30) + @versionParts[3];
					$omLocsHash{$rank} = $omLoc;
					$totalLocs++;
				}
				elsif (@versionParts[0] =~ 6)
				{
					if(@versionParts[1] < 41)
					{
						# not correct version
				}
					elsif(@versionParts[1] == 41)
					{
						if(@versionParts[4] == 7)
						{
							if(@versionParts[2] > 6)
							{
								$rank = (@versionParts[4]*365) + (@versionParts[2]*30) + @versionParts[3];
								$omLocsHash{$rank} = $omLoc;
								$totalLocs++;
							}
						}
					}
				}
			}
		}
	}
	if($totalLocs > 1)
	{
		@locsHashSort = sort {$b <=> $a}(keys %omLocsHash);
		$selectLoc = $omLocsHash{@locsHashSort[0]};
	}
	elsif($totalLocs == 1)
	{
		$selectLoc = $omLocsHash{$rank};
	}
	else
	{
		$selectLoc = 1;
	}
	return $selectLoc;
}