#!/usr/bin/perl
package main;

=head1 NAME

omtgtedit

=head1 SYNOPSIS

omtgtedit.pl [<options>] targetfile1 [targetfile2 ...]

=cut

# omtgtedit.pl, an Openmake (TM) support utility
#
# Copyright 1998-2003
#
# This is UNPUBLISHED PROPRIETARY SOURCE CODE of Catalyst Systems
# Corporation; the contents of this file may not be disclosed to
# third parties, copied or duplicated in any form, in whole or in part,
# without the prior written permission of Catalyst Systems Corporation.
#
# Permission is hereby granted soley to the licencee for use of this
# source code in its unaltered state.  This source code may not be
# modified by licencee except under direction of Catalyst Systems
# Corporation.  Neither may this source code be given under any
# circumstances to non-licensees in any form, including source or
# binary.
#
# Modification of this source constitutes breach of contract, which
# voids any potential pending support responsibilities by Catalyst
# Systems Corporation.  Divulging the exact or paraphrased contents of
# this source code to unlicensed parties either directly or indirectly
# constitutes violation of federal and international copyright and trade
# secret laws, and will be duly prosecuted to the fullest extent
# permitted under law.
#
# This software is provided by Catalyst Systems Corporation "as is" and
# any express or implied warranties, including, but not limited to, the
# implied warranties of merchantability and fitness for a particular
# purpose are disclaimed.  In no event shall the regents or contributors
# be liable for any direct, indirect, incidental, special, exemplary, or
# consequential damages (including, but not limited to, procurement of
# substitute goods or services; loss of use, data, or profits; or
# business interruption) however caused and on any theory of liability,
# whether in contract, strict liability, or tort (including negligence
# or otherwise) arising in any way out of the use of this software, even
# if advised of the possibility of such damage.
#
# This is software written, owned and supported by Catalyst Systems
# Corporation, 1-800-359-8049.
#
#
# omtgtedit.pl Version 3.5.4
#
# Bug Fixes and Enhancements:
#
# 04.21.2004 3.5.4 JAG - case 4606: fix empty Dependency Taskname bug from
#                        last release -- if the task is already set, ignore it
#                        fix is made in OMTarget.pm. THIS REQUIRS VERSION
#                        3.5.4 of OMTarget.pm
#
# 10/02/2003 3.5.3 JAG - case 3693: add fix for empty Dependency Taskname if the
#                        dependency refers to a previous task. THIS REQUIRS VERSION
#                        3.5.3 of OMTarget.pm
#
# 09/02/2003 3.5.2 JAG - fix for case 3560. Precompile params. THIS REQUIRES VERSION
#                        3.5.2 of OMTarget.pm.
#                      - fixes for case 3500. Can add Dependencies recursively thru a
#                        Java glob from the command line.
#
# 07/29/2003 3.5.1 JAG - added EscaoeXml to switch back and forth between XML
#                        and regular code
#                      - added quotesplit to correctly add dependencies
#
# 07/16/2003 3.5.0 JAG - added version info a la harrefresh to ensure we're
#                        at the right place
#                      - fixed case 3368 - "-i" in batch mode called SetIndDirectory
#                        instead of SetIntDirectory
#                      - fixed case 3367 - "-A" in batch mode only called SetProject
#                        for first OMTarget in tgt file; broke on java TGTs.
#
#
#-- old updates
#
# An Example Openmake5 tgt file:
#|PRISM | |prb1099c |AIX_Executable | | | |prb1098c.c |N | | |^prb1099c.c |N | | |^

#$debug = 1;


#-- JAG 06.04.02 -- upgrades for Openmake 6
#  1. Use Openmake::OMTarget5 and Openmake::OMTarget objects to
#     store Target. Note that this version will write v5 or v6 files
#     and convert v5 -> v6, but not other way around. Also, targets
#     with SubTasks must be written out v6.
#  2. Moved some functionality (subroutines) to methods in the above
#     so that they can be accessed by other scripts.
#  3. Added functionality for SubTasks. Can specify to add a dependency
#     to a subtask in a batch mode by
#     -a "<sub task>:<dependency>"
#  4. Interactively, for options d,I,a,V,e,R,M,A,i can pass
#     a list of names/numbers. Eg
#        > I 2  === changes to subtask 2
#        > d 17 19 === deletes deps 17 and 19
#        > a 2:temp.java === adds temp.java to subtask 2.
#  5. Added Getopts::Long
#  6. Uses XML::Simple.
#  7. Cleaned up some code. Global variables are capitalized. Moved to
#     'use strict' paradigm.
#  8. 'Add dependency' 'edit dependency' can add defines and additional flags
#     with |. So, we could have:
#     > a 3:test.class||EXCLUDEJAVAC to add 'test.class' to the 3rd subtask
#     (typically the jar task) with the Additional flag = EXCLUDEJAVAC.
#  9. Listing the deps shows Defines and addition deps.
#

#-- JAG 03.18.03 -- Fix for Case 2986, bug with setting the OS from the
#                   command line

#-- define version
our $OmTgtEditVersion = "3.5.4";

&Usage() if ( scalar (@ARGV )  == 0);

use File::Find;
use Cwd;
use Getopt::Long;
use Openmake::OMTarget5;
use Openmake::OMTarget 3.54;
use strict;
our ( $cwd,
      %Opt,
      $Batch,
      @Tgtfilelist,
      @Globlist,
      $New,
      $Isom5, $Isom6,
      $Filter, @Fdeps,
      $SearchDir, $SubTaskIndx,
      $Tfile, $Changed,
      $FilterAnchor,
      $HelpText,
      $globExt,
      $Omtgt
      );


$cwd = getcwd();
#-- Change $Opt_x to $Opt{x}

#-- check for version
if ( grep /-version/, @ARGV )
{
 print "omtgtedit.pl, Openmake Target Editor\n";
 print "Version $OmTgtEditVersion\n";
 print "\nCopyright 2000-2003 Catalyst Systems Corporation\n";
 exit 0;
}

Getopt::Long::Configure("bundling", "pass_through");
#-- initialize options
foreach my $opt ( qw( A a b C v t I i f d j S P J D h n p l F) ){
 if ( $opt eq 'a' )
 {
  $Opt{$opt} = [ ()];
 }
 else
 {
  $Opt{$opt} = '';
 }
}
GetOptions( \%Opt,
            "A|AppName=s",
            'a|addDep=s@' ,
            "b|buildType=s",
            "C|Convert",
            "v|tgtVersion=s",
            "t|target=s",
            "I|subTaskIndex=n",
            "i|intDir=s",
            "f|filter=s",
            "d|filterDir=s",
            "g|glob=s",
            "j|javaFilter=s",
            "S|searchPath=s",
            "P|Project=s",
            "O|OSName=s",
            "J|Jar=s",
            "D|Define=s",
            "F|AdditionalFlags=s",
            "h|help",
            "n|newTarget",
            "p|printHeader",
            "l|listDeps:s",
            "W|WhichTargets",
            "V|Version=i");

$Batch = 1
   if $Opt{i} or $Opt{A} or $Opt{b} or $Opt{t} or $Opt{p} or $Opt{l}
    or $Opt{f} or $Opt{d} or $Opt{j} or $Opt{J} or $Opt{D} or $Opt{F}
    or $Opt{W} or $Opt{C} or $Opt{g};

#-- add fix for $Opt{a} inited as an array
$Batch = 1 if ( $Opt{a} && $Opt{a}->[0] ne "" );

@Tgtfilelist = @ARGV;

# Handle wildcards for DOS
@Globlist    = grep( /\*|\?/,@Tgtfilelist);
@Tgtfilelist = grep(!/\*|\?/,@Tgtfilelist);

foreach (@Globlist) {
 my @globbies = glob("$_");
 push(@Tgtfilelist, @globbies);
}


#-- Determine if the user has specified an OM type
#   The default is OM 6
if ( defined $Opt{V} ) {
 if ( $Opt{V} == 5 ) {
  $Isom5 = 1;
  $Isom6 = 0;
 } else {
  $Isom6 = 1;
  $Isom5 = 0;
 }
}
else
{
 $Isom5 = 0;
 $Isom6 = 1;
}

# interpret new tgt file
if($Opt{n}) {
 $New = 1;
}

#-- give the help, info, or run batch mode.
if($Opt{h}) {
 &Usage();
 exit(0);
} elsif($Batch) {

 #-- if we want a list of targets do so now
 if ( $Opt{W} ){
  if ( ! ( $Opt{P} && $Opt{S} && $Opt{V}) ){
   print "Must specify Project, SearchPath and Version to search\n";
   exit;
  }
  my @tgtfiles;
  if ( $Isom6 ) {
   @tgtfiles = Openmake::OMTarget::findTargetFiles( $Opt{P}, $Opt{S}, $Opt{t});
  } else {
   @tgtfiles = Openmake::OMTarget5::findTargetFiles( $Opt{P}, $Opt{S}, $Opt{t});
  }
  print "\n\nFollowing version$Opt{V} target files are Project $Opt{P} and SearchPath $Opt{S},\n";
  print "  optionally with target $Opt{t}\n";
  foreach my $file ( @tgtfiles) {
   print "\t$file\n";
  }
  exit;
 }

 $Filter = $Opt{f} || '*';
 @Fdeps = ();
 $SearchDir = '';
 $SubTaskIndx = 0;

 #-- if a subtask is defined, set index
 if($Opt{I}) {
  #-- JAG - don't need -1 since the root guy is the 0 object
  $SubTaskIndx = $Opt{I};
 }

 if ( $Opt{g})
 {
  $SearchDir = $Opt{d};
  if ( $SearchDir =~ /^(\d+):(.*)/ ) {
   $SubTaskIndx = $1;
   $SearchDir = $2;
  }
  $globExt = $Opt{g};
  chdir $SearchDir or print "WARNING: Couldn't change directory to '$SearchDir'\n";
  chdir $SearchDir;

  find(\&Search4Packages,".");

  die "No match found for recursive dependency search.\n" if @Fdeps == ();
  # Change back to original directory
  chdir $cwd;


 }
 elsif($Opt{d})
 {
  # Add a bunch of files as dependencies recursively, starting
  # from this anchor
  $SearchDir = $Opt{d};
  # If this is v6, look for a subtask
  if ( $SearchDir =~ /$(\d+):(.*)/ ) {
   $SubTaskIndx = $1;
   $SearchDir = $2;
  }

  chdir $SearchDir or print "WARNING: Couldn't change directory to '$SearchDir'\n";
  chdir $SearchDir;

  find(\&Search4Files,".");

  die "No match found for recursive dependency search.\n" if @Fdeps == ();

  # Change back to original directory
  chdir $cwd;

 } elsif($Opt{j}) {
  # Add all files as dependencies recursively, starting
  # from this anchor except class and jar files
  # ignore any supplied filter
  $SearchDir = $Opt{j};
  # If this is v6, look for a subtask
  if ( $SearchDir =~ /^(\d+):(.*)/ ) {
   $SubTaskIndx = $1;
   $SearchDir = $2;
  }
  chdir $SearchDir;

  find(\&Search4JavaFiles,".");

  die "No match found for recursive dependency search.\n" if @Fdeps == ();

  # Change back to original directory
  chdir $cwd;

# } elsif($Opt{f}) {
#  $SearchDir = $Opt{f};
#  if ( $SearchDir =~ /^(\d+):(.*)/ ) {
#   $SubTaskIndx = $1;
#   $SearchDir = $2;
#  }
#  @Fdeps = glob("$Filter");
 }

 if($Opt{J}) {
  $SearchDir = $Opt{J};
  # If this is v6, look for a subtask
  if ( $SearchDir =~ /^(\d+):(.*)/ ) {
   $SubTaskIndx = $1;
   $SearchDir = $2;
  }

  _DoAddJarDep($SearchDir);
 }

 # Interpret batch arguments
 #-- Loop over files in @Tgtfilelist

 foreach $Tfile (@Tgtfilelist) {
  # Set write flag
  $Changed = 0;

  ReadTgt($Tfile);

  #-- Add the OS fix
  if ( $Opt{O} && $Isom6) {
   my $os = $Opt{O};
   $Omtgt->setOSPlatform( $os);
   $Changed++;
  }

  #-- set the searchpath if necessary
  if ( $Opt{S} ) {
   $Omtgt->setSearchPath($Opt{S});
  }

  #-- Change the subtask if necessary
  if ( $Isom6 && $SubTaskIndx ) {
   $Omtgt->setIndex($SubTaskIndx);
  }

  if($Opt{t}) {
   # If redefining target, chop off any subdir
   # path leaving only the filename and extension
   # this helps if we have a target of name 'bin/myexe'
   # and want to replace it with 'myexe'

   my $index;
   my $target = $Omtgt->getName;
   $target =~ s|^/||;
   $target =~ s|^[^/]+/||g;

   my $temptarg = $Opt{t};

   $temptarg =~ s/TARGET/$target/g;

   if ($Isom6 ) {
    $index = $Omtgt->getIndex;
    $Omtgt->setIndex;

    #-- set the first one
    $Omtgt->setName($temptarg);
    my @temp = split /\./, $temptarg;
    my $prefix = shift @temp;

    my $i;
    for ( $i = 1 ; $i< $Omtgt->getNumberTargets; $i++ )
    {
     $Omtgt->setIndex($i);
     my $name = $Omtgt->getName;
     my @temp = split /\./, $name;
     shift @temp;
     my $postfix = join ".", @temp;
     my $name = $prefix . "." . $postfix;
     $Omtgt->setName($name);


     #-- update all deps in this sub task
     my @deps = $Omtgt->getDependencies;
     next unless ( @deps );
     foreach my $dep ( @deps )
     {
      if ( $dep->getTaskName )
      {
       my $depname = $dep->getName;
       my @temp = split /\./, $depname;
       shift @temp;
       my $postfix = join ".", @temp;
       my $depname = $prefix . "." . $postfix;
       $dep->setName($depname);
      }
     }
    }
   }
   else
   {
    $Omtgt->setName($temptarg);
   }

   $Omtgt->setIndex($index) if $Isom6 ;
   $Changed++;
  }

  if ( $Opt{i}) {
   my $intdir = $Opt{i};
   $intdir = '' if ($intdir eq '.' or $intdir eq './' or $intdir =~ /^\s+$/);
   if ( $Isom6 )
   {
    my $index = $Omtgt->getIndex;

    #-- set index to the root level
    my $len = scalar @{$Omtgt->{Targets}};

    for (my $i=0;$i<$len;$i++)
    {
     $Omtgt->setIndex($i);
     $Omtgt->setIntDirectory($intdir);
    }

    #-- set index back
    $Omtgt->setIndex($index);
   }
   else
   {
    $Omtgt->setIntDirectory($intdir);
   }
   $Changed++;
  }

  if ( $Opt{a} ) {
   #-- add a dependency
   #-- JAG - change this to be an array so that the user
   #         can add more than one dep per command line

   #my $dep = $Opt{a};
   foreach my $dep ( @{$Opt{a}} )
   {
    #   if v6, and in batch mode, look for
    #   a subTask index of the form N:<name>;

    if ( $Isom6 ) {
     my $indx;
     if ( $dep =~ /^(\d+):(.*)/ ) {
      $indx = $1;
      $dep = $2;
     }
     $Omtgt->setIndex($indx);
    }

    _DoAddDep($dep);
    $Changed++;
   }
  }

  if ( $Opt{A} ) {
   my $app = $Opt{A};
   #-- fix for case 3367
   if ( $Isom6 ) {
    my $index = $Omtgt->getIndex;

    #-- set index to the root level
    my $len = scalar @{$Omtgt->{Targets}};

    for (my $i=0;$i<$len;$i++)
    {
     $Omtgt->setIndex($i);
     $Omtgt->setProject($app);
    }

    #-- set index back
    $Omtgt->setIndex($index);
   }
   else
   {
    $Omtgt->setProject($app);
   }
   $Changed++;
  }

  if( $Opt{b}) {
   $Omtgt->setBuildType($Opt{b});
   $Changed++;
  }

  if ($Opt{D}) {
   my $defines = $Opt{D};
   $defines =~ s/^\'//;
   $defines =~ s/\'$//;
   $Omtgt->setDefines($defines);
   $Changed++;
  }

  if ($Opt{F})
  {
   #-- set index will have been done by I option
   my $startindex = 0;
   my $index = 0;
   if ( $Isom6 )
   {
    $startindex = $Omtgt->getIndex;
   }

   my $addnFlags = $Opt{F};
   if ( $addnFlags =~ /^(\d+):(.*)/ ) {
    $index = $1;
    $addnFlags = $2;
    if ( $Isom6 )
    {
     $Omtgt->setIndex($index);
    }
   }
   $addnFlags =~ s/^\'//;
   $addnFlags =~ s/\'$//;
   if ( $Isom6 )
   {
    $Omtgt->setAdditionalFlags($addnFlags);
    #-- set the index back
    $Omtgt->setIndex($index);
   }
   else
   {
    $Omtgt->setDefines($addnFlags);
   }
   $Changed++;
  }

  if($Opt{d} or $Opt{j}) {
   chdir $SearchDir;

   # Loop through found files and add them
   my $matched = 0;
   foreach my $fdep (@Fdeps) {
    if (-f "$fdep" || $Opt{g} ) {
     $matched++ if _DoAddDep($fdep);
    }
   }

   print "\nAdded $matched dependencies to $Tfile.\n" if $matched;

   # Change back to original directory!
   chdir $cwd;
  } elsif ($Filter) {
    @Fdeps = glob("$Filter");
  }

  if ($Opt{J}) {
   foreach(@Fdeps) {
    _DoAddDep($_);
   }
  }

  DisplayHeader() if $Opt{p};

  if ($Opt{l}) {
   my $target = $Omtgt->getName;
   print "\nTarget: $target\n\n" unless $Opt{p};
   if ( $Opt{l} =~ /(\d+)/ && $Isom6 ) {
    $Omtgt->setIndex($Opt{l});
    my @deps = $Omtgt->getDependencyNames;
    my $i = 1;
    foreach my $dep ( @deps ){
     print "$i. $dep\n";
     $i++;
    }
   }
  }

  if ( $Opt{C} && $Isom5 ) {
   #-- $Omtgt is an OMv5 object. Make it
   #   and OMv6 object
   $Omtgt = Openmake::OMTarget->convert5($Omtgt);
   $Changed++;
   $Isom6 = 1;
   $Isom5 = 0;
  }

  # write tgt
  CreateTgt() if $Changed;
 }

} else { # Non-batch mode
 #-- Non-batch mode

 &Usage() if ( scalar ( @Tgtfilelist ) == 0 );

 LoadHelp();

 $FilterAnchor = '.';

 foreach $Tfile (@Tgtfilelist) {
  ReadTgt($Tfile);
  #-- set the searchpath if necessary
  if ( $Opt{S}) {
   $Omtgt->setSearchPath($Opt{S});
  }

  DisplayDeps();

  print "\nEnter '?' for help.\n";

  while( &DoCommand() ) {}

  print "\n";
 }
}

exit(0);

#----------------------------------------
sub ReadTgt {
 # Read in the tgt file
 # This places target object (either 5 or 6)
 # into object $omtgt, and returns it
 # Updated for v6
 my $Tfile = shift;
 $Tfile .= '.tgt' unless $Tfile =~ /\.tgt$/;
 my (@lines, $line);

 if( -e "$Tfile" and !$New) {
  open(TIN,"<$Tfile") or die "Couldn't open $Tfile\n";

  #-- for om5, the .tgt file is one line, for
  #   om6, it is multiple lines - let's find out
  #   which

  @lines = <TIN>;
  close TIN;

  if ($#lines > 0 and $lines[0] =~ /^\s*\<\?/) {
   $Isom6 = 1;
   $line = join('',@lines);
   $Omtgt = ReadTgt6( $Tfile, $line );
  } elsif( $#lines > -1 ) {
   $Isom5 = 1;
   $line = shift @lines;
   chomp $line;
   $Omtgt = ReadTgt5( $Tfile, $line );
  } else {
   die "Unexpected end of file!\n";
  }
 } elsif($New) { # This is a new tgt file

  #undef %Deps;
  #undef @DepKeys;
  #undef @deps;

  die "File '$Tfile' already exists." if -e "$Tfile";
  #$app = 'NO_APP';

  #$buildtype = 'NO_BUILDTYPE';
  if ( $Opt{V} == 5 ){
   $Omtgt = Openmake::OMTarget5->new;
  } else {
   $Omtgt = Openmake::OMTarget->new;
  }
  my $tmpstr = $Tfile;
  $tmpstr =~ s/\.tgt$//;

  $Omtgt->setProject("NO_APP");
  $Omtgt->setName($tmpstr);
  $Omtgt->setTargetName($Tfile);
 } else {
  warn "'$Tfile' not found!\n";
  exit 1;
 }
 return $Omtgt;
}

#----------------------------------------
sub ReadTgt5 {
 # Updated for v6
 my $tfile = shift;
 my $line = shift;
 my $Omtgt = Openmake::OMTarget5->new($line);
 $Omtgt->setFileName($tfile);
 return $Omtgt;
}

#----------------------------------------
sub ReadTgt6 {
 # Updated for v6
 my $tfile = shift;
 my $line = shift;
 #my $tgt6 = Openmake::OMTarget->XMLin($line);
 #-- I think steve changed the method
 my $Omtgt = Openmake::OMTarget->XMLin($line);

 #-- case 3693 - fix dependency TaskNames
 my $changed = $Omtgt->fixDepTaskname;

 $Changed += $changed;

 $Omtgt->setTargetName($tfile);
 $Omtgt->setIndex(0);
 return $Omtgt;
}

#----------------------------------------
sub DisplayHeader {
 # Updated for v6
 print "\n\n";
 print '********** ';
 print "OPENMAKE Target Editor **********\n";
 print "File:                " . $Omtgt->getTargetName . "\n";
 $Omtgt->displayHeader;
}

#----------------------------------------
sub DoAddFilterDep {
 # Updated for v6
 my($fdep,$matched,$Recurse);
 use File::Find;

 # $FilterAnchor is the directory we look for
 # the fortunate files fitting the fine filter

 # We have the technical value, $FilterAnchor
 # and the meaningful representaiton of the
 # value, $FilterAnchorRep

 my($FilterAnchorRep) = $FilterAnchor;
 $FilterAnchorRep = '.', $FilterAnchor = '.' if ($FilterAnchor eq '');

 print "Enter Filter Anchor\n";
 print "(Default \"$FilterAnchorRep\")\n";
 print "Root Path: ";

 my $NewFilterAnchor = <STDIN>;
 chomp $NewFilterAnchor;

 $FilterAnchor = $NewFilterAnchor unless ($NewFilterAnchor eq '');

 $Filter = GetName('filter (e.g., com/sasdata/ros*java)');

 # Get current working directory
 $cwd = `cd` or $cwd = `pwd`;
 chomp $cwd;

 # Try changing the directory, or
 unless( chdir $FilterAnchor ) {
  # Report a PEBCAK
  print "Couldn't change directory to '$FilterAnchor'\n";
  return;
 }
 print "Recursive Search: ";
 $Recurse = <STDIN>;
 chomp $Recurse;

 if ($Recurse =~ /^Y/i) {
  @Fdeps = ();
  find(\&Search4Files,".");
 } else {
  # Get the list of files matching the filter
  @Fdeps = glob("$Filter");
 }

 # Loop through found files and add them
 foreach $fdep (@Fdeps) {
  $matched++;
  _DoAddDep($fdep);
 }

 print "No match found.\n" unless $matched;
 print "\nAdded $matched dependencies.\n" if $matched;

 # Change back to original directory!
 chdir $cwd;
}

#----------------------------------------
sub DoAddPackageDep {
 # Updated for v6
 my($fdep,$matched,$Recurse);
 use File::Find;

 # $FilterAnchor is the directory we look for
 # the fortunate files fitting the fine filter

 # We have the technical value, $FilterAnchor
 # and the meaningful representaiton of the
 # value, $FilterAnchorRep

 my($FilterAnchorRep) = $FilterAnchor;
 $FilterAnchorRep = '.', $FilterAnchor = '.' if ($FilterAnchor eq '');

 print "Enter Anchor\n";
 print "(Default \"$FilterAnchorRep\")\n";
 print "Root Path: ";

 my $NewFilterAnchor = <STDIN>;
 chomp $NewFilterAnchor;

 $FilterAnchor = $NewFilterAnchor unless ($NewFilterAnchor eq '');

 $Filter = GetName('filter (e.g., com/sasdata/* or * )');

 print "Enter an extension to apply to the glob, e.g.\n";
 print " enter 'java' for com/sasdata/*.java : ";
 $globExt = <STDIN>;
 chomp $globExt;
 $globExt =~ s/^\*+//;
 $globExt =~ s/^\.+//;

 #-- JAG - 06.26.03 - change case 3262
 # _DoAddDep( "\*\.$globExt" ) if ( $Filter eq '*' );

 # Get current working directory
 $cwd = `cd` or $cwd = `pwd`;
 chomp $cwd;

 # Try changing the directory, or
 unless( chdir $FilterAnchor ) {
  # Report a PEBCAK
  print "Couldn't change directory to '$FilterAnchor'\n";
  return;
 }

 @Fdeps = ();
 find(\&Search4Packages,".");

 # Loop through found files and add them
 foreach $fdep (@Fdeps) {
  $matched++;
  _DoAddDep($fdep);
 }

 print "No match found.\n" unless $matched;
 print "\nAdded $matched dependencies.\n" if $matched;

 # Change back to original directory!
 chdir $cwd;
}

#----------------------------------------
sub DoAddFileDep {
 # Updated for v6
 my($depfile) = GetName('dependency file');

 open(DEP,"<$depfile") or print "Couldn't open '$depfile'!\n";
 my(@deplist) = <DEP>;
 close DEP;

 my($count) = 0;

 chomp @deplist;

 foreach my $fdep (@deplist) {
  # skip comments and blank lines
  unless ($fdep =~ /^#/ || $fdep =~ /^\s*$/) {
   #$fdep =~ s/\s+$/;
   #$fdep =~ s/^\s+/;
   _DoAddDep($fdep);
   $count++;
  }
 }

 print "\nAdded $count dependencies.\n";
}

#----------------------------------------
sub DisplayHelp {
 # Updated for v6
 print "$HelpText";
}

#----------------------------------------
sub LoadHelp {
 # Updated for v6
 $HelpText=<<OTEHELPTEXT;

+++ omtgtedit.pl Commands +++

Display:
  h - Show (h)eader info
  s - (s)how dependency list
Target Definition:
  A - Change (A)pplication name ( can list name)
  t - change (t)arget name (can list name)
  b - change (b)uild type
  i - change (i)ntermediates directory
  I - change SubTask (I)ndex
  T - add SubTask
  C - Convert v5 -> v6
  D - replace the #(D)EFINEs field ("Additional Flags" on v6 Main TGT GUI)
  n - appe(n)d to the #DEFINEs field ("Additional Flags" on v6 Main TGT GUI)
  p - replace db/(p)recompile field ("Precompile" on v6 Main TGT GUI)
  P - ap(P)end to precompile options ("Precompile" on v6 Main TGT GUI)
  O - change (O)perating System
  R - Remove a subtask
  M - change target filena(M)e
  W - Write-out list of target files that match
      to the Project and Searchpath and optionally
      the target.

Dependencies:
  a - (a)dd dependency
  e - (e)dit a dependency
  d - (d)elete
  f - a dependency, add dependencies by (f)ilter
  F - add dependencies  by (F)ile
  J - add dependencies from a (J)ar
  g - add (g)lob dependencies  recursively
  L - sort dependency (L)ist by extension
  V - set (V)ersion Path. Necessary to convert
      v5 tgt files that contain .jup or .rmic
      files as dependencies.
Target File:
  (S)ave, help(?) or (q)uit
+++++++++++++++++++++++++++++

OTEHELPTEXT

=head1 Interactive Commands

=head2 Display Commands

  h - show (h)eader info
  s - (s)how dependency list

=head2 Target Definition Commands

  A - change (A)pplication name
  t - change (t)arget name
  b - change (b)uild type
  i - change (i)ntermediates directory
  I - change SubTask (I)ndex
  T - add SubTask
  C - Convert v5 -> v6
  D - replace the #(D)EFINEs field ("Additional Flags" on v6 Main TGT GUI)
  n - appe(n)d to the #DEFINEs field ("Additional Flags" on v6 Main TGT GUI)
  p - replace db/(p)recompile field ("Precompile" on v6 Main TGT GUI)
  P - ap(P)end to precompile options ("Precompile" on v6 Main TGT GUI)
  R - Remove a subtask
  M - change the target filena(M)e
  W - Write-out list of target files that match to
      the project and Searchpath and optionally to
      the target

=head2 Dependency Commands

  a - (a)dd dependency (can list index,name,defines,flags)
  e - (e)dit a dependency (can list number, or index:number)
  d - (d)elete
  f - a dependency, add dependencies by (f)ilter
  F - add dependencies  by (F)ile
  J - add dependencies from a (J)ar
  g - add (g)lob dependencies  recursively
  L - sort dependency (L)ist by extension
  V - set (V)ersion Path. Necessary to convert
      v5 tgt files that contain .jup or .rmic
      files as dependencies.

=cut
}
#----------------------------------------
sub DisplayDeps {
 # Updated for v6
 DisplayHeader();

 my $index = 1;
 my $pgindex = 9;


 my @deps;
 if ($Isom5 ) {
  @deps = $Omtgt->getDependenciesPrint;
 } else {
  @deps = $Omtgt->getDependencyPrint;
  print "\nCurrent SubTask is: ". $Omtgt->getIndex . " " .$Omtgt->getName ;
  print "\n\tAdditionalFlags:\t" . $Omtgt->getAdditionalFlags . "\n";
  print "with following Dependencies\n";
 }
 print "\n     Dependency" . " "x22 . "Defines               Flags\n";
 DisplayList($pgindex, @deps);
}

#----------------------------------------
sub DoCommand {
 # Updated for v6

 print "\nEnter command: ";
 my $cmd = <STDIN>;
 $cmd = substr($cmd,0,1) unless ( $cmd =~ /^\s*(d|I|a|V|e|R|M|A|t|i)\s+/);

CMDSW:
 {
  DisplayHelp(),      last CMDSW if $cmd eq '?';
  DisplayHeader(),    last CMDSW if $cmd eq 'h';
  DisplayDeps(),      last CMDSW if $cmd eq 's';

  DoAddDep($cmd),     last CMDSW if $cmd =~ /^\s*a/;
  DoAddFilterDep(),   last CMDSW if $cmd eq 'f';
  DoAddPackageDep(),  last CMDSW if $cmd eq 'g';
  DoAddFileDep(),     last CMDSW if $cmd eq 'F';
  DoAddJarDep(),      last CMDSW if $cmd eq 'J';

  DoChangeTarget($cmd), last CMDSW if $cmd =~ /^\s*t/;
  DoChangeApp($cmd),  last CMDSW if $cmd =~ /^\s*A/;
  DoChangeBT(),       last CMDSW if $cmd eq 'b';
  DoChangeDep($cmd),  last CMDSW if $cmd =~ /^\s*e/;
  DoChangePrecomp(),  last CMDSW if $cmd eq 'p';
  DoAppendPrecomp(),  last CMDSW if $cmd eq 'P';
  DoChangeDefines(),  last CMDSW if $cmd eq 'D';
  DoAppendDefines(),  last CMDSW if $cmd eq 'n';
  DoChangeOS(),       last CMDSW if $cmd eq 'O';
  DoChangeIntDir($cmd),   last CMDSW if $cmd =~ /^\s*i/;
  DoChangeFileName($cmd), last CMDSW if $cmd =~ /^\s*M/;

  DoAddSubTask(),     last CMDSW if $cmd eq 'T';
  DoDeleteSubTask($cmd),  last CMDSW if $cmd =~ /^\s*R/;
  DoChangeIndex($cmd),    last CMDSW if $cmd =~ /^\s*I/;
  DoSetVersionPath($cmd), last CMDSW if $cmd =~ /^\s*V/;
  DoConversion(),     last CMDSW if $cmd eq 'C';
  DisplayTgts(),      last CMDSW if $cmd eq 'W';

  if ($cmd eq 'L') {
   $Omtgt->sortDependenciesByExt();
   print "\nDependencies sorted by extension.\n\n";
   $Changed++;
   last CMDSW;
  }

  DoDeleteDep($cmd),  last CMDSW if $cmd =~ /^\s*d/;
  DoSaveTgt(),        last CMDSW if $cmd eq 'S';

  if ($cmd eq 'q')
  {
   return(0) if (DoQuit());
  }
 }

 return(1);
}
#----------------------------------------
sub DoAddDep {
 # Updated for v6
 my $cmd = shift;
 my $Newdep;

 if ($Isom6)
 {
  if ($Omtgt->getOSPlatform eq "") {print "\nOS must be defined before adding a dependency.\n"; return;}
  if ($Omtgt->getBuildType eq "")  {print "\nBuild Type must be defined before adding a dependency.\n";return;}
 }

 if ($cmd =~ /^a\s+(.+)/ ) {
  $Newdep = $1;
 } else {
  $Newdep = GetName('new dependency');
 }
 my ($indx, $c);

 #-- need to improve this for deps with spaces.
 my @ccc=quotesplit($Newdep);
 foreach my $cc (@ccc){
  if ( $cc =~ /(\d+):(.*)/ ) {
   $indx = $1;
   $cc = $2;
   if ( $Isom6 ) {
    $Omtgt->setIndex($indx);
   }
  }
  _DoAddDep($cc);
 }

}

#----------------------------------------
sub DoAddJarDep {

 if ($Isom6)
 {
  if ($Omtgt->getOSPlatform eq "") {print "\nOS must be defined before adding a dependency.\n"; return;}
  if ($Omtgt->getBuildType eq "")  {print "\nBuild Type must be defined before adding a dependency.\n";return;}
 }

 # Updated for v6
 my($jarfile) = GetName('jar file');
 @Fdeps = ();

 _DoAddJarDep($jarfile);

 foreach(@Fdeps) {
  _DoAddDep($_)
 }
}

#----------------------------------------
sub _DoAddJarDep {

 if ($Isom6)
 {
  if ($Omtgt->getOSPlatform eq "") {print "\nOS must be defined before adding a dependency.\n"; return;}
  if ($Omtgt->getBuildType eq "")  {print "\nBuild Type must be defined before adding a dependency.\n";return;}
 }

 # Updated for v6
 my($jarfile) = shift @_;

 print "\nAdd dependencies from an existing Jar file...\n";

 my @classes = `jar tf $jarfile`;

 if($classes[0] =~ /Exception/i) {
  print "@classes\n";
  return(0);
 }

 chomp(@classes);

 foreach (@classes) {
  # skip empty directories
  #  and inner classes and manifest
  next if m|/$|;
  next if m|\$|;
  next if m|META-INF|;

  # convert class to java file
  s/\.class$/\.java/i;
  push(@Fdeps,$_);
 }
}

#----------------------------------------
sub _DoAddDep {
 # Updated for v6
 #  change this to allow us to add DEFINES and Additional Flags.

 my($Newdep) = shift @_;

 my $depobj;
 return if ($Newdep eq '');
 #-- split on '|'
 my $defines = '';
 my $flags = '';
 if ( $Newdep =~ /\|/ ) {
  my @newdep = split /\|/, $Newdep;
  if ( defined $newdep[1] ) { $defines = $newdep[1]; }
  if ( defined $newdep[2] ) { $flags = $newdep[2]; }
  $Newdep = shift @newdep;
 }

 if ( $Omtgt->existsDependency($Newdep) ) {
  print "Dependency '$Newdep' already exists.\n";
  return(0);
 }

 if ( $Isom5 ) {
  $depobj = Openmake::OMTarget5Dependency->new();
 } else {
  $depobj = Openmake::Dependency->new();
 }
 $depobj->setName($Newdep);

 if ( defined $defines ) {
  $depobj->setDefines($defines);
 }
 if ( defined $flags ) {
  if ($Isom6 ) {
   $depobj->setAdditionalFlags($flags);
  } else {
   $depobj->setPrecompile($flags);
  }
 }
 $Omtgt->addDependency($depobj);

 print "Added '$Newdep'\n";
 $Changed++;
 return 1;
}

#----------------------------------------
sub DoChangeDefines {
 # Updated for v6
 my $defines = GetName('#DEFINE\'s');
 $Omtgt->setDefines($defines);
 $Changed++;
}

#----------------------------------------
sub DoAppendDefines {
 # Updated for v6
 my $defines = $Omtgt->getDefines;
 $defines .= GetName('Append to #DEFINE\'s');
 $Omtgt->setDefines($defines);
 $Changed++;
}

#----------------------------------------
sub DoChangePrecomp {
 # Updated for v6
 my $dbinfo = GetName('Precompile/AdditionalFlags options');
 if ( $Isom6 ) {
  #-- this doesn't exist?
  #   Case 3560 - yes it does.
  $Omtgt->setAdditionalFlags($dbinfo);
  $Changed++;
  return;
 }
 #my $dbinfo = $Omtgt->getPrecompile;
# my $dbinfo = GetName('Precompile options');
 $Omtgt->setPrecompile($dbinfo);
 $Changed++;
}

#----------------------------------------
sub DoAppendPrecomp {
 # Updated for v6
 if ( $Isom6 ) {
  #-- this doesn't exist?
  #   Case 3560 Yes it does
  my $dbinfo = $Omtgt->getAdditionalFlags;
  $dbinfo .= GetName('Append to AdditionalFlags options');
  $Omtgt->setAdditionalFlags($dbinfo);
  $Changed++;

  return;
 }
 my $dbinfo = $Omtgt->getPrecompile;
 $dbinfo .= GetName('Append to precompile options');
 $Omtgt->setPrecompile($dbinfo);
 $Changed++;
}

#----------------------------------------
sub DoChangeIntDir {
 # Updated for v6
 my $cmd = shift;
 my $intdir;
 if ( $cmd =~ /\s*i\s+(.+)/ ) {
  $intdir = $1;
  $intdir =~ s/\s+$//;
  $intdir =~ s/^"//;
  $intdir =~ s/"$//;
 } else {
  $intdir = GetName('Intermediate directory');
 }

 $intdir = '' if ($intdir eq '.' or $intdir eq './');

 if ( $Isom6 )
 {
  my $index = $Omtgt->getIndex;

  #-- set index to the root level
  my $len = scalar @{$Omtgt->{Targets}};

  for (my $i=0;$i<$len;$i++)
  {
   $Omtgt->setIndex($i);
   $Omtgt->setIntDirectory($intdir);
  }

  #-- set index back
  $Omtgt->setIndex($index);
 }
 else
 {
  $Omtgt->setIntDirectory($intdir);
 }
 $Changed++;
}

#----------------------------------------
sub DoAddSubTask {
 # Updated for v6
 # add a subtask to end of list
 if ( $Isom5 )
 {
  return;
 }

 if ($Omtgt->getOSPlatform ne "Java") {
  print "\nOnly Java programs can have Sub-Tasks.\n";
  return;
 }

 my @BuildTypes = grep(!/^Java/,GetBuildTypes());
 DisplayList(8,@BuildTypes);
 my $ind = GetIndex();
 $ind--;
 return if ($ind < 0 or $ind > scalar @BuildTypes);
 my $build = $BuildTypes[$ind];
 if ($Isom5 ) {
  return;
 }
 $Omtgt->addSubTask($build);
 $Changed++;
 return;
}

#----------------------------------------
sub DoChangeIndex {
 # Updated for v6
 # change the index of the subtask
 if ( $Isom5 ) { return;}
 my $cmd = shift;
 #-- see if this matches to 'I <n>'
 #
 my $ind;
 if ( $cmd =~ /^I\s+(\d+)/ ) {
  $ind = $1;
 } else {
  $ind = GetIndex();
 }
 return if ($ind < 0 or $ind > $Omtgt->getNumberTargets );

 $Omtgt->setIndex($ind);
}

#----------------------------------------
sub DoConversion {
 # Updated for v6
 $Omtgt = Openmake::OMTarget->convert5($Omtgt);
 #undef $Omtgt;
 #$Omtgt = $newom;
 print "\n\nConverting to v6 target file\n\n";
 $Changed++;
 $Isom6 = 1;
 $Isom5 = 0;
}

#----------------------------------------
sub DoChangeApp {
 # Updated for v6
 my $cmd = shift;
 my $Newapp;
 my $index;
 if ( $cmd =~ /\s*A\s+(.+)/ ) {
  $Newapp = $1;
 } else {
  $Newapp = GetName('Application');
 }

 return if ($Newapp eq "");

 if ( $Isom6 ) {
  $index = $Omtgt->getIndex;

  #-- set index to the root level
  my $len = scalar @{$Omtgt->{Targets}};

  for (my $i=0;$i<$len;$i++)
  {
   $Omtgt->setIndex($i);
   $Omtgt->setProject($Newapp);
  }

  #-- set index back
  $Omtgt->setIndex($index);
 }
 else
 {
  $Omtgt->setProject($Newapp);
 }
 $Changed++;
}

#----------------------------------------
sub DoChangeBT {
 # Updated for v6
 my @BuildTypes = ();
 if ($Omtgt->getOSPlatform() eq "Java")
 {
  @BuildTypes = grep(/^Java/,GetBuildTypes());
 }
 else
 {
  @BuildTypes = GetBuildTypes();
 }

 DisplayList(8,@BuildTypes);
 my $ind = GetIndex();
 $ind--;
 return if ($ind < 0 or $ind > scalar @BuildTypes);

 if ($Omtgt->getOSPlatform() eq "")
 {
  print "\nYou must first choose an Operating System first.\n";
  return;
 }

 $Omtgt->setBuildType($BuildTypes[$ind]);
 $Changed++;
}

#----------------------------------------
sub DoChangeOS {
 # Updated for v6
 return if ($Isom5);

 my @OS = qw(Windows Java AIX HP-UX Solaris Linux);
 DisplayList(8,@OS);
 my $ind = GetIndex();
 $ind--;
 return if ($ind < 0 or $ind > scalar @OS);

 if ($Omtgt->getOSPlatform() eq "Java")
 {
  print "\nCannot change the OS from Java to $OS[$ind].\n";
  return;
 }

 if ($Omtgt->getOSPlatform() ne "Java" && $Omtgt->getOSPlatform() ne "" && $OS[$ind] eq "Java")
 {
  print "\nCannot change the OS from " . $Omtgt->getOSPlatform() . " to Java.\n";
  return;
 }

 my $index = $Omtgt->getIndex;

 #-- set index to the root level
 my $len = scalar @{$Omtgt->{Targets}};

 for (my $i=0;$i<$len;$i++)
 {
  $Omtgt->setIndex($i);
  $Omtgt->setOSPlatform($OS[$ind]);
  $Omtgt->setBuildType("");
 }

 #-- set index back
 $Omtgt->setIndex($index);

 $Changed++;
}

#----------------------------------------
sub DoDeleteDep {
 # Updated for v6
 my $cmd = shift;
 #-- see if this matches to 'd <n1> <n2>'
 #
 my @deletes;

 if ( $cmd =~ /^d\s+\d+/ ) {
  @deletes = split " ", $cmd;
  shift @deletes;
  @deletes = reverse ( sort @deletes); #--
  foreach my $dels ( @deletes) { $dels--; }
 } else {

  print "Enter a pattern or index number: ";
  my $patt = <STDIN>;
  my $ind;
  if ($patt =~ /^(\d+)\n?$/ ) {
   #-- user supplied an index number
   $ind = $1;
   $ind--;
  }
  push @deletes, $ind;
 }
 foreach my $ind ( @deletes) {

  #-- check see if out of range
  if($ind > $Omtgt->getDependencyCount or $ind < 0) {
   print "Index out of range\n";
   return;
  }

  #-- remove the $dependency
  $Omtgt->removeDependencyIndex($ind);
  $Changed++;
 }
 return;

}

#----------------------------------------
sub DisplayList {
 # Updated for v6
 my($pgindex,@list) = @_;
 my($index) = 1;
 my($dummy);

 #print "\n";

 foreach my $item (@list) {
  if($pgindex > 16)  {
   print "\nHit Return to Continue, or 'q' to stop listing: ";
   my $dummy = <STDIN>;
   return if lc(substr($dummy,0,1)) eq 'q';
   print "\n";
   $pgindex = 0;
  } else { $pgindex++ }
  if ( $item =~ /\|/ ) {
   #-- if we contain a '|' character, we are separating on Defines and
   #   additional flags. We write a string assuming 80 chars
   my @items = split /\|/, $item;
   undef $item;
   $item = sprintf "%-30s  %-20s  %-20s", $items[0], $items[1], $items[2];
   #foreach my $i ( @items ) {
   # $item .= $i . "\t";
   #}
  }

  printf "%3d. %-70s\n", $index,  $item;
  $index++;
 }
}

#----------------------------------------
sub DoChangeDep {
 my $cmd = shift;
 my $ind;
 my $index;
 my $rest;
 my $defines;
 my $flags;
 my $Newdep;
 if ( defined $cmd ) {
  if ( $cmd =~ /^\s*e\s+(\d+)$/ ) {
   $ind = $1;
  } elsif ( $cmd =~ /^\s*e\s+(\d+):(\d+):(.+)/ ) {
   $index = $1;
   $ind = $2;
   $Newdep = $3;
   if ( $Newdep =~ /\|/ ) {
    my @newdep = split /\|/, $Newdep;
    if ( defined $newdep[1] ) { $defines = $newdep[1]; }
    if ( defined $newdep[2] ) { $flags = $newdep[2]; }
    $Newdep = shift @newdep;
   }
  } elsif ( $cmd =~ /^e\s+(\d+):(\d+)$/ ) {
   $index = $1;
   $ind = $2;
  } elsif ( $cmd =~ /\s*e\s+(\d+):(.+)/ ) {
   $ind = $1;
   $Newdep = $2;
   $Newdep =~ s/\s+$//;
   $Newdep =~ s/"//g;
   #"
  } else {
   $ind = GetIndex();
  }
 }
 $ind--;
 return if $ind < 0;

 if ( defined $index && $Isom6) {
  $Omtgt->setIndex($index);
 }

 #-- get the dependency object by index

 my $dep = $Omtgt->getDependencyIndex($ind);

 if ( ! defined $Newdep ) {
  $Newdep = GetName('Dependency');
 }
 #-- add defines and target info here

 if ($Isom6 ) {
  $dep->setName($Newdep);
  if ( defined $defines ) {
   $dep->setDefines($defines);
  }
  if ( defined $flags ){
   $dep->setAdditionalFlags($flags);
  }
 } else {
  $dep = $Omtgt->setDependency($Newdep);
  if ( defined $defines ) {
   $dep->setDefines($defines);
  }
  if ( defined $flags ){
   $dep->setPrecompile($flags);
  }
 }

 # Update @DepKeys
 #$Omtgt->removeDependency($olddep);
 #$Omtgt->addDependency($Newdep);
 $Changed++;
}

#----------------------------------------
sub DoQuit {
 # Updated for v6
 my($ans) = '';

 if($Changed) {
  until( $ans eq 'y' or $ans eq 'n') {
   print "\nSave tgt file? (y/n): ";
   $ans = <STDIN>;
   $ans =~ /^(.?)/;
   $ans = lc(substr($ans,0,1));
  }
 }

 if($ans eq 'y')
 {
  return DoSaveTgt()
 }
 else
 {
  exit(0);
 }
}

#----------------------------------------
sub DoSaveTgt {
 # Updated for v6
  return CreateTgt();
}
#----------------------------------------
sub DoChangeFileName {
 my $cmd = shift;
 my $filename;
 if ( $cmd =~ /\s*M\s+(.+)/ ) {
  $filename = $1;
  $filename =~ s/\s+$//;
  $filename =~ s/"//g;

  #"
 } else {
  print "Enter target filename: ";
  $filename = <STDIN>;
  chomp $filename;
 }

 return if ($filename eq "");

 if ( $Isom6 )
 {
  my $index = $Omtgt->getIndex;

  #-- set index to the root level
  my $len = scalar @{$Omtgt->{Targets}};

  for (my $i=0;$i<$len;$i++)
  {
   $Omtgt->setIndex($i);
   $Omtgt->setTargetName($filename);
  }

  #-- set index back
  $Omtgt->setIndex($index);
 }
 else
 {
  $Omtgt->setTargetName($filename);
 }

 $Changed++;
}

#----------------------------------------
sub DoChangeTarget {
 # Updated for v6
 my $cmd = shift;
 my $Newtarget;
 if ( $cmd =~ /\s*t\s+(.+)/) {
  $Newtarget = $1;
  $Newtarget =~ s/\s+$//;
 } else {
  $Newtarget = GetName('Target');
 }
 my $index;
 unless( $Newtarget =~ /^\s*$/ ) {

  #-- fix to change all names in the list of indices
  if ($Isom6 ) {
   $index = $Omtgt->getIndex;
   $Omtgt->setIndex;

   #-- set the first one
   $Omtgt->setName($Newtarget);
   my @temp = split /\./, $Newtarget;
   my $prefix = shift @temp;

   my $i;
   for ( $i = 1 ; $i< $Omtgt->getNumberTargets; $i++ )
   {
    $Omtgt->setIndex($i);
    my $name = $Omtgt->getName;
    my @temp = split /\./, $name;
    shift @temp;
    my $postfix = join ".", @temp;
    my $name = $prefix . "." . $postfix;
    $Omtgt->setName($name);

    #-- update all deps in this sub task
    my @deps = $Omtgt->getDependencies;
    next unless ( @deps );
    foreach my $dep ( @deps )
    {
     if ( $dep->getTaskName )
     {
      my $depname = $dep->getName;
      my @temp = split /\./, $depname;
      shift @temp;
      my $postfix = join ".", @temp;
      my $depname = $prefix . "." . $postfix;
      $dep->setName($depname);
     }
    }
   }
  }
  else
  {
   $Omtgt->setName($Newtarget);
  }

  $Omtgt->setIndex($index) if $Isom6 ;
  $Changed++;
 }
}
#----------------------------------------
sub DoSetVersionPath {
 my $cmd = shift;
 #-- see if this matches to 'V <name>'
 #
 my $searchpath;
 chomp $cmd;
 if ( $cmd =~ /^\s*V\s+.+/ ) {
  ($cmd, $searchpath) = split " ", $cmd;
 } else {
  print "Enter name of the version Path: ";
  $searchpath = <STDIN>;
  chomp $searchpath;
 }
 $Omtgt->setSearchPath($searchpath);

}

#----------------------------------------
sub DoDeleteSubTask {
 my $cmd = shift;
 my $index;
 if ( $cmd =~ /^R\s+(\d+)/ ) {
  $index = $1;
 } else {
  $index = GetIndex();
 }
 $index;
 return if $index < 0;

 if ( defined $index && $Isom6) {
  $Omtgt->setIndex($index);
  $Omtgt->removeTarget;
 }
 $Changed++;
}
#----------------------------------------
sub DisplayTgts {
 print "\nEnter project:";
 my $project = <STDIN>;
 chomp $project;
 print "Enter searchpath name:";
 my $searchpathname = <STDIN>;
 chomp $searchpathname;
 print "Enter target:";
 my $target = <STDIN>;
 chomp $target;
 my @tgtfiles;
 if ( $Isom6 ) {
  @tgtfiles = Openmake::OMTarget::findTargetFiles( $project, $searchpathname, $target);
 } else {
  @tgtfiles = Openmake::OMTarget5::findTargetFiles( $project, $searchpathname, $target);
 }
 foreach my $file ( @tgtfiles) {
  print "$file\n";
 }
}


#----------------------------------------
sub Usage {
 # Updated for v6
 my($usage1) =<<ENDUSAGE1;

omtgtedit.pl, Openmake Target Editor
Version $OmTgtEditVersion

Copyright 2000-2003 Catalyst Systems Corporation

Interactive Mode:
 perl omtgtedit.pl [-n] <tgtfile1>[.tgt] [tgtfile2[.tgt]]...

  -n            This is a new target, create a new .tgt file

Batch Mode:
 perl omtgtedit.pl [-A <app>] [-b <buildtype>] [-i <intdir>]
                   [-t <target>] tgtfile1[.tgt] [tgtfile2[.tgt]]...
                   [-f <filter> -d <directory>] [-j <directory>]
                   [-version]

(Press Enter)
ENDUSAGE1

 my($usage2) =<<ENDUSAGE2;
Batch Mode Options:
 -h               Help

 -A <app>         Change Application name to <app>
 -a <dep>         Add dependency:
                   for Java sub-tasks, this can be of the form
                    n:<name>, where n is the number of the sub-task
                   e.g.
                    -a 1:rt.jar
                   adds "rt.jar" to the first sub-task (typically
                   "Set Classpath")
                   See also the -I flag.
                  One can include multiple -a option on the command line
                  to specify adding of multiple dependencies.
 -I <index>       Set the Java sub-task index to <index>
 -b <bt>          Change Build Type to <bt>
 -i <intdir>      Change Intermediate Directory to <intdir>
 -t <target>      Change Target name to <target>
 -O <OS Platform> Change the OS Platform

(Press Enter)
ENDUSAGE2

 my $usage3 =<<EOF;
 -d <directory>   Add dependencies recursively from <directory>
                  according to supplied <filter> from -f <filter>
 -j <directory>   Add dependencies recursively from <directory>
                  except for types .class and .jar
 -f <filter>      filter to use with -d and -j options
 -n               This is a new target, create new .tgt file(s)
 -J <jar file>    Add dependencies from a jar file changing .class->.java
 -D "<define>"    Add or replace the target compiler defines. Corresponds to
                  "Additional Flags" field on Version 6 Main TGT GUI pane
 -F "<flag>"      Add or replace a flag to the Precompiler. Corresponds to
                  "Precompile" field on Version 6 Main TGT GUI pane.
                  Can use <index>:<Flag> notation to add to "Additional Flags"
                  of a Dependency detail.
 -p               Print out the target header
 -l               Print out a list of dependencies

 Target Name Symbolic Replacement Options
 -t <dir>/TARGET  Prepend <dir> to existing target name
 -t TARGET        Strip any path prefix from root target name

 Finding Target Files
 -W               Find Target files along a search Path
 -P <project>     Project on KB Server
 -S <search path> Search Path name on KB Server
 -V (5|6)         Type of tgt files to find
EOF

 my $usage4 =<<EOF;
 Warning:

 It is not recommended that one use the -n flag to create new
 Java target files. The use of sub-tasks within Java targets
 does not facilitate the clean creation of target file. Instead,
 use the Web Client to create a template tgt file, copy that
 file, and use the batch mode options to modify the .tgt file
 as necessary.

EOF
 print "$usage1\n";
 my $dummy = <STDIN>;
 print "$usage2\n";
 $dummy = <STDIN>;
 print "$usage3\n";
 $dummy = <STDIN>;
 print "$usage4\n";

 exit 1;
}


#----------------------------------------
sub GetBuildTypes {
 # Updated for v6

 my @BuildType;

 if ( $Isom5 ) {
  # First find the Openmake file 'vpath.kb'
  # It's location is determined by the environment var
  # OPENMAKE_KB

  die "ERROR 121: No OPENMAKE_KB environment variable\n"
   unless $ENV{OPENMAKE_KB};

  my $kbrule = "$ENV{OPENMAKE_KB}/rule.kb";
  open (FP,"<$kbrule") or die "Couldn't open $kbrule\n";
  my @RuleList = <FP>;
  close(FP);

  foreach my $line (@RuleList) {
   my @Rule = split(/\s/,$line);
   my $bt = shift(@Rule);

   my @found = grep(/$bt/,@BuildType);

   push(@BuildType,$bt) unless @found;
  }
 } else {
  #-- om6, need to look at KB Server
  #   Use getBuildTypes for OS
  use Openmake::KBServer;
  my $kb = Openmake::KBServer->new;
  my $os = $Omtgt->getOSPlatform;
  @BuildType = sort($kb->listBuildTypes4OS($os));
 }

 return(@BuildType);
}

#----------------------------------------
sub GetIndex {
 # Updated for v6
 my($ind,$dummy);

 print "\nWhich #?: ";
 $dummy = <STDIN>;

 if($dummy =~ /^(\d+)/) {
  $ind = $1;
 } else {
  $ind = 0;
 }

 return($ind);
}

#----------------------------------------
sub CreateTgt {
 # Updated for v6

 my($TgtName,$Appl,$Target,$BuildType,$IntDir,$DBINFO,$Defines) = @_;
 my($Dep,$Tmp);   # Local Variables
 my $dummy;
 $TgtName = $Omtgt->getTargetName;

 if ($Omtgt->getTargetName eq "") {print "\nFile Name is required.\n"; return 0;}
 if ($Omtgt->getName eq "") {print "\nTarget Name is required.\n";return 0;}
 if ($Omtgt->getOSPlatform eq "") {print "\nOS is required.\n"; return 0;}
 if ($Omtgt->getBuildType eq "") {print "\nBuild Type is required.\n"; return 0;}
 if ($Omtgt->getProject eq "") {print "\nProject Name is required.\n"; return 0;}

 # Check if file is writable
 unless( -w $TgtName or $New)
 {
  print "'$TgtName' is not writable.  Override? (y/n):";
  $dummy = <STDIN> until $dummy =~ /^[yn]/i;
  chmod 0777, $TgtName if $dummy =~ /^y/i;
 }

 # Open TGT for writing
 print "Writing $TgtName\n";  # Announce creation of tgt
 open (TGT,">$TgtName") or print "Couldn't open '$TgtName'\n", return 0;

 #-- write out the file
 my $xml = $Omtgt->writeOut;
 print TGT $xml;
 close TGT;

 $Changed=0;
 return 1;
}

#----------------------------------------
sub GetName {
 # Updated for v6
 my($string) = shift @_;

 print "\nEnter $string Name: ";
 my $dummy = <STDIN>;

 chomp $dummy;
 return $dummy;
}

#----------------------------------------
sub Search4Files {
 # Updated for v6
 my($matchstr) = $Filter;
 my($file) = $File::Find::name;

 # convert shell wild cards to perl regexp
 $matchstr =~ s/\./\\\./g;

 # take special case of full glob
 if ( $matchstr =~ s/^\*$// or $matchstr =~ s/^\*\\\.\*$// ) {
  $matchstr = '.*';
 } else { # normal
  $matchstr = '^' . $matchstr unless ( $matchstr =~ s/^\*// );
  $matchstr .= '$' unless ( $matchstr =~ s/\*$// );

  $matchstr =~ s/\?/\./g;
  $matchstr =~ s/\*/\.\*\?/g;
 }

 $file =~ s|^\./?||;

 my @temp = split( '/', $file);
 my $lastpart = pop @temp;

 my $evalstr = "\$file =~ m|$matchstr|";
 $evalstr .= 'i' if $^O =~ /win|os2/i;

 push(@Fdeps,$file) if ( eval( $evalstr )
                          && -e $lastpart);
}

#----------------------------------------
sub Search4Packages {
 # Updated for v6
 my($matchstr) = shell2regex($Filter);

 #-- In this routine, we look in the given
 #   directory for sub-directories
 #   "$file" is either a file or dir, but
 #   we only care about sub-dirs
 #
 #   The Find::File Module will locally 'cd'
 #   into a given directory, but provide in
 #   the file name the path relative to where
 #   we started.
 #
 #-- if we find a "file" in the current directory that:
 #    1. Is a directory ( -d)
 #    2. path relative to start point matches
 #       our Filter
 #    3. Files within the directory match the extension
 #       (glob)
 #   we push the filter onto the FDeps array
 #
 my $dir = $File::Find::name;
 my @temp = split( '/', $dir);
 my $lastdir =  pop @temp ;
 return unless ( -d $lastdir );

 my $matchdir = $dir;

 #-- shell2regex leads with ^(dir)/
 #   hence the need to remove "./"
 $matchdir =~ s|^\./?||;

 #-- add a trailing "/" unless it's the local
 #   dir, since the matchstr needs it.
 $matchdir .= "/" unless ( ! $matchdir);

 #-- need to look in dir for the type glob.
 my @globs = ();
 @globs = glob "$lastdir/*.$globExt";

 if ( $matchdir =~ m|$matchstr| && -d $lastdir && @globs )
 {
  push(@Fdeps, $matchdir . "\*.$globExt");
 }
}

#----------------------------------------
sub Search4JavaFiles {
 # Updated for v6
 my $file  = $File::Find::name;

 $file =~ s|\s*$||;
 $file =~ s|^\./||;

 my @temp = split( '/', $file);
 my $lastpart = pop @temp;

 push(@Fdeps,$file)       if (
                                           $file !~ /\.class$/
                                       and $file !~ /\.jar$/
                                       and $file !~ /\.tgt$/
                                       and $file !~ /\.jpr$/
                                       and $file !~ /hsig$/
                                       and $file !~ /harvest.sig$/
                                       and -f $lastpart
                                       );
}

#----------------------------------------
# function to be used by sort
sub by_extension {
 # get extensions
 $a =~ /\.([^.])*$/;
 my $extA = $1;

 $b =~ /\.([^.])*$/;
 my $extB = $1;

 return $extA cmp $extB unless $extA eq $extB;
 return $a cmp $b

}

#----------------------------------------
# function to be used by sort
sub shell2regex {
 my $matchstr = shift;

 # convert shell wild cards to perl regexp
 # +.(){}|$ get back slashed
 $matchstr =~     s/([\+\.\(\)\{\}\|\$])/\\$1/g;

 # take special case of full glob
 if ( $matchstr =~ s/^\*$// or $matchstr =~ s/^\*\\\.\*$// ) {
  $matchstr = '.*';

 } else { # normal
  $matchstr = '^' . $matchstr unless ( $matchstr =~ s/^\*// );
  $matchstr .= '$' unless ( $matchstr =~ s/\*$// );

  $matchstr =~ s/\?/\./g;
  $matchstr =~ s/\*/\.\*\?/g;

 }

 return $matchstr;
}

sub quotesplit
{
 my $string = shift @_;
 $string =~ s/^\s+//;
 $string =~ s/\s+$//;

 # Split as usual
 my @split = split(/\s/, $string);

 # Reconstruct quoted args
 my @correctsplit = ( );
 my $at = "";

 # Loop through the arguments to match up quotes
 for (my $i = 0; $i < @split; $i++) {
  $at .= $split[$i];
  if ($at !~ /"/ || ($at =~/^".*"$/ && $at !~ /^".*\\"$/ )) { #"
   #-- strip quotes
   $at =~ s/^"//;
   $at =~ s/"$//;

   push(@correctsplit, $at);
   $at = "";
  }
  else
  {
   $at =~ s/\\"$/"/;
   $at .= " ";
  }
 }

 return @correctsplit;
}

1;

