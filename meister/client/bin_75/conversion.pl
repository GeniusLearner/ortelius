#!/usr/bin/perl

# User interface for Conversion
# Runs in two modes:
#	1. Interface (default)
#	2. Batch
#
# Batch mode is only invoked if all the following conditions are met:
#	1. Platform configuration file is loaded
#	2. Openmake BuildTypes file is loaded
#	3. Build output file is loaded
#	4. Openmake Project name is specified

use Openmake;
use File::Copy;
use Cwd;

# Constants
# Command-line capture utility messages
$CAPTURE_BEGIN = "# OPENMAKE CAPTURE BEGIN";
$CAPTURE_END   = "# OPENMAKE CAPTURE END";
$ERROR         = "# ERROR: UNABLE TO OPEN RESPONSE FILE";

# Variables
# $AllowCommonOutput
#   Flag to allow output from these routines
#   Defaults to false
$AllowCommonOutput = 0;

# $IsWindows
#   Flag for handling platform-specific file extensions (.exe, .bat, .sh) 
#   and case-sensitivity
if ($^O =~ /win32/i) {
    $IsWindows = 1;
}
else {
    $IsWindows = 0;
}

# Platform
# $OS
#   Specified OS/Platform for configuration file
#   Will also be used in TGT generation
$OS = "";
# @FinalTargetExts
#   List of final target extensions
#   Used to help locate final targets from the parsed targets
@FinalTargetExts = ();

# Platform Executable
# @Executables
#   List of executables used in the build
@Executables = ();
# %FlagPrefixes
#   Hashtable of the flag prefixes (-,/) keyed to the executable name
%FlagPrefixes = ();
# %OutputFlag
#   Hashtable of the output flag keyed to the executable name and possible
#   modifiers
%OutputFlag = ();
# %DerivedOutput
#   Hashtable of rules to derive a target from a depedency name
#   Needed for the case where a target is not explicitly stated on
#   a command-line.  Example: gcc -c source.c: source.c -> source.o
%DerivedOutput = ();
# %StandardFlags
#   Standard flags used by the compiler 
#   These will be excluded from consideration in Build Type matching
#   and TGT generation
%StandardFlags = ();
# %DependencyExcludeFilters
#   Filters used to exclude possible dependencies from the command-line
#   These filters may be necessary to exclude some intermediate targets
#   that are will be handled internally by the command-line or Openmake
#   scripts and should not actually appear on any dependency list
%DependencyExcludeFilters = ();
# @PlatformFinalTargetExts
#   List of final target extensions for the platform
@PlatformFinalTargetExts = ();

# Openmake Build Types
# $DefaultBuildType
#   Default Build Type to use if a match cannot be made
$DefaultBuildType = "";
# @BuildTypes
#   List of defined Build Types
@BuildTypes = ();
# %BuildTypeFinalTarget
#   Hashtable of final targets (by extension) keyed to the Build Type
#   Used for matching parsed targets to Build Types
%BuildTypeFinalTarget = ();
# %BuildTypeGenerateTarget
#   Hashtable of final targets (by extension) keyed to the Build Type
#   Overrides the FinalTarget settings when generating the TGT
%BuildTypeGenerateTarget = ();
# %BuildTypeRulesExe
#   Hashtable of executable used by Build Type Rule keyed to Build Type
#   and rule
%BuildTypeRulesExe = ();
# %BuildTypeRulesExe
#   Hashtable of executable flags used by Build Type Rule keyed to Build 
#   Type and rule
%BuildTypeRulesFlags = ();

# Openmake TGT
# $OMProject
#   Openmake Project for the generated TGTs
$OMProject = "";
# $IntDir
#   Intermediate directories for the generated TGTs
$IntDir = "";

# Command-line processing
# %ParsedTargetDeps
#   Hashtable of found target dependencies keyed to target name
%ParsedTargetDeps = ();
# %ParsedTargetArgs
#   Hashtable of command-line arguments key to target name
%ParsedTargetArgs = ();

# Target processing
# Determining build steps
# @FinalTargets
#   List of final targets found from parsed command-lines
@FinalTargets = ();
# %TargetDeps
#   Hashtable of dependencies keyed to the final target name
%TargetDeps = ();
# %TargetBuildStepDepExts
#   Hashtable of dependencies extensions keyed to the final target name
#   and target build step
%TargetBuildStepDepExts = ();
# %TargetBuildStepDepExts
#   Hashtable of command-line arguments keyed to the final target name
#   and target build step
%TargetBuildStepArgs = ();
# %TargetArgDifferences
#   Hashtable of command-line argument differences for intermediate targets
#   keyed to the final target name, target build step, and intermediate 
#   target and its dependencies
%TargetArgDifferences = ();

# Determining rules
# Matches structures for Openmake Build Type rules
# %TargetRulesExe
#   Hashtable of target rule executables keyed to final target name and
#   rule
%TargetRulesExe = ();
# %TargetRulesExe
#   Hashtable of target rule command-line arguments keyed to final target 
#   name and rule
%TargetRulesFlags = ();

# PLATFORM ROUTINES ###########################################
# Platform Description
# Platform Description consists of
#   OS/Platform Name
#   Executables used on the platform for builds:
#     - Precompilers (idl, proc)
#     - Compilers (gcc, cc, cl.exe)
#     - Linkers (ld, link)
#
#   For each executable we need to know:
#     - Flag prefix (- /)
#     - Output flag (-o /Fo /out:) and modifiers (-c /c)
#     - Standard flags

# Initalize/reset platform description
sub InitializePlatformConfiguration
{
    $OS = "";
    @PlatformFinalTargetExts = ();

    @Executables = ();
    %FlagPrefixes = ();
    %OutputFlag = ();
    %DerivedOutput = ();
    %StandardFlags = ();
    %DependencyExcludeFilters = ();
}

# Load the platform description
#
# Paramters: <Platform Configuration File> [Die on Error]
#
# The format of the file is XML-ish
# See the example .cfg file for details
sub LoadPlatformConfiguration
{
    my $PlatCfgFile = shift @_;
    my $DieOnError = shift @_;

	if (!$PlatCfgFile) {
      print "Configuration file not specified!\n" if ($AllowCommonOutput);
      die if ($DieOnError);
      return 0;
    }

    if (!open(CFGFILE, "$PlatCfgFile")) {
	print "Couldn't open configuration file $PlatCfgFile\n" if ($AllowCommonOutput);
	die if ($DieOnError);
	return 0;
    }

    my $atLine = 0;
    my $line;
    my $tag;

    my $CurrentExecutable;
    my $CurrentExecutable = "";
    my $CurrentFlagPrefix = "";
    my $CurrentOutputFlag = "";
    my $CurrentStandardFlags = "";
    my $CurrentDependencyExcludeFilters = "";

    print "Loading platform configuration from $PlatCfgFile...\n" if ($AllowCommonOutput);
    
    # Read in configuration file line by line
    while ($line = <CFGFILE>) {
	$atLine++;
	chomp($line);
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;

	# Ignore whitespace or comment (#) lines
	if (!$line || $line =~ /^#/) {
	    next;
	}

	# Most of these checks are to make sure proper syntax is followed.
	# Primarily makes sure EXECUTABLE tags need to be closed.
	if ($Marker =~ /PLATFORM/) {
	    if ($line eq "/PLATFORM") {
		# End of PLATFORM section
		if ($Marker ne "PLATFORM" || $CurrentExecutable) {
		    # Can't close PLATFORM section if it was never open
		    # or if we're still working on an EXECUTABLE section
		    print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
		    die if ($DieOnError);
		    return 0;
		}
		
		$Marker ="";
	    }
	    elsif ($line =~ /OS/) {
		# OS tag
		$line =~ s/^(\S*)\s*//;
		$tag = $1;

		$OS = $line;
	    }
	    elsif ($line =~ /TARGET/) {
		# TARGET extensions tag
		$line =~ s/^(\S*)\s*//;
		$tag = $1;

		@PlatformFinalTargetExts = split(/\s+/, $line);
	    }
	    elsif ($line eq "/EXECUTABLE") {
		# End of EXECUTABLE section
		if (!$CurrentExecutable) {
		    # Can't close EXECUTABLE section if we're not in one
		    print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
		    die if ($DieOnError);
		    return 0;
		}

		# Save executable information
		DefineExecutable($CurrentExecutable, 
				 $CurrentFlagPrefix,
				 $CurrentOutputFlag, 
				 $CurrentDerivedOutput,
				 $CurrentStandardFlags, 
				 $CurrentDependencyExcludeFilters);

		# Clear out saved information
		$CurrentExecutable = "";
		$CurrentFlagPrefix = "";
		$CurrentOutputFlag = "";
		$CurrentDerivedOutput = "";
		$CurrentStandardFlags = "";
		$CurrentDependencyExcludeFilters = "";

		# Back to PLATFORM section
		$Marker = "PLATFORM";
		next;
	    }
	    else {
		# Break apart line into TAGs and contents
		$line =~ s/^(\S*)\s*//;
		$tag = $1;

		if ($tag eq "EXECUTABLE") {
		    # Beginning of EXECUTABLE section
		    if ($CurrentExecutable) {
			# Can't start a new EXECUTABLE section without 
			# closing the current one
			print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }

		    $CurrentExecutable = $line;
		}
		else {
		    # Can't process executable information if we're not
		    # in an EXECUTABLE section
		    if (!$CurrentExecutable) {
			print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }
		    
		    # Save executable information
		    # It's processed when we close up the EXECUTABLE section
		    if ($tag eq "FLAG_PREFIX") {
			$CurrentFlagPrefix = $line;
		    }
		    elsif ($tag eq "OUTPUT_FLAG") {
			$CurrentOutputFlag = $line;
		    }
		    elsif ($tag eq "DERIVE_OUTPUT") {
			$CurrentDerivedOutput = $line;
		    }
		    elsif ($tag eq "STANDARD_FLAGS") {
			$CurrentStandardFlags = $line;
		    }
		    elsif ($tag eq "DEPENDENCY_EXCLUDE_FILTERS") {
			$CurrentDependencyExcludeFilter = $line;
		    }
		    else {
			# The TAG isn't valid
			print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }
		}
	    }
	}
	else {
	    if ($CurrentExecutable) {
		print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
		die if ($DieOnError);
		return 0;
	    }

	    if ($line eq "PLATFORM") {
		$Marker = $line;
	    }
	    else {
		# The TAG isn't recognized
		print "\nParsing error ($PlatCfgFile : $atLine)\n" if ($AllowCommonOutput);
		die if ($DieOnError);
		return 0;
	    }
	}
    }

    # Filter out non-.exe/.com/.bat executables in Windows
#    if ($IsWindows) {
#	@Executables = grep(/\.(exe|com|bat)/, @Executables);
#    }

    print "Platform: $OS\n" if ($AllowCommonOutput);
    print "Targets: " . join(" ", @PlatformFinalTargetExts)  if ($AllowCommonOutput);
    print "\n"  if ($AllowCommonOutput);

    print "Executables:\n  " . join("\n  ", @Executables) . "\n\n" if ($AllowCommonOutput);

    return 1;
}

# Saves the currently defined platform description
#
# Paramters: [Platform Configuration File] [Die on Error]
# Will default to $OS.cfg if parameter not specified
#
# The format of the file is XML-ish
# See the example .cfg file for details
sub SavePlatformConfiguration
{
    my $PlatCfgFile = shift @_;
    my $DieOnError = shift @_;

    # If a filename isn't specified, default to [OS].cfg
    if (!$PlatCfgFile) {
	$PlatCfgFile = $OS . ".cfg";
    }

    if (!open (PLATFORMCFG, ">$PlatCfgFile")) {
	print "Couldn't write to $PlatCfgFile!\n" if ($AllowCommonOutput);
	die if ($DieOnError);
	return 0;
    }

    # Save general platform information
    print "Saving platform configuration to $PlatCfgFile...\n"  if ($AllowCommonOutput);
    print PLATFORMCFG "PLATFORM\n";
    print PLATFORMCFG " OS $OS\n";
    print PLATFORMCFG " TARGET " . join(" ", @PlatformFinalTargetExts) . "\n";
    
    # Save individual executable information
    foreach $Exe (@Executables) {
	print PLATFORMCFG " EXECUTABLE $Exe\n";
	print PLATFORMCFG "  FLAG_PREFIX $FlagPrefixes{$Exe}\n";
	print PLATFORMCFG "  OUTPUT_FLAG $OutputFlag{$Exe}\n";
	print PLATFORMCFG "  DERIVE_OUTPUT $DerivedOutput{$Exe}\n" if ($DerivedOutput{$Exe});
	print PLATFORMCFG "  STANDARD_FLAGS $StandardFlags{$Exe}\n";
	print PLATFORMCFG "  DEPENDENCY_EXCLUDE_FILTERS $DependencyExcludeFilters{$Exe}\n";
	print PLATFORMCFG " /EXECUTABLE\n";
    }

    print PLATFORMCFG "/PLATFORM\n";

    close (PLATFORMCFG);

    print "\n" if ($AllowCommonOutput);

    return 1;
}

# Routine for defining a platform executable
#
# Parameters: <Exe> <Flag Prefixes> <Output Flag> <Derived Output Rules>
#             <Standard Flags> <Dependency Exclude Filters>
# All parameters should be strings
#
# Should be called by user interface routines to add/modify a platform
# executable
sub DefineExecutable
{
    (my $exe, 
     my $flagPrefixes, 
     my $outputFlag, 
     my $derivedOutput,
     my $standardFlags, 
     my $dependencyExcludeFilters) = @_;

    push(@Executables, $exe);
    $FlagPrefixes{$exe} = $flagPrefixes;
    $OutputFlag{$exe} = $outputFlag;
    $DerivedOutput{$exe} = $derivedOutput;
    $StandardFlags{$exe} = $standardFlags;
    $DependencyExcludeFilters{$exe} = $dependencyExcludeFilters;
}

# Remove an executable from the platform
#
# Parameters: <Executable>
#
# Removes all references to the specified executable from the
# platform structures
sub RemoveExecutable
{
    my $exe = shift @_;

    @Executables = grep(!/\Q$exe\E/, @Executables);
    delete $FlagPrefixes{$exe};
    delete $OutputFlag{$exe};
    delete $DerivedOutput{$exe};
    delete $StandardFlags{$exe};
    delete $DependencyExcludeFilters{$exe};
}

# Copies capture utility to appropriate executable name
# and creates a wrapper script to call the capture exe 
# in addition to the actual executable
#
# No parameters
#
# Requires the "which" command
# Standard on Unix
# Bundled with Openmake on Windows
sub CreateWrappers
{
    my $inDir = shift @_;
    my $cwd = cwd();
    $inDir = $cwd if (!$inDir);
    my $CaptureExe = FirstFoundInPath("capture");

    my @executables = @Executables;

    # Filter out non-.exe/.com/.bat executables in Windows
    if ($IsWindows) {
#	@executables = grep(/\.(exe|com|bat)/, @executables);
    }

    # Creates wrapper/ and bin/ subdirectories
    mkfulldir("$inDir/wrapper") if (!-d "$inDir/wrapper");
    mkdir "$inDir/bin" if (!-d "$inDir/bin");

    if (!-d "$inDir/wrapper" || !-d "$inDir/bin") {
	print "Couldn't create subdirectories\n"  if ($AllowCommonOutput);
	return 0;
    }

    if (!-f $CaptureExe) {
	print "Could not find capture executable $CaptureExe!\n" if ($AllowCommonOutput);
	return 0;
    }

    print "Setting up capture utility wrapper scripts...\n" if ($AllowCommonOutput);
    if (!@executables) {
	print "No executables specified for platform!\n" if ($AllowCommonOutput);
	return 0;
    }

    my $cwd = cwd();
    if ($IsWindows) {
	$cwd =~ s/\//\\/g;
    }

    $rc = 1;
    # Loop through defined executables
    foreach my $exe (@executables) {
	# Find location of real executable
	my @which;
	if ($IsWindows) {
	  @which = `which $exe 2> nul`;
	}
	else 
	{
	  @which = `which $exe 2>/dev/null`;
	}
	my $which = shift @which;
	chomp($which);
	if (!$which) {
	    print "$exe is not in the PATH!\n" if ($AllowCommonOutput);
	    $rc = -1;
	    next ;
	}
	else {
	    print "Found $exe: $which\n"  if ($AllowCommonOutput);
	}

	# Change name to .exe if Windows
	if ($IsWindows) {
	    $exe =~ s/\.(com|bat)$/.exe/;
	}

	# Copy capture executable to bin/ with the appropriate name
	print "Copying capture executable to bin/$exe\n"  if ($AllowCommonOutput);
	copy ("$CaptureExe", "$inDir/bin/$exe");
	if (!-f "$inDir/bin/$exe") {
	    print "Couldn't copy $CaptureExe to $inDir/bin/$exe!\n" if ($AllowCommonOutput);
	    $rc = -1;
	    next ;
	}
        chmod 0755, "$inDir/bin/$exe";

	# Create wrapper to capture the command line and run the
	# actual executable
	my $WrapperFile = "$inDir/wrapper/$exe";
	my $WrapperText;
	if ($IsWindows) {
	    $cwd =~ s/\//\\/g;
	    $WrapperFile =~ s/\.exe$/.bat/;
	    $WrapperText =<<WINWRAP;
\@echo off
$inDir\\bin\\$exe \%*
$which \%*
WINWRAP
	}
	else {
	    $WrapperText = <<SHWRAP;
\#!/bin/sh

$inDir/bin/$exe \$*
$which \$*
SHWRAP
	}

	print "Creating wrapper $WrapperFile\n" if ($AllowCommonOutput);
	if (!open (WRAPPER, ">$WrapperFile")) {
	    print "Couldn't create wrapper file $WrapperFile!\n" if ($AllowCommonOutput);
	    $rc = -1;
	    next ;
	}
	print WRAPPER "$WrapperText\n";
	close(WRAPPER);

	print "\n" if ($AllowCommonOutput);
	chmod 0755, $WrapperFile;
    }

    my $WrapperDir = "$inDir/wrapper";
    if ($IsWindows) {
	$WrapperDir =~ s/\//\\/g;
    }

    print "Please add $WrapperDir to your PATH.\n"  if ($AllowCommonOutput);
    print "\n"  if ($AllowCommonOutput);

    return $rc;
}

# Creates the full directory structure for the specified directory
#
# Parameters: <Directory to create>
#
# From Openmake.pm
sub mkfulldir {
 my($Path) = @_;
 my(@Dirs,$Dir,$newdir);

 $Path=~ s/\"//g; # Strip quotes "
 $Path=~ s/\\/\//g; 
 $newdir = '';
 
 @Dirs = split(/\//, $Path);

 foreach $Dir (@Dirs) {
  if ($Dir !~ /:$/)  {
   $newdir .= $Dir;

   # Works with unix slashes for all os's
   mkdir $newdir, 0777; 
 
   $newdir .= '/';
  } else {
   $newdir = $Dir . '/';
  }
 }
}

# PLATFORM ROUTINES ###########################################

# OPENMAKE BUILDTYPES ROUTINES ################################
# Openmake Build Types Description
#
# Openmake Build Types consists of
#   Default Build Type
#   Build Type (Executable, Library, etc.)
#     - Final target
#     - Rules
#
#   For each rule:
#       - Executable used by rule
#       - Command-line arguments used by rule

# Initialize/reset Openmake Build Type information
sub InitializeBuildTypes
{
    $DefaultBuildType = "";
    @BuildTypes = ();
    %BuildTypeFinalTarget = ();
    %BuildTypeGenerateTarget = ();
    %BuildTypeRulesExe = ();
    %BuildTypeRulesFlags = ();
}

# Load Openmake Build Type information for platform 
#
# Parameter: <Openmake Build Type Configuration File> [Die on Error]
#
# The format of the file is XML-ish
# See the example .cfg file for details
sub LoadBuildTypes
{
    my $OMCfgFile = shift @_;
    my $DieOnError = shift @_;

    if (!$OMCfgFile) {
	print "Configuration file not specified!\n" if ($AllowCommonOutput);
	die if ($DieOnError);
	return 0;
    }

    if (!open(CFGFILE, "$OMCfgFile")) {
	print "Couldn't open configuration file $OMCfgFile\n" if ($AllowCommonOutput);
	die if ($DieOnError);
	return 0;
    }

    my $atLine = 0;
    my $line;
    my $tag;

    my $CurrentBuildType;
    my $CurrentRule;
    my $CurrentKey;

    print "Processing Openmake Build Types from $OMCfgFile...\n" if ($AllowCommonOutput);

    # Read in configuration file line by line
    while ($line = <CFGFILE>) {
	$atLine++;
	chomp($line);
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;

	# Ignore whitespace and comment (#) lines
	if (!$line || $line =~ /^#/) {
	    next;
	}

	if ($Marker =~ /BUILDTYPES/) {
	    if ($line eq "/BUILDTYPES") {
		if ($Marker ne "BUILDTYPES") {
		    # Can't close BUILDTYPES if it wasn't open
		    print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
		    die if ($DieOnError);
		    return 0;
		}
		
		$Marker ="";
	    }
	    elsif ($line eq "/BUILDTYPE") {
		# Can't close BUILDTYPES section if we're currently
		# in either a BUILDTYPE or RULE
		if (!$CurrentBuildType || $CurrentRule) {
		    print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
		    die if ($DieOnError);
		    return 0;
		}

		$CurrentBuildType = "";
	    }
	    else {
		# Break apart line into TAGs and contents
		$line =~ s/^(\S*)\s*//;
		$tag = $1;

		if ($tag eq "DEFAULT") {
		    if ($CurrentBuildType || $CurrentRule) {
			# Can't be in here if we're currently in a BUILDTYPE
			# or RULE
			print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }

		    # Assign DEFAULT Build Type
		    $DefaultBuildType = $line;
		}
		elsif ($tag eq "BUILDTYPE") {
		    if ($CurrentBuildType || $CurrentRule) {
			# Can't open a new BUILDTYPE if we're currently in
			# a BUILDTYPE or RULE
			print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }

		    $CurrentBuildType = $line;
		    push(@BuildTypes, $CurrentBuildType);
		}
		else {
		    if (!$CurrentBuildType) {
			# Must be in a BUILDTYPE to save its information
			print "\nParsing error ($OMCfgFile : $atLine)\n"  if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }

		    if ($tag eq "FINAL_TARGET") {
			# Build Type final target extension
			$BuildTypeFinalTarget{$CurrentBuildType} = $line;
		    }
		    elsif ($tag eq "GENERATE_TARGET") {
			# Build Type generated target extension
			$BuildTypeGenerateTarget{$CurrentBuildType} = $line;
		    }
		    elsif ($tag eq "/RULE") {
			if (!$CurrentRule) {
			    # Can't close a RULE section if we're not in one
			    print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			    die if ($DieOnError);
			    return 0;
			}

			$CurrentRule = "";
			$CurrentKey = "";
		    }
		    elsif ($tag eq "RULE") {
			if ($CurrentRule) {
			    # Can't open a new RULE if we're still in one
			    print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			    die if ($DieOnError);
			    return 0;
			}

			$CurrentRule = $line;
			$CurrentKey = $CurrentBuildType . "|" . $CurrentRule;
		    }
		    elsif ($tag eq "EXECUTABLE") {
			if (!$CurrentRule) {
			    # Can't save RULE information
			    print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			    die if ($DieOnError);
			    return 0;
			}

			# RULE's executable
			$BuildTypeRulesExe{$CurrentKey} = $line;
		    }
		    elsif ($tag eq "FLAGS") {
			if (!$CurrentRule) {
			    # Can't save RULE information
			    print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			    die if ($DieOnError);
			    return 0;
			}

			# RULE's flags
			$BuildTypeRulesFlags{$CurrentKey} = $line;
		    }
		    else {
			# TAG not recognized
			print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
			die if ($DieOnError);
			return 0;
		    }
		}
	    }
	}
	else {
	    if ($CurrentBuildType || $CurrentRule) {
		# Couldn't have closed BUILDTYPES section if we're in
		# a BUILDTYPE or RULE
		print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
		die if ($DieOnError);
		return 0;
	    }

	    if ($line eq "BUILDTYPES") {
		# Start of BUILDTYPES section
		$Marker = $line;
	    }
	    else {
		# TAG not recognized
		print "\nParsing error ($OMCfgFile : $atLine)\n" if ($AllowCommonOutput);
		die if ($DieOnError);
		return 0;
	    }
	}
    }

    return 1;
}

# Saves Openmake Build Type information for platform 
#
# Parameter: [Openmake Build Type Configuration File] [Die on Error]
# Will default to Openmake.cfg if configuration file not specified
#
# The format of the file is XML-ish
# See the example .cfg file for details
sub SaveBuildTypes
{
    my $OMCfgFile = shift @_;
    my $DieOnError = shift @_;

    if (!$OMCfgFile) {
	$OMCfgFile = "Openmake.cfg";
    }

    if (!open (OMCFG, ">$OMCfgFile")) {
	print "Couldn't write to $OMCfgFile!\n" if ($AllowCommonOutput);
	die if ($DieOnError);
	return 0;
    }

    print "Saving platform configuration to $OMCfgFile...\n" if ($AllowCommonOutput);

    # Save general Build Type information
    print OMCFG "BUILDTYPES\n";
    print OMCFG " DEFAULT $DefaultBuildType\n" if ($DefaultBuildType);

    # Loop through Build Types
    foreach $BuildType (@BuildTypes) {
	print OMCFG " BUILDTYPE $BuildType\n";
	print OMCFG "  FINAL_TARGET $BuildTypeFinalTarget{$BuildType}\n";
	print OMCFG "  GENERATE_TARGET $BuildTypeGenerateTarget{$BuildType}\n" if $BuildTypeGenerateTarget{$BuildType};

	@Rules = keys(%BuildTypeRulesExe);
	@Rules = grep(/^\Q$BuildType\E\|/, @Rules);
	@Rules = sort(@Rules);

	# Loop through Rules
	foreach $Rule (@Rules) {
	    $PrintRule = $Rule;
	    $PrintRule =~ s/^\Q$BuildType\E\|//;
	    print OMCFG "  RULE $PrintRule\n";
	    print OMCFG "   EXECUTABLE $BuildTypeRulesExe{$Rule}\n";
	    print OMCFG "   FLAGS $BuildTypeRulesFlags{$Rule}\n";
	    print OMCFG "  /RULE\n";
	}
	
	print OMCFG " /BUILDTYPE\n";
    }

    print OMCFG "/BUILDTYPES\n";

    close (OMCFG);

    print "\n" if ($AllowCommonOutput);

    return 1;
}

# Routine for defining a Build Type
#
# Parameters: <Build Type>, <Final Target Ext>, [Generated Target Ext]
#
# Should be called by user interface routines in order to add/modify
# Build Types
sub DefineBuildType
{
    (my $buildType, my $finalTarget, my $generateTarget) = @_;
    push(@BuildTypes, $buildType);
    @BuildTypes = unique(@BuildTypes);
    $BuildTypeFinalTarget{$buildType} = $finalTarget;
    $BuildTypeGenerateTarget{$buildType} = $generateTarget;
}

# Routine for defining a new Build Type Rule
#
# Parameters: <Build Type>, <Rule>, <Executable>, <Flags>
#
# Should be called by user interface routines in order to add/modify
# Build Type Rules
sub DefineBuildTypeRule
{
    (my $buildType, my $rule, my $exe, my $flags) = @_;
    my $key = "$buildType|$rule";
    $BuildTypeRulesExe{$key} = $exe;
    $BuildTypeRulesFlags{$key} = $flags;
}

# Routine for removing a Build Type
#
# Parameters: <Build Type>
#
# Should be called by user interface routines in order to remove
# a defined Build Type
sub RemoveBuildType
{
    my $buildType = shift @_;

    @BuildTypes = grep(!/^\Q$buildType\E$/, @BuildTypes);

    delete $BuildTypeFinalTarget{$buildType};
    delete $BuildTypeGenerateTarget{$buildType};

    my @keys = keys(%BuildTypeRulesExe);
    @keys = grep(/^\Q$buildType\E\|/, @keys);
    foreach my $key (@keys) {
	delete $BuildTypeRulesExe{$key};
	delete $BuildTypeRulesFlags{$key};
    }
}

# Routine for removing a Build Type Rule
#
# Parameters: <Build Type>, <Rule>
#
# Should be called by user interface routines in order to remove
# a defined Build Type Rule
sub RemoveBuildTypeRule
{
    my $buildType = shift @_;
    my $rule = shift @_;

    my $key = "$buildType|$rule";
    delete $BuildTypeRulesExe{$key};
    delete $BuildTypeRulesFlags{$key};    
}
# OPENMAKE BUILDTYPES ROUTINES ################################

# BUILD OUTPUT PROCESSING ROUTINES ############################
# Initializes (and resets) parsed command-line structures
sub InitializeParsing
{
    %ParsedTargetDeps = ( );
    %ParsedTargetArgs = ( );
}

# Reads in file with captured command lines and initiates parsing
#
# Parameters: [Build Output File]
# Will default to STDIN if Build Output File not specified
# 
# Locates text between BEGIN/END capture blocks.  ParseCommandLine() 
# is called to actually perform the command-line parsing.
sub ProcessCommandFile
{
    my $inFile = shift @_;
    my $DieOnError = shift @_;

    # Open input file or duplicate STDIN if no file specified
    if ($inFile) {
    	if (!open(INPUT, "$inFile")) {
    		print "Couldn't open input file $inFile\n" if ($AllowCommonOutput);
    		die if ($DieOnError);
    		return 0;
    	}
    }
    else {
    	if (!open(INPUT, "<&STDIN")) {
    		print "Couldn't duplicate STDIN!" if ($AllowCommonOutput);
    		die if ($DieOnError);
    		return 0;
    	}
    }
    
    my $inCommand = 0;
    my $command = "";
    
    print "Processing commands....\n" if ($AllowCommonOutput);
    while (my $line = <INPUT>) {
	chomp($line);
	$line =~ s/^\s+//;
	if ($inCommand) {
	    if ($line =~ /\Q$CAPTURE_END\E/) {
		# End of command-line capture
		$inCommand = 0;
		$command =~ s/\s+$//;
		ParseCommandLine($command);
	    }
	    else {
		# Add line as part of command-line text
		# [in case command-line is broken up across
		# multiple lines]
		$command .= "$line ";
	    }
	}
	elsif ($line =~ /^\#/) {
	    if ($line =~ /\Q$CAPTURE_BEGIN\E/) {
		# Beginning of command-line capture
		$inCommand = 1;
		$command = "";
	    }
	    elsif ($line =~ /\Q$ERROR\E/) {
		# Detect errors in capture (follows end of capture)
		# Don't do anything at the moment...
	    }
	}
    }

	return 1;
}

# Parses the command line
#
# Parameter: <command line>
#
# Information obtained from command-line:
#   - Compiler/linker executable
#   - Flags
#   - Source
#   - Target
# 
# This information is stored in the %ParsedTargetDeps and %ParsedTargetArgs
# for further processing
sub ParseCommandLine
{
    my $line = shift @_;

    # Split the captured line into its individual arguments
    my @args = SmartSplit($line);

    # First argument is the compiler/linker
    my $exe = shift @args;

    # Match compiler/linker to one that's been defined 
    my $matchedExe = "";
    for ($i = 0; $i < @Executables && !$matchedExe; $i++) {
		if (($IsWindows && $exe =~ /\Q$Executables[$i]\E$/i) ||
		    (!$IsWindws && $exe =~ /\Q$Executables[$i]\E$/)) {
		    $matchedExe = $Executables[$i];
		}
    }

    # Return if a match isn't found
    # Shouldn't happen if the platform is properly defined but just in case...
    if (!$matchedExe) {
	print "$exe not defined in configuration!\n"  if ($AllowCommonOutput);
	print "$line\n\n" if ($AllowCommonOutput);
	return;
    }

    # Find the output...
    my @flags = split(/\s+/, $OutputFlag{$matchedExe});

    # Can't identify the output if we don't have any flag specifications
    # Also shouldn't happen...
    if (!@flags) {
	print "No output flags specified for $matchedExe!\n" if ($AllowCommonOutput);
	print "$line\n\n" if ($AllowCommonOutput);
	return;
    }

    # Identify the proper output flag
    my $matchedOutputFlag = "";
    for ($i = 0; $i < @flags && !$matchedOutputFlag; $i++) {
	# Split if we find a "|".  Need to match both flags in the set.
	# Examples: -o, /out:, -o|-c, /Fo|//c
	my $atFlag = $flags[$i];
	my $atFlagModifier = "";
	if ($atFlag =~ /(.+)\|(.+)/) {
	    $atFlag = $1;
	    $atFlagModifier = $2;
	}

	# Look for the actual output flag?
	my @testAtFlag = grep(/^\Q$atFlag\E/, @args);
	my @testAtFlagModifier = ();

	# Look for the modifier flag (if we need to)
	if ($atFlagModifier) {
	    @testAtFlagModifier = grep(/^\Q$atFlagModifier\E/, @args);
	}
	
	# Did we find a match?
	if (@testAtFlag && 
	    (($atFlagModifier && @testAtFlagModifier) || !$atFlagModifier)) {
	    $matchedOutputFlag = $atFlag;
	}
    }
    
    # Get output file (from the matched output flag)
    my $Target = "";
    for ($i = 0; $i < @args && !$Target; $i++) 
    {
	$atFlag = $args[$i];
	if ($atFlag =~ /\Q$matchedOutputFlag\E/) {
	    $atFlag =~ s/\Q$matchedOutputFlag\E//;
	    if (!$atFlag) {
		$i++;
		$atFlag = $args[$i];
	    }
	    
	    $Target = $atFlag;
	    $Target =~ s/^\"//;
	    $Target =~ s/\"$//;
	}
    }
    
    # If we didn't locate a target, let's see if we can derive it
    # Rules for deriving the output must be specified 
    if (!$Target && $DerivedOutput{$matchedExe}) {
	my @DerivedRules = split(/,+/, $DerivedOutput{$matchedExe});
	for ($i = 0; $i < @DerivedRules && !$Target; $i++) {
	    $DeriveRule = trim($DerivedRules[$i]);
	    
	    # Example .c -> .o
	    if ($DeriveRule =~ /(.*)-\>(.*)/) {
		my $from = trim($1);
		my $to = trim($2);

		my $fromRE = GenerateRE($from);
		my $toRE = GenerateRE($to);
		my @DeriveFrom = grep(/$fromRE$/, @args);
		if (@DeriveFrom) {
		    $Target = shift @DeriveFrom;
		    print "  $Target => " if ($AllowCommonOutput);
		    $Target =~ s/$fromRE$/$to/;
		    print "$Target\n\n"  if ($AllowCommonOutput);
		}
	    }
	}
	
	if (!$Target) {
	    print "  Could not derive target!\n\n" if ($AllowCommonOutput);
	}
    }

    # Return if we still can't identify the target
    if (!$Target) {
	# No target found!
	print "Failed to find target!\n" if ($AllowCommonOutput);
	print "$matchedExe : $matchedOutputFlag\n" if ($AllowCommonOutput);
	print "$line\n\n" if ($AllowCommonOutput);
	return ;
    }
    
    # Remove standard flags (so they don't show up as dependencies)
    # We need to separate out DEFINES (with spaces) since we can't use
    # the grep() filter with them.  
    @flags = SmartArgSplit($StandardFlags{$matchedExe}, $FlagPrefixes{$matchedExe});
    my @defines = grep(/\s/, @flags);
    @flags = grep(!/\s/, @flags);
    foreach $flag (@flags) {
	@args = grep(!/\Q$flag\E/, @args);
    }

    # Reconstruct the command-line and filter out the DEFINES
    $line = join(" ", @args);
    foreach my $define (@defines) {
	$line =~ s/\Q$define\E//;
    }

    # Split the command-line back up
    @args = SmartSplit($line);

    # Locate dependencies
    my @dependencies = (); 
    my @foundDeps = ();
	
    # If we have a list of dependencies extensions (ie rules have been
    # defined), then use it.  Otherwise anything that isn't a flag is 
    # a possible dependency.
    if (@DependencyExts) {
	foreach $ext (@DependencyExts) 
	{
	    @foundDeps = grep(/\Q$ext\E\"*$/, @args);
	    if (@foundDeps) {
		push(@dependencies, @foundDeps);
	    }
	}
	
	# Filter out using the DependencyFilters
	foreach $exclude (@DependencyExcludeFilters) 
	{
	    @dependencies = grep(!/\Q$exclude\E/, @dependencies);
	}
    }
    else {
	@foundDeps = @args;

	my @flagPrefix = split(/\s+/, $FlagPrefixes{$matchedExe});
	foreach my $flagPrefix (@flagPrefix) {
	    @foundDeps = grep(!/^\Q$flagPrefix\E/, @foundDeps);
	}
	
	# Dependencies on a command-line must have an extension!
	@foundDeps = grep(/\.[^\.]*/, @foundDeps);
	
	if (@foundDeps) {
	    push(@dependencies, @foundDeps);
	}
    }

    # Clean up and sort the dependencies
    foreach (@dependencies) {
	s/^[^\"]*\"//;
	s/\"$//;
    }
    @dependencies = sort(@dependencies);

    # Filter out target from the dependencies list
    @dependencies = grep(!/^\Q$Target\E$/, @dependencies);

    # Construct the list of remaining arguments
    # First we need to filter out the target and dependencies...
    @args = grep(!/\Q$Target\E/, @args);
    foreach $dep (@dependencies) {
	@args = grep(!/\Q$dep\E/, @args);
    }

    # An argument tag is prepended to the remaining arguments list
    # It'll help identify what was used to create the particular target
    # Used for constructing the target's build steps and rules
    my $argTag = "$matchedExe $matchedOutputFlag";
    $argTag .= " $atFlagModifier" if ($atFlagModifier); 
    my $args = join(" ", @args);

    # Place the parsed information into the ParsedTarget hashtables
    $ParsedTargetDeps{$Target} = join("|", @dependencies);
    $ParsedTargetArgs{$Target} = $argTag . "|" . $args;

    print "Target: $Target\n" if ($AllowCommonOutput);
    print "Dependencies: " . join("\n\t\t", @dependencies) . "\n" if ($AllowCommonOutput);
    print "Arg tag: $argTag\n" if ($AllowCommonOutput);
    print "Remaining Args: $args\n\n" if ($AllowCommonOutput);
}
# BUILD OUTPUT PROCESSING ROUTINES ############################

# TARGET PROCESSING ROUTINES ############################
# Initializes/resets all the structures used in processing
# the parsed information to determine targets and their 
# corresponding build steps and rules
sub InitializeTargetProcessing {
    @FinalTargets = ();

    %TargetDeps = ();

    %TargetAllBuildSteps = ();    

    %TargetBuildStepDepExts = ();
    %TargetBuildStepArgs = ();
    %TargetArgDifferences = ();
    
    %TargetRulesExe = ();
    %TargetRulesFlags = ();
}

# "Best guess" to determine top-level targets
#
# Two methods:
#   1.  If a @FinalTargetExts array is populated, use its entries
#   2.  Find all the targets that are not also a dependency
# 
# There are limitations to both:
#   1.  Searching for extensions may find too many final targets
#   2.  Searching for "final" targets may find too little
#
# Some manual intervention may be necessary (especially if the build
# uses libraries).  Once the list is created, it can be manipulated
# until it's just right.
sub GetFinalTargets
{
    # Initialize Final Targets list
    @FinalTargets = ();

    # Get all the parsed targets
    my @TargetList = keys(%ParsedTargetDeps);
    my $target;

    # If we have a list of specific extensions to look for, use those
    # Otherwise, we have to make a best guess
    if (@FinalTargetExts) {
	# Loop through specified extensions and find matches
	foreach my $finalExt (@FinalTargetExts) 
	{
	    if ($finalExt eq ".noext") {
		# .noext targets don't have a real extension
		# so we need to look for them separately
		foreach my $target (@TargetList) {
		    if ($target !~ /\.[A-Za-z0-9]*$/) {
			push(@FinalTargets, $target);
		    }
		}
	    }
	    else {
		# Use a grep filter to match
		# Since we're allowing wildcards, we can't do \Q\E
		$finalExtRE = GenerateRE($finalExt);
		push(@FinalTargets, grep(/$finalExtRE$/, @TargetList)); 
	    }
	}
    }
    else {
    	# Generate array of _all_ dependencies
	# This is easier than going through everything one-by-one
	# every single time
    	my @AllDependencies = ();
    	foreach $target (@TargetList) {
	    push(@AllDependencies, $ParsedTargetDeps{$target} . "|");
	}
    	
    	# Run through the targets and make sure they don't appear 
	# in any dependency list
    	foreach $target (@TargetList) {
	    @isDep = grep(/\Q$target\E\|/, @AllDependencies);
	    if (!@isDep) {
		push (@FinalTargets, $target);	
	    }
    	}
    }

    # Sort the array...
    @FinalTargets = sort(@FinalTargets);

    print "Found top-level targets:\n  " . join("\n  ", @FinalTargets) . "\n\n" if ($AllowCommonOutput);
}

# Process the top-level targets
# 
# Parameters: [List of top-level targets]
# Will use the @FinalTargets list if a top-level list isn't specified
#
# Processes the top-level targets to:
#   - Generate a complete dependency list for a target
#       ProcessTargetDeps()
#   - Identify all the build steps used to build a target
#       ProcessTargetBuildSteps()
#   - Identift the rules used to build a target
#       ProcessTargetRules()
sub ProcessTargets
{
    my @topLevelTargets = @_;

    if (!@topLevelTargets) {
	@topLevelTargets = @FinalTargets;
    }
    else {
	@FinalTargets = @topLevelTargets;
    }

    # Loop through all the specified targets
    foreach my $target (@topLevelTargets) {
	# Identify the actual targets
	my @ProcessedDeps = ProcessTargetDeps($target);

	# Clean-up the dependency specification
	# If it's another top-level target, use the whole identified
	# path and filename. Otherwise, we just want the filename
	foreach $dep (@ProcessedDeps) {
	    if (!grep(/\Q$dep\E/, @topLevelTargets)) 
	    {
		$dep =~ s/.*[\\\/]([^\\\/]+)/$1/;
	    }
	}
	@ProcessedDeps = unique(sort(@ProcessedDeps));
	my $DepList = join("|", @ProcessedDeps);
	$TargetDeps{$target} = $DepList;

	# Identify build steps and rules
	ProcessTargetRules($target);
    }
}

# Get processed information on a specific target
#
# Parameter: <Target>
# Returns: String
#
# Returns an output array with the following information on the target:
#   - Target name
#   - Dependencies list
#   - Rules
#   - Any build steps with unique arguments
sub GetTargetInfo
{
    my $target = shift @_;
	my $nodeps = shift @_;
	
	my $output = "";
    # Output basic target information
    $output .= "$target :\n";
    my $targetDeps = $TargetDeps{$target};
    if (!$nodeps) {
    if ($targetDeps) 
    {
	$output .= "  DEPENDENCIES\n";
	foreach my $dep  (split(/\|/, $targetDeps)) {
	  $output .= "    $dep\n";
	}
    }
    $output .= "\n";
    }
    
    # List out build rules
    $output .= "  RULES\n";
    my @ProcessedRules = keys(%TargetRulesExe);
    @ProcessedRules = grep(/^\Q$target\E\|/, @ProcessedRules);
    foreach my $ruleKey (@ProcessedRules) {
	my $rule = $ruleKey;
	$rule =~ s/^\Q$target\E\|//;
	$output .= "  $rule\n" . 
	           "    $TargetRulesExe{$ruleKey}\n" .
	           "    $TargetRulesFlags{$ruleKey}\n";
    }
    $output .= "\n";
    
    # Output argument differences for a build step (if any)
    my @argDifferences = keys(%TargetArgDifferences);
    @argDifferences = grep(/^\Q$target\E/, @argDifferences);
    
    if (@argDifferences) {
	$output .= "  ARGUMENT DIFFERENCES\n";
	foreach my $argDiffKey (@argDifferences) {
	    my $argDiff = $TargetArgDifferences{$argDiffKey};
	    $argDiff =~ s/^(.*)\|/$1\n    FLAGS /;
	    
	    $output .= "  $argDiffKey\n";
	    $output .= "    EXE $argDiff\n";
	}
	$output .= "\n";
    }
    
    return $output;
}

# Generate the list of a target's real dependencies and prepares the 
# information needed to construct the its build steps and rules
#
# Parameters: <Top-level Target>, [Target], [List of found dependencies]
# Returns: <List of found dependencies>
#
# Given a particular target, searches through the ParsedTargetDeps to identify
# its "real dependencies".  Real dependencies include:
#   - Source (dependencies that are not also targets)
#   - Other "identified" top-level targets
#
# In addition, loads up the structures (%TargetAllBuildSteps and 
# %TargetBuildStepDepExts) used to construct the build steps and rules.
#
# This is a recursive subroutine!
# [Target] is only optional in the top-level call
sub ProcessTargetDeps
{
    my $realTarget = shift @_;
    my $target = shift @_;
    my @foundDeps = @_;

    # Assign the real target as the current target (if not specified)
    $target = $realTarget if (!$target);

    # Get dependencies for current target
    my $targetDeps = $ParsedTargetDeps{$target};
    if (!$targetDeps) 
    {
	# If we can't immediately find the target, maybe it was
	# moved (sometimes up or down a directory level).  We'll
	# search for anything that looks like it.
	#
	# If it's been completely renamed, we can't do anything
	my @parsed = keys(%ParsedTargetDeps);
	my @possible = grep(/\Q$target\E$/, @parsed);
	
	if (@possible) {
	    print "$realTarget: $target was moved from original location $possible[0]\n" if ($AllowCommonOutput);
	    $target = shift(@possible);
	    $targetDeps = $ParsedTargetDeps{$target};
	}
    }

    # If no dependencies exist, push the current target onto the found
    # dependencies list and return
    if (!$targetDeps) {
	push(@foundDeps, $target);
	return @foundDeps;
    }

    # Get the associated command-line 
    my $targetArgs = $ParsedTargetArgs{$target};
    
    # Split of the argTag and actual arguments
    # We need the argTag (exe + output flags) to key the build step
    (my $argTag, $targetArgs) = split(/\|/, $targetArgs);

    # Associate this individual build step with the target
    # Stored in %TargetAllBuildSteps
    my $buildStepKey = $realTarget . "|" . GetExtension($target) . "|" . $argTag;
    
    my $buildStepTargetDepsKey = "$target <- " . $targetDeps;
    $buildStepTargetDepsKey =~ s/\|/,/g;
    $buildStepTargetDepsKey = "$buildStepKey|$buildStepTargetDepsKey";
    $TargetAllBuildSteps{$buildStepTargetDepsKey} = $targetArgs;

    # Run through each found dependency for the build step target 
    # Note: We also grab the dependency extensions to add to the list
    # for this type of build step.  It'll be used in creating the
    # rules for this target
    my @depsList = split(/\|/, $targetDeps);
    my @depExtsList = split(/\s+/, $TargetBuildStepDepExts{$buildStepKey});
    
    foreach my $dep (@depsList) {
    	push(@depExtsList, GetExtension($dep));
	if (grep/\Q$dep\E/, @FinalTargets) {
	    # If the dependency is another top-level target, we don't
	    # need to go any further.  Just push it on the dependency
	    # list and return
	    push(@foundDeps, $dep);
	}
	else {
	    # Recursively call this subroutine again in order to get
	    # the dependencies for the build step target's dependency.  
	    # All of this gets pushed on the foundDeps list.
	    push(@foundDeps, ProcessTargetDeps($realTarget, $dep));
	}
    }

    # Sort through the dependencies extension list and remove duplicates
    # It gets stored back in %TargetBuildStepDepExts
    @depExtsList = unique(sort(@depExtsList));
    $TargetBuildStepDepExts{$buildStepKey} = join(" ", @depExtsList);
    
    return @foundDeps;
}

# Process the target's individual build steps to get the "summary" rules
#
# Parameters: <Target>
# Returns: <List of Target rules>
#
# Goes through all the target's individual build step creates the summary
# entries and rules.
#
# Build steps keyed by target extension and executable plus output flags
# Arguments in summary will be found in all build steps
# Any individual build step that has additional arguments will be noted
sub ProcessTargetRules
{
    my $target = shift @_;

    # Get build steps for the target
    my @allBuildStepKeys = keys(%TargetAllBuildSteps);
    @allBuildStepKeys = grep(/^\Q$target\E\|/, @allBuildStepKeys);

    # Loop through build steps to generate summaries
    while (@allBuildStepKeys) {
	# Get the first build step in the list
	my $buildStepKey = $allBuildStepKeys[0];
	
	# We need to get all build steps like the current one...
	my @keyFields = split(/\|/, $buildStepKey);
	
	# We don't need <target> <- <deps> here
	pop(@keyFields);
	
	# We do need the arg tag (executable plus output flags)
	my $argTag = pop(@keyFields);
	push(@keyFields, $argTag);

	# Isolate just the executable
	my $exe = $argTag;
	if ($argTag =~ /(\S+)\s/) {
	    $exe = $1;
	}

	# Create the look-up filter
	$buildStepKey = join("|", @keyFields);
	
	# Find all the matching keys
	my @matchedBuildStepKeys = grep(/^\Q$buildStepKey\E/, @allBuildStepKeys);
	# Remove the matches from the list of build steps to process
	@allBuildStepKeys = grep(!/^\Q$buildStepKey\E/, @allBuildStepKeys);

	# Run through the build step arguments and find the ones common to
	# all the matched steps.  We use the first step's flag list
	my @buildStepArgs = ();
	my $nToMatch = @matchedBuildStepKeys;
	my @testArgs = SmartArgSplit($TargetAllBuildSteps{$matchedBuildStepKeys[0]}, $FlagPrefixes{$exe});
	
	# Place all the matching build step arguments into a list so
	# we can do just do a grep()
	my @matchedBuildStepArgs = ();
	foreach my $matchedKey (@matchedBuildStepKeys) {
	    push(@matchedBuildStepArgs, $TargetAllBuildSteps{$matchedKey});
	}

	# Test the arguments...
	foreach my $arg (@testArgs) {
	    my @matched = grep(/\Q$arg\E/, @matchedBuildStepArgs);
	    my $didMatch = @matched;
	    if ($nToMatch == @matched) {
		# Argument is common to all matching build steps...
		push(@buildStepArgs, $arg);
	    }
	}

	# These are the common flags for this type of build step...
	$TargetBuildStepArgs{$buildStepKey} = join(" ", @buildStepArgs);
	
	# Find out if there are any steps have additional flags
	foreach my $matchedKey (@matchedBuildStepKeys) {
	    @keyFields = split(/\|/, $matchedKey);
	    my $stepTargetDeps = pop(@keyFields);
	    my $argDiff = GetArgDiff($TargetBuildStepArgs{$buildStepKey}, $TargetAllBuildSteps{$matchedKey}, $FlagPrefixes{$exe});
	    if ($argDiff) {
		$argDiff = $argTag . "|" . $argDiff;
		my $argDiffKey = "$target: $stepTargetDeps";
		$TargetArgDifferences{$argDiffKey} = $argDiff;
	    }
	} 
    }

    # Now that we have the summaries, we can create the rules
    # The summaries are keyed to
    #   <target>|<build step target ext>|<build step exe>
    # Rules are keyed to
    #   <target>|<build step target ext> <- <dep exts>
    # Target rule structures match up with the Build Type rule
    # structures for easy comparison (and creation)

    # Grab the stored summary information on what dependencies 
    # go into a build step target.
    my @rules = keys(%TargetBuildStepDepExts);
    @rules = grep(/^\Q$target\E\|/, @rules);
	
    my @processedRules = ();

    # Go through each build step summary and fill in the appropriate
    # rule structure information
    foreach my $rule (@rules) {
	my $depExts = $TargetBuildStepDepExts{$rule};
	(my $dummy, my $targetExt, my $exe) = split(/\|/, $rule);
	
	my $realRule = "$targetExt <- $depExts";
	($exe, my @exeFlags) = SmartSplit($exe);
	my $realFlags = $TargetBuildStepArgs{$rule};
	
	my $ruleKey = $target . "|" . $realRule;
	$TargetRulesExe{$ruleKey} = $exe;
	$TargetRulesFlags{$ruleKey} = $realFlags;
	
	push(@processedRules, $realRule);
    }

    # Return the list of rules for the target
    return @processedRules;
}
# TARGET PROCESSING ROUTINES ############################

# TARGET <=> BUILDTYPE ROUTINES #########################
# Given a processed target, creates a Build Type based on its rules
#
# Parameters: <Build Type Name> <Target to base Build Type on>
#
# Takes the Target rule information and transfers that information to
# the Build Type structures.
#
# Note: This routine can be the basis of an interface driven process where
# rules and flags can be modified before they're stored in the Build Type
# structures.
sub GenerateBuildTypeFromTargetRules
{
    my $buildTypeName = shift @_;
    my $fromTarget = shift @_;
    
    # Get the target extension from the supplied target
    my $targetExt = GetExtension($fromTarget);

    $fromTarget =~ /(\.[^\\\/]+)$/;
    my $realTargetExt = $1;

    my $generatedExt = "";
    if ($targetExt ne ".noext" && ($targetExt ne $realTargetExt)) {
	$generatedExt = $targetExt;
	$targetExt .= "*";
    }

    # Define the Build Type
    RemoveBuildType($buildTypeName);
    DefineBuildType($buildTypeName, $targetExt, $generatedExt);

    # Define the Build Type rules
    # Loop through each of the target's rules
    my @ruleKeys = keys(%TargetRulesExe);
    @ruleKeys = grep(/^\Q$fromTarget\E\|/, @ruleKeys);    
    foreach my $ruleKey (@ruleKeys) {
	my $rule = $ruleKey;
	$rule =~ s/^\Q$fromTarget\E\|//;
	DefineBuildTypeRule($buildTypeName, $rule, 
			    $TargetRulesExe{$ruleKey}, $TargetRulesFlags{$ruleKey});
    }	
}

# Matches a Target to a defined BuildType
#
# Parameters: <Target>
# Returns: <Build Type "Best Match">, <Filter Level>
#
# Uses a series of "filters" to determine the best match to a build type
# Filter 1: Final Target Extension
# Filter 2: Rule Targets
# Filter 3: Rule Executable
# Filter 4: Best-match Rule Flags
# 
# After any filter, if only a single defined BuildType remains, this is
# returned.  If after any filter, no defined BuildTypes remain, it goes
# back to the previous filter and chooses the first one on the list.
#
# For Targets that don't pass even the first filter, returns the 
# defined Default Build Type (with Filter Level = 0).
#
# If no Build Types have been defined, returns an empty string "" with
# Filter Level = -1.
sub MatchTargetToBuildType
{
    my $target = shift @_;
    
    if (!@BuildTypes) {
	return ("", -1);
    }
    
    my @possibleMatches = ();
    
    # First filter is against final target extensions
    # Loop through all Build Types and test the extension against
    # the supplied target name
    foreach my $buildType (@BuildTypes) {
	my $finalTargetExt = $BuildTypeFinalTarget{$buildType};
	my $extRE = GenerateRE($finalTargetExt);
	if ($target =~ /$extRE$/ || 
	    ($finalTargetExt eq ".noext" && $target !~ /\.[A-Za-z0-9]*$/)) {
	    push(@possibleMatches, $buildType);
	}
    }
    
#	print "First filter: " . join(", ", @possibleMatches) . "\n" if ($AllowCommonOutput);
    
    if (@possibleMatches == 1) {
	# If there's only one match, return that
	return ($possibleMatches[0], 1);
    }
    elsif (!@possibleMatches) {
	# No matches, return the default
	return ($DefaultBuildType, 0) if ($DefaultBuildType);
	return ("", -1) if (!$DefaultBuildType);
    }

    # Grab out the Target's rules
    my @targetRuleKeys = keys(%TargetRulesExe);
    @targetRuleKeys = grep(/^\Q$target\E\|/, @targetRuleKeys);
    
    my @filteredPossibleMatches = ();
    
    # Second filter is rule targets
    # Pre-load a list of the Target's rule targets
    my @targetRuleTargets = ();
    foreach my $targetRule (@targetRuleKeys) {
	my $ruleTarget = GetRuleTarget($targetRule);
	push (@targetRuleTargets, $ruleTarget);
    }

    # Loop through the remaining Build Types
    foreach my $possibleMatch (@possibleMatches) {
	# Get the Build Type rules
	my @buildTypeRuleKeys = keys(%BuildTypeRulesExe);
	@buildTypeRuleKeys = grep(/^\Q$possibleMatch\E\|/, @buildTypeRuleKeys);
	
	# Pre-load a list of the Build Type's rule targets
	my @buildTypeRuleTargets = ();
	foreach my $buildTypeRule (@buildTypeRuleKeys) {
	    my $ruleTarget = GetRuleTarget($buildTypeRule);
	    push (@buildTypeRuleTargets, $ruleTarget) if ($ruleTarget);		
	}

	# Make sure there's a match for every Target rule target
	my $noSuchTarget = 0;
	for (my $i = 0; $i < @targetRuleTargets && !$noSuchTarget; $i++) {
	    if (!$targetRuleTargets[$i]) {
		next;
	    }
	    
	    my @matchedTarget = grep(/^\Q$targetRuleTargets[$i]\E$/, @buildTypeRuleTargets);
	    if (!@matchedTarget) {
		print "Couldn't find $targetRuleTargets[$i]\n" if ($AllowCommonOutput);
		$noSuchTarget = 1;
	    }
	}
	
	push (@filteredPossibleMatches, $possibleMatch) if (!$noSuchTarget);
    }
    
#	print "Second filter: " . join(", ", @filteredPossibleMatches) . "\n" if ($AllowCommonOutput);
    
    if (@filteredPossibleMatches == 1) {
	# If there's only one match, return that
	return ($filteredPossibleMatches[0], 2);
    }
    elsif (!@filteredPossibleMatches) {
	# No remaining matches, use the previous filter results
	return ($possibleMatches[0], 1);
    }
    
    @possibleMatches = @filteredPossibleMatches;
    @filteredPossibleMatches = ();
    
    # Third filter is rule exe
    # Loop through the remaining Build Types
    foreach my $possibleMatch (@possibleMatches) {
	# Get the Build Type rules
	my @buildTypeRuleKeys = keys(%BuildTypeRulesExe);
	@buildTypeRuleKeys = grep(/^\Q$possibleMatch\E\|/, @buildTypeRuleKeys);
	
	# Make sure there's a match between a Target rule's exe and
	# the one used by the corresponding Build Type rule
	my $noSuchExe = 0;

	# Loop through all the Target's rules
	for (my $i = 0; $i < @targetRuleKeys && !$noSuchExe; $i++) {
	    if (!$targetRuleTargets[$i]) {
		next;
	    }

	    # Find the matching Build Type rule
	    my @matchedRuleKey = grep(/\Q$targetRuleTargets[$i]\E\s*\<-/, @buildTypeRuleKeys);
	    if (@matchedRuleKey) {
		# Make sure the exe's match
		if ($TargetRulesExe{$targetRuleKeys[$i]} ne $BuildTypeRulesExe{$matchedRuleKey[0]}) {
		    $noSuchExe = 1;
		}
	    }
	    else {
		$noSuchExe = 1;
	    }
	}
	
	push (@filteredPossibleMatches, $possibleMatch) if (!$noSuchExe);
    }
    
#	print "Third filter: " . join(", ", @filteredPossibleMatches) . "\n" if ($AllowCommonOutput);
    
    if (@filteredPossibleMatches == 1) {
	# If there's only one match, return that
	return ($filteredPossibleMatches[0], 3);
    }
    elsif (!@filteredPossibleMatches) {
	# No remaining matches, use the previous filter results
	return ($possibleMatches[0], 2);
    }
    
    @possibleMatches = @filteredPossibleMatches;
    @filteredPossibleMatches = ();
    
    # Fourth filter is a scored flag match
    # Top score wins
    # Initialize score tracker
    my %matchScore = ();
    foreach my $possibleMatch (@possibleMatches) {
	$matchScore{$possibleMatch} = 0;
    }

    # Loop through the remaining Build Types
    foreach my $possibleMatch (@possibleMatches) {
	# Get the Build Type rules
	my @buildTypeRuleKeys = keys(%BuildTypeRulesExe);
	@buildTypeRuleKeys = grep(/^\Q$possibleMatch\E\|/, @buildTypeRuleKeys);

	# Loop through all the Target's rules
	for (my $i = 0; $i < @targetRuleKeys; $i++) {
	    if (!$targetRuleTargets[$i]) {
		next;
	    }
	    
	    my $atTargetRulesFlags = $TargetRulesFlags{$targetRuleKeys[$i]};

	    # Find the matching Build Type rule
	    my @matchedRuleKey = grep(/\Q$targetRuleTargets[$i]\E\s*\<-/, @buildTypeRuleKeys);
	    if (@matchedRuleKey) {
		# Go through all the Build Type rule flags
		my @matchedRuleFlags = SmartArgSplit($BuildTypeRulesFlags{$matchedRuleKey[0]},
						     $FlagPrefixes{$BuildTypeRulesExe{$matchedRuleKey[0]}});
		
		foreach my $matchedFlag (@matchedRuleFlags) {
		    # Add 1 to the Build Type's score for a flag match
		    $matchScore{$possibleMatch} += 1 if ($atTargetRulesFlags =~ /\Q$matchedFlag\E/);
		}
	    }
	}
    }

    # Find the top scorer(s)
    my $topScore = -1;
    foreach my $possibleMatch (@possibleMatches) {
	if ($matchScore{$possibleMatch} > $topScore) {
	    $topScore = $matchScore{$possibleMatch};
	    @filteredPossibleMatches = ( $possibleMatch );
	}
	elsif ($matchScore{$possibleMatch} == $topScore) {
	    push (@filteredPossibleMatches, $possibleMatch);
	}
    }
    
#	print "Fourth filter: " . join(", ", @filteredPossibleMatches) . "\n" if ($AllowCommonOutput);
    
    if (@filteredPossibleMatches) {
	# Return the first on the list
	return ($filteredPossibleMatches[0], 4);
    }
    else {
	# No remaining matches, use the previous filter results
	return ($possibleMatches[0], 1);
    }

    # Shouldn't be able to get here
    return ("", -1); 
}
# TARGET <=> BUILDTYPE ROUTINES #########################

# Helper routine to get a rule's target
#
# Parameters: <Rule>
# Returns: <Rule's Target Ext>
#
# Parses the rule string to get the target extension.
sub GetRuleTarget
{
    my $ruleKey = shift @_;
    $ruleKey =~ s/^[^\|]*\|//;
    
    if ($ruleKey =~ /(.*)\<-/) {
	return trim($1);
    }
    else {
	return undefined;
    }
}

# TARGET TO TGT ROUTINES ################################
# Generates the TGT file for the specified target
#
# Parameters: <Target> <OS/Platform> <Build Type>
#
# Using the processed Target dependency list and rules, fills in a
# TGT template.
sub GenerateTgt {
    my $target = shift @_;
    my $os = shift @_;
    my $buildType = shift @_;

    # Grab the dependencies list
    my $dependencies = $TargetDeps{$target};

    # Get the target-specific arguments (ie. what's not in the Build Type)
    # All build steps arguments are rolled up into one string for now
    my $compilerArgs = GetTargetArguments($target, $buildType);

    # See if there is a generated extension
    # This overrides the "matched" extension (in case we had to wildcard)
    my $realTarget = $target;
    if ($BuildTypeGenerateTarget{$buildType}) {
	my $fromRE = GenerateRE($BuildTypeFinalTarget{$buildType});
	my $to = $BuildTypeGenerateTarget{$buildType};

	my $generateTarget = $target;
	$generateTarget =~ s/$fromRE$/$to/;

	if ($generateTarget ne $target) {
	    print "Using target name $generateTarget\n" if ($AllowCommonOutput);
	}

	$target = $generateTarget;
    }

    # Derive tgt filename
    # Add .tgt extension and substitute directory separator with _
    my $tgtName = $target . ".tgt";
    $tgtName =~ s/[\\\/]/_/g;

    # TGT header
    my $Tgt =<<STARTXML;
<?xml version="1.0"?>
<OMTarget>
 <Targets>
  <Name>$target</Name>
  <Project>$OMProject</Project>
  <TargetName>$tgtName</TargetName>
  <OSPlatform>$os</OSPlatform>
  <BuildType>$buildType</BuildType>
  <TaskName></TaskName>
  <IntDirectory>$IntDir</IntDirectory>
  <Defines>$compilerArgs</Defines>
  <AdditionalFlags></AdditionalFlags>
  <PhoneyTarget></PhoneyTarget>
STARTXML

    # Prep array of possible argument differences
    # If all the arguments are standard, then this will be empty
    my @argDifferences = keys(%TargetArgDifferences);
    @argDifferences = grep(/^\Q$realTarget\E/, @argDifferences);
    
    # Loop through each dependency and write it's XML
    foreach my $dep (split(/\|+/, $dependencies)) {
	# Look-up to see if there are any argument differences for
	# this particular dependency's build step
	# 
	# The dependency-specific defines need to have both the 
	# target's defines and the differences (for now)
	my $argDiff = "";
	if (@argDifferences) {
	    my @matchArgDiff = grep(/<-.*\Q$dep\E/, @argDifferences);
	    if (@matchArgDiff) {
		my $argDiffKey = shift(@matchArgDiff);
		$argDiff = $TargetArgDifferences{$argDiffKey};
		my @argDiffFields = split(/\|+/, $argDiff);
		$argDiff = pop(@argDiffFields);
		$argDiff .= " $compilerArgs";
	    }
	}
	$Tgt .= <<DEPXML;
  <Dependencies>
    <Name>$dep</Name>
    <TaskName></TaskName>
    <Defines>$argDiff</Defines>
    <AdditionalFlags></AdditionalFlags>
  </Dependencies>
DEPXML
    }

    # Close up the TGT
    $Tgt .=<<ENDXML;
 </Targets>
</OMTarget>
ENDXML

    # Write the TGT file
    if (!open(TGT, ">$tgtName")) {
	print "Couldn't write $tgtName!\n" if ($AllowCommonOutput);
	return ;
    }

    print "Writing $tgtName..." if ($AllowCommonOutput);
    print TGT $Tgt . "\n";
    print "Done\n\n" if ($AllowCommonOutput);
    
    return $tgtName;
}
# TARGET TO TGT ROUTINES ################################

# TARGET UTILITY ROUTINES ###############################
# Returns all the target-specific arguments in one string
#
# Parameters: <Target> <Build Type>
# Returns: <Target Arguments>
#
# Determines the target-specific arguments based on differences
# between the target rule's flags and the Build Type rule's.
sub GetTargetArguments
{
    my $target = shift @_;
    my $buildType = shift @_;

    # Get the Target's rules
    my @targetRuleKeys = keys(%TargetRulesFlags);
    @targetRuleKeys = grep(/^\Q$target\E\|/, @targetRuleKeys);

    # Pre-load a rule target list (for matching with to Build Type's)
    my @targetRuleTargets = ();
    foreach my $targetRule (@targetRuleKeys) {
	my $ruleTarget = GetRuleTarget($targetRule);
	push (@targetRuleTargets, $ruleTarget);
    }

    # Get the Build Type rules
    my @buildTypeRuleKeys = keys(%BuildTypeRulesFlags);
    @buildTypeRuleKeys = grep(/^\Q$buildType\E\|/, @buildTypeRuleKeys);

    my @ruleArgDiffs = ();

    # Loop through all the Target rules
    for (my $i = 0; $i < @targetRuleTargets; $i++) {
	# Find the matching Build Type rule
	my @matchedRuleKey = grep(/\Q$targetRuleTargets[$i]\E\s*\<-/, @buildTypeRuleKeys);
	if (@matchedRuleKey) {
	    # Get the target-specific flags
	    my $ruleArgDiff = GetArgDiff($BuildTypeRulesFlags{$matchedRuleKey[0]}, $TargetRulesFlags{$targetRuleKeys[$i]}, $FlagPrefixes{$TargetRulesExe{$targetRuleKeys[$i]}});
	    push (@ruleArgDiffs, $ruleArgDiff) if ($ruleArgDiff);
	}
    }

    return join(" ", @ruleArgDiffs);
}

# Gets the differences between two argument strings
#
# Parameters: <Base Argument String> <Comparison Argument String>
# Returns: <Arguments only in Comparison>
#
# Determines what's different between two sets of arguments.
# Useful in determining if an individual build step has unique
# arguments and determining target-specific arguments.
sub GetArgDiff
{
    my $Base = shift @_;
    my $Comp = shift @_;

    my $flagPrefixes = shift @_;

    @BaseArgs = SmartArgSplit($Base, $flagPrefixes);
    @CompArgs = SmartArgSplit($Comp, $flagPrefixes);

    foreach $arg (@BaseArgs) {
	@CompArgs = grep(!/^\Q$arg\E$/, @CompArgs);
    }

    my $diff = "";
    if (@CompArgs) {
	$diff = join(" ", @CompArgs);
    }

    return $diff;
}

# Gets the extension for the specificed filename
#
# Parameters: <Filename>
# Returns: <Extension>
#
# Uses ".noext" for filenames without an extension.  Also allows
# additional processing on the extension (so.N.N -> .so).
sub GetExtension
{
    my $filename = shift @_;
    my $ext = ".noext";
    if ($filename =~ /(\.[^\\\/]+)$/) {
	$ext = $1;
	$ext =~ s/(\.[^\.]+).*/$1/;
    }
    
    return $ext;
}
# TARGET UTILITY ROUTINES ###############################

# GENERAL UTILITY ROUTINES ##############################
# Smart split that respects ""
#
# Parameters: <Arguments>
# Returns: <List of arguments>
#
# The normal split to obtain separate arguments can't really handle 
# arguments enclosed in quotes that may have spaces.  This routine
# modifies the normal split by making sure that quotes match up.
sub SmartSplit
{
    my $string = shift @_;
    $string = trim($string);

    # Split as usual
    @split = split(/\s+/, $string);

    # Reconstruct quoted args
    @correctsplit = ( );
    $at = "";

    # Loop through the arguments to match up quotes
    for ($i = 0; $i < @split; $i++) {
	$at .= $split[$i];
	if ($at !~ /\"/ || ($at =~/\".*\"$/)) {
	    push(@correctsplit, $at);
	    $at = "";
	}
	else {
	    $at .= " ";
	}
    }

    return @correctsplit;
}

# Smart split that respects "" and flags
#
# Parameters: <Arguments>
# Returns: <List of arguments>
#
# Same as SmartSplit() but goes one step further in order to group 
# together flag parameters.
sub SmartArgSplit
{
    my $string = shift @_;
    my @FlagPrefixes = split(/\s+/, shift @_);
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    @split = split(/\s+/, $string);

    $FlagRE = join("|", @FlagPrefixes);

    # Reconstruct quoted args
    @correctsplit = ( );
    $at = "";
    for ($i = 0; $i < @split; $i++) {
	$at .= $split[$i];
	if ($at !~ /\"/ || ($at =~/\".*\"$/)) {
	    if ($FlagRE && $at !~ /^$FlagRE/) {
		$at = pop(@correctsplit) . " " . $at;
	    }
	    push(@correctsplit, $at);
	    $at = "";
	}
	else {
	    $at .= " ";
	}
    }

    return @correctsplit;
}

# Generate basic Regular Expression pattern from a wildcarded string
#
# Parameter: <String>
# Returns: <String suitable for Regular Expression>
#
# Makes sure that \, /,and . are escaped.  Handles "*" wildcard with
# ".*".
sub GenerateRE
{
    $string = shift @_;
    $REString = $string;
    $REString =~ s/\\/\\\\/g;
    $REString =~ s/\//\\\//g;
    $REString =~ s/\./\\./g;
    $REString =~ s/\*/.*/g;
    
    return $REString;
}

# Return the unique elements in a list
#
# Parameters: <List of elements>
# Returns: <Unique elements in list>
#
# Processes a list to find only the unique elements.  All duplicates
# are removed.
sub unique
{
    @arr = @_;
    
    @unique = ( );
    while (@arr) {
        $val = shift @arr;
        @arr = grep(!/^\Q$val\E$/, @arr);
        push (@unique, $val);
    }

    return @unique;
}

# Removes whitespace at the beginning and end of a string
#
# Parameters: <string>
# Returns: <cleaned string>
#
# Removes surrounding whitespace from a string.
sub trim
{
    my $str = shift @_;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;

    return $str;
}
# GENERAL UTILITY ROUTINES ##############################

################# MAIN ##################

$| = 1;

$debug = 0;
$AllowCommonOutput = 0;

# $IsWindows = 1;

$InInit = 0;
$SetFinalTargetsUsing = 0;

$CurrentMenuLabel = "";
$CurrentMenuPrompt = "";
$CurrentMenuOrder = "";
%CurrentMenuText = ();
%CurrentMenuActions = ();

######################################################
# Define Menus
# BEGIN
$DefaultPrompt = "Enter Choice > ";

# GATHERING BUILD OUTPUT
# 1. Create Wrappers
# 2. Run Build

# CONVERTING BUILD OUTPUT TO TARGET DEFINITIONS
# 1. Set Project Name
# 2. Set Current Config From Defaults
# 3. Set Build Types From Defaults
# 4. Load In Build Output
# 5. Clean up Targets
# 6. Save Targets

# ADMINISTRATION
# 1. Edit Platform Config
# 2. Creating Build Types From Build Output
# 3. Edit Build Types 

$MainMenuLabel = "Main";
$MainMenuOrder = "G|C|A|Q";
%MainMenuText = ( "G" => "** (G)athering Build Output **\n\n                In this step you will wrapper your current compile\n                and link programs so Openmake can capture the compile and\n                link flags when you perform a build.",
				  "C" => "** (C)onverting Captured Build Output **\n\n                In this step you will convert the captured build output from the\n                previous step and generate Openmake Target Definitions\n",
				  "A" => "** (A)dministration **\n\n                In this step you can update the default configuration files\n                that are used to parse the captured output and create the\n                Openmake Target Definitions\n",
				  "Q" => "** (Q)uit **"
				);
%MainMenuActions = ( "G" => "GoToGatherOut",
					 "C" => "GoToBCMain",
					 "A" => "GoToAdmin",
					 "Q" => "SafeExit"
				   );

$GatherOutMenuLabel = "Gathering Build Output";
$GatherOutMenuPrompt = "Gathering Build Output, Enter Choice> ";
$GatherOutMenuOrder = "C|R|BMQ";
%GatherOutMenuText = ("C" => "(C)reate Executable Wrappers",
					  "R" => "(R)un Build",
					  "B" => "(B)ack a Menu",
					  "M" => "(M)ain Menu",
					  "Q" => "(Q)uit"
				  );
%GatherOutMenuActions = (
					   "C" => "CreateExeWrappers",
					   "R" => "RunBuild",
					   "B" => "GoToMain",
					   "M" => "GoToMain",
					   "Q" => "SafeExit"
					 );

$BCMainMenuLabel = "Captured Build Output Conversion";
$BCMainMenuPrompt = "Build Output Conversion, Enter Choice> ";
$BCMainMenuOrder = "CR|P|FADL|G|BMQ";
%BCMainMenuText = ( "C" => "(C)urrent Build Information",
					"R" => "(R)eset Build Information",
					"P" => "Set Build (P)roject Name",
					"F" => "List (F)inal Build Targets",
					"A" => "(A)dd Final Build Target",
					"D" => "(D)elete Final Build Target",
					"L" => "(L)oad from Build Output from File",
					"G" => "(G)enerate Openmake TGTs",
					"B" => "(B)ack a Menu",
					"M" => "(M)ain Menu",
					"Q" => "(Q)uit"
				  );
%BCMainMenuActions = ( "C" => "DisplayBInfo",
					   "R" => "ResetBInfo",
					   "P" => "SetProjectName",
					   "F" => "DisplayBTargets",
					   "A" => "AddBTarget",
					   "D" => "DeleteBTarget",
					   "L" => "LoadBInfoFile",
					   "G" => "GenerateBuildTGTs",
					   "B" => "GoToMain",
					   "M" => "GoToMain",
					   "Q" => "SafeExit"
					 );

$AdminMenuLabel = "Administration";
$GatherOutMenuPrompt = "Administration, Enter Choice> ";
$AdminMenuOrder = "C|BMQ";
%AdminMenuText  = ( "C" => "** Edit (C)ompiler Mapping **\n\n                Defines what the compiler and linkers are and\n                what information to parse from the captured output.\n",
				  "B" => "(B)ack a Menu",
				  "M" => "(M)ain Menu",
				  "Q" => "(Q)uit"
				);
%AdminMenuActions = ( "C" => "GoToPCMain",
					 "B" => "GoToMain",
					 "M" => "GoToMain",
					 "Q" => "SafeExit"
				   );

$PCMainMenuLabel = "Compiler Mapping Configuration";
$PCMainMenuPrompt = "Compiler Mapping, Enter Choice> ";
$PCMainMenuOrder = "CR|AEDLS|BMQ";
%PCMainMenuText = ( "C" => "(C)urrent Compiler Mapping",
					"R" => "(R)eset Compiler Mapping",
					"A" => "(A)dd Compiler/Linker Executable",
					"E" => "(E)dit Compiler/Linker Mapping",
					"D" => "(D)elete Compiler/Linker Executable",
					"L" => "(L)oad Compiler Mapping from File",
					"S" => "(S)ave Compiler Mapping to File",
				    "B" => "(B)ack a Menu",
				    "M" => "(M)ain Menu",
				    "Q" => "(Q)uit"
				  );
%PCMainMenuActions = ( "C" => "DisplayPC",
					   "R" => "ResetPC",
					   "A" => "AddBuildExe",
					   "E" => "EditBuildExe",
					   "D" => "DeleteBuildExe",
					   "L" => "LoadPCFile",
					   "S" => "SavePCFile",
					   "B" => "GoToAdmin",
					   "M" => "GoToMain",
					   "Q" => "SafeExit"
					 );

$PCExeEditMenuLabel = "Edit Compiler Mapping";
$PCExeEditMenuPrompt = "Edit Compiler Mapping, Enter Choice> ";
$PCExeEditMenuOrder = "C|X|FOSDR|BMQ";
%PCExeEditMenuText = ( "C" => "(C)urrent Executable Settings",
					   "X" => "Set E(x)ecutable Name",
					   "F" => "Set (F)lag Prefixes",
					   "O" => "Set (O)utput Flag Identifiers",
					   "S" => "Set (S)tandard Flags",
					   "D" => "Set (D)ependency Exclusion Filters",
					   "R" => "Set (R)ules for Deriving Target for Executable",
 				       "B" => "(B)ack a Menu",
				       "M" => "(M)ain Menu",
				       "Q" => "(Q)uit"
					);
%PCExeEditMenuActions = ( "C" => "DisplayBuildExe",
						  "X" => "SetBuildExe",
						  "F" => "SetBuildExeFlagPrefixes",
						  "O" => "SetBuildExeOutputFlags",
						  "S" => "SetBuildExeStandardFlags",
						  "D" => "SetBuildExeDependencyExclude",
						  "R" => "SetBuildExeDerivedRules",
					      "B" => "GoToPCMain",
					      "M" => "GoToMain",
					      "Q" => "SafeExit"
						);

$BTMainMenuLabel = "Edit Build Type Mapping";
$BTMainMenuPrompt = "Edit Build Type Mapping, Enter Choice> ";
$BTMainMenuOrder = "CR|AEDS|F|BMQ";
%BTMainMenuText = ( "C" => "(C)urrent Openmake Build Types",
					"R" => "(R)eset Build Types",
					"L" => "(L)oad Build Types from File",
					"A" => "(A)dd Build Type",
					"E" => "(E)dit Build Type",
					"D" => "(D)elete Build Type",
					"S" => "(S)ave to File",
					"F" => "Set As De(f)ault Build Type", 
 				    "B" => "(B)ack a Menu",
				    "M" => "(M)ain Menu",
				    "Q" => "(Q)uit"
				  );
%BTMainMenuActions = ( "C" => "DisplayBTs",
					   "R" => "ResetBTs",
					   "L" => "LoadBTFile",
					   "E" => "GoToBTEdit",
					   "A" => "AddBuildType",
					   "E" => "EditBuildType",
					   "D" => "DeleteBuildType",
					   "S" => "SaveBTFile",
					   "F" => "SetDefaultBT",
					   "B" => "GoToAdmin",
					   "M" => "GoToMain",
					   "Q" => "SafeExit"
					 );

$BTBTEditMenuLabel = "Edit Build Type Detail";
$BTBTEditMenuPrompt = "Edit Build Type Detail, Enter Choice> ";
$BTBTEditMenuOrder = "C|N|TG|AED|BMQ";
%BTBTEditMenuText = ( "C" => "(C)urrent Build Type",
					  "N" => "Build Type (N)ame",
					  "T" => "Final (T)arget Extension",
					  "G" => "(G)enerated Target Extension",
					  "A" => "(A)dd Rule",
					  "E" => "(E)dit Rule",
					  "D" => "(D)elete Rule",
   				      "B" => "(B)ack a Menu",
				      "M" => "(M)ain Menu",
				      "Q" => "(Q)uit"
					);
%BTBTEditMenuActions = ( "C" => "DisplayBT",
						 "N" => "SetBTName",
						 "T" => "SetBTFinalTargetExt",
						 "G" => "SetBTGeneratedExt",
						 "A" => "AddBTRule",
						 "E" => "EditBTRule",
						 "D" => "DeleteBTRule",
					     "B" => "GoToBTMain",
					     "M" => "GoToMain",
					     "Q" => "SafeExit"
					   );

####################
#$PCEditMenuLabel = "Edit Platform Configuration";
#$PCEditMenuPrompt = "PC:E> ";
#$PCEditMenuOrder = "C|N|T|AD|B|R|PM";
#%PCEditMenuText = ( "C" => "(C)urrent Platform Configuration",
#					"T" => "Set Final (T)arget Extensions for Platform",
#					"B" => "Edit (B)uild Executable Settings",
#				  );
#%PCEditMenuActions = ( "C" => "DisplayPC",
#					   "T" => "SetPlatformTargetExts",
#					   "B" => "EditBuildExe",
#					 );
#
#$BTEditMenuLabel = "Edit Build Types";
#$BTEditMenuPrompt = "BT:E> ";
#$BTEditMenuOrder = "C|B|AD|E|R|OM";
#%BTEditMenuText = ( "C" => "(C)urrent Openmake Build Types",
#					"B" => "Generate (B)uild Types from Target Build Rules",
#					"O" => "Back to (O)penmake Build Types Menu",
#					"M" => "Back to (M)ain Menu"
#				  );
#%BTEditMenuActions = ( "C" => "DisplayBTs",
#					   "B" => "GenerateBuildTypes",
#					   "R" => "ResetBTs",
#					   "O" => "GoToBTMain",
#					   "M" => "GoToMain"
#					 );
#
# END

######################################################
# Main
PrintHeader();
GetOpts();
Initialize();

if ($BatchMode) {
	print "Batch Mode\n\n";
	FindBTargetsBT();
	GenerateBuildTGTs();
}
else {
	GoToMain();
	while (1) {
	GetUserMenuChoice();
	}
}

exit 0;

######################################################
# Command-line arguments
sub PrintHeader
{
	print "Openmake Build Conversion\n";
	print "\n";
}

sub PrintUsage
{
	print "Usage:\n";
	print "  Conversion.pl [-b(atch mode)]\n";
	print "                [-pc <Platform Configuration File]\n";
	print "                [-bt <Build Types File>]\n";
	print "                [-op <Openmake Project Name>]\n";
	print "                [-id <Intermediate Directory for Openmake Build>]\n";
	print "                [<Build Info File> or - (stdin)]\n";
	print "\n";
	print "All flags are optional in interactive mode (default).\n";
	print "\n";
	print "Batch mode requires Platform Configuration, Build Types, and Build Info\n";
	print "files to be specified.  An Openmake Project Name must also be assigned.\n";
	print "\n";
}

sub GetOpts 
{
	$BatchMode = 0;

	$PCFile = "";
	$BTFile = "";
	$BuildOutputFile = "";

	$OpenmakeProject = "";
	$IntDir = ".";

	for ($i = 0; $i < @ARGV; $i++) {
	if ($ARGV[$i] =~ /^-b$/i) {
		$BatchMode = 1;
	}
	elsif ($ARGV[$i] =~ /^-pc$/i) {
		$i++;
		$PCFile = $ARGV[$i];
	}
	elsif ($ARGV[$i] =~ /^-bt$/i) {
		$i++;
		$BTFile = $ARGV[$i];
	}
	elsif ($ARGV[$i] =~ /^-op$/i) {
		$i++;
		$OpenmakeProject = $ARGV[$i];
	}
	elsif ($ARGV[$i] =~ /^-id$/i) {
		$i++;
		$IntDir = $ARGV[$i];
	}
	elsif ($ARGV[$i] =~ /^-h|\?$/i) {
		PrintUsage();
		exit 0;
	}
	elsif ($ARGV[$i] !~ /^-/) {
		$BuildOutputFile = $ARGV[$i];
	}
	else {
		PrintUsage();
		exit -1;
	}
	}

	my $doDie = 0;
	if ($BatchMode) {
	if (!$PCFile) {
		print "Platform Configuration file not specified!\n";
		$doDie = 1;
	}
	if (!$BTFile) {
		print "Openmake BuildTypes file not specified!\n";
		$doDie = 1;
	}
	if (!$BuildOutputFile) {
		print "Captured Build Output file not specified!\n";
		$doDie = 1;
	}
	if (!$OpenmakeProject) {
		print "Openmake Project name not specified!\n";
		$doDie = 1;
	}
	}


	if ($PCFile && !(-f $PCFile)) {
		print "Platform Configuration file $PCFile cannot be found!\n";
		$PCFile = "";
		$doDie = 1 if ($BatchMode);
	}
	if ($BTFile && !(-f $BTFile)) {
		print "Openmake BuildTypes file $BTFile cannot be found!\n";
		$BTFile = "";
		$doDie = 1 if ($BatchMode);
	}
	if ($BuildOutputFile && !(-f $BuildOutputFile)) {
		print "Captured Build Output file $BuildOutputFile cannot be found!\n";
		$BuildOutputFile = "";
		$doDie = 1 if ($BatchMode);
	}

	if ($doDie) {
		print "\n";
		print "Couldn't start in batch mode.\n";
		print "Exiting...";
		exit 1;
	}
}

sub FindCfgFile
{
 my $FileName = shift;
 my @dirs;
 my $str;

 return $FileName if (-e $FileName);

 if ($^O =~ /win32/i)
 {
  @dirs = split(/;/,$ENV{PATH});
 }
 else
 {
  @dirs = split(/:/,$ENV{PATH});
 }

 foreach (@dirs)
 {
  $str = "$_/$FileName";
  return $str if (-e $str);
 }
 return "";
}

sub Initialize
{
	$InInit = 1;
	my $didInit = 0;
	

	if ($PCFile eq "")
	{
	 $PCFile = "conversion/compilers/$^O.cfg";
	 $PCFile = FindCfgFile($PCFile);
	}

	if ($BTFile eq "")
	{
	 $BTFile = ($^O =~ /win32/i) ? "conversion/buildtypes/windows.cfg" : "conversion/buildtypes/unix.cfg";
	 $BTFile = FindCfgFile($BTFile);
	}

	if ($BuildOutputFile eq "")
	{
	 $BuildOutputFile="ombuild.log";
	 $BuildOutputFile="" if (!-e $BuildOutputFile);
	}

	if ($OpenmakeProject eq "")
	{
	 if (-e "project.cfg")
	 {
	  print "Loading Project Name from project.cfg\n";
	  open (FP,"<project.cfg");
	  $OpenmakeProject = <FP>;
	  close(FP);
	  $OpenmakeProject =~ s/\n//g;
	 }
	}

	if ($PCFile) {
		LoadPCFile($PCFile);
		FindBTargetsPC();
		$didInit = 1;
	}

	if ($BTFile) {
		LoadBTFile($BTFile);
		FindBTargetsPC();
		if ($SetFinalTargetsUsing == 0) {
			if (@PlatformFinalTargetExts) {
				FindBTargetsPC();	
			}
		}
		$didInit = 1;
	}
	
	if ($BuildOutputFile) {
		LoadBInfoFile($BuildOutputFile);
		$didInit = 1;
	}
	
	print "\n" if ($didInit);
	
	$InInit = 0;
}

######################################################
# Menu handling
sub SetCurrentMenu
{
	my $id = shift @_;

	$CurrentMenuLabel = ${$id . "MenuLabel"};
	$CurrentMenuOrder = ${$id . "MenuOrder"};
	%CurrentMenuText = %{$id . "MenuText"};
	%CurrentMenuActions = %{$id . "MenuActions"};	 

	$CurrentMenuPrompt = ${$id . "MenuPrompt"};
	$CurrentMenuPrompt = $DefaultPrompt if (!$CurrentMenuPrompt);
}

sub DisplayCurrentMenu
{
	print "$CurrentMenuLabel\n\n";

	my $length = length($CurrentMenuOrder);

	for ($i = 0; $i < $length; $i++) {
		my $charAt = substr($CurrentMenuOrder, $i, 1);
		$charAt =~ tr/a-z/A-Z/;
		my $menuItem = $CurrentMenuText{$charAt};
		$displayItem = "\t";
		if ($charAt ne "|" && $menuItem) {
			$displayItem .= $charAt;
		}
		$displayItem .= "\t" . $menuItem;

		print "$displayItem\n";
	}

	print "\n";
}

sub GetUserMenuChoice
{
	my $valid = 0;
	my $input;
	do {
		$input = GetUserInput("", $CurrentMenuPrompt);

		trim($input);
		if ($input =~ /^QUIT$/i || $input =~ /^EXIT$/i) {
			SafeExit();
		}

		# Only want the first non-whitespace character
		$input = substr($input, 0, 1);
		$input =~ tr/a-z/A-Z/;

		if (($input && $input ne "|" && $CurrentMenuOrder =~ /\Q$input\E/)) {
			$valid = 1;
		}

		if (!$valid) {
			if ($input eq "?") {
				DisplayCurrentMenu();
			}
			elsif ($input) {
				print "Command not recognized.	\"?\" displays the menu\n";
			}
			elsif (!$input) {
				DisplayCurrentMenu();
 #				print "\"?\" displays the menu\n";
			}
		}
	} while (!$valid);

	print "$CurrentMenuActions{$input}\n" if ($debug);
	&{$CurrentMenuActions{$input}}();
}

sub GetUserInput
{
	my $msg = shift @_;
	my $prompt = shift @_;
	my $default = shift @_;

	my $displayMsg = "$msg";
	if ($default) {
		$displayMsg .= " [$default]";
	}
	$displayMsg .= "$prompt";
	print "\n$displayMsg";
	$userInput = <STDIN>;
	$userInput = trim($userInput);

	$userInput = $default if (!$userInput && $default);
	print "\n";
	return $userInput;
}

sub ShowList
{
	my $maxAtOnce = shift @_;
	my @displayList = @_;

	for (my $i = 1; $i <= @displayList; $i++) {
		print "  $displayList[$i - 1]\n";
		if (($i % $maxAtOnce) == 0) {
			my $input = GetUserInput("[Return to continue. \"q\" to quit]");
			return if ($input =~ /^q/i);
		}
	}
}

sub GetUserListSelection
{
	my $msg = shift @_;
	my $prompt = shift @_;
	my $maxAtOnce = shift @_;
	my @displayList = @_;
	
	my @realList = @_;

	$msg = "Selection number" if (!$msg);
	$prompt = ":" if (!$prompt);

	my $idx = 1;
	foreach my $displayItem (@displayList) {
		$displayItem = "$idx. " . $displayItem;	
		$idx++;
	}
	
	ShowList($maxAtOnce, @displayList);
		
	my $selection = "";
	do {
		$selection = GetUserInput($msg, $prompt);
		if ($selection eq "" || $selection eq "-") {
			return "";
		}
		elsif ($selection =~ /^\d*$/) {
			my $selectionVal = int($selection);
			if ($selectionVal >= 1 && $selectionVal <= @realList) {
				$selection = $realList[$selectionVal - 1];
			}
			else {
				print "Selection is not in list!\n";
				$selection = "";
			}
		}
		else {
			# If it's not a number, assume that it's an actual value...
		} 
	} while (!$selection);
	
	return $selection;
}

######################################################
# Menu Actions
sub GoToMain
{
	$DisplayFull = 0;
	SetCurrentMenu("Main");
	DisplayCurrentMenu();
}

sub GoToAdmin
{
	$DisplayFull = 0;
	SetCurrentMenu("Admin");
	DisplayCurrentMenu();
}

sub GoToPCMain
{
	$DisplayFull = 0;
	SetCurrentMenu("PCMain");
	DisplayCurrentMenu();
}

sub GoToGatherOut
{
	$DisplayFull = 0;
	SetCurrentMenu("GatherOut");
	DisplayCurrentMenu();
}

sub GoToPCEdit
{
	$DisplayFull = 1;
	SetCurrentMenu("PCEdit");
	DisplayCurrentMenu();
}

sub GoToBTMain
{
	$DisplayFull = 0;
	SetCurrentMenu("BTMain");
	DisplayCurrentMenu();
}

sub GoToBTEdit
{
	$DisplayFull = 1;
	SetCurrentMenu("BTEdit");
	DisplayCurrentMenu();
}

sub GoToBCMain
{
	$DisplayFull = 0;
	SetCurrentMenu("BCMain");
	DisplayCurrentMenu();
}

######################################################
# Platform Configuration 
sub DisplayPC
{
	my $output = "";
	
	if ($DisplayFull) {
	   $output .= "Platform Configuration\n\n";
	}
	else {
	   $output .= "Platform Configuration Summary\n\n";
	}

	my $displayOS = $OS;
	$displayOS = "[Not Set]" if (!$displayOS);
	$output .= "Platform: $displayOS\n";
	$output .= "\n";
	$output .= "Final Target Extensions: " . join(" ", @PlatformFinalTargetExts) . "\n\n" if (@PlatformFinalTargetExts);

	my @displayExe = sort(@Executables);
	if (!@displayExe) {
	   $output .= "No Build Executables defined for Platform\n";
	}
	else {
	   $output .= "Build Executables:\n";
	   foreach my $exe (@displayExe) {
		   $output .= DisplayBuildExe($exe);
	   }
	}

	ShowList(20, split(/\n/, $output));

	print "\n";
}

sub LoadPCFile
{
	my $arg = shift @_;
	my $cfgFile;

	if ($arg) {
	   $cfgFile = $arg;
	}
	else {
	   $cfgFile = GetUserInput("Configuration File", ": ", $PCFile);
	}

	if (!-f $cfgFile) {
	   print "Platform configuration file $cfgFile cannot be found!\n";
	   return ;
	}

	ResetPC(1);
	print "Loading Platform Configuration from $cfgFile.... ";
	if (LoadPlatformConfiguration($cfgFile)) {
		print "Done\n";
		DisplayPC() if (!$InInit);
		$PCFile = $cfgFile;
	}
	else {
		print "ERROR!\n";
		$PCFile = "" if ($InInit);
		if (-f $PCFile) {
			print "Reseting Platform configuration using $PCFile!\n";
			ResetPC(2);
		}
		else {
			print "Clearing Platform configuration\n";
			ResetPC(1);
		}
	}
}


sub RunBuild
{
	my $default = "build";
	my $PATH = $ENV{PATH};
    my $cmd = GetUserInput("Enter Command to run your Build (eg. build)", ": ", $default);

    $ENV{PATH} = ($^O =~ /win32/i) ?  ".\\wrapper;" . $ENV{PATH} : "./wrapper:" . $ENV{PATH};

    print "\n\nCreating Captured Output File ombuild.log\n\n";

	open (FPIN,"$cmd|");
    open (FPOUT,">ombuild.log");

    while (<FPIN>) 
	{
	 print $_;
	 print FPOUT $_;
	}
    close(FPOUT);
    close(FPIN);

    $ENV{PATH} = $PATH;

    print "\n\nDone Capturing Build Outut\n\n";
}

sub SavePCFile
{
	if (!$OS) {
		print "Platform has not been specified!\n";
		return;
	}

	if (!@Executables) {
		print "No Build Executables have been defined for Platform!\n";
		return;
	}

	my $default = $PCFile;
		$default = $OS . ".cfg" if (!$default && $OS);
		my $cfgFile = GetUserInput("Save to File", ": ", $PCFile);

	if (!$cfgFile) {
		print "Filename not specified!\n";
		return;
	}

	if (SavePlatformConfiguration($cfgFile)) {
		$PCFile = $cfgFile;
		$DoSavePlatform = 0;
	}
	else {
		print "Couldn't write to $cfgFile\n";
	}
}

sub CreateExeWrappers
{
	$cwd = cwd();
	my $toDir = GetUserInput("Create executable wrappers in", ": ", $cwd);

	if (!$toDir) {
		print "Directory not specified!\n";
		return;
	}

	$rc = CreateWrappers($toDir);
	if ($rc == 0) {
		print "Failed to create executable wrappers!\n";
	}
	elsif ($rc == -1) {
		print "Some executable wrappers may not have been created!\n";
	}
	elsif ($rc == 1) {
		print "Executables wrappers successfully created\n";
	}
}

sub ResetPC
{
	my $resetArg = shift @_;
	my $reloadFromFile = 0;
	my $doAsk = 1;

	if ($resetArg == 1) {
		$doAsk = 0;
	}
	elsif ($resetArg == 2) {
		$reloadFromFile = 1;
		$doAsk = 0;
	}

	if ($resetArg == 0 && $doAsk) {
		if ($PCFile && -f $PCFile) {
			my $YN = GetUserInput("Reload Platform configuration from $PCFile?", " ", "Y");
			if ($YN =~ /^y/i) {
				$doAsk = 0;
				$reloadFromFile = 1;
			}
		}
	}

	if ($reloadFromFile && $PCFile && -f $PCFile) {
		if ($doAsk) {
			my $YN = GetUserInput("Reload Platform configuration from $PCFile?", " ", "Y");
			if ($YN !~ /^y/i) {
				print "Platform configuration reload cancelled.\n";
				return ;
			}
		}

		InitializePlatformConfiguration();
		if (!LoadPlatformConfiguration($PCFile)) {
			print "Couldn't load Platform configuration from $PCFile!\n";
			InitializePlatformConfiguration();
		}		
	}
	else {
		if ($doAsk) {
			my $YN = GetUserInput("Clear Platform configuration?", " ", "Y");
			if ($YN !~ /^y/i) {
				print "Platform configuration reset cancelled.\n";
				return ;
			}
			else {
				$PCFile = "";
			}
		}

		InitializePlatformConfiguration();
		print "Platform configuration cleared\n" if (!$InInit);
		$OS = "";
	}
}

sub SetPlatformName
{
	$OS = GetUserInput("Platform Name", ": ", $OS);
	$DoSavePlatform = 1;
}

sub SetPlatformTargetExts
{
	my $currentPlatformTargetExts = join(" ", @PlatformFinalTargetExts);
	print "Current Final Target Extensions: $currentPlatformTargetExts\n";
	my $newTargetExts = GetUserInput("Final Target Extensions", ": ");
	@PlatformFinalTargetExts = split(/\s+/, $newTargetExts);
	$DoSavePlatform = 1;
}

sub DisplayBuildExe
{
	my $args = @_;
	
	my $exe = shift @_;
	$exe = $CurrentBuildExe if (!$exe);

	my $output = "";
	$output .= "	 $exe\n";
	if ($DisplayFull) {
		$output .= "	   Flag Prefixes                $FlagPrefixes{$exe}\n";
		$output .= "	   Output Flag Identifiers      $OutputFlag{$exe}\n";
		$output .= "	   Standard Flags               $StandardFlags{$exe}\n";
		$output .= "	   Dependency Exclusion Filters $DependencyExcludeFilters{$exe}\n";
		$output .= "	   Rules for Deriving Outputs   $DerivedOutput{$exe}\n";
		$output .= "\n";
	}
	
	ShowList(20, split(/\n/, $output)) if (!$args);
	
	return $output;
}

sub AddBuildExe {
	my $currentExe = "";
	my @inList = ();
	do {
		$currentExe = GetUserInput("Executable", ": ");
		if (!$currentExe) {
			print "Executable name not specified!\n";
			return ;
		}

		@inList = grep(/^\Q$currentExe\E/, @Executables);
		if (@inList) {
			my $doEdit = GetUserInput("Executable alredy defined.  Edit", "? ", "Y");
			if ($doEdit !~ /^Y/i) {
				return;
			}
		}
	} while (!$currentExe);

	if (!@inList) {
		push(@Executables, $currentExe);
		$DoSavePlatform = 1;
	}

	EditBuildExe($currentExe);
}

sub DeleteBuildExe
{
	if (!@Executables) {
		print "No Build Executables defined for Platform\n";
		return;
	}

	my $toDelete = "";
	do {
		$toDelete = GetUserInput("Delete Build Executable [\"?\" to display list]", ": ");

		if ($toDelete =~ /^\?/) {
			my @displayExe = sort(@Executables);
			$toDelete = GetUserListSelection("Delete Build Executable", ": ", 20, @displayExe);
		}

		if (!$toDelete) {
			print "Executable not specified\n";
			return;
		}
		else {
			my @inExeList = grep(/^\Q$toDelete\E$/, @Executables);
			if (!@inExeList) {
				print "$toDelete is not a defined Build Executable!\n";
				$toDelete = "";
			}
		}
	} while (!$toDelete);

	RemoveExecutable($toDelete);
	$DoSavePlatform = 1;
	print "Deleted $toDelete\n";
}

sub EditBuildExe
{
	$DisplayFull = 1;

	my $toEdit = shift @_;
	while (!$toEdit) {
		$toEdit = GetUserInput("Edit Build Executable [\"?\" to display list]", ": ");

		if ($toEdit =~ /^\?/) {
			my @displayExe = sort(@Executables);
			$toEdit = GetUserListSelection("Edit Build Executable", ": ", 20, @displayExe);
		}

		if (!$toEdit) {
			print "Executable not specified\n";
			return;
		}
		else {
			my @inExeList = grep(/^\Q$toEdit\E$/, @Executables);
			if (!@inExeList) {
				print "$toEdit is not a defined Build Executable!\n";
				$toEdit = "";
			}			
		}		
	}
	
	$CurrentBuildExe = $toEdit;
	print "Editing $CurrentBuildExe...\n\n";

	SetCurrentMenu("PCExeEdit");
	DisplayCurrentMenu();
}

sub SetBuildExe
{
	my $newExe = GetUserInput("Executable", ": ", $CurrentBuildExe);

	if (!$newExe || $newExe eq $CurrentBuildExe) {
		print "No change to executable\n";
		return ;
	}

	my @inExeList = grep(/^\Q$newExe\E$/, @Executables);
	if (@inExeList) {
		print "$newExe is already a defined Build Executable!\n";
		my $doReplace = GetUserInput("Replace $newExe", "? ", "N");
		if ($doReplace =~ /^Y/i) {
			print "Replacing $newExe with current settings\n";
			RemoveExecutable($newExe);
		}
		else {
			print "Executable name change cancelled\n";
			return;
		}
	}				

	DefineExecutable($newExe,
					 $FlagPrefixes{$CurrentBuildExe},
					 $OutputFlag{$CurrentBuildExe},
					 $DerivedOutput{$CurrentBuildExe},
					 $StandardFlags{$CurrentBuildExe},
					 $DependencyExcludeFilters{$CurrentBuildExe});

	RemoveExecutable($CurrentBuildExe);
	$CurrentBuildExe = $newExe;
	$DoSavePlatform = 1;
}

sub SetBuildExeFlagPrefixes
{
	print "Current Flag Prefixes: $FlagPrefixes{$CurrentBuildExe}\n";
	$FlagPrefixes{$CurrentBuildExe} = GetUserInput("Flag Prefixes", ": ");
	$DoSavePlatform = 1;
}

sub SetBuildExeOutputFlags
{
	print "Current Output Flag Identifiers: $OutputFlag{$CurrentBuildExe}\n";
	$OutputFlag{$CurrentBuildExe} = GetUserInput("Output Flag Identifiers", ": ");
	$DoSavePlatform = 1;
}

sub SetBuildExeStandardFlags
{
	print "Current Standard Flags: $StandardFlags{$CurrentBuildExe}\n";
	$StandardFlags{$CurrentBuildExe} = GetUserInput("Standard Flags", ": ");
	$DoSavePlatform = 1;
}

sub SetBuildExeDependencyExclude
{
	print "Current Dependency Exclusion Filters: $DependencyExcludeFilters{$CurrentBuildExe}\n";
	$DependencyExcludeFilters{$CurrentBuildExe} = GetUserInput("Dependency Exclusion Filters", ": ");
	$DoSavePlatform = 1;
}

sub SetBuildExeDerivedRules
{
	print "Current Rules for Deriving Output: $DerivedOutput{$CurrentBuildExe}\n";
	$DerivedOutput{$CurrentBuildExe} = GetUserInput("Rules for Deriving Output", ": ");
	$DoSavePlatform = 1;
}

######################################################
# Openmake Build Types

sub DisplayBTs
{
	my $output = "";
	
	if ($DisplayFull) {
		$output .= "Openmake Build Types\n\n";
	}
	else {
		$output .= "Openmake Build Types Summary\n\n";
	}

	my $displayDefault = $DefaultBuildType;
	$displayDefault = "[Not Set]" if (!$DefaultBuildType);
	$output .= "Default Build Type: $displayDefault\n\n";

	my @displayBTs = sort(@BuildTypes);
	if (!@displayBTs) {
		$output .= "No Build Types defined\n";
	}
	else {
		$output .= "Build Types:\n";
		foreach my $buildType (@displayBTs) {
			$output .= DisplayBT($buildType);
		}
	}
	
	ShowList(20, split(/\n/, $output));
}

sub LoadBTFile
{
	my $arg = shift @_;
	my $cfgFile;

	if ($arg) {
		$cfgFile = $arg;
	}
	else {
		$cfgFile = GetUserInput("Openmake Build Types file", ": ", $BTFile);
	}

	if (!-f $cfgFile) {
		print "Openmake Build Type file $cfgFile cannot be found!\n";
		return ;
	}

	ResetBTs(1);
	print "Loading Openmake Build Type from $cfgFile... ";
	if (LoadBuildTypes($cfgFile)) {
		print "Done\n";
		$BTFile = $cfgFile;
		DisplayBTs() if (!$InInit);
	}
	else {
		print "ERROR!\n";
		$BTFile = "" if ($InInit);
		if (-f $BTFile) {
			print "Reseting Platform configuration using $BTFile!\n";
			ResetBTs(2);
		}
		else {
			print "Clearing Openmake Build Types\n";
			ResetBTs(1);
		}
	}
}

sub SaveBTFile
{
	if (!@BuildTypes) {
		print "No Build Types have been defined!\n";
		return;
	}

	my $default = $BTFile;
	my $cfgFile = GetUserInput("Save to File", ": ", $BTFile);

	if (!$cfgFile) {
		print "Filename not specified!\n";
		return;
	}

	if (SaveBuildTypes($cfgFile)) {
		$BTFile = $cfgFile;
		$DoSaveBuildTypes = 0;
	}
	else {
		print "Couldn't write to $cfgFile\n";
	}
}

sub ResetBTs
{
	my $resetArg = shift @_;
	my $reloadFromFile = 0;
	my $doAsk = 1;

	if ($resetArg == 1) {
		$doAsk = 0;
	}
	elsif ($resetArg == 2) {
		$reloadFromFile = 1;
		$doAsk = 0;
	}

	if ($resetArg == 0 && $doAsk) {
		if ($BTFile && -f $BTFile) {
			my $YN = GetUserInput("Reload Openmake Build Types from $BTFile?", " ", "Y");
			if ($YN =~ /^y/i) {
				$doAsk = 0;
				$reloadFromFile = 1;
			}
		}
	}

	if ($reloadFromFile && $BTFile && -f $BTFile) {
		if ($doAsk) {
			my $YN = GetUserInput("Reload Openmake Build Types from $BTFile?", " ", "Y");
			if ($YN !~ /^y/i) {
				print "Openmake Build Types reload cancelled.\n";
				return ;
			}
		}

		InitializeBuildTypes();
		if (!LoadBuildTypes($BTFile)) {
			print "Couldn't load Openmake Build Types from $BTFile!\n";
			InitializeBuildTypes();
		}		
	}
	else {
		if ($doAsk) {
			my $YN = GetUserInput("Clear Openmake Build Types?", " ", "Y");
			if ($YN !~ /^y/i) {
				print "Openmake Build Types reset cancelled.\n";
				return ;
			}
			else {
				$BTFile = "";
			}
		}

		InitializeBuildTypes();
		print "Openmake Build Types cleared\n" if (!$InInit);
	}

	$DoSaveBuildTypes = 0;
}

sub DisplayBT
{
	my $args = @_;
	
	my $buildType = shift @_;
	$buildType = $CurrentBuildType if (!$buildType);

	my $output = "";
	
	$output .= "  $buildType\n";

	if ($DisplayFull) {
		$output .= "    Final Target     $BuildTypeFinalTarget{$buildType}\n";
		$output .= "    Generated Target $BuildTypeGenerateTarget{$buildType}\n" if ($BuildTypeGenerateTarget{$buildType});
        $output .= "\n";
        
		my @btRules = keys(%BuildTypeRulesExe);
		@btRules = grep(/\Q$buildType\E\|/, @btRules);
		@btRules = sort(@btRules);

		foreach my $rule (@btRules) {
			$output .= DisplayRule($rule);
		}
	
		print "\n";
	}
	
	ShowList(20, $output) if (!$args);
	
	return $output;
}

sub SetDefaultBT 
{
	my $toDefault = "";
	do {
		$toDefault = GetUserInput("Build Type [\"?\" to display list]", ": ", $DefaultBuildType);

		if ($toDefault =~ /^\?/) {
                        my @displayBTs = sort(@BuildTypes);
                        $toDefault = GetUserListSelection("Build Type", ": ", 20, @displayBTs);
                }

                if (!$toDefault || $toDefault eq "-") {
                        print "Build Type not specified\n";
                        return;
		}
		else {
			my @inBTList = grep(/^\Q$toDefault\E$/, @BuildTypes);
			if (!@inBTList) {
				print "$toDefault is not a defined Build Type!\n";
				$toDefault = "";
			}			
		}	  
	} while (!$toDefault);
	
	$DefaultBuildType = $toDefault;
	$DoSaveBuildTypes = 1;
}

sub AddBuildType 
{
	my $currentBT = "";
	my @inList = ();
	do {
		$currentBT = GetUserInput("Build Type", ": ");
		if (!$currentBT) {
			print "Build Type not specified!\n";
			return ;
		}

		@inList = grep(/^\Q$currentBT\E/, @BuildTypes);
		if (@inList) {
			my $doEdit = GetUserInput("Build Type alredy defined.  Edit", "? ", "Y");
			if ($doEdit !~ /^Y/i) {
				return;
			}
		}
	} while (!$currentBT);

	if (!@inList) {
		push(@BuildTypes, $currentBT);
		$DoSaveBuildTypes = 1;
	}

	EditBuildType($currentBT);
}

sub DeleteBuildType
{
	if (!@BuildTypes) {
		print "No Build Types defined!\n";
		return;
	}

	my $toDelete = "";
	do {
		$toDelete = GetUserInput("Delete Build Type [\"?\" to display list]", ": ");

		if ($toDelete =~ /^\?/) {
			my @displayBTs = sort(@BuildTypes);
			$toDelete = GetUserListSelection("Delete Build Type", ": ", 20, @displayBTs);
		}

		if (!$toDelete) {
			print "Build Type not specified\n";
			return;
		}
		else {
			my @inBTList = grep(/^\Q$toDelete\E$/, @BuildTypes);
			if (!@inBTList) {
				print "$toDelete is not a defined Build Type!\n";
				$toDelete = "";
			}			
		}	  
	} while (!$toDelete);

	RemoveBuildType($toDelete);
	$DoSaveBuildTypes = 1;
	print "Deleted $toDelete\n";
}

sub EditBuildType
{
	$DisplayFull = 1;

	my $toEdit = shift @_;
	while (!$toEdit) {
		$toEdit = GetUserInput("Edit Build Type [\"?\" to display list]", ": ");
	
		if ($toEdit =~ /^\?/) {
			my @displayBTs = sort(@BuildTypes);
			$toEdit = GetUserListSelection("Edit Build Type", ": ", 20, @displayBTs);
		}
		
		if (!$toEdit) {
			print "Build Type not specified\n";
			return;
		}
		else {
			my @inBTList = grep(/^\Q$toEdit\E$/, @BuildTypes);
			if (!@inBTList) {
				print "$toEdit is not a defined Build Type!\n";
				$toEdit = "";
			}			
		}		
	}
	
	$CurrentBuildType = $toEdit;
	print "Editing $CurrentBuildType...\n\n";

	SetCurrentMenu("BTBTEdit");
	DisplayCurrentMenu();
}

sub SetBTName
{
	my $newBT = GetUserInput("Build Type", ": ", $CurrentBuildType);

	if (!$newBT || $newBT eq $CurrentBuildType) {
		print "No change to Build Type\n";
		return ;
	}

	my @inBTList = grep(/^\Q$newBT\E$/, @BuildTypes);
	if (@inBTList) {
		print "$newBT is already a defined Build Type!\n";
		my $doReplace = GetUserInput("Replace $newBT", "? ", "N");
		if ($doReplace =~ /^Y/i) {
			print "Replacing $newBT with current settings\n";
			RemoveBuildType($newBT);
		}
		else {
			print "Build Type name change cancelled\n";
			return;
		}
	}				

	DefineBuildType($newBT, 
					$BuildTypeFinalTarget{$CurrentBuildType},
					$BuildTypeGenerateTarget{$CurrentBuildType});

	my @btRules = keys(%BuildTypeRulesExe);
	@btRules = grep(/^\Q$CurrentBuildType\E\|/, @btRules);
	foreach my $rule (@btRules) {
		$rule =~ /\|(.*)/;
		my $realRule = $1;
		DefineBuildTypeRule($newBT, $realRule,
							$BuildTypeRulesExe{$rule},
							$BuildTypeRulesFlags{$rule});
	}
	RemoveBuildType($CurrentBuildType);
	$CurrentBuildType = $newBT;
	$DoSaveBuildTypes = 1;
}

sub SetBTFinalTargetExt
{
	my $newBTFinalTargetExt = GetUserInput("Final Target Extension", ": ", $BuildTypeFinalTarget{$CurrentBuildType});
	$BuildTypeFinalTarget{$CurrentBuildType} = $newBTFinalTargetExt;
}

sub SetBTGeneratedExt
{
	my $newBTGenerateTargetExt = GetUserInput("Generated Target Extension", ": ", $BuildTypeGenerateTarget{$CurrentBuildType});
	
	if ($newBTGenerateTargetExt eq "-") {
		delete $BuildTypeGenerateTarget{$CurrentBuildType};
		print "Deleted Generated Target Extension setting\n";
	}
	else {
		$BuildTypeGenerateTarget{$CurrentBuildType} = $newBTGenerateTargetExt;
	}
}

sub DisplayRule
{
	my $rule = shift @_;

	$rule =~ /\|(.*)/;
	my $realRule = $1;

	my $output = "";

	$output .= "      $realRule\n";
	$output .= "        Executable $BuildTypeRulesExe{$rule}\n";
	$output .= "        Flags      $BuildTypeRulesFlags{$rule}\n";
	$output .= "\n";
	
	return $output;
}

sub AddBTRule
{
	my $realRule = GetUserInput("Rule", ": ");
	if (!$realRule) {
		print "Rule not specified\n";
		return;
	}

	my $rule = $CurrentBuildType . "|$realRule";
	my $ruleTarget = GetRuleTarget($rule);
	print "Rule Target: $ruleTarget\n";

	my @btRules = keys(%BuildTypeRulesExe);
	@btRules = grep(/^\Q$CurrentBuildType\E\|/, @btRules);
	my @inBTRules = grep(/\|\s*\Q$ruleTarget\E\s*\<-/, @btRules);
	if (@inBTRules) {
		my $doEdit = GetUserInput("Rule for $ruleTarget alredy defined.	 Replace", "? ", "Y");
		if ($doEdit !~ /^Y/i) {
			return;
		}
		else {
			$rule = $inBTRules[0];
			$rule =~ s/^[^\|]*\|//;
		}
	}

	EditBTRule($rule, $realRule);
}

sub DeleteBTRule
{
	my $toDelete = "";

	my @btRules = keys(%BuildTypeRulesExe);
	@btRules = grep(/^\Q$CurrentBuildType\E\|/, @btRules);
	foreach my $rule (@btRules) {
		$rule =~ s/^[^\|]*\|//;
	}
	@btRules = sort(@btRules);

	do {
		$toDelete = GetUserInput("Delete Rule [\"?\" to display list]", ": ");

		if ($toDelete =~ /^\?/) {
			$toDelete = GetUserListSelection("Delete Rule", ": ", 20, @btRules);
		}

		if (!$toDelete) {
			print "Rule not specified!\n";
			return ;
		}
		else {
			$toDelete = GetRuleTarget($toDelete) if ($toDelete =~ /\<-/);
			my @inBTRules = grep(/^\s*\Q$toDelete\E\s*\<-/, @btRules);
			if (!@inBTRules) {
				print "Rule for $toDelete not defined!\n";
				return ;
			}
			$toDelete = $inBTRules[0];
		}
	} while (!$toDelete);
	
	RemoveBuildTypeRule($CurrentBuildType, $toDelete);
	print "Deleted rule $toDelete\n";
	$DoSaveBuildTypes = 1;
}

sub EditBTRule
{
	my $toEdit = shift @_;
	my $newRule = shift @_;

	if (!$toEdit) {
		my @btRules = keys(%BuildTypeRulesExe);
		@btRules = grep(/^\Q$CurrentBuildType\E\|/, @btRules);
		foreach my $rule (@btRules) {
			$rule =~ s/^[^\|]*\|//;
		}
		@btRules = sort(@btRules);

		do {
			$toEdit = GetUserInput("Edit Rule [\"?\" to display list]", ": ");

			if ($toEdit =~ /^\?/) {
				$toEdit = GetUserListSelection("Edit Rule", ": ", 20, @btRules);
			}

			if (!$toEdit) {
				print "Rule not specified!\n";
				return ;
			}
			else {
				$toEdit = GetRuleTarget($toEdit) if ($toEdit =~ /\<-/);
				my @inBTRules = grep(/^\s*\Q$toEdit\E\s*\<-/, @btRules);
				if (!@inBTRules) {
					print "Rule for $toEdit not defined!\n";
					return ;
				}
				$toEdit = $inBTRules[0];
			}
		} while (!$toEdit); 
	}

	$newRule = GetUserInput("Rule", ": ", $toEdit) if (!$newRule);
	my $editKey = $CurrentBuildType . "|" . $toEdit;
	my $newRuleExe = GetUserInput("Rule Executable", ": ", $BuildTypeRulesExe{$editKey});
	my $newRuleFlags = GetUserInput("Rule Flags", ": ", $BuildTypeRulesFlags{$editKey});

	if ($toEdit ne $newRule) {
		RemoveBuildTypeRule($CurrentBuildType, $toEdit);
	}
	DefineBuildTypeRule($CurrentBuildType, $newRule, $newRuleExe, $newRuleFlags);

	$DoSaveBuildTypes = 1;	  
}

######################################################
# Build Conversion
sub DisplayBInfo
{
	my $output = "";
	
	my $displayProject = $OpenmakeProject;
	$displayProject = "[Not Set]" if (!$displayProject);
	
	$output .= "Openmake Project: $displayProject\n\n";
	
	if (!@FinalTargets) {
		$output .= "No Final Targets found!\n";
	}
	else {
    	if ($#TargetDeps) {
    		ProcessTargets();
    	}
    
    	@FinalTargets = sort(@FinalTargets);
    	foreach my $target (@FinalTargets) {
    		$output .= GetTargetInfo($target);
    	}
    }
    
    ShowList(20, split(/\n/, $output));
}

sub DisplayBTargets
{
	my $output = "";
	@FinalTargets = sort(@FinalTargets);
	
	if (!@FinalTargets) {
		$output .= "No Final Targets found!\n\n";
	}
	else {
		$output .= "Final Targets:\n";

		foreach my $target (@FinalTargets) {
			my $FTandBT = "$target";
			(my $matchedBT, my $dummy) = MatchTargetToBuildType($target);
			$FTandBT .= " [$matchedBT]" if ($matchedBT);
			$output .= "$FTandBT\n";
		}
		
		if ($BatchMode) {
		    print $output . "\n";
		}
		else {
		    ShowList(20, split(/\n/, $output));
		}
	}
}

sub FindBTargetsPC
{
	@FinalTargetExts = @PlatformFinalTargetExts;
	
	if (@FinalTargetsExts) {
		$SetFinalTargestUsing = 1;
	}
	else {
		$SetFinalTargestUsing = 0;
	}

	if (!$InInit) {
		if (!@FinalTargetExts) {
			print "No Platform Configuration Target Extensions defined!\n";
			print "Using Build Information...\n\n";	
		}
		else {
			print "Looking for Targets Extensions: " . join(" ", @FinalTargetExts) . "\n\n";
		}
	
		InitializeTargetProcessing();
		GetFinalTargets();	
		DisplayBTargets();
	}
}

sub FindBTargetsBT
{
	@FinalTargetExts = ();
	
	foreach my $bt (@BuildTypes) {
		push(@FinalTargetExts, $BuildTypeFinalTarget{$bt});
	}
	@FinalTargetExts = unique(@FinalTargetExts);
	
	if (@FinalTargetsExts) {
		$SetFinalTargestUsing = 2;
	}
	else {
		$SetFinalTargestUsing = 0;
	}

	if (!$InInit) {
		if (!@FinalTargetExts) {
			print "No Build Types Final Target Extensions defined!\n";
			print "Using Build Information...\n\n";
		}
		else {
			print "Looking for Targets Extensions: " . join(" ", @FinalTargetExts) . "\n\n";
		}
	
		InitializeTargetProcessing();
		GetFinalTargets();
		DisplayBTargets();
	}
}

sub FindBTargetsBInfo
{
	$SetFinalTargestUsing = 0;
	@FinalTargetExts = ();
	InitializeTargetProcessing();
	GetFinalTargets();
	DisplayBTargets();
}

sub AddBTarget 
{
	my $toAdd = "";
	my @displayTargets = keys(%ParsedTargetDeps);
	@displayTargets = sort(@displayTargets);
	do {
		$toAdd = GetUserInput("Add as Final Target [\"?\" to display list]", ": ");

		if ($toAdd =~ /^\?/) {
			$toAdd = GetUserListSelection("Add as Final Target", ": ", 20, @displayTargets);
		}

		if (!$toAdd) {
			print "Target not specified\n";
			return;
		}
		else {
			my @inTargetList = grep(/^\Q$toAdd\E$/, @displayTargets);
			if (!@inTargetList) {
				print "$toAdd is not a Build Target!\n";
				$toAdd = "";
			}			
		}	  
	} while (!$toAdd);
	
	my @inFinalTargetList = grep(/^\Q$toAdd\E$/, @FinalTargets);
	if (@inFinalTargetList) {
		print "$toAdd is already in the Final Targets list!\n";
		return ;
	}
	
	push(@FinalTargets, $toAdd);
	print "Added $toAdd to Final Targets list\n";
}

sub DeleteBTarget
{
	if (!@FinalTargets) {
		print "No Final Targets found!\n";
		return;
	}

	my $toDelete = "";
	@FinalTargets = sort(@FinalTargets);
	do {
		$toDelete = GetUserInput("Delete Final Target [\"?\" to display list]", ": ");

		if ($toDelete =~ /^\?/) {
			$toDelete = GetUserListSelection("Delete Final Target", ": ", 20, @FinalTargets);
		}

		if (!$toDelete) {
			print "Target not specified\n";
			return;
		}
		else {
			my @inTargetList = grep(/^\Q$toDelete\E$/, @FinalTargets);
			if (!@inTargetList) {
				print "$toDelete is not in the Final Target list!\n";
				$toDelete = "";
			}			
		}	  
	} while (!$toDelete);

	@FinalTargets = grep(!/\Q$toDelete\E/, @FinalTargets);
	print "Deleted $toDelete from Final Targets list\n";
}

sub SetProjectName
{
	$OpenmakeProject = GetUserInput("Openmake Project Name", ": ", $OpenmakeProject);
	
	if (!$OpenmakeProject) {
		print "Openmake Project Name not specified!\n";	
	}
	else
	{
	 open (FP,">project.cfg");
	 print FP "$OpenmakeProject\n";
	 close(FP);
	}
}

sub GenerateBuildTypes
{
	if (!@FinalTargets) {
		print "No Final Targets found!\n";
		return ;
	}
	
    if ($#TargetDeps) {
    	ProcessTargets();
    }
    
	@FinalTargets = sort(@FinalTargets);
	
	foreach my $target (@FinalTargets) {
		(my $matchedBT, my $dummy) = MatchTargetToBuildType($target);
		my $output = GetTargetInfo($target, 1);
		ShowList(20, split(/\n/, $output));
		my $newBT = "";
		do {
			$newBT = GetUserInput("Build Type Name", ": ", $matchedBT);

			if ($newBT eq "-") {
				break ;
			}
		
			my @inBTList = grep(/^\Q$newBT\E$/, @BuildTypes);
			if (@inBTList) {
				my $YN = GetUserInput("Replace existing Build Type", "? ", "Y");
				if ($YN !~ /^y/i) {
					$newBT = "";
				}
			}
		} while (!$newBT);
		
		if ($newBT ne "-") {
			GenerateBuildTypeFromTargetRules($newBT, $target);
			$DoSaveBuildTypes = 1;
		}
	}
}

sub GenerateBuildTGTs
{
	if (!$OpenmakeProject) {
		print "Openmake Project Name not set!\n";
		return ;	
	}
	
	if (!@FinalTargets) {
		print "No Final Targets found!\n";
		return ;
	}
	
	if (!@BuildTypes) {
		print "No Openmake Build Types defined!\n";
		return ;
	}
	
    if ($#TargetDeps) {
    	ProcessTargets();
    }
    
	@FinalTargets = sort(@FinalTargets);
	
	my $output = "";
	
	foreach my $target (@FinalTargets) {
		$output .= "Generating TGT for $target... ";
		(my $matchedBT, my $dummy) = MatchTargetToBuildType($target);
		if (!$matchedBT) {
			$output .= "ERROR!\n";
			$output .= "No matching Build Type!\n";
			$output .= "Skipping $target...\n";
			next ;
		}
		my $tgtName = GenerateTgt($target, $OS, $matchedBT);
		if (!$tgtName) {
			$output .= "ERROR!\n";
			$output .= "Couldn't write to $tgtName!\n";
		}
		else {
			$output .= "Done\n";
			$output .= "  Wrote $tgtName\n";
		}
	}
	
	if ($BatchMode) {
		print $output;
	}
	else {
		ShowList(20, split(/\n/, $output));
	}
}

sub LoadBInfoFile
{
	my $arg = shift @_;
	my $biFile;

	if ($arg) {
	   $biFile = $arg;
	}
	else {
	   $biFile = GetUserInput("Build Output File", ": ", $biFile);
	}

	if (!-f $biFile) {
	   print "Build Output file $biFile cannot be found!\n";
	   return ;
	}

	ResetBInfo(1);
	print "Loading Build Information from $biFile... ";
	if (ProcessCommandFile($biFile)) {
		print "Done\n";
	   	$BuildOutputFile = $biFile;
		GetFinalTargets();
		DisplayBTargets() if (!$InInit);
	}
	else {
		print "ERROR!\n";
		if (-f $BuildOutputFile) {
			print "Reseting Platform configuration using $BuildOutputFile!\n";
			ResetBInfo(2);
		}
		else {
			print "Clearing Build Information\n";
			ResetBInfo(1);
		}
	}
}

sub ResetBInfo
{
	my $resetArg = shift @_;
	my $reloadFromFile = 0;
	my $doAsk = 1;

	if ($resetArg == 1) {
		$doAsk = 0;
	}
	elsif ($resetArg == 2) {
		$reloadFromFile = 1;
		$doAsk = 0;
	}

	if ($resetArg == 0 && $doAsk) {
		if ($BuildOutputFile && -f $BuildOutputFile) {
			my $YN = GetUserInput("Reload Build Information from $BuildOutputFile?", " ", "Y");
			if ($YN =~ /^y/i) {
				$doAsk = 0;
				$reloadFromFile = 1;
			}
		}
	}

	if ($reloadFromFile && $BuildOutputFile && -f $BuildOutputFile) {
		if ($doAsk) {
			my $YN = GetUserInput("Reload Build Information from $BuildOutputFile?", " ", "Y");
			if ($YN !~ /^y/i) {
				print "Build Information reload cancelled.\n";
				return ;
			}
		}

		InitializeParsing();
		InitializeTargetProcessing();
		if (!ProcessCommandFile($BuildOutputFile)) {
			print "Couldn't load Build Information from $BuildOutputFile!\n";
			InitializeParsing();
		}		
	}
	else {
		if ($doAsk) {
			my $YN = GetUserInput("Clear Build Information?", " ", "Y");
			if ($YN !~ /^y/i) {
				print "Build Information reset cancelled.\n";
				return ;
			}
			else {
				$BuildOutputFile = "";
			}
		}

		InitializeParsing();
		InitializeTargetProcessing();
		print "Build Information cleared\n" if (!$InInit);
	}
}

######################################################
sub SafeExit
{
	if ($DoSavePlatform) {
		my $YN = GetUserInput("Save Platform Configuration", "? ", "Y");
		if ($YN =~ /^y/i) {
			SavePCFile();
		}
	}
	if ($DoSaveBuildTypes) {
		my $YN = GetUserInput("Save Build Types", "? ", "Y");
		if ($YN =~ /^y/i) {
			SaveBTFile();
		}
	}
	exit 0;
}


