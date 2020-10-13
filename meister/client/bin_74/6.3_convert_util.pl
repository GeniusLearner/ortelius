#!/usr/local/bin/perl

#-- MDG 11/21/03
#   Utility used to convert Openmake 6.0 - 6.1 Build Types into Openmake 6.3 
#   Build Type format. 
#
#   The utility provides the user with two conversion options:
#
#   1) Convert one explicitly referenced Build Type XML file
#   2) Convert all Build Type XML files in a specified directory
#
#   The conversion process parses the existing Build Type XML to retrieve the 
#   Build Type information. The information is then reformatted\reinterpreted
#   into 6.3 format. A backup of each converted Build Type is created by appending
#   a ".converted" extension to the end of the file name.
#
#   All of the output from the conversion process is printed to the screen and
#   printed to a log file defined in the $LOGFILE global constant. The log file
#   is created in the directory that contains the Build Types being converted.


#===============================================================================
#-- Section: use declarations

use File::Copy;
use Cwd;

#===============================================================================
#-- Section: variables

#-- Set up Global Constant variables 
#
$VERSION_NUMBER = '6.3'; #-- Version number to be used during the conversion
@DEFAULT_BUILD_TASKS = ("Compile=Rules in this Build Task perform compile actions by calling a specific compiler."); 
$DEFAULT_TASK_NAME = "Compile"; #-- Name of the Default Build Task
$DEFAULT_OPTION_GROUP = "Build Task Options"; #-- Name of the Default Option Group
$DEFAULT_RULE_OPTION_GROUP = "Rule Options"; #-- Name of the Default Option Group used for Rules
$DEFAULT_FLAG_TYPE = 1; #-- Default Bit used for Option Type. 1 = Required Option      
$RELEASE_FLAG_TYPE = 8; #-- Bit used for to indicate a RELEASE Option Type.
$DEBUG_FLAG_TYPE = 16; #-- Bit used for to indicate a DEBUG Option Type.
$COMMON_FLAG_TYPE = $DEBUG_FLAG_TYPE + $RELEASE_FLAG_TYPE; #-- Bit used for to indicate a COMMON Option Type.
$LOGNAME = '6.3Conversion.log'; #-- Name of the log file to print output to

#-- Set up the Operating System specific variables
if ($^O =~ /mswin32/i)
{
 $DL = "\\";
 $UNIX = 0;
}
else
{
 $DL = "/";
 $UNIX = 1; 
}

#===============================================================================
#-- Section: user interface

#-- OPTIONS label used to return to if the user needs to redirected to the OPTIONS
OPTIONS:
print $Options=<<OPTIONS;

+++ 6.3 Build Type Conversion +++++++++++

Convert Options:

  o - convert (o)ne Build Type XML file
  a - convert (a)ll Build Type XML files in a directory
  q - (q)uit

+++++++++++++++++++++++++++++++++++++++++

OPTIONS
 print " >";

 #-- Get the selected OPTION through STDIN
 chomp($option = <STDIN>);
 if($option eq 'o') #-- The user wants to convert one Build Type
 {
  #-- FILE label used to return to if the user needs to redirected to the 
  #   file name prompt.
  FILE:
  print "\nEnter the full path and filename for the Build Type XML file you wish to convert.\n >";
  chomp(my $input = <STDIN>);  
   
  if($input =~ /^q$/) #-- quit
  {
   Exit("\nExiting the 6.3 Build Type conversion utility.");
  }
  elsif($input !~ /\.xml$/i) #-- not an XML file. return to FILE prompt
  {
   print "\n$input is not a valid Build Type XML file.\n";
   goto FILE;
  }
  else #-- process the Build Type XML file
  {
   #-- split the directory from the file name
   if(!$UNIX)
   {
    @tmp = split(/\\/,$input);
   }
   else
   {
    @tmp = split(/\//,$input);
   }
   $btFile = pop @tmp;
   $btDir = join($DL,@tmp);
   
   #-- change to the build type directory
   unless(chdir $btDir)
   {
    print "\n\nWARNING! - Couldn't change directories while converting Build Types, $btDir\n";
    goto OPTIONS;
   }   
   
   #-- print the starting label for the conversion process
   Print("\n" . localtime() . " - Starting Build Type Conversion ########\n");
   
   #-- run the ConvertBuildType sub-routine   
   ConvertBuildType($btFile);   
  }
 }
 elsif($option eq 'a')#-- The user wants to convert multiple Build Type
 {
  #-- DIRECTORY label used to return to if the user needs to redirected to the 
  #   directory prompt.  
  DIRECTORY:
  print "\nEnter the full path to the directory containing the Build Type XML files you wish to convert.\n >";
  chomp(my $btDir = <STDIN>);  
  
  if($btDir =~ /^q$/) #-- quit
  {
   Exit("\nExiting the 6.3 Build Type conversion utility.");
  }
  
  #-- make sure it's actually a directory
  if(! -d $btDir)
  {
   print "\n$btDir is not a valid directory.\n";
   goto DIRECTORY;   
  }  
  
  #-- change to the build type directory
  unless(chdir $btDir)
  {
   print "\n\nWARNING! - Couldn't change directories while converting Build Types, $btDir\n";
   goto OPTIONS;
  }   
  
  #-- get a list of the xml files in the directory
  if(!$UNIX)
  {
   @files = `dir /b *.xml`;
  }
  else
  {
   @files = `ls *.xml`;
  }
  
  if(@files) #-- loop through each XML file and convert it
  {
   #-- print the starting label for the conversion process
   Print("\n" . localtime() . " - Starting Build Type Conversion ########\n");
   
   my $btFile;
   foreach $btFile (@files)
   {
    #-- run the ConvertBuildType sub-routine      
    ConvertBuildType($btFile);
   }
  }
  else #-- since no XML files were found, push the user back to the OPTIONS
  {
   print "\nNo XML files were found in the specified directory, $btDir\n";
   goto OPTIONS;
  } 
 }
 elsif($option eq 'q') #-- quit
 {  
  Exit("\nExiting the 6.3 Build Type conversion utility.");
 }
 else #-- since the user entered an invalid option, push the user back to OPTIONS
 {
  print "\n\nWARNING! - $option is not a a valid Option. Please enter a valid option. \n";
  goto OPTIONS;
 }
 
 
#===============================================================================
#-- Section: sub-routines 

 #####
 #-- Parses the orginal Build Type XML file, backs it up and creates a new Build
 #   Type XML file in the 6.3 format
 #
 sub ConvertBuildType 
 {
  my $btFile = shift;

  if($btFile ne ())
  {
   #-- make sure the file's slashes are going the right way
   $btFile =~ s|\\|/|g;
   $btFile =~ s|\n||g;   
   
   #-- if the file is a directory, we don't need to do any comparisons. we only should compare actual files.   
   if(-d $btFile)
   {
    next;
   }
   
   #-- check to see if the $btFile exists
   if(-e $btFile)
   {
    #-- Open the temporary Build Type file
    $tmpFile = $btFile . '.tmp';
    unless ( open(TMP,">$tmpFile") ) 
    {
     Print( "Unable to open temporary Build Type file, $tmpFile");
     next;
    }
    
    #-- Read the $btFile
    if ( ! open(BT,"$btFile") ) 
    {
     Print( "Unable to open Build Type file, $btFile");
     next;
    }
    else
    {
     Print( "\n\nConverting $btFile \.\.\.");
     @tmp = <BT>;
     @btLines = @tmp;
     close(BT);
    
     #-- reset the DEFAULT_BUILD_TASKS array to just the Compile Build Task
     @DEFAULT_BUILD_TASKS = ("Compile=Rules in this Build Task perform compile actions by calling a specific compiler.");
     
     #-- Run a preliminary scan to determine which Rule Groups to include 
     #   for this Build Type
     my $aLine;
     my $x=0;
     my $aLen = 0;
     my $aNode = "";
     my $aValue = "";
     my $aLastchar = "";
     my $aRc = 0;
     my $aOnIgnore = 1;
     my $aOnNode = 0;
     my $aOnValue = 0;
     my $addedLink = 0;
     my $addedArchive = 0;
     my $javaOS = 0;
     my $taskName = "";
     my $version = "";
     
     foreach $aLine (@tmp)
     {
      $taskName = "";
      $x = 0;
      $aLine =~ s/^\s+$//g; 
      $aLine =~ s/\n//g; 
      $aLine =~ s/\t//g; 
           
      $aLen = length($aLine);      
      if($aLine =~ /^\<\?xml/)
      {
       next;
      }
 
      while ($x<=$aLen)
      {
       my $ch = substr($aLine,$x,1);
       ($aRc,$aNode,$aValue,$aLastchar,$aOnIgnore,$aOnNode,$aOnValue) = findNode($aNode,$aValue,$ch,$aLastchar,$aOnIgnore,$aOnNode,$aOnValue);
       $x++;
   
       if ($aRc || $x == $aLen)
       {
        if($aNode)
        {
         if($aNode =~ /^Version$/)
         {
          $version = $aValue;
         }
         elsif($aNode =~ /^TargetExt$/)
         {
          if($aValue =~ /^\.dll$/ || $aValue =~ /^\.exe$/ || $aValue =~ /^\.lib$/ || $aValue =~ /^\.noext$/ || $aValue =~ /^\.so$/ || $aValue =~ /^\.sl$/)
          {
	          if(!$addedLink)
       	   {
       	    push(@DEFAULT_BUILD_TASKS,"Link=Rules in this Build Task perform link actions by calling a specific linker.");
            $addedLink = 1;
           }
          }
          elsif($aValue =~ /^\.a$/)
          {
       	   if(!$addedArchive)
       	   {
       	    push(@DEFAULT_BUILD_TASKS,"Archive=Rules in this Build Task create archive objects.");
       	    $addedArchive = 1;
       	   }
          }
         }
         elsif($aNode =~ /^OperatingSystem$/)
         {
          if($aValue =~ /^Java$/)
          {
           $javaOS = 1;
          }
         }         
         elsif($aNode =~ /^Name$/ && $javaOS)
         {
          if($aValue !~ /^Java/)
          {
           $taskName = $aValue;
          }
         }         
        }
        #-- reset the Node and Value scalars
        $aNode = "";
        $aValue = "";
       } 
      }
     }
     
     if($taskName)
     {
      @DEFAULT_BUILD_TASKS = ($taskName);
      $DEFAULT_TASK_NAME = $taskName;      
     }
     else
     {
      $DEFAULT_TASK_NAME = "Compile";
     }
     
     #-- Make sure the Build Type hasn't already been converted
     if($version ne ())
     {
      Print( "\n     - $btFile is already VERSION $version.\nSkipped $btFile."); 
      return;
     }
     
     my $line;
     my $i=0;
     my $len = 0;
     my $Node = "";
     my $Value = "";
     my $lastchar = "";
     my $rc = 0;
     my $onIgnore = 1;
     my $onNode = 0;
     my $onValue = 0;
     my $onTarget = 0; 
     my $onDep = 0;
     my $hitRuleNodes = 0;
     my $addedFlagGroupNodes = 0;
     my $openedOptionGroup = 0;
     my $closedOptionGroup = 0;     
     my $flagXML;
     my $ruleXML;
     
     #-- Process Build Type lines
     foreach $line (@btLines)
     {
      $i = 0;
      $line =~ s/^\s+$//g; 
      $line =~ s/\n//g; 
      $line =~ s/\t//g; 
           
      $len = length($line);      
      if($line =~ /^\<\?xml/)
      {
       print TMP $line . "\n";
       next;
      }
 
      while ($i<=$len)
      {
       my $ch = substr($line,$i,1);
       ($rc,$Node,$Value,$lastchar,$onIgnore,$onNode,$onValue) = findNode($Node,$Value,$ch,$lastchar,$onIgnore,$onNode,$onValue);
       $i++;
   
       if ($rc || $i == $len)
       {
        #print "Node: $Node" . "\n";
        #print "Value: $Value". "\n";
        
        if($Node)
        {
         if($Node =~ /^OperatingSystem$/)
         {
          #-- insert the Version tag
          print TMP '<Version>' . $VERSION_NUMBER . '</Version>';
         }
         if($Node =~ /CommonFlags$/ || $Node =~ /DebugFlags$/ || $Node =~ /ReleaseFlags$/)
         {
          #-- if the $Node starts with "/" (e.g. </DebugFlags>), it's an ending 
          #   tag to a Node we no longer use
          if(!($Node =~ /^\//))
          {
           if($Node =~ /^commonflags$/i)
           {
            if($openedOptionGroup == 0)
            {
             #-- Add the Flag Group node before adding the CommonFlags since we know
             #   CommonFlags are the first to be processed
             $openedOptionGroup = 1;
             $closedOptionGroup = 0;
             print TMP '<OptionGroup>';
             print TMP '<GroupName>' . $DEFAULT_RULE_OPTION_GROUP . '</GroupName>';  
             print TMP '<Type>2</Type>'; 
            }
            
            $type = $DEFAULT_FLAG_TYPE + $COMMON_FLAG_TYPE; 
            $flagsXML = "";
            $flagsXML = ConvertFlags($type,$Value); 
           }
           if($Node =~ /^debugflags$/i)
           {
            if($openedOptionGroup == 0)
            {
             #-- Add the Flag Group node before adding the CommonFlags since we 
             #   know CommonFlags are the first to be processed
             $openedOptionGroup = 1;
             $closedOptionGroup = 0;
             print TMP '<OptionGroup>';
             print TMP '<GroupName>' . $DEFAULT_RULE_OPTION_GROUP . '</GroupName>';  
             print TMP '<Type>2</Type>'; 
            }
            
            $type = $DEFAULT_FLAG_TYPE + $DEBUG_FLAG_TYPE; 
            $flagsXML .= ConvertFlags($type,$Value); 
           }
           if($Node =~ /^releaseflags$/i)
           {
            if($openedOptionGroup == 0)
            {
             #-- Add the Flag Group node before adding the CommonFlags since we 
             #   know CommonFlags are the first to be processed
             $openedOptionGroup = 1;
             $closedOptionGroup = 0;
             print TMP '<OptionGroup>';
             print TMP '<GroupName>' . $DEFAULT_RULE_OPTION_GROUP . '</GroupName>';  
             print TMP '<Type>2</Type>'; 
            }

            $type = $DEFAULT_FLAG_TYPE + $RELEASE_FLAG_TYPE; 
            $flagsXML .= ConvertFlags($type,$Value); 
            
            print TMP $flagsXML;
            #-- Add the closing Flag Gorup node since we know ReleaseFlags are 
            #   the last to be processed
            $closedOptionGroup = 1;
            $openedOptionGroup = 0;
            print TMP '</OptionGroup>';

           }           
          
           #-- convert the Flag nodes
           # $flagsXML = ConvertFlags($Node,$Value);
           # print TMP $flagsXML; 
          }
         }
         elsif($Node =~ /^Rules$/ && !$hitRuleNodes)
         {
          $hitRuleNodes = 1;
          
          #-- flip the addedFlagGroupNodes flag to 0 so we add the FlagGroup 
          #   nodes for this Rule
          $addedFlagGroupNodes = 0;          
          
          #-- add the DEFAULT Rule Groups
          foreach $RuleGroup (@DEFAULT_BUILD_TASKS)
          {
           my @tmp = split(/=/,$RuleGroup);
           my $group = shift @tmp;
           my $description = shift @tmp;
           print TMP '<BuildTasks>';
           print TMP '<Name>' . $group . '</Name>';
           print TMP '<Description>' . $description . '</Description>';
           print TMP '<OptionGroups>';
           print TMP '  <GroupName>' . $DEFAULT_OPTION_GROUP . '</GroupName>'; 
           print TMP '  <Type>1</Type>'; 
           print TMP '  </OptionGroups>';           
           print TMP '</BuildTasks>';
          }
          #-- add the Rule node
          print TMP '<' . $Node . '>';
#
## INSERT RULE CONVERSION SUB-ROUTINE CALL HERE
#
         }
         elsif($Node =~ /^TargetExt$/ && $hitRuleNodes )
         {
          if($Value =~ /^\.dll$/ || $Value =~ /^\.exe$/ || $Value =~ /^\.lib$/ || $Value =~ /^\.noext$/ || $Value =~ /^\.so$/ || $Value =~ /^\.sl$/)
          {
           #-- add the Default Build Rule Name
           print TMP '<ParentBuildTask>Link</ParentBuildTask>'; 
          }
          elsif($Value =~ /^\.a$/)
          {
           #-- add the Default Build Rule Name
           print TMP '<ParentBuildTask>Archive</ParentBuildTask>'; 
          }
          else
          {
           #-- add the Default Build Rule Name
           print TMP '<ParentBuildTask>' . $DEFAULT_TASK_NAME . '</ParentBuildTask>'; 
          }          
          print TMP '<' . $Node . '>';
          if($Value)
          {
           print TMP $Value;
          }
         }
         else #-- just print the Node and Value. If it's not a Flag or Rule Node,
              #   we leave it alone
         {
          if($Node =~ /^\/Rules$/)
          {
           #-- check to see if we need to close the Option Group node
           if($openedOptionGroup == 1 && $closedOptionGroup == 0)
           {
            $openedOptionGroup = 0;
            print TMP '</OptionGroup>';
           }
          }

          if($Node !~ /\/$/) #-- don't need to add empty nodes that end in /
          {
           print TMP '<' . $Node . '>';
           if($Value)
           {
            print TMP $Value;
           }
           }
         }
        }
        #-- reset the Node and Value scalars
        $Node = "";
        $Value = "";
       } 
      }
     } 
    }
    close TMP;
    #-- rename the original BT File to $btFile.converted and strip the .tmp off 
    #   of the converted file
    Print( "\n     - Renaming $btFile to $btFile\.converted\.\.\.");
    copy ( $btFile , $btFile . '.converted');
    Print( "\n     - Renaming $tmpFile to $btFile\.\.\.");
    move ( $tmpFile , $btFile );
    Print( "\nConverted $btFile.");    
   }
  }
}

 #####
 #-- Converts the Flag strings from the original Build Type XML into the Option
 #   XML Tag structure used for 6.3
 #
 #
 sub ConvertFlags 
 {
  my $type = shift; # -- this is the Node for the FlagGroup that needs conversion
  my $Value = shift;# -- this is the Flags that belong to the FlagGroup
  my $flagXML;
  
  #-- split the $Value into the flags
  @flags = split(/\|/,$Value);
  foreach $flag (@flags)
  {
   $flagXML .= '<Options>';
   $flagXML .= '<Flag>' . $flag . '</Flag>';
   $flagXML .= '<Type>' . $type . '</Type>';    
   $flagXML .= '</Options>';
  }
  return $flagXML;
 }
 
 #####
 #-- Finds the next node to be parsed based on the specified parameters
 #
 #
 sub findNode
 {
  my ($Node,$Value,$ch,$lastchar,$onIgnore,$onNode,$onValue) = @_;
  
  if ($ch eq '?' && $lastchar eq '<')
   {
    $onIgnore = 1;
    $onNode = 0;
    $onValue = 0;
    $Node = "";
    $Value = "";
   }
   elsif ($ch eq '<')
   {
    $onNode=1;
    $onValue=0;
    $onIgnore=0;
    
    if ($Node ne "")
    {
     $Value =~ s/&quot;/\"/g;
     $Value =~ s/\n$//g;
     return (1,$Node,$Value,$lastchar,$onIgnore,$onNode,$onValue);
    }
  
    $Node = "";
    $Value = "";
   }
   elsif ($onNode)
   {
    if ($ch eq ' ' ) #|| $ch eq '/')
    {
     $onNode = 0;
    }
    elsif ($ch eq '>')
    {
     $onNode = 0;
     $onValue = 1;
    }
    else
    {
     $Node .= $ch;
    }
   }
   elsif ($onValue)
   {
    $Value .= $ch;
   } 
   $lastchar = $ch;
   
   return (0,$Node,$Value,$lastchar,$onIgnore,$onNode,$onValue);
 }
 
 #####
 #-- Print routine
 #   Prints to both the log file and the screen
 sub Print 
 {
  my $msg = shift;
  $logFile = cwd() . $DL . $LOGNAME;
  unless ( open(LOG,">>$logFile") ) 
  {
   print "Unable to open log file, $logFile";
   return;
  }   
  
  #-- Print to the screen
  print $msg;
  #-- Print to the log file
  print LOG $msg;
  
  #-- Close the LOG
  close LOG;
 }
 #####
 #-- Exit routine
 #   Prints the specified messege and exits the conversion utility
 sub Exit 
 {
  my $msg = shift;
  print $msg;
  exit 1;
 }
 


