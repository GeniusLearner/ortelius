#==========================================================================
#-- $Header: /CVS/openmake64/perl/lib/Openmake.pm,v 1.43 2011/07/29 18:49:39 steve Exp $
#
package Openmake;

BEGIN
{
 use Exporter ();
 use vars qw(@ISA  @EXPORT $VERSION $HEADER);
 use File::Copy;
 use Carp;
 use Openmake::Log;
 use Openmake::FileList;
 use Openmake::SearchPath;
 use Openmake::Footprint;
 use File::Glob ':glob';

 @ISA    = qw( Exporter );
 $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake.pm,v 1.43 2011/07/29 18:49:39 steve Exp $';
 if ( $HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path    = $1;
  my $version = $2;
  $version =~ s/\.//g;

  #-- massage path
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/;
  $VERSION = "6." . $major . $version;
 } #-- End: if ( $HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/...

 @EXPORT = qw(
   &mkfulldir
   &FirstFoundInPath
   &unique
   &GetCompiler
   &GetCompilerFlags
   &get_compiler
   &GetAntCompiler
   &CopyLocal
   &CopyExcludeLocal
   &GetClasspath
   &GetPackages
   &GetPackageDeps
   &GetBuildDirPackages
   &GetAntIncludeXML
   &GetSubTaskDeps
   &CommonPath
   &GenerateBillofMat
   &GenerateFootPrint
   &ExitScript
   &Exclude
   &GetExcludes
   &WriteAntXML
   &GetAnt
   &FindFlag
   &GetFlag
   &ProcessAntFlags
   &GetClasses
   &ParseModuleDirectories
   &StripModuleDirectories
   &AddDestdirDirectories
   &AntSplitDirs
   &Check4Errors
   &TrimIntDir
   &Check4Errors
   &lengthSort
   &ExpandEnv
   &AntFilesetOrg
   &CollapseFlags
   &EvalEnvironment
   &OrderLibs
   &GetTarget2RelTargetMap
   );

} #-- End: BEGIN

@DefaultExcludes =
  qw(
  .packages
  .classpath
  .javac
  .hsig
  .rmic
  harvest.sig
  ~
  CVS
  .cvsignore
  SCCS
  vssver.scc
  .tgtdeps
  );

=head1 NAME

Openmake.pm

=head1 LOCATION

program files/openmake6/perl/lib

=head1 DESCRIPTION

Openmake.pm is a reusable PERL module that contains functions that are
used by the Openmake scripts to pass information from the scripts to
the compiler. When developing customized scripts, it is useful to
borrow these common routines.  Functions are organized as follows:

=over 4

=item Path Functions

Provides convenient ways to search for files in the PATH.

=item List Functions

Provides an easy ways to change lists contents.

=item Compiler Flag Functions

Parses compiler flags from a string passed by OM to the scripts.

=item File Copy & Directory Functions

Provides the ability to copy files that are needed for performing compiles and manipulate directories.

=item JAVA Related Functions

Provides the ability to format file names into compatible JAVA format and to get the JAVA dependencies.

=item ANT Build XML Functions

Provides a wrapper to create the build.xml is used by ANT.

=item Bill of Material Creator Functions

Allow you to add the Bill of Material reporting to your script.

=item Foot Print Creator Functions

Allow you to add Foot Printing to your script.

=item Cleanup Functions

These functions clean up variables and files, and set the return code for when a script needs to exit.

=item Misc Functions

=back

=head1 PATH FUNCTIONS

=head2 FirstFoundInPath ( $File, $UserPath )

This functions searches $MyUserPath for a file by the name of $MyFile.
This is useful for searching for an executable in a PATH statement.
It can also be used to find any file in any path.

If $MyUserPath is undefined, the user's default PATH operating system
environment variable will be searched.  On the Windows Operating System,
the PATHEXT Windows Environment Variable is also used to find the file by
appending the file extensions listed in the PATHEXT to the $MyFile name.

USAGE:

$FoundFile = FirstFoundInPath( $MyFile, $MyUserPath );

Note: $MyUserPath is an Openmake::SearchPath object that contains a
list of specific directories to search.

RETURNS:

Fully-qualified filename, i.e,  Path + Filename ( + Windows Extension).

If the filename cannot be found, the function returns a PERL Undefined String.

=head2 GetAnt

Do everything possible to find Ant.  The preferred method is to use the
shell or batch script provided with the Ant distribution which goes to
great lengths to set the local ant classpath

Order of priority:

=over 4

=item 1

Use ant executable in 'ANT_HOME'

=item 2

Use ant.jar in 'ANT_HOME/lib'

=item 3

Use ant.jar found in 'ANT_HOME'

=item 4

Use ant executable in system 'PATH'

=item 5

Use ant.jar found in 'CLASSPATH'

=item 6

Use ant.jar found in 'PATH'

=back

USAGE:

$antCommand = GetAnt;

RETURNS:

Command-line statement used to run ant

=head1 LIST FUNCTIONS

=head2 unique

A filter for lists that simply returns a list without duplicates.

USAGE:

@mylist = unique @mylist;

RETURNS:

Filtered list

=head2 Exclude( $pattern, @inlist )

Filters out items from a list that match the specified pattern.

USAGE:

@outlist = Exclude( $pattern, @inlist );

$pattern is a string using shell wildcards (? and *) and
not a regular expression

@inlist is the list of items to be filtered

RETURNS:

The list of filtered items

=head1 COMPILER FLAG FUNCTIONS

=head2 GetCompiler

Extracts compiler name from flags passed if these contain any of
the compilers in AvailableCompilers, otherwise uses as compiler
CompilerFound. Searches for compiler in Path.

In addition, if a compiler name is passed through the flags of a
TGT file, GetCompiler will attempt to find that compiler,
regardless if it is in the Path. The flags in the TGT file can be
a "|" delimited list of compilers to look for, including the name
of the compiler (not just a path to the compiler). E.g.

  $(GCC1.0)/gcc|$(GCC1.1)/gcc

Environment variables can be used, and the GetCompiler method will
use the first found in the list. If it cannot find one of the
compilers in the list (either because the compiler doesn't exist,
or because an Environment variable is undefined), GetCompiler will
attempt to find the compiler in the Path.

USAGE:

($Compiler, $Flags) = GetCompiler ;

RETURNS:

($Compiler, $Flags)

$Compiler is the full path to the found compiler
$Flags is the compiler flag string minus the found compiler.

For Java subtasks, see GetFlag.

=head2 FindFlag( $flagString, @possibleFlags )

Verifies the existence of one of a set of flags within a string.
The first flag matched is returned.

USAGE:

$myFlag = FindFlag( $flagString, @possibleFlags );

RETURNS:

First found item from a list of items, @possibleFlags, from a given
string, $flagString, where the individual items are delimited by
word boundaries ( ^, & and \s).

  @possibleFlags = qw( javac jikes jvc );
  $flagString = 'javac -deprecation -g';
  $compiler = FindFlag( $flagString, @possibleFlags );

The $compiler variable above will have the value 'javac'.

=head2 GetFlag( $flagString, @possibleFlags );

Used with Ant Tasks Javac and Rmic to get the compiler name to use.
Unlike 'GetCompiler', the fully qualified path to the compiler is
not returned, just the exactly matched compiler name.

USAGE:

($newFlagString, $myFlag) = GetFlag( $flagString, @possibleFlags );

RETURNS:

($newFlagString, $myFlag)

$newFlagString is $flagString without the matched flag and the first
found item from the list of possible items @possibleFlags.

$myFlag is the matched flag string.

=head2 GetExcludes( $Defines )

Separates and generates a list of exclude patterns from a defines string.

USAGE:

( $pureDefines, @excludePatterns ) = GetExcludes ( $Defines );

$Defines is a string representing, for instance, the flags used in a
java subtask

RETURNS:  ( $pureDefines, @excludePatterns )

$pureDefines is the processed $Defines string with the exclude
statements removed

@excludePatterns is the list of excluded patterns from the $Defines string

For example:

  $Defines = 'flag1 exclude=.java exclude=.class flag4';

will yield

  $pureDefines = 'flag1 flag4';
  @excludePatterms = qw( .java .class );

=head1 FILE COPY AND DIRECTORY FUNCTIONS

=head2 mkfulldir ( $Path )

Creates a directory, including parent directories, if necessary.

USAGE:

mkfulldir( $Path );

$Path is a string representing the directory to be created.  If $Path
does not end in a '/' or '\', mkfulldir assumes that $Path contains
a filename and will strip off that filename.

=head2 CopyLocal( $FullPathDeps, $RelDeps, $toDir )
  CopyLocal( $FullPathDeps, $RelDeps, $toDir, @includeExtensions )

When a compiler doesn't have the capability of reading source code in
directories other than the build directory (e.g. jdk 1.1 javac,
MicroFocus COBOL).  Files that Openmake has found in the Search Path that
aren't already local are copied local and files that are copied are pushed
onto an array, @main::dellist, so they can be deleted after the compile
operation.

Copies fully qualified files to a directory.  The 'include' list of
extensions is a list of patterns to match against the end of the full
path.  For example, '.java' will copy all java files - regardless of path
depth - and no other file types.

Filters out file ending with an element of @Openmake::DefaultExcludes.

Also pushes copied files onto @main::dellist for later deletion.

USAGE:

@localDeps = CopyLocal( $FullPathDeps, $RelDeps, $toDir, @includeExtensions );

$FullPathDeps and $RelDeps are Openmake::FileList references.

$FullPathDeps is the full path

$RelDeps are the same files but with the relative paths after they are
copied local.

$toDir is the destination directory

@includeExtensions is an optional list of extensions to be matched against

For example,

  $lf = Openmake::FileList->new( qw( c:\ref\project\dev\hello.c
                                     c:\ref\index.html ) );
  $rf = Openmake::FileList->new( qw( project\dev\hello.c index.html ) );
  @localdeps = CopyLocal( $lf, $rf, 'source', qw( .c ) );

In this example, @localdeps will contain the single element
'project\dev\hello.c'.

RETURNS:

Returns a list of ALL files that exist in the to-directory after
the copy operation, that match the filtering conditions.  The files are
listed relative to the destination directory, $toDir.

WARNINGS:

The pattern matching is imperfect and can't be made better
without more information, such as which Search Path directory the file
originates from.  Currently there is no way to turn off the @DefaultExcludes.

=head2 CopyExcludeLocal( $TargetDeps, $RelDeps, $toDir, @excludeExtensions )

Copies files from wherever to a directory.  The 'exclude' list of
extensions is a list of patterns to match against the end of the full
path.  For example, '.java' will exclude all java files.  Wildcards are
not supported.  Files ending with an element of @Openmake::DefaultExcludes
will also be excluded.

Also pushes copied files onto @main::dellist for later deletion.

See CopyLocal.

USAGE:

@localDeps = CopyExcludeLocal( $TargetDeps, $RelDeps, $toDir, @excludeExtensions );

RETURNS:

A list of ALL files that exist in the to-directory after the copy
operation, that match the filtering conditions.

WARNING:

The pattern matching is imperfect and can't be made better without
more information, such as which Search Path directory the file
originates from.

=head2 CommonPath( $TargetDeps, $RelDeps, $type,
                   $include_extensions_ref, $exclude_extensions_ref);

Groups files that are in both $TargetDeps (full path information) and $RelDeps
(relative path information) into lists with a common path. Returns a hash of
files, indexed by the common path. The values of the hash are references to
arrays containing the files that are in that common path.

$type controls how the paths are determined. $type == 0 divides the paths at the
Search Path/Dependency boundary. $type == 1 divides the paths at the
path/filename boundary. See the example below

Files can be filtered, either by including extensions, or excluding them. The
filters are passed as a reference to arrays.

The returned hash is a data structure indexed by directory. Each value per
directory is a hash that has two keys:

=over 4

=item 'DIR_DEPTH': the depth of this directory below the Search Path directory.
For items of type 1, DIR_DEPTH is always 0.

=item 'FILES': an array of files under this directory

=back

USAGE:

%common_paths = CommonPath( $FullPathDeps, $RelDeps, $type, $inc_ref, $exc_ref);

$FullPathDeps and $RelDeps are Openmake::FileList references.

$FullPathDeps is the full path

$RelDeps are the same files but with the relative paths after they are
copied local.

$type is an integer detailing where to break the hash key. $type == 0 breaks
at the Search Path/Dependency line, whereas $type == 1 breaks at the path/
filename line.

$inc_ref is a reference to an array of file extensions to include (optional)

$exc_ref is a reference to an array of file extensions to exclude (optional)

For example,

  $lf = Openmake::FileList->new( qw( c:\ref\project\dev\hello.c,
                                     c:\ref\project\test\goodbye.c,
                                     c:\ref\project\test\sub\sub.c,
                                     c:\ref\index.html ) );
  $rf = Openmake::FileList->new( qw( dev\hello.c test\goodbye.c index.html ) );

  %common_paths = CommonPath( $lf, $rf, 0, [.c] );

 In this example, the hash will contain

  %common_paths = ( 'C:\ref\project' =>
                      { 'DIR_DEPTH' => 0,
                        'FILES' => [ 'dev\hello.c', 'test\goodbye.c',
                                     'test\sub\sub.c' ]
                      }
                   )

 If $type == 1, the path returned will be slightly different

  %common_paths = CommonPath( $lf, $rf, 1, qw( .c) );

  %common_paths = ( 'C:\ref\project\dev'  =>
                     { 'DIR_DEPTH' => 1,
                       'FILES'     => [ 'hello.c' ],
                     },
                    'C:\ref\project\test' =>
                     { 'DIR_DEPTH' => 1,
                       'FILES'     => [ 'goodbye.c' ],
                     },
                    'C:\ref\project\test\sub' =>
                     { 'DIR_DEPTH' => 2,
                       'FILES'     => [ 'sub.c' ],
                     },
                   )

  The second format is useful for Ant type builds.

RETURNS:

Returns a hash keyed by path, pointing at an array of files under that path.

=head1 JAVA RELATED FUNCTIONS

=head2 ReadPackagesFile ( $TargetDeps )

Reads the .package file created by a JAVAC subtask.

USAGE:

@Packages = ReadPackagesFile( $TargetDeps );

$TargetDeps is an Openmake::FileList reference.

RETURNS:

A listed of compiled packages @Packages.

Entries in @Packages will be of the form:

  com/openmake/server/*

=head2 GetPackages( @FileList )

Parses a list of files and returns the list of java packages that the
files correspond to.

USAGE:

@packages = GetPackages( @FileList );

@FileList should be a list of relative (as opposed to fully qualified)
filenames

RETURNS:

A list of packages

=head2 GetPackageDeps ( $TargetDeps )

Reads the .package files created by all Java subtasks.

USAGE:

@AllPackages = GetPackageDeps ( $TargetDeps );

$TargetDeps is an Openmake::FileList reference.

RETURNS:

A listed of all packages @AllPackages.

Entries in @AllPackages will be of the form:

  com/openmake/server/*


=head2 GetBuildDirPackages( $dir, @possible_classes)

Finds packages on the filesystem under directory $dir that match
to the class files listed in @possible_classes. We are looking for
the Java package structure that might not be obvious from the
relative path in @possible_classes

Consider a possible file

  MinibankWeb/Java Source/com/minibank/foo.class

which belongs to the Java package com.minibank

Ant compiles this using destdir="intdir/classes" to

  <build dir>/intdir/classes/com/minibank/foo.class

In this case, $dir would be passed as "intdir/classes", and this
routine would search the local directory to find the class file.

USAGE:

@Found_Classes = &GetBuildDirPackages( $destdir, @possible_classes);
$ref_to_Found_Classes = &GetBuildDirPackages( $destdir, @possible_classes);

RETURNS:

An array, or reference to an array depending on the calling context.

=head2 GetClassPath ( $TargetDeps )

Reads the .classpath files created by CLASSPATH subtask(s).

USAGE:

$Classpath = GetClassPath( $TargetDeps );

$TargetDeps is an Openmake::FileList reference.

RETURNS:

A string $Classpath with the combined list of classpaths.

=head2 GetClasses ( $TargetDeps )

Returns the list of all .class generated by JAVAC and RMIC subtasks.

USAGE:

@Classes = GetClasses ( $TargetDeps );

$TargetDeps is an Openmake::FileList reference

RETURNS:

List of .class files

=head2 GetLocalClassPath ( $HOME_ENV )

In situations where you are given a 'home' environment variable for a
tool such as 'JAVA_HOME', 'ANT_HOME', or 'TOMCAT_HOME', you may want to
get the local classpath needed to run that application.

USAGE:

$HOME_ENV = $ENV{ANT_HOME};

$AntClasspath = Openmake::SearchPath->new(GetLocalClassPath($HOME_ENV));

RETURNS:

Array of path-delimited string of .jar and .zip files found in
$HOME_ENV/lib.

=head2 GetSubTaskDeps ( $TargetDeps,$TargetRelDeps,$wanted_dir,$sub_task_ext )

Resolves all "Results From" Sub Task dependencies found in the Target
Definition File for a given sub task extension. Once the derived dependency
is located in the TargetDeps or TargetRelDeps array, it is scanned for
any included file references.  All file references are put into an array
of Sub Task Dependencies along with the relative path to their root location.

Consider the passed in Sub Task file "int_classes/hello.javac". Contained
in "int_classes/hello.javac" are references to all of the classes required
to build the hello.jar target.  For example:

 com/my/package/*.class

GetSubTaskDeps will return all of the class references found in
hello.javac as well as the relative path to the root of those locations.
In this case, the relative path would resolve to:

 int_classes

and the classes would be:

 com/my/package/*.class

USAGE:

($rel_dir, @subtask_deps) = &GetSubTaskDeps($TargetDeps,$TargetRelDeps,$wanted_dir,$sub_task_ext);

$TargetDeps and $TargetRelDeps are Openmake::FileList references

$wanted_dir is a passed in directory value that might contain the derived dependencies,
such as Ant's basedir= value. An empty value assumes ".".

$sub_task_ext is the extension to search for, such as .javac, .rmic, .jup

RETURNS:

The relative directory where all of the derived dependencies are found and the complete list
of the resolved dependencies in an array.

=head1 ANT BUILD XML FUNCTIONS

=head2 GetAntIncludeXML ( @items )

Generates the include tags for ant based on a list of files

USAGE:

@includes = GetAntIncludeXML( @items );

@items is a list of filenames to be placed in the include tags

"." and the specified intermediate directory ($main::IntDir) are
stripped from the filenames

RETURNS:

A list of include tags @includes

=head2 WriteAntXML($xml, $build_XML_File)

Writes the "build.xml" file for ant.

$xml is a string of xml to write, without the "<" and ">" delimiters
$build_XML_File is an optional name of the Ant build.xml file. Defaults
to 'build.xml'

USAGE:

WriteAntXML($xml, $Build_XML_File);

=head2 ProcessAntFlags ( $CompilerArgs, $AntTask )

Used with Ant Tasks Javac and Rmic to set Ant properties 'build.compiler',
'build.rmic' and 'java.home'.  The Openmake flag compiler="javac" type flag
is removed from the $CompilerArgs string and -Dbuild.compiler=javac type
defines are appended.

USAGE:

($newCompilerArgs, $taskArgs) = ProcessAntFlags($CompilerArgs, $AntTask);

  $ENV{JIKES_HOME} = 'c:\jikes';
  $CompilerArgs = 'compiler=jikes -deprecation -g';
  ($newCompilerArgs, $TaskArgs) = ProcessAntFlags( $CompilerArgs, 'javac' );
  print "$newCompilerArgs\n";

The value of $newCompilerArgs will be
  ' -deprecation -g -Dbuild.compiler=jikes -Djava.home='c:\jikes'.

In addition, the path environment variable will be modified to

  $ENV{PATH} .= "$ENV{JAVA_HOME}\bin$PathDL" . $ENV{PATH};

RETURNS:

($newCompilerArgs, $taskArgs)

$newCompilerArgs is the arguments string for the compiler.

$taskArgs is the parsed arguments string for the task.

=head2 ParseModuleDirectories

Used primarily with WebSphere and J2EE tasks to identify module
(EJB jar, Web Application war, etc.) directories that are located
in a directory on the Search Path and as part of the dependencies'
name.

These module directories are not included on the Search Path due
to repetition of deployment file names and locations such as
META-INF/MANIFEST.MF.

Can also be used for 'destdir=' parsing by passing optional second
argument 'destdir='

USAGE:

 $ModuleDirectoryList = ParseModuleDirectories($Defines);

where $Defines is the string of defines for the build task.

RETURNS:

Openmake::SearchPath object containing the list of module directories

=head2 StripModuleDirectories

Strips the module directories references from a list of files.  This
function assumes that the files are specified using relative paths and
that the module directories will be found at the beginning of the
relative path.

This function is used in conjunction with ParseModuleDirectories to
properly specify the staging location for files that are copied from
the Search Path.

USAGE:

 $RelDeps = StripModuleDirectories($ModuleDirs, $RelDeps);

where $ModuleDirs is an Openmake::SearchPath object containing the
module directories and $RelDeps is an Openmake::FileList object
containing files specified using relative paths.

RETURNS:

Openmake::FileList object with module directory references stripped
from the filenames.

=head2 AddDestdirDirectories

Adds the destdir directories references to a list of files.  This
function assumes that the files are specified using relative paths and
that the destdir directories will be added at the beginning of the
relative path.

This function is used in conjunction with ParseDestdirDirectories to
properly specify the staging location for files that are copied from
the Search Path.

USAGE:

 $RelDeps = AddDestdirDirectories($DestDirs, $RelDeps);

where $DestDirs is an Openmake::SearchPath object containing the
destination directories and files and $RelDeps is an
Openmake::FileList object containing files specified using
relative paths.

RETURNS:

Openmake::FileList object with destination directories added to
the filenames.

=head2 AntSplitDirs( $directory_string, $intermediate_directory, $append_directory, @file_list);

Given a string with a comma-separated list of prefix directories,
organize the @file_list array by that list. This subroutine is
used to prepare a list of files for inclusion in an Ant build in
different zipfilesets. Can take a $directory_string with no commas
(only one dir). The $intermediate_directory, if defined, is prepended
to each of the directories in the list, and becomes part of the key
in the hash (only if different from the $directory_striing). The
$append_directory, if defined, is appended to each of the directories in the list,
and becomes part of the key in the hash.

USAGE:

 %hash = AntSplitDirs( $directory_string, $intermediate_directory, $append_directory, @file_list);

 where;

   $directory_string resembles '"<dir 1>,<dir 2>"' (with optional
   encasing quote '"' characters)

   and @file_list is a list of files that might start with <dir 1>,
   <dir 2>, etc.

RETURNS:

 A hash, indexed by directory, of files that lead with that
 directory string. Directories that do not match to any directories
 in the list are stored under the "." (local dir) entry.

 $hash{<dir 1>} = \@file_list_dir1

 etc.

=head1 BILL OF MATERIAL CREATOR FUNCTIONS

=head2 GenerateBillofMat( $BillofMat, $BillofMatRpt, $TargetFile )

Generates the Bill of Materials for the specified target file.

USAGE:

GenerateBillofMat( $BillofMat, $BillofMatRpt, $TargetFile );

=head2 FormatFootPrint( $TargetFile, @OmFPtext )

Formats the footprint report information from the
Openmake om.exe format to a C subroutine text format
that can be embedded in the executable.

USAGE:

$text = FormatFootPrint( $TargetFile, @OmFPtext )

=head1 FOOT PRINT CREATOR FUNCTIONS

=head2 GenerateFootPrint( $FootPrint,$TargetFile,$FPSource,$FPObject,$CompilerFound,$FPCompilerArguments )

Generates the footprinting source file for the specified target file.
This source file will be compiled and linked into the target.

USAGE:

GenerateFootPrint( $FootPrint,$TargetFile, $FPSource,$FPObject, $CompilerFound,$FPCompilerArguments );

=head2 FormatFootPrint( $TargetFile, @OmFPtext )

Formats the bill of materials report information from the
Openmake om.exe format to human-readable format

USAGE:

$text = FormatBillofMat( $TargetFile, @OmFPtext )

=head1 CLEANUP FUNCTIONS

=head2 ExitScript( $RC, @doomedFiles )

This is the standard exit script for Openmake compiler scripts.
Think of this as a destructor.  Currently this just provides a
convenience for deleting unwanted files on script exit.  You must
pass the return code and the list of files to delete.

USAGE:

ExitScript( $RC, @doomedFiles );

=cut

#############################################
sub FirstFoundInPath
{

 # This if finally done correctly on Windows
 # also accepts a user-supplied path for seaching
 # through the classpath
 my $file     = shift;
 my $userpath = shift;
 my $path;

 if ( $userpath ne '' )
 {
  $path = $userpath;
 }
 else
 {

  # use default system path
  $path = Openmake::SearchPath->new( $ENV{PATH} );
 }

 my @pathexts = split ';', $ENV{PATHEXT};    # win only
 push @pathexts, '.bat', '.exe', '.com';     # fix for win9x - case 1981

 foreach my $dir ( $path->getList )
 {

  # Handle windows case
  if ( $^O =~ /MSWin|os2|dos/i )
  {
   foreach my $pathext ( @pathexts )
   {
    $fullfile = $dir . $DL . $file . $pathext;
    return Win32::GetShortPathName( $fullfile ) if -f $fullfile;    # case 2054
   }
  }

  # Handle bare file (i.e. ant.jar )
  $fullfile = $dir . $DL . $file;

  if ( $^O =~ /MSWin|os2|dos/i )
  {
   return Win32::GetShortPathName( $fullfile ) if -f $fullfile;
  }
  else
  {
   return $fullfile if -f $fullfile;
  }
 } #-- End: foreach my $dir ( $path->getList...

 # nothing found!
 return undef;
} #-- End: sub FirstFoundInPath

sub GetAntCompiler
{
 my ( $DebugFlags, $ReleaseFlags ) = @_;
 my $OmPassedFlags = "";
 my $Var           = "";
 my $Val           = "";
 my @Flags         = ();
 my $Flag          = "";
 my $ParsedFlags   = "";

 my $Compiler = GetAnt();

 #-- parse Debug and Release flags
 my %optionhash;
 if ( $main::CFG eq "DEBUG" )
 {

  #-- invert the keys of the hash reference
  %optionhash = &InvertOptionHashRef( $DebugFlags );
 }
 else
 {
  %optionhash = &InvertOptionHashRef( $ReleaseFlags );
 }

 my @optionkeys = keys %optionhash;
 if ( scalar( @optionkeys ) == 1 )
 {
  $OmPassedFlags = $optionkeys[0];
 }
 else
 {
  $RC = 1;
  my $ErrorMsg = "Attempted to call GetAntCompiler with more than one set of options.\n";
  @CompilerOut = ( $ErrorMsg );

  #-- add the options:
  push @CompilerOut, "Following option sets called:\n";
  my $i = 1;
  foreach my $k ( @optionkeys )
  {
   $k =~ s/^\s+//;
   push @CompilerOut, "  $i: $k\n";
   $i++;
  }

  omlogger( "Final", "GetAntCompiler", "ERROR:", $ErrorMsg, $CompilerFound, "", "", $RC, @CompilerOut );
  ExitScript( $RC, () );
 } #-- End: else[ if ( scalar( @optionkeys...
 $OmPassedFlags =~ s/^\s+//;
 $OmPassedFlags =~ s/\s+$//;

 $OmPassedFlags = EvalEnvironment( $OmPassedFlags );

 @Flags = split( / /, $OmPassedFlags );
 foreach $Flag ( @Flags )
 {
  $Flag =~ s/\"//g;
  ( $Var, $Val ) = split( /=/, $Flag );

  $ParsedFlags .= "-target $Val " if ( $Var =~ /target/i );
  $ParsedFlags .= "-g "           if ( $Var =~ /debug/i && $Val =~ /on/i );
  $ParsedFlags .= "-deprecation " if ( $Var =~ /deprecation/i && $Val =~ /on/i );
  $ParsedFlags .= "-O "           if ( $Var =~ /optimize/i && $Val =~ /on/i );
  $ParsedFlags .= "-verbose "     if ( $Var =~ /verbose/i && $Val =~ /on/i );

  #-- JAG - 04.19.04 - case 4610: added following 1.4 options
  $ParsedFlags .= "-nowarn "        if ( $Var =~ /nowarn/i );
  $ParsedFlags .= "-encoding $Val " if ( $Var =~ /encoding/i );
  $ParsedFlags .= "-source $Val "   if ( $Var =~ /source/i );

 } #-- End: foreach $Flag ( @Flags )
 return ( $Compiler, $ParsedFlags );
} #-- End: sub GetAntCompiler

sub Check4Errors
{
 my $LookFor = shift @_;
 my $rc      = shift @_;
 my @Output  = @_;

 return 1 if ( $rc != 0 );
 return 1 if ( grep( /\Q$LookFor\E/, @Output ) );
 return 0;
}

sub TrimIntDir
{
 my @IncludeLines = @_;
 my $myIntDir     = $main::IntDir->get;
 $myIntDir =~ s|\\|/|g;
 $myIntDir =~ s|\.|\\\.|g;

 my @noIntDirIncludesLines = @IncludeLines;
 foreach ( @noIntDirIncludesLines )
 {
  s|\\|/|g;
  tr|/|/|s;

  s|\"$myIntDir/|\"|;
  s|\"/|\"|;
 }

 return join( "", @noIntDirIncludesLines );
} #-- End: sub TrimIntDir

#############################################
sub GetAnt
{

 #-- Case 1821 - Use runant.pl instead of ant.bat in order to have
 #               proper return code passed back.

 #-- Case 2134 - Need to use short path name for JAVA_HOME to avoid
 #               space breaks

 #-- Case 4422 - add quotes around all calls to CLASSPATH and perl.
 #
 if ( $^O =~ /MSWin/i )
 {
  $ENV{JAVA_HOME} = Win32::GetShortPathName( $ENV{JAVA_HOME} );
  if ( !-f "$ENV{JAVA_HOME}\\bin\\javac.exe" )
  {
   $javahome = $ENV{JAVA_HOME};
   $javahome =~ s/jre$//i;
   if ( -f "$javahome\\bin\\javac.exe" )
   {
    $ENV{JAVA_HOME} = $javahome;
   }
  }
 } #-- End: if ( $^O =~ /MSWin/i )
 else
 {
  if ( !-f "$ENV{JAVA_HOME}/bin/javac" )
  {
   $javahome = $ENV{JAVA_HOME};
   $javahome =~ s/jre$//i;
   if ( -f "$javahome/bin/javac" )
   {
    $ENV{JAVA_HOME} = $javahome;
   }
  }
 } #-- End: else[ if ( $^O =~ /MSWin/i )

 # If user has specified $ANT_HOME, use that
 if ( $ENV{ANT_HOME} ne '' )
 {
  if ( $^O =~ /MSWin/i )
  {
   $AntHome = Win32::GetShortPathName( $ENV{ANT_HOME} );
  }
  else
  {
   $AntHome = $ENV{ANT_HOME};
  }

  $Ant = $AntHome . $DL . 'bin' . $DL . 'runant.pl';

  if ( -f $Ant )
  {
   $Ant = "perl \"" . $Ant . "\"";
   return $Ant;
  }
  elsif ( -f "$AntHome$DL" . "lib$DL" . 'ant.jar' )
  {

   # We found ant.jar instead of the standard script
   $ENV{"CLASSPATH"} = "";
   my $AntClassPath = GetLocalClassPath( $AntHome );
   if ($^O =~ /darwin|osx/i)
   {
   $AntClassPath .= $ENV{JAVA_HOME} . $DL . '../Classes' . $DL . 'classes.jar' if $ENV{JAVA_HOME} ne '';
   }
   else
   {
   $AntClassPath .= $ENV{JAVA_HOME} . $DL . 'lib' . $DL . 'tools.jar' if $ENV{JAVA_HOME} ne '';
   }
   return "java -classpath \"$AntClassPath\" -Dant.home=\"$AntHome\" org.apache.tools.ant.Main";
  } #-- End: elsif ( -f "$AntHome$DL" ...
  elsif ( -f "$AntHome$DL" . 'ant.jar' )
  {

   # We found ant.jar instead of the standard script in the wrong, but probably
   #  the intended place
   $ENV{"CLASSPATH"} = "";
   my $AntClassPath = GetLocalClassPath( $AntHome );

   #$AntClassPath = $ENV{JAVA_HOME} . $DL . 'lib' . $DL . 'tools.jar' if $ENV{JAVA_HOME} ne '';

   return "java -classpath \"$AntClassPath\" -Dant.home=\"$AntHome\" org.apache.tools.ant.Main";
  } #-- End: elsif ( -f "$AntHome$DL" ...
 } #-- End: if ( $ENV{ANT_HOME} ne...

 #-- $ANT_HOME is not defined, look in the path
 if ( $Ant = FirstFoundInPath( 'runant.pl' ) )
 {

  # Use the ant distribution's script which is ** really good ** at
  # setting the local classpath and running it
  # and don't forget to quote it, MM
  my $AntHome = $Ant;
  $AntHome =~ s/[\\\/]+bin[\\\/]+runant.pl//;

  if ( $^O =~ /MSWin/i )
  {
   $ENV{'ANT_HOME'} = Win32::GetShortPathName( $AntHome );
   $AntHome = Win32::GetShortPathName( $AntHome );
  }
  else
  {
   $ENV{'ANT_HOME'} = $AntHome;
  }

  $ENV{"CLASSPATH"} = "";
  $Ant = "perl \"" . $Ant . "\"";

  return $Ant;
 } #-- End: if ( $Ant = FirstFoundInPath...

 #-- Look for ant.jar in ClassPath
 if ( $Ant = FirstFoundInPath( 'ant.jar', Openmake::SearchPath->new( "$ENV{CLASSPATH}" ) ) )
 {
  my $AntHome = $Ant;
  $AntHome =~ s/ant.jar$//;
  $AntHome =~ s/lib$eDL$//;

  #-- If you are setting the classpath and trying to run ant that way,
  # then that is the classpath ant will run under also

  return "java -classpath \"$ENV{CLASSPATH}\" -Dant.home=\"$AntHome\" -Djava.home=\"$ENV{JAVA_HOME}\" org.apache.tools.ant.Main";
 } #-- End: if ( $Ant = FirstFoundInPath...

 #-- Last resort, look for ant.jar in path
 #   JAG - 01.06.04 - fix case 4050
 if ( $Ant = FirstFoundInPath( 'ant.jar' ) )
 {
  my $AntHome = $Ant;
  $AntHome =~ s/ant.jar$//;
  $AntHome =~ s/lib$eDL$//;

  return "java -classpath \"$ENV{CLASSPATH}\" -Dant.home=\"$AntHome\" -Djava.home=\"$ENV{JAVA_HOME}\" org.apache.tools.ant.Main";
 }

 $RC                = 1;
 $Compiler          = "runant.pl";
 @CompilerOut       = ( "ERROR: Openmake.pm: GetAnt: Ant not found!  You must have runant.pl in your system path or set ANT_HOME." );
 $CompilerArguments = $OriginalPassedFlags;
 $StepDescription   = "runant.pl not found";
 $StepError         = "ERROR: Openmake.pm: GetAnt: Ant not found!  You must have runant.pl in your system path or set ANT_HOME.";
 omlogger( "Final", $StepDescription, "ERROR:", $StepError, $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
 exitScript( $RC, @main::DeleteFileList );
} #-- End: sub GetAnt

#############################################

sub unique
{
 my @unoq;
 # SBT - Update for performance
 my %saw;

 #-- JAG - 04.09.08 - case IUD-135. 
 #   From http://theoryx5.uwinnipeg.ca/CPAN/perl/pod/perlfaq4/How_can_I_remove_duplicate_elements_from.html
 @unoq = grep(!$saw{$_}++, @_);

 return @unoq;
} #-- End: sub unique

##############################################

sub Exclude
{
 my $patt   = shift;
 my @inlist = @_;
 my @outlist;

 # convert shell wild cards to perl regexp
 $patt =~ s/\./\\\./g;

 # take special case of full glob
 if ( $patt =~ s/^\*$// )
 {
  $patt = '.*';
 }
 elsif ( $patt =~ s/^\*\\\.\*$// )
 {
  $patt = '[^\.]*\..*';
 }
 else
 {    # normal
  $patt = '^' . $patt unless ( $patt =~ s/^\*// );
  $patt .= '$' unless ( $patt =~ s/\*$// );

  $patt =~ s/\?/\./g;
  $patt =~ s/\*/\.\*\?/g;
 }

 my $evalstr = "\$file =~ m|$patt|";
 $evalstr .= 'i' if $^O =~ /win|os2/i;

 foreach my $file ( @inlist )
 {
  $file =~ s|^\./?||;

  #-- JAG - 07.08.04 - Case 4805 - doing opposite of what was supposed to happen
  #push(@outlist,$file) if ( eval( $evalstr ) );
  push( @outlist, $file ) unless ( eval( $evalstr ) );

 }

 return @outlist
} #-- End: sub Exclude

#############################################

sub GetCompiler
{
 my ( $DebugFlags, $ReleaseFlags, $CompilerFound, @AvailableCompilers ) = @_;
 my ( $Compiler, $OmPassedFlags, $OriginalPassedFlags, $OrigCompiler );

 $OrigCompiler = $CompilerFound;

 $CompilerFound =~ s/\.exe$// if $^O =~ /win32/i;    #-- case 5253 SAB

 my $local_target = $main::Target->get();
 $local_target =~ s|\\|/|g;

 #-- parse Debug and Release flags
 my %optionhash;
 if ( $main::CFG =~ /^DEBUG$/i)
 {

  #-- invert the keys of the hash reference
  %optionhash = &InvertOptionHashRef( $DebugFlags );
 }
 else
 {
  %optionhash = &InvertOptionHashRef( $ReleaseFlags );
 }

 my @optionkeys = keys %optionhash;
 if ( scalar( @optionkeys ) > 1 )
 {
  @optionkeys = grep /\w/, @optionkeys;    #grep only for flags with values
 }
 if ( scalar( @optionkeys ) == 1 )
 {
  $OmPassedFlags = $optionkeys[0];
 }
 else
 {

  #-- JAG - 02.17.04 - case 4268 and 4309/4310.
  #   If we have more than one possible set of options, we have to look
  #   at the dependency parents.

  my %potential_options_hash = ();
  foreach my $options ( @optionkeys )
  {
   my @files = @{ $optionhash{$options} };
   foreach my $file ( @files )
   {
    my $depparent = $main::DependencyParent{$file};
    $depparent =~ s|\\|/|g;
    if ( $depparent =~ /;$local_target;/ )
    {
     $potential_options_hash{$options} = 1;
    }
   }
  } #-- End: foreach my $options ( @optionkeys...

  my @potential_options = keys %potential_options_hash;
  if ( scalar( @potential_options ) > 1 )
  {
   @potential_options = grep /\w/, @potential_options;    #grep only for flags with values
  }
  if ( scalar( @potential_options ) <= 1 )
  {
   $OmPassedFlags = $potential_options[0];
  }
  else
  {
   $RC = 1;
   my $ErrorMsg = "Attempted to call GetCompiler with more than one set of options.\n";
   @CompilerOut = ( $ErrorMsg );

   #-- add the options:
   push @CompilerOut, "Following option sets called:\n";
   my $i = 1;
   foreach my $k ( @potential_options )
   {
    $k =~ s/^\s+//;

    #-- case 4310, eval Envs
    $k = EvalEnvironment( $k );
    push @CompilerOut, "  $i: $k\n";
    $i++;
   }

   omlogger( "Final", "GetCompiler", "ERROR:", $ErrorMsg, $CompilerFound, "", "", $RC, @CompilerOut );
   ExitScript( $RC, () );
  } #-- End: else[ if ( scalar( @potential_options...
 } #-- End: else[ if ( scalar( @optionkeys...

 $OmPassedFlags =~ s/^\s+//;
 $OmPassedFlags =~ s/\s+$//;

 # Since the flags can contain the compiler and this will be need to be
 # parsed out store the original version of the flags, so that in the case
 # of an error the user will know what the flags (including compilers) om
 # passed to the script.

 $OriginalPassedFlags = $OmPassedFlags;

 #-- Evaluate any environment variables such as BLD_OPTIONS
 $OmPassedFlags = EvalEnvironment( $OmPassedFlags );

 # Loop through the list of all available compilers to see whether the
 # flags contain them and if so, parse them out. This step will be
 # skipped if you set @AvailableCompilers = () above.

 if ( $OmPassedFlags ne "" )
 {
  foreach $Compiler ( @AvailableCompilers )
  {
   $EscapedCompiler = $Compiler;
   $EscapedCompiler =~ s/(\W)/\\$1/g;

   if ( $OmPassedFlags =~ /^$EscapedCompiler\s/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/^$EscapedCompiler\s+//;
    $CompilerFound = $Compiler;
    last;
   }
   elsif ( $OmPassedFlags =~ /\s$EscapedCompiler\s/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/\s+$EscapedCompiler\s+/ /;    #-- 5264 SAB replace with a space
    $CompilerFound = $Compiler;
    last;
   }
   elsif ( $OmPassedFlags =~ /\s$EscapedCompiler$/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/\s+$EscapedCompiler$//;
    $CompilerFound = $Compiler;
    last;
   }
   elsif ( $OmPassedFlags =~ /^$EscapedCompiler$/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/^$EscapedCompiler$//;
    $CompilerFound = $Compiler;
    last;
   }

   $OmPassedFlags = EvalEnvironment( $OmPassedFlags );
   print "New Flags: $OmPassedFlags\n" if $debug;
  } #-- End: foreach $Compiler ( @AvailableCompilers...

 } #-- End: if ( $OmPassedFlags ne...

 # We should have now a default compiler, $CompilerFound,
 # if it is blank, these means we could not find a compiler
 # although we expected one. Error out.

 if ( $CompilerFound eq "" )
 {
  $RC                      = 1;
  $main::Quiet             = "NO";
  $main::Compiler          = "<not found>";
  @main::CompilerOut       = ( qw("Compiler <$OrigCompiler> was not found") );
  $main::CompilerArguments = $OriginalPassedFlags;
  $main::StepDescription   = "Extracting compiler name from flags passed";
  $main::StepError         = "$StepDescription failed!";
  omlogger( "Final", $StepDescription, "ERROR:", "ERROR: $StepDescription failed!", $Compiler, $CompilerArguments, "", $RC, @main::CompilerOut );
  exitScript( $RC, @main::DeleteFileList );
 } #-- End: if ( $CompilerFound eq...

 #-- JAG - 05.20.03 -- Case 3232 -- look for compiler in DBInfo
 #   expand $DBInfo to substitute any environment variables.
 #   Note that $FullDBInfo may still have un-resolvable environment variables,
 #   see code below. Also change "\\" to "/"
 my $FullDBInfo = &ExpandEnv( $main::DBInfo );
 $FullDBInfo =~ s/\\/\//g;

 #-- remove MODULEDIR="<blah>" from $FullDBInfo
 if ( $FullDBInfo =~ /MODULEDIR="/ )    #"
 {
  $FullDBInfo =~ s|MODULEDIR="?.+?"||;
 }
 else
 {
  $FullDBInfo =~ s|MODULEDIR=.+?\s+||;
 }

 # We determined the compiler and need to search for it in the path.

 $ScriptCompiler = $CompilerFound;
 $OrigCompiler   = $CompilerFound;

 my $Key = $CompilerFound;
 $Key =~ tr/a-z/A-Z/;
 $Key =~ s/\..*//;

 if ( $main::Tools{$Key} ne "" )
 {
  $ScriptCompiler = $main::Tools{$Key};
 }

 #-- look for compiler in $DBInfo
 elsif ( $FullDBInfo =~ /\Q$ScriptCompiler\E/ )
 {

  #-- user has passed in a compiler via a flag
  #   Grab the first existing available existing
  #   compiler in the list. Otherwise we'll default to PATH
  my $tempcompiler = "";
  my @tempcompilerlist = split /\|/, $FullDBInfo;
  push @tempcompilerlist, $FullDBInfo unless ( @tempcompilerlist );

  foreach $tclist ( @tempcompilerlist )
  {
   if ( $tclist =~ /\Q$ScriptCompiler\E/ && -e $tclist )
   {
    $tempcompiler = $tclist;
    last;
   }
  }

  #-- check to see if we found a compiler
  if ( $tempcompiler )
  {
   $ScriptCompiler = $tempcompiler;
  }
  else
  {
   $main::Compiler          = $ScriptCompiler;
   $main::StepDescription   = "Searching for $OrigCompiler in Precompile Parameters";
   $main::StepError         = "Could not find compiler $OrigCompiler in Precompile Parameters $FullDBInfo";
   @main::CompilerOut       = ( $main::StepError );
   $main::CompilerArguments = $OriginalPassedFlags;

   omlogger( "Intermediate", $StepDescription, "WARNING:", "WARNING: Could not find compiler $Compiler in Precompile Parameters $FullDBInfo. Using PATH", $Compiler, $CompilerArguments, "", $RC, @main::CompilerOut );
   $ScriptCompiler = FirstFoundInPath( $ScriptCompiler );
  } #-- End: else[ if ( $tempcompiler )
 } #-- End: elsif ( $FullDBInfo =~ /\Q$ScriptCompiler\E/...
 else
 {
  $ScriptCompiler = FirstFoundInPath( $ScriptCompiler );
 }

 # If the compiler could not be found, error out.

 if ( $ScriptCompiler eq "" )
 {
  $RC                      = 1;
  $main::Quiet             = "NO";
  $main::Compiler          = $ScriptCompiler;
  $main::StepDescription   = "Searching for $OrigCompiler in PATH\n";
  $main::StepError         = "Could not find compiler $OrigCompiler in PATH!\n";
  @main::CompilerOut       = ( $main::StepError );
  $main::CompilerArguments = $OriginalPassedFlags;

  omlogger( "Final", $StepDescription, "ERROR:", "ERROR: Could not find compiler $Compiler in PATH!", $Compiler, $CompilerArguments, "", $RC, @main::CompilerOut );
  exitScript( $RC, @main::DeleteFileList );
 } #-- End: if ( $ScriptCompiler eq...

 # If the compiler could not be found, error out.

 unless ( -e $ScriptCompiler )
 {
  $RC                      = 1;
  $main::Quiet             = "NO";
  $main::Compiler          = $ScriptCompiler;
  $main::StepDescription   = "Searching for $ScriptCompiler on File System";
  $main::StepError         = "Could not find compiler $OrigCompiler on File System!";
  @main::CompilerOut       = ( $main::StepError );
  $main::CompilerArguments = $OriginalPassedFlags;

  omlogger( "Final", $StepDescription, "ERROR:", "ERROR: Could not find compiler $Compiler on File System!", $Compiler, $CompilerArguments, "", $RC, @main::CompilerOut );
  exitScript( $RC, @main::DeleteFileList );
 } #-- End: unless ( -e $ScriptCompiler...

 if ( $^O =~ /MSWin/i )
 {
  $ScriptCompiler = Win32::GetShortPathName( $ScriptCompiler );
 }
 if( $ScriptCompiler =~ m{\s+})
 {
  $ScriptCompiler = '"' . $ScriptCompiler . '"'
 }    # fix for case 2054

 $OmPassedFlags =~ s/PROJECTDIR=.*;}/}/g;
 $OmPassedFlags =~ s/PROJECTDIR=.*; / /g;

 return ( $ScriptCompiler, $OmPassedFlags );
} #-- End: sub GetCompiler

*get_compiler = *GetCompiler;

########################################################

# LN -- 08.25.2003 -- CASE 3534
# EvalEnvironment added to GetCompiler, GetCompiler, and
# GetAnt
#
# Evaluates a string and fills in specified environment
# variables.  These variables can be specified in one of
# two ways:
#    1. Openmake standard $(ENV_VAR)
#    2. Perl standard     $ENV{ENV_VAR}
#
# This evaluation will fill in empty strings if a pattern
# match is found but the environment value is not specified
#
# Example
# Environment Variables:
# EV1 = VAL1
# EV2 = VAL2
#
# String:
# "A B $(EV1) $ENV{EV2}"
#
# Result:
# "A B VAL1 VAL2"

sub EvalEnvironment
{
 my $str = shift;

 # Evaluate flags for any environment variables

 # First pass is to locate and set $(ENV_VAR)
 while ( $str =~ /\$\((\S+?)\)/ ) #-- JAG - 04.18.07 - case FLS-3
 {
  print "Evaluating $1\n";
  $envVal = $1;
  $str =~ s/\$\(\S+?\)/$ENV{$envVal}/;  #-- JAG - 04.18.07 - case FLS-3
 }

 # Second pass is to locate and set $ENV{ENV_VAR}
 while ( $str =~ /\$ENV\{(\S+?)\}/ )  #-- JAG - 04.18.07 - case FLS-3
 {
  print "Evaluating $1\n";
  $envVal = $1;
  $str =~ s/\$ENV\{\S+?\}/$ENV{$envVal}/; #-- JAG - 04.18.07 - case FLS-3
 }

 return $str;
} #-- End: sub EvalEnvironment

########################################################

sub FindFlag
{
 my $flagString    = shift;
 my @possibleFlags = @_;
 foreach my $flag ( @possibleFlags )
 {
  my $escapedFlag = $flag;
  $escapedFlag =~ s/(\W)/\\$1/g;
  if ( $flagString =~ /\b$flag\b/ )
  {
   return $flag;
  }
 }
} #-- End: sub FindFlag

#############################################

sub GetCompilerFlags
{
 my ( $DebugFlags, $ReleaseFlags, $CompilerFound, @AvailableCompilers ) = @_;

 $CompilerFound =~ s/\.exe$//;

 my ( $Compiler, $OmPassedFlags, $OriginalPassedFlags );

 #my $debug = 1;
 #-- parse Debug and Release flags
 my %optionhash;
 if ( $main::CFG eq "DEBUG" )
 {

  #-- invert the keys of the hash reference
  %optionhash = &InvertOptionHashRef( $DebugFlags );
 }
 else
 {
  %optionhash = &InvertOptionHashRef( $ReleaseFlags );
 }

 my @optionkeys = keys %optionhash;
 if ( scalar( @optionkeys ) == 1 )
 {
  $OmPassedFlags = $optionkeys[0];
 }
 else
 {
  $RC = 1;
  my $ErrorMsg = "Attempted to call GetCompiler with more than one set of options.\n";
  @CompilerOut = ( $ErrorMsg );

  #-- add the options:
  push @CompilerOut, "Following option sets called:\n";
  my $i = 1;
  foreach my $k ( @optionkeys )
  {
   $k =~ s/^\s+//;
   push @CompilerOut, "  $i: $k\n";
   $i++;
  }

  omlogger( "Final", "GetCompiler", "ERROR:", $ErrorMsg, $CompilerFound, "", "", $RC, @CompilerOut );
  ExitScript( $RC, () );
 } #-- End: else[ if ( scalar( @optionkeys...
 $OmPassedFlags =~ s/^\s+//;
 $OmPassedFlags =~ s/\s+$//;

 # Since the flags can contain the compiler and this will be need to be
 # parsed out store the original version of the flags, so that in the case
 # of an error the user will know what the flags (including compilers) om
 # passed to the script.

 $OriginalPassedFlags = $OmPassedFlags;

 # Loop through the list of all available compilers to see whether the
 # flags contain them and if so, parse them out. This step will be
 # skipped if you set @AvailableCompilers = () above.

 if ( $OmPassedFlags ne "" )
 {
  foreach $Compiler ( @AvailableCompilers )
  {
   $EscapedCompiler = $Compiler;
   $EscapedCompiler =~ s/(\W)/\\$1/g;

   if ( $OmPassedFlags =~ /^$EscapedCompiler\s*/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/^$EscapedCompiler\s*//;
    $CompilerFound = $Compiler;
    last;
   }
   elsif ( $OmPassedFlags =~ /\s$EscapedCompiler\s/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/$EscapedCompiler\s//;
    $CompilerFound = $Compiler;
    last;
   }
   elsif ( $OmPassedFlags =~ /\s*$EscapedCompiler$/ )
   {
    print "parsed compiler: $Compiler\n" if $debug;
    $OmPassedFlags =~ s/\s*$EscapedCompiler$//;
    $CompilerFound = $Compiler;
    last;
   }

   $OmPassedFlags = EvalEnvironment( $OmPassedFlags );

   print "New Flags: $OmPassedFlags\n" if $debug;
  } #-- End: foreach $Compiler ( @AvailableCompilers...

 } #-- End: if ( $OmPassedFlags ne...

 # We should have now a default compiler, $CompilerFound,
 # if it is blank, these means we could not find a compiler
 # although we expected one. Error out.

 if ( $CompilerFound eq "" )
 {
  $RC                = 1;
  $Compiler          = "<not found>";
  @CompilerOut       = ();
  $CompilerArguments = $OriginalPassedFlags;
  $StepDescription   = "Extracting compiler name from flags passed";
  $StepError         = "$StepDescription failed!";
  omlogger( "Final", $StepDescription, "ERROR:", "ERROR: $StepDescription failed!", $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
  exitScript( $RC, @main::DeleteFileList );
 } #-- End: if ( $CompilerFound eq...

 # We determined the compiler and need to search for it in the path.

 $ScriptCompiler = $CompilerFound;

 return ( $ScriptCompiler, $OmPassedFlags );
} #-- End: sub GetCompilerFlags

########################################################

sub GetFlag
{
 my $flagString    = shift;
 my @possibleFlags = @_;
 foreach my $flag ( @possibleFlags )
 {
  my $escapedFlag = $flag;
  $escapedFlag =~ s/(\W)/\\$1/g;
  if ( $flagString =~ s/\b$flag\b// )
  {
   return $flagString, $flag;
  }
 }
} #-- End: sub GetFlag

########################################################

sub GetExcludes
{

 #-- Usage: ( $pureDefines, @excludePatterns) =
 #                     GetExcludePatterns( $Defines );

 my $defines = shift;

 my @excludePatterns;

 my @allbits = split( /\s+/, $defines );
 @bits = grep( /\bexclude\=/i, @allbits );
 my @otherBits = grep( !/\bexclude\=/i, @allbits );
 my $pureDefines = join( ' ', @otherBits );

 foreach ( @bits )
 {
  s/\bexclude\=//i;
  push( @excludePatterns, $_ );
 }
 return $pureDefines, @excludePatterns;

} #-- End: sub GetExcludes

##########################################

#############################################
sub mkfulldir
{
 my ( $Path ) = @_;
 my ( @Dirs, $Dir, $newdir );

 $Path =~ s/\"//g;     # Strip quotes "
 $Path =~ s/\\/\//g;
 $newdir = '';

 @Dirs = split( /\//, $Path );

 #-- JAG 07.15.04 - case 4826 and others. If $Path ends in [\/\\], don't pop
 $Dir = pop( @Dirs ) unless $Path =~ /[\/\\]$/;

 foreach $Dir ( @Dirs )
 {
  if ( $Dir !~ /:$/ )
  {
   $newdir .= $Dir;

   # Works with unix slashes for all os's
   mkdir $newdir, 0777;

   $newdir .= '/';
  }
  else
  {
   $newdir = $Dir . '/';
  }
 } #-- End: foreach $Dir ( @Dirs )
} #-- End: sub mkfulldir

########################################################

sub CopyLocal
{
 my $TargetDeps = shift;    # Openmake::FileList object
 my $RelDeps    = shift;    # Openmake::FileList object
 my $toDir      = shift;    # Destination directory
 my @exts       = @_;       # optional list of 'include' extensions
 my ( $file, $Tmp, $localfiles );
 my @localfiles = ();
 my ( @ResList, @LocalResList );

 if ( @exts )
 {

  #-- Grep for the desired files
  foreach my $ext ( @exts )
  {
   $ext =~ s/(\W)/\\$1/g;
   push( @ResList,      grep( /$ext$/, $TargetDeps->getList ) );
   push( @LocalResList, grep( /$ext$/, $RelDeps->getList ) );
  }
 } #-- End: if ( @exts )
 else
 {

  #-- Take all files
  push( @ResList,      $TargetDeps->getList );
  push( @LocalResList, $RelDeps->getList );
 }

 # Now apply default excludes
 foreach my $ext ( @DefaultExcludes )
 {
  $ext =~ s/(\W)/\\$1/g;
  @ResList      = grep( !/$ext$/, @ResList );
  @LocalResList = grep( !/$ext$/, @LocalResList );
 }

 #-- JAG - 01.09.08 - case FLS-304. This is N^2.
 #   If the lists are the same length, see if we can copy local based on
 #   the ordering of the lists
 if ( length @ResList == length @LocalResList )
 {
  my $i = 0 ;
  foreach my $res ( @ResList )
  {
   my $localres = $LocalResList[$i];
   if ( index( $res, $localres) > -1 )
   {
    $TargetRes = $localres;

    $TargetRes = $toDir . $DL . $TargetRes
      unless $toDir eq '.' or ( $TargetRes =~ /^\Q$toDir\E$eDL/ );

    if ( !( -e $TargetRes ) )
    {
     mkfulldir( $TargetRes );

     # unix slashes good for all OS's in copy
     #-- JAG - 10.24.05 - for perl 5.8, File::Copy throws a 'die' if the two
     #  files are the same. Wrap in eval
     if ( $res ne $TargetRes )
     {
      eval { copy $res, $TargetRes; };
      if ( $@ )
      {
       print "Couldn't copy resource \"$res\": $@\n";
      }
      else
      {
       push(@main::dellist,$TargetRes);
      }
     }
     #-- end JAG 10.24.05
    }
    push( @localfiles, $TargetRes );
   }
   $i++;
  }
  return @localfiles;
 }

 # Perform a sort by length and reverse it (Result: longer strings first)
 @LocalResList = reverse( sort lengthSort @LocalResList );

 # Now see if the file is local, if not, copy it there
 foreach $ResFile ( @ResList )
 {
  my $SlashResFile = $ResFile;
  $SlashResFile =~ s|[\\/]|#|g;

  if ( $SlashResFile !~ /^#/ )
  {
   $SlashResFile = "#" . $SlashResFile;
  }

  my $foundmatch = 0;
  foreach $Tmp ( @LocalResList )
  {
   my $MatchTargetRes = "#" . $Tmp;

   $MatchTargetRes =~ s|[\\/]|#|g;    # just in case

   #   $MatchTargetRes =~ s/\\/\\\\/g;  # just in case
   $MatchTargetRes =~ s/\./\\\./g;
   $MatchTargetRes =~ s/\$/\\\$/g;

   if ( $SlashResFile =~ /$MatchTargetRes$/ )
   {
    $TargetRes  = $Tmp;
    $foundmatch = 1;
    last;
   }
  } #-- End: foreach $Tmp ( @LocalResList...

  #-- JAG need the intdir, regardless
  # $TargetRes = $toDir . $DL . $TargetRes
  #  unless $toDir eq '.' or $TargetRes =~ /^$toDir$eDL/;
  $TargetRes = $toDir . $DL . $TargetRes
    unless $toDir eq '.' or ( $TargetRes =~ /^$toDir$eDL/ && $foundmatch == 0 );

  if ( !( -e "$TargetRes" ) )
  {
   mkfulldir( $TargetRes );

   # unix slashes good for all OS's in copy
   #-- JAG - 10.24.05 - for perl 5.8, File::Copy throws a 'die' if the two
   #  files are the same. Wrap in eval
   eval { copy "$ResFile", "$TargetRes"; };
   if ( $@ )
   {
    print "Couldn't copy resource \"$ResFile\": $@\n";
   }
   else
   {
    push(@main::dellist,$TargetRes);
   }
   #-- end JAG 10.24.05
  }
  push( @localfiles, $TargetRes );
 } #-- End: foreach $ResFile ( @ResList...
 return ( @localfiles );
} #-- End: sub CopyLocal

##########################################

sub CopyExcludeLocal
{
 my $TargetDeps  = shift;
 my $RelDeps     = shift;
 my $toDir       = shift;
 my @excludeExts = ( @_, @DefaultExcludes );

 my @localfiles = ();

 my @ResList      = $TargetDeps->getList;
 my @LocalResList = $RelDeps->getList;

 #-- Filter out unwanted files
 foreach my $ext ( @excludeExts )
 {
  $ext =~ s/(\W)/\\$1/g;
  @ResList      = grep( !/$ext$/, @ResList );
  @LocalResList = grep( !/$ext$/, @LocalResList );
 }

 #-- JAG - 01.09.08 - case FLS-304. This is N^2.
 #   If the lists are the same length, see if we can copy local based on
 #   the ordering of the lists
 if ( length @ResList == length @LocalResList )
 {
  my $i = 0 ;
  foreach my $res ( @ResList )
  {
   my $localres = $LocalResList[$i];
   if ( index( $res, $localres) > -1 )
   {
    $TargetRes = $localres;

    $TargetRes = $toDir . $DL . $TargetRes
      unless $toDir eq '.' or ( $TargetRes =~ /^\Q$toDir\E$eDL/ );

    if ( !( -e $TargetRes ) )
    {
     mkfulldir( $TargetRes );

     # unix slashes good for all OS's in copy
     #-- JAG - 10.24.05 - for perl 5.8, File::Copy throws a 'die' if the two
     #  files are the same. Wrap in eval
     if ( $res ne $TargetRes )
     {
      eval { copy $res, $TargetRes; };
      if ( $@ )
      {
       print "Couldn't copy resource \"$res\": $@\n";
      }
      else
      {
       push(@main::dellist,$TargetRes);
      }
     }
     #-- end JAG 10.24.05
    }
    push( @localfiles, $TargetRes );
   }
   $i++;
  }
  return @localfiles;
 }

 # Perform a sort by length and reverse it (Result: longer strings first)
 @LocalResList = reverse( sort lengthSort @LocalResList );

 #
 # Loop thru the resource files in the version
 # path and copy them local.
 #

 foreach $ResFile ( @ResList )
 {
  my $foundmatch = 0;
  foreach $Tmp ( @LocalResList )
  {
   my $MatchTargetRes = $Tmp;

   #  $MatchTargetRes =~ s/\\/\\\\/g;  # just in case
   #  $MatchTargetRes =~ s/\./\\\./g;
   #  $MatchTargetRes =~ s/\$/\\\$/g;

   if ( $ResFile =~ /\Q$MatchTargetRes\E$/ )
   {
    $TargetRes  = $Tmp;
    $foundmatch = 1;
    last;
   }
  } #-- End: foreach $Tmp ( @LocalResList...

  #-- JAG need the intdir, regardless
  # $TargetRes = $toDir . $DL . $TargetRes
  #  unless $toDir eq '.' or $TargetRes =~ /^$toDir$eDL/;
  $TargetRes = $toDir . $DL . $TargetRes
    unless $toDir eq '.' or ( $TargetRes =~ /^\Q$toDir\E$eDL/ && $foundmatch == 0 );

  if ( !( -e "$TargetRes" ) )
  {
   mkfulldir( $TargetRes );

   # unix slashes good for all OS's in copy
   #-- JAG - 10.24.05 - for perl 5.8, File::Copy throws a 'die' if the two
   #  files are the same. Wrap in eval
   if ( $ResFile ne $TargetRes )
   {
    eval { copy "$ResFile", "$TargetRes"; };
    if ( $@ )
    {
     print "Couldn't copy resource \"$ResFile\": $@\n";
    }
    else
    {
     push(@main::dellist,$TargetRes);
    }
   }
   #-- end JAG 10.24.05
  }
  push( @localfiles, $TargetRes );
 } #-- End: foreach $ResFile ( @ResList...
 return ( @localfiles );
} #-- End: sub CopyExcludeLocal

#####################################
# subroutine to sort by length
sub lengthSort { length( $a ) <=> length( $b ) }

#####################################
# subroutine to read a .packages file
# created by a JAVAC step
# The file contains lines of the form:
#  com/openmake/server/*

sub ReadPackagesFile
{
 my $TargetDeps  = shift;
 my $PackageFile = $TargetDeps->getExt( '.javac' );

 unless ( open( RSP, "<$PackageFile" ) )
 {
  $RC = 1;
  my $ErrorMsg = "ERROR: ReadPackagesFile: 01: Couldn't open .packages file: '$PackageFile'.\n";
  @CompilerOut = ( $ErrorMsg );
  omlogger( "Final", "ReadPackagesFile", "ERROR:", $ErrorMsg, $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
  ExitScript( $RC, () );
 }

 my @Packages = <RSP>;
 chomp @Packages;

 close RSP;
 return @Packages
} #-- End: sub ReadPackagesFile

###########################################
sub GetPackages
{
 my @javafiles = @_;
 my @packages;

 @javafiles = grep /\.java$/, @javafiles;

 foreach ( @javafiles )
 {
  my $file    = Openmake::File->new( $_ );
  my $package = $file->getPath;
  $package =~ s/^\.$eDL//g;

  if ( $package eq '' or $package eq '.' )
  {
   push( @packages, '.' )
  }
  else
  {
   push( @packages, $package )
  }
 } #-- End: foreach ( @javafiles )

 # foreach $package (@packages) {
 #  $package =~ s/\./$DL/g;
 # }
 @packages = grep !/^\s*$/, @packages;
 return unique @packages;
} #-- End: sub GetPackages

#####################################
# subroutine to read a .packages file
# created by a JAVAC step
# The file contains lines of the form:
#  com/openmake/server/*

sub GetPackageDeps
{
 my $TargetDeps = shift;

 #-- JAG - 08.02.04 - add addition arg to determine if we want to
 #                    add full path to found deps.
 my $add_full_path = shift;

 # Below is a list of task token files that contain
 #  a list of packages generated by the task
 my @PackageFiles = $TargetDeps->getExt( qw( .javac .wsdljava .copypkg .omidl .sqljava .javag) );
 my @AllPackages;

 # Loop through all the .packages files that are dependencies
 foreach my $PackageFile ( @PackageFiles )
 {
  unless ( open( PACKFILE, "<$PackageFile" ) )
  {
   $RC = 1;
   my $ErrorMsg = "ERROR: ReadPackagesFile: 01: Couldn't open .packages file: '$PackageFile'.\n";
   @CompilerOut = ( $ErrorMsg );
   omlogger( "Final", "ReadPackagesFile", "ERROR:", $ErrorMsg, $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
   ExitScript( $RC, () );
  }

  my $full_path = "";
  if ( $add_full_path )
  {
   $full_path = $PackageFile;

   #-- cv to /
   $full_path =~ s/\\/\//g;
   my @t = split /\//, $full_path;
   pop @t;
   $full_path = join $DL, @t;
   $full_path .= $DL;

  } #-- End: if ( $add_full_path )

  my @Packages = <PACKFILE>;
  foreach ( @Packages )
  {
   $_ = $full_path . $_;
   s/\n//g;
   s/[\\\/]/$DL/g;
  }
  push( @AllPackages, @Packages );
  close PACKFILE;
 } #-- End: foreach my $PackageFile ( @PackageFiles...

 @AllPackages = unique( @AllPackages );
 return @AllPackages;
} #-- End: sub GetPackageDeps

#####################################
# -- subroutine to find actual classes in the
#    build directory. Searches the file system

sub GetBuildDirPackages
{
 use File::Find;

 my $dest_dir       = shift;
 my @wanted_classes = @_;
 my @found_packages = ();
 @Openmake::GetBuildDirPackages::possible_classes = ();
 my %found_packages = ();

 #-- find classes under the destdir
 File::Find::find(
  {
   wanted =>
     sub
   {
    return unless -f;
    push @Openmake::GetBuildDirPackages::possible_classes, $File::Find::dir if ( /\.class$/ );
    return;
     }
  },
  $dest_dir );

 #-- strip off $dest_Dir
 #-- JAG - 02.20.04 - Case 4341 remove trailing / if necessary
 $dest_dir =~ s/\\/\//g;
 $dest_dir =~ s/\/$//;
 my $edest_dir = quotemeta( $dest_dir );
 foreach ( @Openmake::GetBuildDirPackages::possible_classes )
 {
  s/^$edest_dir//;
  s/^\///;
  $_ = "." if ( $_ eq "" );

  #-- add this to the hash that identifies that this exists;

  $found_packages{$_} = 1;
 } #-- End: foreach ( @Openmake::GetBuildDirPackages::possible_classes...

 #-- convert java file to a package list
 foreach ( @wanted_classes )
 {
  s/\\/\//g;

  #-- chop off the file name. Don't use a file object, it's too slow
  my @path_parts = split /\//;
  pop @path_parts;

  #-- start rejoining this together, see if it exists
  while ( @path_parts )
  {
   my $possible_path = join "/", @path_parts;

   #-- test if it exists in the hash of found packages
   if ( $found_packages{$possible_path} )
   {
    push @found_packages, $possible_path;
    last;
   }

   shift @path_parts;

  } #-- End: while ( @path_parts )

  #-- if there is no remaining path_part, we must be in the root dir
  if ( !@path_parts )
  {
   if ( $found_packages{"."} )
   {

    #-- add a null dir. The $destdir will be added in a later loop
    push @found_packages, "";
   }
   next;
  } #-- End: if ( !@path_parts )
 } #-- End: foreach ( @wanted_classes )

 @found_packages = unique @found_packages;

 #-- add back in $dest_dir, since this is where the file really lives
 foreach ( @found_packages )
 {
  $_ = "$dest_dir/" . $_;

  #-- remove leading ./ unless it's the only thing there
  if ( $_ eq "./" )
  {
   $_ = ".";
  }
  else
  {
   s/^\.\///;
  }
 } #-- End: foreach ( @found_packages )

 return wantarray ? @found_packages : \@found_packages;

} #-- End: sub GetBuildDirPackages( $, @)
#####################################
# subroutine to read a .classpath file
# created by a classpath step

sub GetClasspath
{
 my $TargetDeps     = shift;
 my @ClasspathFiles = $TargetDeps->getExtList( qw(.classpath .resclasspath) );
 my $Classpath;

 foreach my $ClasspathFile ( @ClasspathFiles )
 {
  unless ( open( RSP, "<$ClasspathFile" ) )
  {
   $RC = 1;
   my $ErrorMsg = "ERROR: ReadClasspathFile: 01: Couldn't open .packages file: '$ClasspathFile'.\n";
   @CompilerOut = ( $ErrorMsg );
   omlogger( "Final", "ReadPackagesFile", "ERROR:", $ErrorMsg, $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
   ExitScript( $RC, () );
  }
  my @lines = <RSP>;
  
  my $line = "";
  
  foreach $line (@lines)
  {
   $line =~ s/\n//g;
   $Classpath .= $PathDL . $line  if ($line !~ /</);
  }

  close RSP;
 } #-- End: foreach my $ClasspathFile (...

 return $Classpath
} #-- End: sub GetClasspath


###########################################
sub GetClasses
{
 my $TargetDeps = shift;
 my @excludes   = @_;
 if ( !@excludes )
 {

  # Below is a list of task token files that contain
  #  a list of packages generated by the task
  @excludes = qw( .javac .rmic );
 }

 my @PackageFiles = $TargetDeps->getExtList( @excludes );
 return undef unless @PackageFiles;

 my @AllPackages;

 # Loop through all the .packages files that are dependencies
 foreach $PackageFile ( @PackageFiles )
 {
  unless ( open( PACKFILE, "<$PackageFile" ) )
  {
   $RC = 1;
   my $ErrorMsg = "ERROR: ReadPackagesFile: 01: Couldn't open .packages file: '$PackageFile'.\n";
   @CompilerOut = ( $ErrorMsg );
   omlogger( "Final", "ReadPackagesFile", "ERROR:", $ErrorMsg, $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
   ExitScript( $RC, () );
  }
  @Packages = ();
  my @Packages = <PACKFILE>;
  close PACKFILE;
  chomp @Packages;
  
  my $line = $Packages[0];
  if (index($line, ';') >= 0)
  {
   @Packages = ();
   my @Fq_Packages = grep(/\.jar/,split(/;/, $line));
   foreach $Fq_Package ( @Fq_Packages )
   {
    my $f = $Fq_Package;
    $f =~ s/\\/\//g;

    push @Packages, $f; 
   }
  }
  push( @AllPackages, @Packages );

 } #-- End: foreach $PackageFile ( @PackageFiles...

 @AllPackages = unique( @AllPackages );
 return @AllPackages
} #-- End: sub GetClasses

########################################################
sub GetLocalClassPath
{

 # will work for $JAVA_HOME, $ANT_HOME, etc.
 my $Home = shift;

 my $pattern = $HOME . $DL . 'lib' . $DL . '*.jar';
 my @jars    = glob( $pattern );
 $pattern = $HOME . $DL . 'lib' . $DL . '*.zip';
 my @zips = glob( $pattern );

 return wantarray ? ( @jars, @zips ) : join "$PathDL", @jars, @zips;
} #-- End: sub GetLocalClassPath

#############################
#-- generates 'include' tags for ant
#-- based on a list of files
sub GetAntIncludeXML
{
 @items = @_;
 my @includes;
 my $idir = $main::IntDir->get;

 foreach ( @items )
 {
  s/^\.$eDL//;
  s/^$idir$eDL//;
  push( @includes, "include name = \"$_\" /\n" );
 }

 return @includes
} #-- End: sub GetAntIncludeXML

#######################################
sub WriteAntXML
{
 my $xml       = shift;
 my $build_xml = shift || 'build.xml';

 #-- Open the xml file for ant
 unless ( open( XML, ">$build_xml" ) )
 {
  $RC = 1;
  my $ErrorMsg = "Couldn't open $build_xml for writing.\n";
  @CompilerOut = ( $ErrorMsg );
  omlogger( "Final", "ReadPackagesFile", "ERROR:", $ErrorMsg, $Compiler, $CompilerArguments, "", $RC, @CompilerOut );
  ExitScript( $RC, () );
 }

 my $indent = 0;
 my @lines = split( /\n/, $xml );
 foreach ( @lines )
 {
  print XML "\n", next if /^\s*$/;

  #-- JAG 10.01.03 - case 3674 - escape the standard XML forbidden chars
  s|(?<!\\)&(?!amp;)|&amp;|g;    #-- this first! the (?<!\\) is a look-behind so that we don't match to \&
                                 #-- the second (?!amp;) will not replace already escaped &amp; to &amp;amp;
  s|'|&apos;|g;                  #'
  s|<|&lt;|g;
  s|>|&gt;|g;

  s/(^\s*)/</;
  s/\s*$/>/;

  if ( m|\s*</| )
  {
   $indent--;
  }
  print XML " " x $indent, "$_\n";

  #-- try to determine the indent for the next line
  if ( m|\s*<(?![/\!])| )
  {
   if ( $_ !~ m|/>\s*$| )
   {
    $indent++;
   }
  }
 } #-- End: foreach ( @lines )

 # Close the file
 close XML
} #-- End: sub WriteAntXML

########################################################

sub ProcessAntFlags
{
 my $CompilerArgs = shift;
 my $AntTask      = shift;
 my $TaskArgs;
 my $JavaCompiler;

 unless ( $CompilerArgs and $AntTask )
 {
  croak "ERROR: Openmake.pm: &ProcessAntFlags: Usage: &ProcessAntFlags( \$CompilerArgs, \$AntTask )";
 }

 #-- First get any compiler flag out
 # Allows for custom flags
 if ( $CompilerArgs =~ s/\bcompiler=(\S+)// )
 {
  $JavaCompiler = $1;
  $JavaCompiler =~ s/[\'\"]//;
  $TaskArgs     = $CompilerArgs;
  $CompilerArgs = '';

  my @JavaCompilers = qw( javac1.1 javac1.2 javac1.3 javac1.4
    gcj vcj kopi );
  my @RmicCompilers = qw( jdk kaffe weblogic );

  #-- Set property for compiler based on type
  if ( $AntTask =~ /javac/i )
  {
   $CompilerArgs .= " -Dbuild.compiler=$JavaCompiler";
  }
  elsif ( $AntTask =~ /rmic/i )
  {
   $CompilerArgs .= " -Dbuild.rmic=$JavaCompiler";
  }
  else
  {
   croak "ERROR: Openmake.pm: &ProcessAntFlags: Unrecognized Ant Task '$AntTask' )";
  }
 } #-- End: if ( $CompilerArgs =~ ...
 else
 {
  $TaskArgs     = $CompilerArgs;
  $CompilerArgs = '';
 }    # end if compiler arg found

 #-- Set JAVA_HOME appropriately

 #-- use the right version of the compiler if the user specified the appropriate
 #   home variable
 %homevars = (
  "javac1.1" => JDK11_HOME,
  "javac1.2" => JDK12_HOME,
  "javac1.3" => JDK13_HOME,
  "javac1.4" => JDK14_HOME,
  jikes      => JIKES_HOME,
  kaffe      => KAFFE_HOME,
  kopi       => KOPI_HOME,
  gcj        => GCJ_HOME,
  jvc        => JVC_HOME,
  sj         => SJ_HOME,
  weblogic   => WEBLOGIC_HOME
 );

 # First check for specific compiler version
 if ( $JavaCompiler and exists $ENV{ $homevars{$JavaCompiler} } )
 {
  $ENV{JAVA_HOME} = $ENV{ $homevars{$JavaCompiler} };

  #  print "setting JAVA_HOME=$homevars{$JavaCompiler}=$ENV{$homevars{$JavaCompiler}}\n";

  # Next check for traditional java home
 }
 elsif ( exists $ENV{JAVA_HOME} )
 {

  #  print "JAVA_HOME=$ENV{JAVA_HOME}\n";

 }
 elsif ( !( $FoundJavaCompiler = FirstFoundInPath( $JavaCompiler ) ) )
 {

  # print "WARNING: Ant Javac Task.sc: main: No JAVA_HOME environment\nvariable found.\n";
  # print "Using first found in path: $FoundJavaCompiler\n";

 }
 else
 {
  print "WARNING: Ant Javac Task.sc: main: No JAVA_HOME is set, $JavaCompiler not found in path.\n";
 }

 $CompilerArgs .= " -Djava.home=$ENV{JAVA_HOME}";

 #-- set the system path: ant shouldn't care
 $ENV{PATH} = "$ENV{JAVA_HOME}" . "$DL" . "bin" . "$PathDL" . "$ENV{PATH}";

 return $CompilerArgs, $TaskArgs;
} #-- End: sub ProcessAntFlags

######################################
sub ParseModuleDirectories
{
 my $definesList = shift @_;
 my $key         = shift @_ || "moduledir=";

 # LN: Update for CASE 3038- Handles spaces in module dir list
 my @defineSplit = SmartSplit( $definesList );

 my @moduleDirs;
 my $moduleDirList = Openmake::SearchPath->new();

 my $define;
 foreach $define ( @defineSplit )
 {
  if ( $define =~ /^$key/i )
  {

   #-- yet another bug found by Matthew @ Queensland Trans
   $define =~ s/^$key//i;
   $define =~ s/^\"//;
   $define =~ s/\"$//;
   foreach ( split( /,+/, $define ) )
   {
    $moduleDirList->push( $_ );
   }
  } #-- End: if ( $define =~ /^$key/i...
 }    #"

 @moduleDirs = $moduleDirList->getList;
 @moduleDirs = sort @moduleDirs;
 @moduleDirs = reverse @moduleDirs;

 $moduleDirList->set( @moduleDirs );

 return $moduleDirList;
} #-- End: sub ParseModuleDirectories

######################################
#Split that respects "" to allow whitespace in flag settings
sub SmartSplit
{
 my $string = shift @_;
 $string =~ s/^\s+//;
 $string =~ s/\s+$//;

 # Split as usual
 @split = split( /\s/, $string );

 # Reconstruct quoted args
 @correctsplit = ();
 $at           = "";

 # Loop through the arguments to match up quotes
 for ( $i = 0 ; $i < @split ; $i++ )
 {
  $at .= $split[$i];
  if ( $at !~ /\"/ || ( $at =~ /\".*\"$/ ) )
  {
   push( @correctsplit, $at );
   $at = "";
  }
  else
  {
   $at .= " ";
  }
 } #-- End: for ( $i = 0 ; $i < @split...

 return @correctsplit;
} #-- End: sub SmartSplit

######################################
sub StripModuleDirectories
{
 my $moduleDirList = shift @_;
 my $relDepsList   = shift @_;

 my @moduleDirs = $moduleDirList->getList;
 my @relDeps    = $relDepsList->getList;

 my $moduleDir;

 if ( @moduleDirs > 0 )
 {
  for ( $i = 0 ; $i < @relDeps ; $i++ )
  {
   $relDeps[$i] =~ s/\\/\//g;
   foreach $moduleDir ( @moduleDirs )
   {
    $moduleDir =~ s|\\|/|g;
    $moduleDir =~ s|\/$||;

    $relDeps[$i] =~ s|^$moduleDir\/||;
   }

   $relDeps[$i] =~ s/^\/// if ( $relDeps[$i] =~ /^\// );
   $relDeps[$i] =~ s/\//$eDL/g;
  } #-- End: for ( $i = 0 ; $i < @relDeps...

  $relDepsList->set( @relDeps );
 } #-- End: if ( @moduleDirs > 0 )

 return $relDepsList;
} #-- End: sub StripModuleDirectories

######################################
sub AddDestdirDirectories
{

 #-- added JAG 05.27.04 for SV
 my $destDirList = shift @_;
 my $relDepsList = shift @_;

 my @destDirs = $destDirList->getList;
 my @relDeps  = $relDepsList->getList;

 if ( @destDirs > 0 )
 {
  foreach ( @relDeps )
  {
   s/\\/\//g;
   foreach my $destDir ( @destDirs )
   {

    #-- if the last part of the destDir matches to relDep,
    #   add it to reldep
    $destDir =~ s|\\|/|g;
    my @p    = split "/", $destDir;
    my $file = pop @p;

    #-- do it case insensitive
    if ( ( lc $_ ) eq ( lc $file ) )
    {
     $_ = $destDir;
    }
   } #-- End: foreach my $destDir ( @destDirs...

   s/\//$eDL/g;
  } #-- End: foreach ( @relDeps )

  $relDepsList->set( @relDeps );
 } #-- End: if ( @destDirs > 0 )

 return $relDepsList;
} #-- End: sub AddDestdirDirectories

######################################
sub AntSplitDirs
{
 my %file_hash = ();
 my $dir       = shift;
 my $int_dir   = shift;
 my $prefix    = shift;
 my @files     = @_;
 my @dirs      = ();

 #-- convert the intermediate directory to "/" delimited
 $int_dir =~ s|\\|/|g;
 $int_dir .= "/" unless ( $int_dir =~ /\/$/ );
 $int_dir =~ s|^\./||;

 #-- convert the prefix directory to "/" delimited
 $prefix =~ s|\\|/|g;
 $prefix =~ s|^\./||;
 $prefix =~ s|/$||;

 $dir = "" if ( $dir eq "." || $dir eq "./" || $dir eq ".\\" );

 #-- parse the $dir string, looking for <marker>=<dir 1>,dir2
 if ( $dir =~ /^\s*"?(.+?)"?$/ )
 {
  my $dir_list = $1;
  @dirs = split /,/, $dir_list;
  foreach my $dir ( @dirs )
  {
   $dir =~ s|^\s+||;
   $dir =~ s|\s+$||;

   $dir .= "/" unless ( $dir =~ /\/$/ );
  }
 } #-- End: if ( $dir =~ /^\s*"?(.+?)"?$/...

 if ( @dirs )
 {

  #-- add the intermediate directories
  my @ldirs = @dirs;
  foreach my $dir ( @ldirs )
  {
   $dir = $int_dir . $dir unless ( $int_dir eq $dir . "/" );
   push @dirs, $dir;
  }

  #-- add the prefix directories
  @ldirs = @dirs;
  foreach my $dir ( @ldirs )
  {
   $dir = $dir . "/" . $prefix . "/" if ( $prefix );
   push @dirs, $dir;
  }

  #-- add the intdir in case we copied local
  push @dirs, $int_dir;
 } #-- End: if ( @dirs )
 else
 {

  #-- add the int dir and the prefix dir
  push @dirs, $int_dir;
  push @dirs, $int_dir . "/" . $prefix . "/" if ( $prefix );
  push @dirs, $prefix . "/" if ( $prefix );
 }

 #-- sort dirs in longest order, so that we match files first
 #   on longest, a la moduledir
 @dirs = unique( @dirs );
 @dirs = sort @dirs;
 @dirs = reverse @dirs;

 #-- now loop over the files and the dirs, see what matches,
 #
 foreach my $file ( @files )
 {
  $file =~ s|\\|/|g;
  my $found = 0;
  foreach my $dir ( @dirs )
  {
   $dir =~ s|\\|/|g;

   if ( $file =~ /^$dir/ )
   {

    #-- have a match to our file. Strip the dir, add to the hash
    $file =~ s|^$dir||;
    my $dirkey = $dir;
    $dirkey =~ s/\/$//;
    push @{ $file_hash{$dirkey} }, $file;
    $found = 1;
    last;
   } #-- End: if ( $file =~ /^$dir/ ...
  } #-- End: foreach my $dir ( @dirs )
  if ( !$found )
  {

   #-- add to the "." hash
   push @{ $file_hash{"."} }, $file;
  }
 } #-- End: foreach my $file ( @files )

 return %file_hash;
} #-- End: sub AntSplitDirs( $, $, $, @)

#------------------------------------------------------------------
sub GenerateBillofMat
{
 return Openmake::Footprint::GenerateBuildAudit(@_);
}

#------------------------------------------------------------------
sub GenerateFootPrint
{
 return Openmake::Footprint::GenerateFP(@_);
}

######################################
sub ExpandEnv
{
 my $str = shift;
 while ( $str =~ /\$\((.+?)\)/ )
 {
  my $env = $1;
  last unless ( $ENV{$env} );
  $str =~ s/\$\($env\)/$ENV{$env}/g;
 }

 return $str;
} #-- End: sub ExpandEnv

######################################
sub ExitScript
{
 my ( $RC, @DeleteFileList ) = @_;

 chmod 0777, @main::DeleteFileList;
 unlink @main::DeleteFileList;

 chmod 0777, @main::dellist;
 unlink @main::dellist;

 chmod 0777, @DeleteFileList;
 unlink @DeleteFileList;

 $main::RC = $RC;

 goto EndOfScript;
} #-- End: sub ExitScript

*exitScript = *ExitScript;

######################################
sub InvertOptionHashRef ($)
{
 use Cwd;

 #-- following parses options as passed through to script
 #   it will remove files from the returned hash that
 #   have DependencyParent{$file} ne $file (these are files
 #   that are scanned dependencies.

 #-- Will also remove keys of option origin.
 #   These are:
 #    DO[]
 #    TBTOG()[]
 #    BTOG()[]
 #    RUL()[]
 # JAG - 12.30.03 - added DT[]
 #
 #my $cwd = cwd();
 #$cwd =~ s|\\|\\\/|g;

 my $target = $main::Target->getDPFE;

 # JAG - 03.16.04
 #$target =~ s|\\|\/|g;

 my $build_task = $main::BuildTask;

 #$target =~ s|\/|\\\/|g;

 my $hashref    = shift;
 my %returnhash = ();
 if ( ref $hashref eq "HASH" )
 {

  #-- invert the hash

  #-- JAG - modified to handle the fact that we now have ->T->BT->OG->file
  #
  #-- short circuit the loop. Go directly to Target->BuildTask

  my $build_task_ref = $hashref->{$target}->{$build_task};
  foreach my $option_group ( keys %{$build_task_ref} )
  {
   my $option_group_ref = $build_task_ref->{$option_group};

   foreach my $key ( keys %{$option_group_ref} )
   {
    my $value = $option_group_ref->{$key};
    next if ( !grep( /\Q$key\E/i, $main::TargetDeps->getList() ) );

    #-- move grep/pattern match to a sub so that other routines can call it
    my $newvalue = CollapseFlags($value);

    #-- strip leading/trailing spaces;
    $newvalue =~ s|^\s+||;
    $newvalue =~ s|\s+$||;
    $newvalue =~ s|\s+| |;

    push @{ $returnhash{$newvalue} }, $key;
   } #-- End: foreach my $key ( keys %{$option_group_ref...
  } #-- End: foreach my $option_group ( ...
 } #-- End: if ( ref $hashref eq "HASH"...
 elsif ( !( ref $hashref ) )
 {

  #-- assume it's a scalar. This should be backwards compatible;
  $returnhash{$hashref} = 1;
 }
 return %returnhash;

} #-- End: sub InvertOptionHashRef ($)

######################################
sub CommonPath
{
 my $TargetDeps = shift;    # Openmake::FileList object
 my $RelDeps    = shift;    # Openmake::FileList object
 my $type       = shift;    # -- how to return, either 0 at the SP/dep dividing line
                            #    or 1 for full path/filename dividing line
 my $inc_ref    = shift;    # optional list of 'include' extensions
 my $exc_ref    = shift;

 my ( $file, $Tmp, $localfiles );
 my @localfiles = ();
 my ( @ResList, @LocalResList );

 my %rethash;

 my @include_exts = @{$inc_ref};
 my @exclude_exts = @{$exc_ref};
 if ( @include_exts )
 {

  #-- Grep for the desired files
  foreach my $ext ( @include_exts )
  {
   $ext =~ s/(\W)/\\$1/g;
   push( @ResList,      grep( /$ext$/, $TargetDeps->getList ) );
   push( @LocalResList, grep( /$ext$/, $RelDeps->getList ) );
  }
 } #-- End: if ( @include_exts )
 elsif ( @exclude_exts )
 {
  @ResList      = $TargetDeps->getList;
  @LocalResList = $RelDeps->getList;

  #-- Grep for the desired files
  foreach my $ext ( @exclude_exts )
  {
   $ext =~ s/(\W)/\\$1/g;
   @ResList      = grep( !/$ext$/, @ResList );
   @LocalResList = grep( !/$ext$/, @LocalResList );
  }
 } #-- End: elsif ( @exclude_exts )
 else
 {

  #-- Take all files
  push( @ResList,      $TargetDeps->getList );
  push( @LocalResList, $RelDeps->getList );
 }

 #-- Now apply default excludes
 foreach my $ext ( @DefaultExcludes )
 {
  $ext =~ s/(\W)/\\$1/g;
  @ResList      = grep( !/$ext$/, @ResList );
  @LocalResList = grep( !/$ext$/, @LocalResList );
 }

 #-- see if the two arrays are the same length. If so, assume that they are
 #   from the same sets of parent objects (eg AllDeps/RelDeps or
 #   TargetDeps/TargetRelDeps)
 #   Don't sort, as they probably are in order.
 if ( scalar @LocalResList != scalar @ResList )
 {

  #-- perform sort by length and reverse it (Result: longer strings first)
  @LocalResList = reverse( sort lengthSort @LocalResList );
 }

 #-- loop over each file, determine path and file
 foreach my $ResFile ( @ResList )
 {
  my $SlashResFile = $ResFile;

  #-- all slashes forward
  $SlashResFile =~ s|\\|\/|g;
  $SlashResFile = "/" . $SlashResFile unless ( $SlashResFile =~ /^\// or $^O =~ /MS|win/i );

  my $TargetRes = "";
  foreach my $tmp ( @LocalResList )
  {
   my $MatchTargetRes = $tmp;

   $MatchTargetRes =~ s|\\|\/|g;
   $MatchTargetRes =~ s|\.|\\\.|g;
   $MatchTargetRes =~ s|\$|\\\$|g;

   $TargetRes = $tmp, last if ( $SlashResFile =~ /$MatchTargetRes$/ );
  } #-- End: foreach my $tmp ( @LocalResList...
  next unless ( $TargetRes );

  $TargetRes =~ s|\\|\/|g;

  #-- these should match exactly. Use rindex instead of match
  my $path  = "";
  my $file  = $TargetRes;
  my $depth = 0;
  if ( $type )
  {
   $SlashResFile =~ s/\\/\//g;
   my @t = split /\//, $SlashResFile;
   $file = pop @t;
   $path = join "/", @t;

   #-- determine the depth.
   $depth = () = $TargetRes =~ m|/|g;
  } #-- End: if ( $type )
  else
  {
   my $rindx = rindex( $SlashResFile, $TargetRes );
   $path = substr( $SlashResFile, 0, $rindx - 1 ) if ( $rindx > 0 );
  }

  if ( $path )
  {

   #--
   push @{ $rethash{$path}->{'FILES'} }, $file;
   $rethash{$path}->{'DIR_DEPTH'} = $depth;
  }
 } #-- End: foreach my $ResFile ( @ResList...

 return %rethash;
} #-- End: sub CommonPath

 # SBT - Update for performance
sub GetRelTarget2TargetMap
{
 my @TarDeps = $::TargetDeps->getList();
 my @RelDeps = $::TargetRelDeps->getList();
 my $tdep = "";

 my @k = keys %main::RelTarget2TargetMap;
 
  if (scalar @k == 0)
  {
   my $i = 0;
   for ($i=0;$i < scalar @RelDeps;$i++)
   {
    if ($TarDeps[$i] eq "")
    {
     $tdep = $RelDeps[$i];
    }
    else
    {
     $tdep = $TarDeps[$i];
    }
 $rdep = $RelDeps[$i];
 $rdep =~ s/\\/\//g;
 $tdep =~ s/\\/\//g;
    $main::RelTarget2TargetMap{$rdep} = $tdep;
   }
  }
}

 # SBT - Update for performance
sub GetTarget2RelTargetMap
{
 my @TarDeps = $::TargetDeps->getList();
 my @RelDeps = $::TargetRelDeps->getList();
 my $tdep = "", $rdep = "";

 my @k = keys  %main::Target2RelTargetMap;
  if (scalar @k == 0)
  {
   my $i = 0;
   for ($i=0;$i < scalar @RelDeps;$i++)
   {
    if ($TarDeps[$i] eq "")
    {
     $tdep = $RelDeps[$i];
    }
    else
    {
     $tdep = $TarDeps[$i];
    }
 $rdep = $RelDeps[$i];
 $rdep =~ s/\\/\//g;
 $tdep =~ s/\\/\//g;
    $main::RelTarget2TargetMap{$tdep} = $rdep;
   }
  }
}

######################################
sub AntFilesetOrg
{
 my $TargetDeps = shift;    # Openmake::FileList object
 my $TargetRelDeps = shift; # Openmake::FileList object

 my $dirstr     = shift;    # string of format dir=""<dir1>","<dir2>"
 my $intdirstr = shift;    # use  int dir if no dir matches are made
 my $prefix     = shift;
 my @exts = @_;             # optional list of 'exclude' extensions

 my ($file, $Tmp, $localfiles);
 my @localfiles = ();
 my (@ResList, @LocalResList);

 my %rethash;

# SBT - Update for performance
GetTarget2RelTargetMap($TargetDeps,$TargetRelDeps);

 #-- convert the prefix directory to "/" delimited
 $prefix =~ s|\\|/|g;
 $prefix =~ s|^\./||;
 $prefix =~ s|/$||;

 #-- add intdir to the list of dirs
 $intdirstr =~ s|\\|/|g;

 $dirstr .= ",$intdirstr";

 #-- parse the $dir string, looking for <marker>=<dir 1>,dir2
 if ( $dirstr =~ /^\s*"?(.+?)"?$/ )
 {
  my $dir_list = $1;
  @dirs = split /,/, $dir_list;
  my @newdir_list = (); #SBT fls-591 - make sure all dirs have / on them
  
  if ( @dirs )
  {
   #-- add the prefix directories
   @ldirs = @dirs;
   foreach my $dir ( @ldirs )
   {
    # SBT - Update for performance
    $dir =~ s|^\s+||;
    $dir =~ s|\s+$||;
    $dir =~ s|\\|/|g;
    $dir .= "/" unless ( $dir =~ /\/$/ );
    push @newdir_list, $dir; #SBT fls-591 - make sure all dirs have / on them
    $dir = $dir . "/" . $prefix . "/"  if ( $prefix) ;
    push @newdir_list, $dir; #SBT fls-591 - make sure all dirs have / on them

   }
   @dirs = @newdir_list; #SBT fls-591 - make sure all dirs have / on them
  }
  @dirs = unique(@dirs);
  @dirs = reverse ( sort lengthSort @dirs);
 }

 # SBT - Update for performance
 push(@extlist,@exts);
 push(@extlist,@DefaultExcludes);

 @extlist = unique(@extlist);

 #-- excludes
 if ( @extlist )
 {
  @ResList = $TargetDeps->getList;
  @RelResList = $TargetRelDeps->getList;

  #-- Grep for the desired files
  foreach my $ext ( @extlist )
  {
   $ext =~ s/(\W)/\\$1/g;
   @ResList = grep( ! /$ext$/, @ResList ) ;
   @RelResList = grep( ! /$ext$/, @RelResList ) ;
  }
 }
 else
 {
  #-- Take all files
  push( @ResList, $TargetDeps->getList );
  push( @RelResList, $TargetRelDeps->getList );
 }

 # #-- perform sort by length and reverse it (Result: longer strings first)
 @ResList = reverse ( sort lengthSort @ResList);
 @RelResList = reverse ( sort lengthSort @RelResList);

 foreach (@RelResList)
 {
  $_ =~ s|\\|/|g; #set all rel files to forward slashes
 }

 #-- loop over each file, determine path and file
 foreach my $ResFile (@ResList)
 {
  my $path = "";
  my $file = "";
  #-- all slashes forward
  $ResFile =~ s|\\|/|g;
  #07.11.05 ADG Commented below line out - was prepending forward [root] slashes to relative paths in unix for dir= zipfileset option
  #$ResFile = "/" . $ResFile unless ( $ResFile =~ /^\// or $^O =~ /MS|win/i );

 # SBT - Update for performance
  $RelResMatch = $main::RelTarget2TargetMap{$ResFile};
  #-- now we look to see if we can sneak one of the @dirs in here.
  #   add in the null "" at the end in case none of the @dirs match
  my $found_dir = 0;
  @dirs = grep {$_ =~ /\w/} @dirs; #grep out only dirs that have word characters, i.e., not ./, / or ADG 02.02.06.
  foreach my $dir (  @dirs )
  {
   my $path = "";
   my $file = "";

   $dir =~ s|//|/|g; # SBT - Fixed matching

   if ($RelResMatch =~ /^\Q$dir\E/)
   {
    $RelPath = $ResFile;
    $RelPath =~ s/\Q$RelResMatch\E//i;
    $path = $RelPath .$dir;
    #09.10.09 LN Updated to allow for UNC paths
    $path =~ s|//|/|g unless ( $path =~ /^\/\// ); #make sure no double slashes are passed through unless at the beginning (UNC Path)
    $file = $RelResMatch;
    $file =~ s{^\Q$dir\E[\\/]*}{}i;
    if ( $path && $file ) #safe guard to prevent emtpy paths and files from being passed through
    {
     $found_dir = 1;
     push @{$rethash{$path}}, $file;
     last;
    }
   }
   ###### old dir parsing logic replaced by above conditional ADG 02.02.06
   #else #below is a safe guard to attempt matching on first found instance of dir
   #{
   # my $indx = index( $ResFile, $dir);
   # my $str_length = length($dir);
   # my $path_indx = $indx + $str_length;
   # $path = substr($ResFile,0,$path_indx);
   # $path =~ s|\/$||; #strip off any trailing slashes
   # $file = substr( $SlashResFile,$path_indx);
   #}
   ######
  }
  if ( $found_dir == 0 ) #Just set dir value to relpath if no dirs were matched
  {
   $file = $RelResMatch;
   $path = $ResFile;
   $path =~ s/\Q$file\E$//i;
   $path =~ s|\/$||; #strip off any trailing slashes
   $path = $intdirstr if ($path !~ /\w+/); #if path has no value, assume it is the intdir
   push @{$rethash{$path}}, $file;
  }
 }
 return %rethash;
}

######################################
#-- goes through all sub task dependencies from preceding tasks and updates TargetRelDeps
#
sub GetSubTaskDeps
{
 my $TargetDeps    = shift;
 my $TargetRelDeps = shift;
 my $wanted_dir    = shift;
 my $sub_task_ext  = shift;

 my @subtask_classes = ();
 my @package_classes = ();

 #-- Find the name of the "results from dependency" - the derived subtask deps that match the passed in extensions
 my @subtask_deps = $TargetRelDeps->getExtList( $sub_task_ext );

 #-- the following is needed if the javac comes from an earlier task AG 08232004 4911
 #push @rel_javac, $RelDeps->getExtList( ".javac") if (scalar @rel_javac == 0); #everything should come from TargetDeps

 foreach $subtask_dep ( @subtask_deps )
 {
  $subtask_dep =~ s/\\/\//g;
  my @temp = split /\//, $subtask_dep;
  pop @temp;
  $rel_subtask_path = join "/", @temp;

  #-- get the list of files in the .javac and .rmic files.
  my @subtask_classes = &GetClasses( $TargetDeps, $sub_task_ext );

  #-- the following is needed if the javac comes from an earlier task AG 08232004 4911
  #push @javac_sub_task_classes, &GetClasses( $AllDeps, qw( .javac) ); #everything should come from TargetDeps

  @subtask_classes = grep { $_ =~ /\w+/ } @subtask_classes;    #strip out any empty class values AG 08/16/04 4930
                                                               #-- add javac prefix to all these guys
  foreach my $file ( @subtask_classes )
  {
   $file = $rel_subtask_path . "/" . $file if ( $rel_subtask_path );

   ######################################################################
   #want to match classes defined in Jar task with those in jup file
   #if matching classes are found use those, and ignore all the remaining
   #contents of the .jup, otherwise inlcude all contents of .jup.
   #AG 08/16/04 4930
   #
   #adopted original in jar script to be used for jup derived deps AG 3.15.05
   #
   # MDG - 08.08.07 - No Case - Needed to make the check referred to above look
   # specifically for ends with matches. Otherwise, any existing JAR dependency that
   # matches a jup file dep in its name causes total exclusion of the jup deps.
   #
#   if ( $sub_task_ext =~ /\.jup/ )                             #Added this logic below to satisfy
#   {
#    $match        = 0;
#    @task_classes = $TargetRelDeps->get;
#    $file =~ s|\/|\\|g;
#    $pos = rindex( $file, "\\" ) + 1;                          #want to grep out the file name portion of the $file string
#    $match_file = substr( $file, $pos );                       # in order to simplify matching (only on file name) in case of intdir's
#    if ( grep /\Q$match_file\E$/, @task_classes )        # MDG - 08.08.07 - No Case - look for ends with matches
#    {
#
     #if a single match is found, assume that the matched file(s) should be used the matching files will
     #be included as file deps from TargetRelDeps, so ignore all the contents of the .jup ADG 3.16.05
#     @subtask_classes = ();
#     last;                                                     #get out since a match was found
#    }
#   } #-- End: if ( $sub_task_ext =~ ...

  } #-- End: foreach my $file ( @subtask_classes...

  push @package_classes, unique( @subtask_classes );
  foreach ( @package_classes ) { $_ =~ s|\\|/|g; }
  foreach ( @package_classes ) { s/\$/\$\$/g }
  @package_classes = &unique( @package_classes );
  if ( $rel_subtask_path )
  {
   if ($wanted_dir =~ /\w+/)
   {
    $rel_dir = "$rel_subtask_path/$wanted_dir";
   }
   else
   {
    $rel_dir = "$rel_subtask_path";
   }
  }
 } #-- End: foreach $subtask_dep ( @subtask_deps...
 return $rel_dir, @package_classes if ( @package_classes );
} #-- End: sub GetSubTaskDeps

sub CollapseFlags
{
 my $value = shift;

 #-- JAG - 01.05.03 - case 4049 - need to parse for
 #-- get rid of the Option keys #{
 #-- JAG - 05.24.04 - case 4689. Cannot just cut "}" characters.
 #                    Need to match on opening closing {}
 #$value =~ s|\}||g;
 #$value =~ s|DO\[\d+\]\{||g; #}
 #$value =~ s|TBTOG\(.+?\)\[\d+\]\{||g; #}
 #$value =~ s|BTOG\(.+?\)\[\d+\]\{||g; #}
 #$value =~ s|RUL\(.+?\)\[\d+\]\{||g; #}
 #$value =~ s|DT\[\d+\]||g;
 #-- following RegExp loops and cuts
 my $newvalue = "";

 #-- JAG - 09.30.04 - case 5078. Need to make () before [\d+] optional
 #                    so that DO[442] matches
 #while ( $value =~
 # s!^\s*([A-Z]{2,5})\(.+?\)\[\d+\]\{(.*?)(\}\s+[A-Z]{2,5}|\}$)!! )
 while (
  $value =~
  s!^\s*([A-Z]{2,5})(?:\(.+?\))?\[\d+\]\{(.*?)(\}\s+[A-Z]{2,5}|\}$)!! )
 {

  #-- don't add TBRT or BRT options -- use Openmake::BuildOptions
  my $temp_key   = $1;
  my $temp_value = $2;
  my $lastmatch  = $3;

  if ( $temp_key ne "TBRT" && $temp_key ne "BRT" )
  {
   $newvalue .= $temp_value;
  }
  if ( $lastmatch =~ /([A-Z]{2,5})/ )
  {
   $value = $1 . $value;
  }
 } #-- End: while ( $value =~ s!^\s*([A-Z]{2,5})(?:\(.+?\))?\[\d+\]\{(.*?)(\}\s+[A-Z]{2,5}|\}$)!!...

 return $newvalue;

}

#------------------------------------------------------------------
sub getSubTaskExts
{
 return qw( .javac .wsdljava .copypkg .omidl .sqljava .javag);
}

#------------------------------------------------------------------
sub getSubTaskFiles
{
 my @exts = getSubTaskExts();
 my $in_file = shift;
 my ( @out_files, @out_file_patt);

 #-- see if the input file is on our list
 my $file = Openmake::File->new($in_file);
 my $ext  = $file->getExt();
 return unless ( grep { $_ eq $ext } @exts);

 #-- open file, find pattern
 return unless open ( FILE, '<', $in_file );
 while (<FILE>)
 {
  chomp;
  my $glob = $file->getDP() . "/" . $_;
  $glob =~ s/\\/\//g;
  $glob =~ s/^\.\///;
  push @out_files, bsd_glob($glob);
 }
 return @out_files;
}

#------------------------------------------------------------------
sub OrderLibs
{
 my ($lib_order_file, @libs ) = @_;
 my @return_libs = ();
 my %in_libs;

 my $fh;
 unless ( open ( $fh, '<', $lib_order_file ))
 {
  #-- error here


 }

 #-- make a hash of the input libs, this is to see if the item exists
 foreach my $lib ( @libs )
 {
  $in_libs{$lib} = 1;
 }

 local $_;
 while ( <$fh> )
 {
  chomp;
  s{^\s+}{};
  s{\s+$}{};

  #-- if not in -l format, change to correct format
  unless( m{^\-l} )
  {
   my $short_obj = $_;
   if ( m{\.(a|so)$} )
   {
    $short_obj = Openmake::File->new($_)->getFE;  #11-22-06 QAB - Use $ShortObject to create -l flags
   }

   $_ = $short_obj;
   if ( m{^lib.*?\.(a|so)$} )
   {
    my $ext = $1;
    my $obj = $_;
    $obj =~ s{^lib}{};  #11-22-06 QAB - Bad parse with more than one "lib" in file name, same as below
    $obj =~ s{\.$ext}{};
    $obj = '-l' . $obj;

    $_ = $obj;
   }
  }

  if ( $in_libs{$_} )
  {
   push @return_libs, $_;
  }
  else
  {
   $RC                      = 1;
   $main::Quiet             = "NO";
   @main::CompilerOut       = ( ".aor file $lib_order_file listed library $_ not in target" );
   $main::CompilerArguments = $OriginalPassedFlags;
   $main::StepDescription   = "Extracting compiler name from flags passed";
   $main::StepError         = "$StepDescription failed!";
   omlogger( "Final", $StepDescription, "ERROR:", "ERROR: $StepDescription failed!", $Compiler, $CompilerArguments, "", $RC, @main::CompilerOut );
   exitScript( $RC, @main::DeleteFileList );
  }
 }
 close $fh;

 #-- remove the listed ones so that we can see what's extra
 #   do this after the initial loop in case there needs to be duplicates
 foreach my $lib ( @return_libs )
 {
  delete $in_libs{$lib} if ( exists $in_libs{$lib} );
 }
 #-- see if there are any extras, get added on at end
 foreach my $lib ( keys %in_libs)
 {
  #-- add to end of lib
  push @return_libs, $lib;
 }

 return @return_libs;
}

1;

__END__

#------------------------------------------
# JAG - 01.09.08 - case FLS-304
# DESCRIPTION: CopyLocal and CopyExcludeLocal take too long. They do a
#  N**2 loop over TargetDeps and TargetRelDeps
#
# RESOLUTION:
#  TargetDeps and TargetRelDeps are pushed to the script in order. So if
# the length of the two arrays are the same, we do an indexed search over
# the arrays instead of a N^2 search
#
#------------------------------------------


