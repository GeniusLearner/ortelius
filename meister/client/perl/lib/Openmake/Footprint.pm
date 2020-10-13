#==========================================================================
package Openmake::Footprint;

use Exporter ();
use strict;
use vars qw( @ISA
  @EXPORT
  $VERSION
  %SCM_TOOLS
  %FOOTPRINT_TYPE
  $BEGIN_SYSTEM_INFO
  $END_SYSTEM_INFO
  $BAR_ENV_REPORT
  $BAR_PROJ_REPORT
  );
  
#use Openmake;
use Openmake::Log;
use File::Temp qw( tempfile );

use Cwd;
use File::Glob ':glob';
use Fcntl ':flock';
use Time::Local;

my $dbfile; 
my $dbh;

@ISA    = qw( Exporter Autoloader );
@EXPORT = qw( );
%SCM_TOOLS = ( 'accu'  => \&_process_Accurev,
               'clear' => \&_process_Clearcase,
               'cvs'   => \&_process_CVS,
               'har'   => \&_process_Harvest,
               'p4'    => \&_process_Perforce,
               'si'    => \&_process_MKS,
               'svn'   => \&_process_SVN
             );
%FOOTPRINT_TYPE = ( 'C'    => \&_format_C_FP,
                    'Java' => \&_format_Java_FP,
                    'CS.NET' => \&_format_CSNET_FP,
                    'VB.NET' => \&_format_VBNET_FP,
                    'VB5|6'  => \&_format_VB56_FP,
                    'VC.NET' => \&_format_C_FP
 );
$BEGIN_SYSTEM_INFO = 'System Info';
$END_SYSTEM_INFO   = 'End System Info';
$BAR_ENV_REPORT    = '.log/om_bar_env.log';
$BAR_PROJ_REPORT   = '.log/om_bar_proj.log';
             
#-- define the version number for the Package
my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/Footprint.pm,v 1.20 2012/08/24 17:58:34 quinn Exp $';
if ( $HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
{
 my $path    = $1;
 my $version = $2;
 $version =~ s{\.}{}g;
 my @t = split /\//, $path;
 my ( $major ) = $t[2] =~ m{6\.?(\d+)};
 $VERSION = "6." . $major . $version;
}

#------------------------------------------------------------------
sub GenerateBuildAudit
{
 my ( $BillofMat, $BillofMatRpt, $TargetFile ) = @_;

 #-- JAG 04/24/03 - have pulled functionality into this module.
 #                  Don't need to spawn additional process
 my $StepDescription = "Generating Build Audit Report for $TargetFile";
 my $BillofMat_Short;
 my @CompilerOut;
 my $Sleep_Time = 30;
 my $Max_Sleep  = 10;

 #-- generate Text billofmat
 my $BillofMatRptTxt;
 my $bom_is_txt = 0;
 if ( $BillofMatRpt =~ m{\.(txt|log)$} )
 {
  $BillofMatRptTxt = $BillofMatRpt;
  $bom_is_txt      = 1;
 }
 else
 {
  ( $BillofMatRptTxt = $BillofMatRpt ) =~ s{(\.[^\.]*)\s*$}{};
  $BillofMatRptTxt .= ".txt";
 }

 if ( $^O =~ m{MSWin|os2|dos}i )
 {
  $BillofMat_Short = Win32::GetShortPathName( $BillofMat );
 }
 else
 {
  $BillofMat_Short = $BillofMat;
 }

 my $Compiler = "";

 #-- errors returned by old ombom.pl are
 #   1 = wrong args
 #   2 = can't open data file
 #   3 = can't open bom.txt file
 # try to open $DataFile
 my ( $RC, @TagList ) = _formatFP( $BillofMat_Short );
 push @CompilerOut, $TagList[0] if ( $RC );

 #-- saved "stored_ref"
 my ( $bomhtml, $bomtxt );
 ( $bomhtml, $bomtxt, $Openmake::Footprint::stored_ref ) = FormatBillofMat( $TargetFile, @TagList );

 my ($rfh, $tfh); #-- file handles for BAR, and text BAR
 #-- write out HTML and text
 my $skiplen = 0;
 my $bom_exists = 0;
 if ( -e $BillofMatRpt )
 {
  $bom_exists = 1;
   unless ( open( $rfh, "+<$BillofMatRpt" ) )
   {    # failure,
    push @CompilerOut, "Could not open output file: $BillofMatRpt.\n";    # print error message.
    $RC = 3;                                                              # exit with code 3.
   }

 } #-- End: if ( -e $BillofMatRpt ...
 else
 {
  # try to create $ReportFile
  unless ( open( $rfh, '>>', $BillofMatRpt ) )
  {    # failure,
   push @CompilerOut, "Could not open output file: $BillofMatRpt.\n";    # print error message.
   $RC = 3;                                                              # exit with code 3.
  }

  #-- om unlinks the BOM, but we need ot delete the text version
  unlink $BillofMatRptTxt if ( $BillofMatRptTxt && -e $BillofMatRptTxt );
 } #-- End: else[ if ( -e $BillofMatRpt ...

 if ( $RC == 0 )
 {
  #-- wait until we get the lock on the file
  my $sleep = 0;
  while ( ! flock( $rfh, LOCK_EX | LOCK_NB ) )
  {
   sleep $Sleep_Time;
   $sleep++;
   if ( $sleep == $Max_Sleep )
   {
    close $rfh;
    $RC = 4;
   }
  }
 }

 #-- now have lock, seek end of both files
 if ( $RC == 0 ) 
 {
  if ( $bom_is_txt)
  {
   $tfh = $rfh;
  }
  else
  {
   seek( $rfh, 0, 2);
   if ( $bom_exists )
   {
    seek( $rfh, length( "</BODY></HTML>" ) * ( -1 ), 2 );
    $skiplen = length( '<html><HEAD><STYLE type="text/css">td {white-space: nowrap;}</STYLE></HEAD><body>' ) + 1;
   }
   
   print $rfh substr( $bomhtml, $skiplen ); # unless ( $bom_is_txt );
   omlogger( "BOM", "", "", "", "", $bomhtml, "", 0, "" );
  }
  
  #-- write out txt
  if ( $BillofMatRptTxt )
  {
   unless ( $tfh )
   {   
    open( $tfh, '>>', $BillofMatRptTxt );
   }
   seek( $tfh, 0, 2);
   print $tfh $bomtxt;
   close $tfh;
  }
  
  #-- close locks
  flock( $rfh, LOCK_UN);
  close $rfh;
 } #-- End: if ( $RC == 0 )

 #-- TODO use hash format
# SBT 02.11.08 - Fixed for CA Harvest
 omlogger( "Final", $StepDescription, "ERROR:", "ERROR: $StepDescription failed!", "", "", "", $RC, @CompilerOut ), ExitScript( $RC, @main::DeleteFileList ) if ( $RC != 0 );
 omlogger( "Intermediate", $StepDescription, "ERROR:", "$StepDescription succeeded.", "", "", "", $RC, @CompilerOut );
 return;
} #-- End: sub GenerateBuildAudit

#------------------------------------------------------------------
sub GenerateFP
{
 my @input = @_;
 my $input_ref;
 my ( $FootPrint, $TargetFile, $FPSource, $FPObject, $CompilerFound, $FPCompilerArguments, $FPType );

 if ( ref( $input[0] ) eq 'HASH' )
 {
  $input_ref           = $input[0];
  $FootPrint           = $input_ref->{'FootPrint'};
  $TargetFile          = $input_ref->{'TargetFile'};
  $FPSource            = $input_ref->{'FPSource'};
  $FPObject            = $input_ref->{'FPObject'};
  $FPType              = $input_ref->{'FPType'};
  $CompilerFound       = $input_ref->{'Compiler'};
  $FPCompilerArguments = $input_ref->{'CompilerArguments'};
 } #-- End: if ( ref( $input[0] ) ...
 else
 {

  #-- this is the old-style format
  ( $FootPrint, $TargetFile, $FPSource, $FPObject, $CompilerFound, $FPCompilerArguments, $FPType ) = @_;
 }
 $FPType ||= 'C';    #-- Possible types will be 'C', 'Java', 'VB.NET', 'C#.NET' ,etc

 #--
 my $StepDescription = "Creating Footprinting Source File for $TargetFile";    #sab added 'my'

 my @pieces = split( /[\\\/]/, $TargetFile );
 my $FETargetFile = pop( @pieces );
 my $FTargetFile;

 #-- fix for .noext
 if ( $FETargetFile =~ /\./ )
 {
  @pieces = split( /\./, $FETargetFile );
  pop( @pieces );
  $FTargetFile = join( "_", @pieces );
 }
 else
 {
  $FTargetFile = $FETargetFile;
 }

 my $FootPrint_Short;
 ( $^O =~ m{MSWin|os2|dos}i )
   ? $FootPrint_Short =
   Win32::GetShortPathName( $FootPrint )
   : $FootPrint_Short = $FootPrint;

 #-- JAG - replace with inline Openmake.pm module below

 #-- errors returned by old omgenfp.pl are
 #   1 = wrong args
 #   2 = can't open data file
 #   3 = can't open output file
 # try to open $DataFile
 # try to open $DataFile
 my ( $Compiler, @CompilerOut );

 my ( $RC, @TagList ) = _formatFP( $FootPrint_Short );
 push @CompilerOut, $TagList[0] if ( $RC );

 # try to create $TagFile
 unless ( open( TAG, '>', $FPSource ) )
 {    # failure,
  push @CompilerOut, "Could not create file: $FPSource.\n";    # print error message.
  $RC = 3;                                                     # exit with code 3.
 }

 if ( $RC == 0 )
 {
  my @TagList = _formatDeps( @TagList );
  my $fptxt   = FormatFootPrint( $FTargetFile, $FPType, \@TagList );
  
  #-- TODO - add in post-processing like we do in the BAR
  print TAG $fptxt;
  close TAG;
 }

 # TODO - rework with Arg format
 # fixed typo below
# SBT 02.11.08 - Fixed for CA Harvest
 omlogger( "Final", $StepDescription, "ERROR:", "ERROR: $StepDescription failed!", $Compiler, "", "", $RC, @CompilerOut ), ExitScript( "1", @main::DeleteFileList ) if ( $RC != 0 );
 omlogger( "Intermediate", $StepDescription, "ERROR:", "$StepDescription succeeded.", $Compiler, "", "", $RC, @CompilerOut );

 $StepDescription = "Creating Footprinting Object for $TargetFile";
 $CompilerFound   = 'cc' unless $CompilerFound;                       #sab modified to allow gcc footprint

 unless ( $CompilerFound eq 'no compile' )
 {
  my @AvailableCompilers = ();
  my ( $Compiler, $junk ) = Openmake::GetCompiler( "", "", $CompilerFound, @AvailableCompilers );
  @CompilerOut = `$Compiler $FPCompilerArguments`;
  $RC          = $?;

  # TODO - rework with Arg format
# SBT 02.11.08 - Fixed for CA Harvest
  omlogger( "Final", $StepDescription, "ERROR:", "ERROR: $StepDescription failed!", $Compiler, $FPCompilerArguments, "", $RC, @CompilerOut ), ExitScript( "1", @main::DeleteFileList ) if ( $RC != 0 );
  omlogger( "Intermediate", $StepDescription, "ERROR:", "$StepDescription succeeded.", $Compiler, $FPCompilerArguments, "", $RC, @CompilerOut );
 } #-- End: unless ( $CompilerFound eq...

 push( @main::DeleteFileList, $FPSource ) unless ( $::KeepScript eq 'YES' );
 push( @main::DeleteFileList, $FPObject );

 return;
} #-- End: sub GenerateFP

#------------------------------------------------------------------
sub FormatBillofMat
{
 #-- import filelines from .fp report
 my $ExeName = shift;
 my @TagList = @_;
 my $DimStr;

 #-- returns a string
 my $billofmattxt;
 my $billofmathtml;

 #-- Last implementation of Project and Env Variables
 my ( @last_proj_html, @last_proj_txt, @last_env_html, @last_env_txt );
 my ( $last_proj_html, $last_proj_txt, $last_env_html, $last_env_txt );
 my ( $last_exe_name );
 my ( $proj_html, $proj_txt, $env_html, $env_txt);

 #-- print out header
 $billofmathtml .= "<html><HEAD><STYLE type=\"text/css\">td {white-space: nowrap;}</STYLE></HEAD><body>\n";
 $billofmathtml .= "<p><TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=\"100%\">\n";
 $billofmathtml .= "<TR><TD><H1><hr align=left noshade size=3 width=100%><TT>Build Audit Report for $ExeName</TT></H1></TD></TR>\n";

 $billofmattxt .= "\n". "-"x40 . "\nBuild Audit Report for $ExeName\n\n";

 # Grep for the lines containing the individual headings:
 # Lines beginning with 4: declare project variables

 #-- JAG 12.11.06 - Sections 4 and 5 should be stored only if different 
 #    from previous target. Saves space
 #-- need to read from disk
 my $fh;
 if ( open ( $fh, '<', $BAR_ENV_REPORT ) )
 {
  my $l = <$fh>;
  chomp $l;
  ( $last_exe_name ) = ( $l =~ m{LastExe: (\S+)$} );
  
  #-- get the txt vs HTML
  my @l = <$fh>;
  close $fh;
  while ( my $l = shift @l )
  {
   last if ( $l eq "HTML\n");
   push @last_env_txt, $l;
  }  
  @last_env_html = @l;  
  $last_env_html = join "\n", @last_env_html;
  $last_env_txt  = join "\n", @last_env_txt;
 }
 if ( open ( $fh, '<', $BAR_PROJ_REPORT ) )
 {
  #-- get the txt vs HTML
  my @l = <$fh>;
  close $fh;
  while ( my $l = shift @l )
  {
   last if ( $l eq "HTML\n");
   push @last_proj_txt, $l;
  }  
  @last_proj_html = @l;  
  $last_proj_html = join "\n", @last_proj_html;
  $last_proj_txt  = join "\n", @last_proj_txt;
 }
 
 #-- refactor Project and Env variables to subroutine.
 ($proj_html, $proj_txt ) = _formatProj( \@TagList); #-- use reference, it's faster
 ($env_html,  $env_txt )  = _formatEnv(  \@TagList); #-- use reference, it's faster
 
 if ( ! -e $::BillOfMaterialRpt )
 {
  unlink $BAR_ENV_REPORT;
  unlink $BAR_PROJ_REPORT;
  
  @last_proj_html = split /\n/, $proj_html;
  @last_proj_txt  = split /\n/, $proj_txt;
  @last_env_html  = split /\n/, $env_html;
  @last_env_txt   = split /\n/, $env_txt;
  
  $last_proj_txt  = $proj_txt;
  $last_env_txt   = $env_txt;
  $last_exe_name  = $ExeName;
  
  $billofmathtml .= $proj_html;
  $billofmathtml .= $env_html;
  $billofmattxt  .= $proj_txt;
  $billofmattxt  .= $env_txt;
  
  #-- save to disk for next BAR report
  open ( $fh, '>', $BAR_ENV_REPORT );
  print $fh "LastExe: $ExeName\n";
  print $fh $env_txt;
  print $fh "HTML\n";
  print $fh $env_html;
  close $fh;
  open ( $fh, '>', $BAR_PROJ_REPORT );
  print $fh $proj_txt;
  print $fh "HTML\n";
  print $fh $proj_html;
  close $fh;
 }
 
 #-- the text will rarely be the same, due to the timing issue of when
 #   the build was run. Print the differences
 if ( $proj_txt ne $last_proj_txt )
 {
  my @proj_html = split /\n/, $proj_html;
  my @proj_txt  = split /\n/, $proj_txt;
  
  $billofmathtml .= "\n<TR ALIGN=\"left\" VALIGN=\"middle\"><TH><TT>Difference in Project Variables from '$last_exe_name':</TT></TH></TR>";    # print out header
  $billofmattxt  .= "\nDifference in Project Variables from '$last_exe_name':\n";
  
  foreach my $i ( 0 .. $#last_proj_txt )
  {
   chomp $last_proj_html[$i];
   chomp $last_proj_txt[$i];
   if ( $last_proj_html[$i] ne $proj_html[$i] )
   {
    $billofmathtml .= $proj_html[$i] . "\n";
   } 
   if ( $last_proj_txt[$i] ne $proj_txt[$i] )
   {
    $billofmattxt  .= $proj_txt[$i] . "\n";
   }  
  }  
 }
 if ( $env_txt ne $last_env_txt )
 {
  $billofmathtml .= "\n<TR ALIGN=\"left\" VALIGN=\"middle\"><TH><TT>Difference in Environment Variables from '$last_exe_name':</TT></TH></TR>";    # print out header
  $billofmattxt  .= "\nDifference in Environment Variables from '$last_exe_name':\n";

  my @env_html = split /\n/, $env_html;
  my @env_txt  = split /\n/, $env_txt;
  foreach my $i ( 0 .. $#last_env_txt )
  {
   chomp $last_env_html[$i];
   chomp $last_env_txt[$i];
   if ( $last_env_html[$i] ne $env_html[$i] )
   {
    $billofmathtml .= $env_html[$i] . "\n";
   } 
   if ( $last_env_txt[$i] ne $env_txt[$i] )
   {
    $billofmattxt  .= $env_txt[$i] . "\n";
   }  
  }  
 }
 elsif ( $ExeName ne $last_exe_name )
 {
  $billofmathtml .= "<TR><TD><H1><hr align=left noshade size=3 width=100%><TT>Project and Environment Variables the same as for $last_exe_name</TT></H1></TD></TR>\n";
  $billofmattxt  .= "Project and Environment Variables the same as for $last_exe_name\n";
 }

 # Lines beginning with 6: declare dependencies
 # -- JAG - this is modified as of 6.2
 #    First 6: line should be
 #    6:VERSIONINFOHEADER:<header information>
 #    Remaining lines as is.
 my @DepList  = grep( /^6:/, @TagList );    # Get them
 my @DepLines = _formatDeps( @DepList );
 
 #-- need to bold the header if necessary
 s{^\s*6:}{} foreach ( @DepLines );

 $billofmathtml .= "\n<TR ALIGN=\"left\" VALIGN=\"middle\"><TH><TT>Dependencies:</TT></TH></TR>\n";    # print out general header
 $billofmattxt  .= "\nDependencies:\n";

 #-- close out the table to start another one
 $billofmathtml .= "</TABLE></p>\n<p><TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=\"100%\">\n";

 my $header = 0;
 my @catagories;
 foreach my $line_array ( @DepLines )
 {
  if ( $line_array =~ s{VERSIONINFOHEADER:}{} )
  {
   $header = 1;
  }
  
  my @items = split ';', $line_array;

  #-- text (first b/c we don't do regexp on it)
  my $i = 0;
  $billofmathtml .= '<TR>';
  my %dep_hash;
  
  foreach my $item ( @items )
  {
   $billofmattxt .= $item;    # sprintf( " %-*.*s", $n, $n, $item);

   $item =~ s{\s+$}{};
   $item =~ s{ }{&nbsp;}g;
   if ( $header )
   {
    $billofmathtml .= "<TD><TT><B>&nbsp;$item</B></TT></TD>";
    
    #-- get the array of header titles;
    $item =~ s{&nbsp;}{ }g;
    push @catagories, $item;
   }
   else
   {
    $billofmathtml .= "<TD><TT>&nbsp;$item</TT></TD>";

    #-- add to stored hash. Needs to be stored by filename if the order changes
#    $item =~ s{&nbsp;}{ }g;
#    if ( $catagories[$i] eq 'Target Dependencies' )
#    {
#     $item =~ s{\\}{/}g;
#    }
#     
#    $dep_hash{$catagories[$i]} = $item;
   }
   $i++;
  } #-- End: foreach my $item ( @items )
#  $stored{'Dependencies'}->{$dep_hash{'Target Dependencies'}} = \%dep_hash;
  $billofmattxt  .= "\n";
  $header = 0 if ( $header );
  $billofmathtml .= "</TR>\n";

 } #-- End: foreach my $line_array ( @DepLines...

 #-- add in post-processing
# my $store_file = _store_Build_Audit( $::BillofMat, \%stored);
# my $last_ref   = _get_last_Build_Audit( $store_file);
 
 #my ( $extra_html, $extra_txt ) = process_Build_Audit( $last_ref );
 #$billofmathtml .= $extra_html;
 #$billofmattxt  .= $extra_txt; 

 #-- return
 $billofmathtml .= "</TABLE></p>\n</body></html>";

 return ( $billofmathtml, $billofmattxt  );
} #-- End: sub FormatBillofMat

#------------------------------------------------------------------
sub BOMGetDateTime
{
 my ( $t ) = @_;
 my ( $sec, $min, $hour, $dofm, $mon, $year, $dofw, $dofy, $daylight ) = localtime( $t );
 $mon++;
 $year += 1900;
 return sprintf( "%2.2d/%2.2d/%4.4d %2.2d:%2.2d:%2.2d", $mon, $dofm, $year, $hour, $min, $sec );
}

#------------------------------------------------------------------
sub JDGetDateTime
{
 my ( $sec, $min, $hour, $dofm, $mon, $year, $dofw, $dofy, $daylight ) = localtime();
 $mon++;
 $year += 1900;
 return sprintf( "%4.4d-%2.2d-%2.2d %2.2d_%2.2d_%2.2d", $year, $mon, $dofm, $hour, $min, $sec );
}

#------------------------------------------------------------------
sub FormatFootPrint
{
 my ( $TargetBin, $FPType, $TagListRef ) = @_;

 #-- dispatch table based on type of footprint to provide. More
 #   coming (VB.NET, CS.NET, VC.NET)
 my $fp_txt;
 if ( exists $FOOTPRINT_TYPE{$FPType} )
 {
  $fp_txt = $FOOTPRINT_TYPE{$FPType}->($TargetBin, $TagListRef);
 }
 return $fp_txt;
} #-- End: sub FormatFootPrint

#------------------------------------------------------------------
sub _format_C_FP
{
 my ( $TargetBin, $TagListRef ) = @_;
 my @TagList = @{$TagListRef};

 my $ic = 0;    # initialize the counter
 my $fptxt;

 foreach my $liner ( @TagList )    # process TagFile info
 {
  $liner =~ s{[\t\n]}{}g;          # get rid of tabs
  $liner =~ s{^ +}{};              # get rid of leading blanks

  next if ( $liner =~ m{^\s+$} );  # if what is left is blank, skip this line.

  $liner =~ s{\\}{\\\\}g;          # escape \ characters
  $liner =~ s{"}{\\"}g;            # escape quotes

  #-- JAG - 04.06.05 - case 5711 -- if there's a trailing ":', split /:/, $liner doesn't
  #   work (eg 5:HOMEDRIVE=C:). Need -1 to specific trailing null elements
  my @words   = split( /:/, $liner, -1 );    # the word to the left of the colon is a single number
  my $VarType = shift( @words );             # get the letter
  my $line    = join( ":", @words );         # reassemble line

  # assemble c-code line the end of line character is :$.
  $fptxt .= "static char BOM" . $ic . "\[\] = \"\$OMBOM$VarType:" . $line . ":\$\";\n";
  $ic++;                                     # increment counter
 } #-- End: foreach my $liner ( @TagList...

 # if no lines were processed, $ic = 0, print warning and exit with code 0.
 return if ( $ic == 0 );

 # assemble c-code line that depends on the declarations above.
 my $outline = "char *BillofMat[] = \{ \n";    # create intial segement
 for ( my $i = 0 ; $i < $ic ; $i++ )           # loop over the line objects created above:
 {
  $outline .= "\t\t\t\tBOM" . $i . ",\n";      # append declaration
 }    # get next object.
 $outline .= "\t\t\t\t0\};";    # put out default object
 $fptxt   .= "$outline\n";      # print assembled line to $TagFile

 $TargetBin =~ s{[\\/]}{_}g;
 $TargetBin =~ s{\s}{_}g;

 $fptxt .= "char **ombom_$TargetBin()\n";
 $fptxt .= "{\n";
 $fptxt .= " return BillofMat;\n";
 $fptxt .= "}\n";
 return $fptxt;
} #-- End: sub _format_C_FP

#------------------------------------------------------------------
sub _format_Java_FP
{
 my ( $TargetBin, $TagListRef ) = @_;
 my @TagList = @{$TagListRef};

 my $fptxt;

 foreach my $liner ( @TagList )    # process TagFile info
 {
  $liner =~ s{[\t\n]}{}g;
  $liner =~ s{^ +}{};              # get rid of leading blanks
  next if ( $liner =~ m{^\s+$} );  # if what is left is blank, skip this line.

  #-- JAG - 04.06.05 - case 5711 -- if there's a trailing ":', split /:/, $liner doesn't
  #   work (eg 5:HOMEDRIVE=C:). Need -1 to specific trailing null elements
  my @words   = split( /:/, $liner, -1 );    # the word to the left of the colon is a single number
  my $VarType = shift( @words );             # get the letter
  my $line    = join( ":", @words );         # reassemble line

  $fptxt .= '$OMBOM' . $VarType . ':' . $line . ":\$\n";
 } #-- End: foreach my $liner ( @TagList...

 return $fptxt;
} #-- End: sub _format_Java_FP

#------------------------------------------------------------------
sub _format_CSNET_FP
{
 my ( $TargetBin, $TagListRef ) = @_;
 my @TagList = @{$TagListRef};

 #-- write dummy class
 my $fptxt;

 $fptxt = "using System;\n\nnamespace OpenmakeBuildAudit\n";
 $fptxt .= "{\n    internal abstract class BUILDAUDIT\n";
 $fptxt .= "    {\n        internal BUILDAUDIT()\n";
 $fptxt .= "        {\n";

 foreach my $liner ( @TagList )    # process TagFile info
 {
  $liner =~ s{[\t\n]}{}g;
  $liner =~ s{^ +}{};              # get rid of leading blanks
  next if ( $liner =~ m{^\s+$} );  # if what is left is blank, skip this line.

  #-- JAG - 04.06.05 - case 5711 -- if there's a trailing ":', split /:/, $liner doesn't
  #   work (eg 5:HOMEDRIVE=C:). Need -1 to specific trailing null elements
  my @words   = split( /:/, $liner, -1 );    # the word to the left of the colon is a single number
  my $VarType = shift( @words );             # get the letter
  my $line    = join( ":", @words );         # reassemble line
  $line =~ s{\\}{\\\\}g;
  $line =~ s{"}{\"}g;

  $fptxt .= '            Console.WriteLine("$OMBOM' . $VarType . ':' . $line . ':$");' . "\n";
 } #-- End: foreach my $liner ( @TagList...

 $fptxt .= "        }\n    }\n}\n";
 return $fptxt;
} #-- End: sub _format_CSNET_FP

#------------------------------------------------------------------
sub _format_VBNET_FP
{
 my ( $TargetBin, $TagListRef ) = @_;
 my @TagList = @{$TagListRef};

 #-- write dummy module
 my $fptxt;

 $fptxt = "Module OpenmakeBuildAudit\n";
 $fptxt .= "    Private Function OpenmakeBuildAudit() As Int32\n";

 foreach my $liner ( @TagList )    # process TagFile info
 {
  $liner =~ s{[\t\n]}{}g;
  $liner =~ s{^ +}{};              # get rid of leading blanks
  next if ( $liner =~ m{^\s+$} );  # if what is left is blank, skip this line.

  #-- JAG - 04.06.05 - case 5711 -- if there's a trailing ":', split /:/, $liner doesn't
  #   work (eg 5:HOMEDRIVE=C:). Need -1 to specific trailing null elements
  my @words   = split( /:/, $liner, -1 );    # the word to the left of the colon is a single number
  my $VarType = shift( @words );             # get the letter
  my $line    = join( ":", @words );         # reassemble line

  $fptxt .= '        Console.WriteLine("$OMBOM' . $VarType . ':' . $line . ':$")' . "\n";
 } #-- End: foreach my $liner ( @TagList...

 $fptxt .= "        Return 1\n    End Function\nEnd Module\n";
 return $fptxt;
} #-- End: sub _format_VBNET_FP

#------------------------------------------------------------------
sub _format_VB56_FP
{
 my ( $TargetBin, $TagListRef ) = @_;
 my @TagList = @{$TagListRef};

 #-- write dummy class
 my $fptxt;
 $fptxt = "Attribute VB_Name = \"OpenmakeBuildAudit\"\nPrivate Function OpenmakeBuildAudit()\n";

 my $i = 1;
 foreach my $liner ( @TagList )    # process TagFile info
 {
  $liner =~ s{[\t\n]}{}g;
  $liner =~ s{^ +}{};              # get rid of leading blanks
  next if ( $liner =~ m{^\s+$} );  # if what is left is blank, skip this line.

  #-- JAG - 04.06.05 - case 5711 -- if there's a trailing ":', split /:/, $liner doesn't
  #   work (eg 5:HOMEDRIVE=C:). Need -1 to specific trailing null elements
  my @words   = split( /:/, $liner, -1 );    # the word to the left of the colon is a single number
  my $VarType = shift( @words );             # get the letter
  my $line    = join( ":", @words );         # reassemble line

  my $bomline = '$OMBOM' . $VarType . ':' . $line . ':$';
  if ( length $bomline > 950 )
  {

   #-- need to create an array to write out
   my @bomlines;
   while ( length $bomline > 950 )
   {
    my $subline = substr( $bomline, 0, 950, '' );
    push @bomlines, $subline;
   }
   foreach my $bline ( @bomlines, $bomline )    #-- get teh last bit too
   {
    $fptxt .= "    Split \"$bline\" \n";
   }
  } #-- End: if ( length $bomline >...
  else
  {
   $fptxt .= '    Split "' . $bomline . "\"\n";
  }
 } #-- End: foreach my $liner ( @TagList...

 $fptxt .= "End Function\n";
 return $fptxt;
} #-- End: sub _format_VB56_FP

#------------------------------------------------------------------
#  Formats .fp file to find missing items, etc. and modifies
#  in place to allow for future pushing to the KB Server
sub _formatFP
{
 my $BillofMat_Short = shift;
 my $RC = 0;
 my @tag_list             = ();
 my @new_list             = ();
 my $n_seps_versionheader = -1;
 my @orig_column_widths   = ();

 
 if ($main::DelayHsigget == 1)
 {
  use DBI;
  use DBD::SQLite;
  
  if ($ENV{USERNAME} ne "")
  {
   
   $dbfile = cwd() . "\\hsig.db";
   $dbfile =~ s/://g;
   $dbfile =~ s/\//\\/g;
   $dbfile =  $ENV{TMP} . "\\openmake\\" . $ENV{USERNAME} .  "\\" . $dbfile;
  }
  else
  { 
   $dbfile = $ENV{TMP} . "/openmake/" . $ENV{USER} . "/" . cwd() . "/hsig.db";
  }
 
  my $database = Openmake::File->new($dbfile);
  $database->mkdir();
  
  $dbh = DBI->connect("DBI:SQLite:dbname=$dbfile") or die;
 
  $dbh->do('CREATE TABLE IF NOT EXISTS Stats ( FileName character PRIMARY KEY, mtime integer, filesize integer, verinfo character)');
  $dbh->do('CREATE TABLE IF NOT EXISTS Dirs  ( DirName character PRIMARY KEY)');
 }

 #-- cache this information so that we don't do this twice if we do build audit
 #   and footprinting in the same build
 if ( @Openmake::Footprint::BillOfMatLines and 
      scalar  @Openmake::Footprint::BillOfMatLines > 0)
 {
  if ($main::DelayHsigget == 1)
  {
   $dbh->disconnect;
  }
  return ( $RC, @Openmake::Footprint::BillOfMatLines);
 }

 if ( open( DAT, '<', $BillofMat_Short ) )
 {
  @tag_list = <DAT>;    # read lines into @$TagList,
  close( DAT );         # close file.
 }
 else
 {
  @tag_list = ( "Could not open input file: $BillofMat_Short.\n" );    # print error message,
  $RC       = 2;                                                       # exit with code 2.
  if ($main::DelayHsigget == 1)
  {
   $dbh->disconnect;
  }
  return ( $RC, @tag_list );
 }

 #-- parse the tag_list,
 my $in_sec5 = 0;
 foreach my $tag ( @tag_list )
 {
  if ( $tag =~ m{^\s*[1-4]} )
  {
   push @new_list, $tag;
   next;
  }

  #-- if we are in the first 5 section, add computer info and .NET info
  if ( $tag =~ m{^\s*5:} )
  {
   push @new_list, $tag;
   next if ( $in_sec5 );
   $in_sec5++;

   my @sysout = systeminfo(); #-- windows or unix;
   push @new_list, "4:$BEGIN_SYSTEM_INFO\n";
   foreach my $liner ( @sysout )
   {
    $liner =~ s{[\t\n]}{}g;
    push @new_list, '4:' . $liner . "\n";
   }

   #-- add .NET ?
   my @dnet = getNetFx();
   #next unless ( @dnet ); #-- JAG - if there's no .NET, things go bad because
   # we don't end the 4: section or set $in_sec5
   foreach my $liner ( @dnet )
   {
    push @new_list, '4:' . $liner . "\n";
   }
   push @new_list, "4:$END_SYSTEM_INFO\n";
   $in_sec5++;
  } #-- End: if ( $tag =~ m{^\s*5:}...

  #-- if we are in the 6 section, look for 0 byte files
  if ( $tag =~ m{^\s*6:} )
  {
   if ( $tag =~ m{VERSIONINFOHEADER} )
   {
    $n_seps_versionheader = ( $tag =~ tr{;}{;} + 0 );
    #-- if this is an "old style" preformatted case, replace with ;
    if ( $n_seps_versionheader == 0 )
    {
     #-- JAG 05.10.06 - rework the splitting -- here use versioninfoheader to determine
     #                  widths of each column
     #-- JAG 07.24.06 - \b is too restrictive. (matches between \w\W). Need look-ahead assertion
     #my @orig_columns = split /\s{2}\b/, $tag, -1;
# SBT 02.11.08 - Fixed for CA Harvest
	 $tag =~ s/6:VERSIONINFOHEADER://g;
	 $tag =~ s/^\s//g;
	 
     my @orig_columns = split /\s{2}(?=\S)/, $tag, -1;
     @orig_column_widths = map { length($_) + 2 } @orig_columns;
	 
	 if (scalar @orig_column_widths > 0)
	 {
     $orig_column_widths[-1] -= 2; #-- last element didn't need 2 added to it.
     }
     #-- remove VERSIONINFOHEADER;
     if ( $orig_columns[0] =~ s{^\s*6:VERSIONINFOHEADER:}{} )
     {
      $orig_column_widths[0] = length($orig_columns[0]) + 2;
     }
     
     $tag =~ s{\s{2,}}{;}g;
     $tag =~ s{;$}{}; #-- replace trailing ';'
     $n_seps_versionheader = ( $tag =~ tr{;}{;} + 0 );
    }

    push @new_list, $tag;
    next;
   }

   chomp $tag;
   $tag =~ s{^\s*6:\s*}{};
   my @elements = split ';', $tag;
   next unless ( ( scalar @elements ) > 2 );
   my ( $date, $size, $file ) = ( $elements[-3], $elements[-2], $elements[-1] );   

   #-- if file has | in it
   if ( $file =~ m{(.+?)\|} )
   {
    $file = $1;
   }

   
   if ($main::DelayHsigget == 1)
   {
    # $verinfo;$mtime;$fsize
    ($elements[0],$elements[1],$elements[2],$elements[3],$elements[4],$elements[5]) = hsigget($file);
   }
   
   ( $date, $size, $file ) = ( $elements[-3], $elements[-2], $elements[-1] );   
   
   #-- add it up, see if we modify this guy
   if ( $date + $size == 0 )
   {
    #-- find on the file system
    if ( -f $file )
    {
     my @stat = stat( $file );
     if ( ref( $stat[0] ) )
     {
      #-- object version
      $date = $stat[0]->mtime;
      $size = $stat[0]->size;
     }
     else
     {
      $date = $stat[9];
      $size = $stat[7];
     }

     #-- create the absolute path.
     if ( $^O =~ m{MSWin|dos}i )
     {
      unless ( $file =~ m{^\w{1}:\\} or $file =~ m{^\\\\} )
      {
       my $tfile = cwd() . "/" . $file;
       if ( -f $tfile ) { ( $file = $tfile ) =~ s{/}{\\}g; }
      }
     }
     else
     {
      unless ( $file =~ m{^/} )
      {
       my $tfile = cwd() . "/" . $file;
       $file = $tfile if ( -f $tfile );
      }
     }
    } #-- End: if ( -f $file )
    else
    {
     #-- skip non-found file
     next;
    }
   } #-- End: if ( $date + $size == ...

   my ( @vinfo ) = @elements[0 .. scalar(@elements)-4];

   my $svinfo = scalar @vinfo;
   if ( $svinfo <= $n_seps_versionheader  || $n_seps_versionheader == 0 )
   {
    my $t = join ";", @vinfo;

    @vinfo = (); #reset
    #-- JAG 05.10.06 - use original column widths to determine how to split up
    #   fixed version string info
# SBT 02.11.08 - Fixed for CA Harvest
    if (scalar @orig_column_widths > 0)
	{
    my @t_col = @orig_column_widths;
    while ( $t && @t_col )
    {
     my $w = shift @t_col;
     my $s = substr( $t, 0, $w, '');
     $s =~ s{^\s+}{};
     $s =~ s{\s+$}{};
     push @vinfo, $s;
    }
    #-- add extra elements if necessary
    foreach my $t ( @t_col )
    {
     push @vinfo, ''; #-- push an empty element if the columns had something but no data returned
    }
    
    #-- splice into elements
    splice @elements, 0, $svinfo, @vinfo;
   }
   }

   #-- item has a size
   if ( $n_seps_versionheader >= 0 )
   {
 # SBT 02.11.08 - Fixed for CA Harvest
    if ( $elements[0] =~ m{^\s*$} )
    {
	 my $line = "";
	 
     $line = ($n_seps_versionheader == 0) ? ' ;' x 3 : ' ;' x $n_seps_versionheader;
     push @new_list, '6:' . " $line;$date;$size;$file\n";
    }
    else
    {
     my $line = "";
	 
	 if ($n_seps_versionheader == 0)
	 {
	  $line = join ';', @elements;
	  push @new_list,  '6:' . "$line\n";
	 }
	 else
	 {
  	  $line = join ';', @elements[ 0 .. $n_seps_versionheader ];
     push @new_list,  '6:' . "$line;$date;$size;$file\n";
    }

    }
   } #-- End: if ( $n_seps_versionheader...
   else
   {
    push @new_list, '6: ; ; ; ;' . "$date;$size;$file\n";
   }

   #-- see if this file is a composite
#   my @files = Openmake::getSubTaskFiles( $file );
#   if ( @files )
#   {
#    foreach my $subfile ( @files )
#    {
#     my ( $date, $size );
#     my @stat = stat( $subfile );
#     if ( ref( $stat[0] ) )
#     {
#      #-- object version
#      $date = $stat[0]->mtime;
#      $size = $stat[0]->size;
#     }
#     else
#     {
#      $date = $stat[9];
#      $size = $stat[7];
#     }
#
#     #-- see if we have a full path
#     if ( $^O =~ m{MSWin|dos}i )
#     {
#      $subfile =~ s{/}{\\}g;
#      unless ( $subfile =~ m{^\w{1}:\\} or $subfile =~ m{^\\\\} )
#      {
#       my $tfile = cwd() . "/" . $subfile;
#       $subfile = $tfile if ( -f $tfile );
#      }
#     }
#     else
#     {
#      unless ( $subfile =~ m{^/} )
#      {
#       my $tfile = cwd() . "/" . $subfile;
#       $subfile = $tfile if ( -f $tfile );
#      }
#     }
#
#     #-- create an empty array b/c we do not call the version program
#     #   at this point
#     my ( @vinfo ) = @elements[0 .. scalar(@elements)-4];
#     my $svinfo = scalar @vinfo;
#     @vinfo = ();
#     $#vinfo = $svinfo;
#     splice @elements, 0, $svinfo, @vinfo;
##     if ( $svinfo <= $n_seps_versionheader  || $n_seps_versionheader == 0 )
##     {
##      my $t = join ";", @vinfo;
##  
##      @vinfo = (); #reset
##      #-- JAG 05.10.06 - use original column widths to determine how to split up
##      #   fixed version string info
##      my @t_col = @orig_column_widths;
##      while ( $t && @t_col )
##      {
##       my $w = shift @t_col;
##       my $s = substr( $t, 0, $w, '');
##       $s =~ s{^\s+}{};
##       $s =~ s{\s+$}{};
##       push @vinfo, $s;
##      }
##      
##      #-- splice into elements
##      splice @elements, 0, $svinfo, @vinfo;
##     }
#
#     if ( $n_seps_versionheader >= 0 )
#     {
#      if ( $elements[0] =~ m{^\s+$} )
#      {
#       my $line = ' ;' x $n_seps_versionheader;
#       push @new_list, '6:' . " $line;$date;$size;$subfile\n";
#      }
#      else
#      {
#       my $line = join ';', @elements[ 0 .. $n_seps_versionheader ];
#       push @new_list,  '6:' . "$line;$date;$size;$subfile\n";
#      }
#     } #-- End: if ( $n_seps_versionheader...
#     else
#     {
#      push @new_list, '6: ; ; ; ;' . "$date;$size;$subfile\n";
#     }
#
#    } #-- End: foreach my $subfile ( @files...
#   } #-- End: if ( @files )
   
  } #-- End: if ( $tag =~ m{^\s*6:}...
 } #-- End: foreach my $tag ( @tag_list...

 #-- write out new .fp file, for later upload to the KB Server.
 #-- this will be added later
 @Openmake::Footprint::BillOfMatLines = @new_list;
 if ($main::DelayHsigget == 1)
 {
  $dbh->disconnect;
 }
 return ( $RC, @new_list );
} #-- End: sub _formatFP

#------------------------------------------------------------------
sub _formatProj
{
 my $tl = shift;
 my $rl = shift;
 my @TagList = @{$tl};
 #my %stored  = %{$rl};
 my $billofmathtml = '';
 my $billofmattxt  = '';
 
 my @ProjVars = grep( m{^4:}, @TagList );    # Get them
 if ( $ProjVars[0] ne "" )                   # make sure the list is not empty
 {
  $billofmathtml .= "\n<TR ALIGN=\"left\" VALIGN=\"middle\"><TH><TT>Project Variables:</TT></TH></TR>";    # print out header
  $billofmattxt  .= "\nProject Variables:\n";                                                              # print out header

  my $in_sysinfo = 0;
  foreach my $liner ( @ProjVars )                                                                          # loop over the lines found
  {
   $liner =~ s{^4:}{};
   $liner =~ s{[\t\n]}{}g;                                                                                 # get rid of tabs, newlines
   $liner =~ s{\s+$}{};
   $liner =~ s{^\s+}{} unless ( $in_sysinfo );

   if ( $liner =~ m{$END_SYSTEM_INFO} )
   {
    $in_sysinfo = 0;
    next;
   }
   (my $html_liner = $liner ) =~ s{\s}{&nbsp;}g;
   $billofmathtml .= "<TR><TD><TT>&nbsp;&nbsp;&nbsp;&nbsp;$html_liner</TT></TD></TR>\n";
   $billofmattxt  .= "    $liner\n";

   #-- get the system info
   if ( $liner =~ m{$BEGIN_SYSTEM_INFO} )
   {
    $in_sysinfo++;
    next;
   }
   
#   if ( $in_sysinfo )
#   {
#    push @{$stored{'Project Variables'}->{'System Info'}}, $liner;
#   }
#   else
#   {
#    push @{$stored{'Project Variables'}->{'General'}}, $liner;
#   }

  } #-- End: foreach my $liner ( @ProjVars...
 } #-- End: if ( $ProjVars[0] ne ""...
 return ( $billofmathtml, $billofmattxt);
}

#------------------------------------------------------------------
sub _formatEnv
{
 my $tl = shift;
 my $rl = shift;
 my @TagList = @{$tl};
 #my %stored  = %{$rl};
 my $billofmathtml = '';
 my $billofmattxt  = '';

 # Lines beginning with 5: declare environment variables
 my @EnvVars = grep( m{^5:}, @TagList );                                                                   # Get them
 if ( $EnvVars[0] ne "" )                                                                                  # make sure the list is not empty
 {
  $billofmathtml .= "\n<TR ALIGN=\"left\" VALIGN=\"middle\"><TH><TT>Environment Variables:</TT></TH></TR>";    # print out header
  $billofmattxt  .= "\nEnvironment Variables:\n";                                                              # print out header

  foreach my $liner ( @EnvVars )                                                                               # loop over the lines found
  {
   $liner =~ s{^5:}{};
   $liner =~ s{[\t\n]}{}g;                                                                                     # get rid of tabs, newlines
   $liner =~ s{ +$}{};                                                                                         # get rid of trailing blanks
   $liner =~ s{^ +}{};                                                                                         # get rid of leading blanks

   #-- JAG 08.08.03 - causes ENVs to be written before BEGIN: Bill of ...
   #print REP "    $liner\n";
   $billofmathtml .= "<TR><TD><TT>&nbsp;&nbsp;&nbsp;&nbsp;$liner</TT></TD></TR>\n";
   $billofmattxt  .= "    $liner\n";
   
   my @env = split /=/, $liner;
   my $env = shift @env;
   my $val = join "=", @env;
   
#   if( defined $env && defined $val )
#   {
#    $stored{'Environment Variables'}->{$env} = $val;
#   }
  } #-- End: foreach my $liner ( @EnvVars...
 } #-- End: if ( $EnvVars[0] ne ""...
 
 return ( $billofmathtml, $billofmattxt);
}

#------------------------------------------------------------------
sub getNetFx
{
 return unless ( $^O =~ m{MSWin|dos}i );
 eval { require Win32::TieRegistry; } or return;
 import Win32::TieRegistry;

 my $Mach_Key = Win32::TieRegistry->new( "LMachine" ) or die "Can't access HKEY_LOCAL_MACHINE key: $^E\n";
 my %config = (
  '1.1'   => 'Software\Microsoft\NET Framework Setup\NDP\v1.1.4322',
  '2.0b1' => 'Software\Microsoft\NET Framework Setup\NDP\v2.0.40607',
  '2.0b2' => 'Software\Microsoft\NET Framework Setup\NDP\v2.0.50215',
  '2.0'   => 'Software\Microsoft\NET Framework Setup\NDP\v2.0.50727'
 );
 my $installed    = 'Install';
 my $service_pack = 'SP';

 my @out_text;

 #-- loop over possible versions
 foreach my $ver ( '1.0', keys %config )
 {
  my ( $found_ver, $found_sp ) = ( undef, undef );

  if ( $ver eq '1.0' )
  {
   my $key                = 'Software\Microsoft\.NETFramework\Policy\v1.0';
   my $installed          = '3705';
   my $msi_key            = 'Software\Microsoft\Active Setup\Installed Components\{78705f0d-e8db-4b2d-8193-982bdda15ecd}';
   my $ocm_key            = 'Software\Microsoft\Active Setup\Installed Components\{FDC11A6F-17D1-48f9-9EA3-9051954BAA24}';
   my $service_pack_value = 'Version';

   my $net_key = $Mach_Key->Open( $key );
   next unless $net_key;

   next unless ( $net_key->GetValue( $installed ) );

   $found_ver = $ver;

   #-- look up service pack depending on OS. Since we don't have access to the
   #   GetSystemMetrics in User32.dll, look up both keys.
   #-- TabletOS (unlikely )
   my $sp_key = $Mach_Key->Open( $ocm_key );
   $sp_key = $Mach_Key->Open( $msi_key ) unless ( defined $sp_key );

   #-- get the service pack value
   $found_sp = $sp_key->GetValue( $service_pack_value ) if ( defined $sp_key );

   if ( defined $found_sp )
   {

    # This registry value should be of the format #,#,#####,# where the last # is the SP level.
    my @v = split /,/, $found_sp;
    $found_sp = pop @v;
   }
  } #-- End: if ( $ver eq '1.0' )
  else
  {
   my $key = $config{$ver};
   next unless $key;

   my $net_key = $Mach_Key->Open( $key );
   next unless $net_key;

   next unless ( $net_key->GetValue( $installed ) );
   $found_ver = $ver;
   $found_sp  = hex( $net_key->GetValue( $service_pack ) );
  } #-- End: else[ if ( $ver eq '1.0' )

  #-- print out the installed versions.
  if ( defined $found_ver )
  {
   my $out_text = ".NET Framework $found_ver";
   $out_text .= ", service pack $found_sp" if ( defined $found_sp );
   push @out_text, $out_text;
  }
 } #-- End: foreach my $ver ( '1.0', keys...
 return @out_text;
} #-- End: sub getNetFx

#------------------------------------------------------------------
sub _formatDeps
{
 my @in = @_;
 my @formats;

 my @out_lines = grep { $_ !~ m{^\s*6:} } @in;
 my @lines     = grep { m{^\s*6:} } @in;
 my @items;

 my $n_cols_header = 0;
 if ( $lines[0] =~ m{^6:VERSIONINFOHEADER:(.+)} )
 {
  chomp $lines[0];
  $lines[0] =~ s{^6:VERSIONINFOHEADER:\s*}{};
  $lines[0] =~ s{\s+$}{};
  $lines[0] =~ s{\s{2,}}{;}g;
  $lines[0] .= ";Date       Time;Size;Target Dependencies";
 }
 else
 {
# SBT 02.11.08 - Fixed for CA Harvest
#  $lines[0] = "6:VERSIONINFOHEADER:Project;State;Version;Object Id;Date Time;Size;Target Dependencies";
  unshift @lines, "Project;State;Version;Object Id;Date Time;Size;Target Dependencies";
 }
 $n_cols_header = ( $lines[0] =~ tr{;}{;} ) + 1;

 #-- set up the first format
 my $head_line = shift @lines;
 my @head_elements = split ';', $head_line;
 foreach my $i ( 0 .. $#head_elements )
 {
  $formats[$i] = ( length $head_elements[$i] ) + 1;
 }

 foreach my $line ( @lines )
 {
  chomp $line;
  $line =~ s{\s+$}{};
  if ( $line =~ m{\s*6:                                                                   ;} )
  {
   $line =~ s{\s*6:                                                                   ;}{};
   $line = " ;" x ( $n_cols_header - 3 ) . $line;
  }
  elsif ( $line =~ m{^\s*6:; ; ;;(\d+);} )
  {
   #-- old style   
   $line =~ s{^\s*6:; ; ;;}{};
   $line = " ;" x ( $n_cols_header - 3 ) . $line;
  }
  
  $line =~ s{^\s*6:\s*}{};

  #-- prep line that matches to \s{2,}
  $line =~ s{\s{2,}}{;}g;

  my $n_cols_line = ( $line =~ tr{;}{;} ) + 1;

  my @elements = split ';', $line;
  if ( $line =~ m{item-uid=}i )
  {
   my @dim_data = @elements[ 0 .. 5 ];
   my @rest     = @elements[ 6 .. 8 ];

   my $DimStr = join( ";", @dim_data );
   $DimStr .= "\n                                                                         ";
   undef @elements = ();
   push( @elements, $DimStr, @rest );
  } #-- End: if ( $line =~ m{item-uid=}i...

  #-- fix the date
  if (scalar @elements > 3)
  {
   $elements[-3] = BOMGetDateTime( $elements[-3] );
  }
  #-- determine the formats and the items
  my $i = 0;
  foreach my $ele ( @elements )
  {
   $formats[$i] = ( length $ele ) + 1 if ( $formats[$i] < ( length $ele ) + 1 );
   $i++;
  }
  push @items, \@elements;
 } #-- End: foreach my $line ( @lines )
 unshift @items, \@head_elements;

 #-- now loop on @items, add to the outlines formatted correctly
 my $j = 0;
 foreach my $line_array ( @items )
 {
  my @elements = @{$line_array};

  my $i = 0;
  foreach my $ele ( @elements )
  {
   $ele = ' ' unless ( defined $ele); #-- Element can be 0 e.g. version 0
   my $n = abs( $formats[$i] );
   $ele = sprintf( "%-*.*s", $n, $n, $ele );
   $i++;
  }

  #-- test to see if this first, and if it has VERSIONINFOHEADER
  if ( $j == 0 )
  {
   push @out_lines, '6:VERSIONINFOHEADER:' . ( join ';', @elements);
   $j++;
  }
  else
  {
   push @out_lines, '6:' . ( join ';', @elements );
  }
 } #-- End: foreach my $line_array ( @items...

 my @temp = ();

 foreach my $line (@out_lines)
 {
  my $work = $line;
  my $first = 0; 
  $work =~ s/ //g;
  if ($work =~ /6:;;;;/)
  {
   my @parts = split(/;/,$line);
   my @newparts = ();
   foreach my $part (@parts)
   {
    my $wpart = $part;
    $wpart =~ s/ //g;
    if ($wpart eq "6:")
    {
	 push(@newparts,"6:;;");
	 }
    elsif ($wpart eq "")
    {
	 push(@newparts," ;;");
    }	
	else
	{
	 if ($first == 0)
	 {
	  pop(@newparts);
	  $first = 1;
	 }
 	 push(@newparts,$part);
	}
   $line = join(";",@newparts);
	 }   
  }
  $line =~ s/\s*;/;/g;

  push(@temp,$line);
 }
 @out_lines = @temp;
 return @out_lines;
} #-- End: sub _formatDeps

##------------------------------------------------------------------
#sub _store_Build_Audit
#{
# my ( $file, $stored_ref) = @_;
# 
# #-- determine the file name from the $fileshort file
# my $of = Openmake::File->new($file);
# unless ( $::JobDateTime) 
# {
#  $::JobDateTime = JDGetDateTime();
# }
# my $new_file = $of->getDPF() . $::JobDateTime . $of->getE();
#
## #-- use Storable to save the file
## if ( $ALLOW_STORABLE )
## {
##  eval "store \$stored_ref, \$new_file";
## }
# return $new_file;
#}

#------------------------------------------------------------------
#sub _get_Build_Audit
#{
# my $file = shift;
# return unless $file;
# 
# #-- use Storable to get the file
# my $stored_ref;
# if ( $ALLOW_STORABLE )
# {
#  eval "\$stored_ref = retrieve \$file; ";
# } 
# return $stored_ref ;
#}

#------------------------------------------------------------------
#sub _get_last_Build_Audit
#{
# my $file = shift; #-- current storable file
# my $of = Openmake::File->new($file);
# 
# opendir ( my $dh, $of->getDP() );
# my @files = grep { /^$of->getF()/ } $dh;
# close $dh;
#
# my $last_access = 99999999999999;
# my $last_file;
# foreach my $f ( @files )
# {
#  my $access = ( -M $f);
#  if ( $access < $last_access and $f ne $file )
#  {
#   $last_file = $f;
#   $last_access = $access;
#  }
# }
# 
# return _get_Build_Audit( $last_file );
#}

#------------------------------------------------------------------
sub _executeRLPCmd
{
 my $file = shift;
 my $vp   = shift;
 my $vp_config = shift;
 my $vp_rules  = shift;
 
 my $tag;
 return unless ($vp and $file );

 my ($fh, $filename) = tempfile( 'om_version_info_XXXXXX', SUFFIX => '.pl', UNLINK => 1);
 my ( $ofh, $output ) = tempfile( 'om_version_info_XXXXXX', SUFFIX => '.txt', UNLINK => 1);
 print $ofh $file, "\n";
 close $ofh;
 
 print $fh "use Cwd;\n";
 
 my $cmd = "\"$filename\" -f \"$file\" ";
 
 #-- don't have the command line
# for (i = 1; i < gargc; i++)
# {
#  if ( gargv[i][0] == '-' )
#  {
#   strcat( CmdLine, gargv[i]);
#  }
#  else
#  {
#   strcat( CmdLine, "\"" );
#   strcat( CmdLine, gargv[i]);
#   strcat( CmdLine, "\"" );
#  }
#  strcat( CmdLine, " ");
#  if (strchr(gargv[i], '=') != NULL)
#  {
#   GetWord(gargv[i], "=", 1, 1, TmpStr);
#   GetWord(gargv[i], "=", 2, 999, line);
#
#   sprintf(TmpStr2,"our $%s='%s';\n",TmpStr,line);
#   Append2Script(TmpStr2,1);
#
#   sprintf(TmpStr2,"$ENV{%s}='%s';\n",TmpStr,line);
#   Append2Script(TmpStr2,1);
#  }
# }


 if ( @::CmdLineParmTargets )
 {
  print $fh "\@CmdLineParmTargets = ();\n";
  foreach my $tgt ( @::CmdLineParmTarget )
  {
   print $fh "push ( \@CmdLineParmTargets, '$tgt' );\n";
  }
  print $fh "our \$CmdLineParmTargets = join \"|\", \@CmdLineParmTargets;\n";
  print $fh "\$ENV{CmdLineParmTargets} = \$CmdLineParmTargets;\n";
 }

 #/* add the commandline and the error code*/
 #print $fh "
 #Append2Script( "#-- Openmake variables\n\n", 1);
 #sprintf( TmpStr, "our $OMCOMMANDLINE = '%s';\n", CmdLine);
 #sprintf( TmpStr, "our $OMERRORRC = '%d';\n", BuildRC);
 print $fh "our \$OMPROJECT = '$ENV{'APPL'}';\n";
 print $fh "our \$OMVPATHNAME = '$ENV{'STAGE'}';\n";
 print $fh "our \$OMVPATH = '$ENV{'VPATH'}';\n";
 print $fh "our \$OMPROJECVPATH = '$ENV{'PROJECTVPATH'}';\n";
 print $fh "our \$OMBOMRPT = '$::BillOfMaterialRpt';\n";

# /* add a temporary id key that can be used amongst multiple pre/post/commands
#    Need a memory address that's constant across the build */
# sprintf(cStr, "%ld", (unsigned long)BillOfMatRpt);
# sprintf( TmpStr, "our $OMTEMPKEY = '%s';\n", cStr);
# Append2Script( TmpStr, 1);
# sprintf( TmpStr, "our $OMEMBEDTYPE = '%s';\n", progtype);
# Append2Script( TmpStr, 1);

# /* add the call to Openmake::Prepost and set the logging */
# Append2Script( "\nuse Openmake::PrePost;\n", 1);
# Append2Script( "&SetLogging($OMCOMMANDLINE);\n\n", 1);

 #-- add the config
 if ( open ( CONFIG, $vp_config ) )
 {
  while ( <CONFIG>)
  {
   $cmd .= "$_ ";
  }
  close CONFIG;
 }
 if ( $vp_rules)
 {
  $cmd .= " -rules \"$vp_rules\"";
 }

 print $fh "sub main_sub\n{\n";

 #/* add comment to top of script */
 print $fh "\n\n###### Above this line is generated by om ######\n\n";

 open ( SCRIPT, '<', $vp ) or ( return );
 while (<SCRIPT>)
 {
  print $fh $_;
 }
 close SCRIPT;
 
 local $\;
 $\ = "\n"; #-- follow all prints with a \n
 
 print $fh '#-- after script';
 print $fh 'if ( $main::{Supports_Multifile} )';
 print $fh '{';
 print $fh ' return @VERSIONTOOL_RETURN;';
 print $fh ' } else {';
 print $fh '  return $VERSIONTOOL_RETURN;';
 print $fh ' }';
 print $fh '}';
 print $fh '#-- Main function on the new script';
 print $fh 'my @files;';
 print $fh 'my @out_files;';
 print $fh "open ( my \$fh, '<', '$output' );";
 print $fh 'while (<$fh> )';
 print $fh '{';
 print $fh ' chomp;';
 print $fh ' push @files, $_;';
 print $fh '}';
 print $fh 'close $fh;';
 print $fh '#-- see if $Supports_Multifile is in the symbol table';
 print $fh 'if (  $main::{Supports_Multifile} )';
 print $fh '{';
 print $fh ' @out_files = main_sub( @files)';
 print $fh '}';
 print $fh 'else';
 print $fh '{';
 print $fh ' my @largv = @ARGV;';
 print $fh ' foreach my $file ( @files )';
 print $fh ' {';
 print $fh '  @ARGV = @largv;';
 print $fh '  push @ARGV, \'-f \';';
 print $fh '  push @ARGV, $file;';
 print $fh '  my $version_str = main_sub();';
 print $fh '  push @out_files, $version_str ';
 print $fh ' }';
 print $fh '}';
 print $fh "open ( my \$ofh, '>', '$output' );";
 print $fh 'my $i=0;';
 print $fh 'foreach my $line ( @out_files)';
 print $fh '{';
 print $fh ' print $ofh $files[$i] . "\x1E" . $line, "\n";';
 print $fh ' $i++;';
 print $fh '}';
 print $fh 'close $ofh;';
 close $fh;
 
# print $fh "\nour \$PerlResultsFile = '$output';\n";
# print $fh "  open (FPRES, '>' , '$output');\n";
# print $fh "  print FPRES \"RC=\$RC\\n\";";
# print $fh "  print FPRES \"VERSIONTOOL_RETURN=\$VERSIONTOOL_RETURN\\n\";\n";
# print $fh "  print FPRES \"OMBUILD_NUMBER=\$OMBUILD_NUMBER\\n\";\n";
# print $fh "  print FPRES \"CHDIR=\" . cwd() . \"\\n\";\n";
# print $fh "  close (FPRES);\n";
# print $fh "  exit(\$RC);\n";
# close $fh;

 #-- TODO - write file names to the $output file
 
 #-- run command
 `$cmd`;
 my ( $RC, $VERSIONTOOL_RETURN);

 #-- rework this to find file|version control
 open ( OFH, '<', $output );
 while ( <OFH>)
 {
  chomp;
  my ( $file, $VERSIONTOOL_RETURN ) = split /\x1E/, $_;
  last;
  
  #-- need to add build number, chdir
 } 
 close OFH; 
 return $VERSIONTOOL_RETURN;
}

#------------------------------------------------------------------
sub process_Build_Audit
{
 foreach my $key ( keys %SCM_TOOLS )
 {
  #-- do the dispatch based on the SCM tool that we've defined
  if ( $::VersionInfoPgm =~ m{$key} )
  {
   return $SCM_TOOLS{$key}->( @_ );
  }
 }
 
 return ;
}
#------------------------------------------------------------------
sub _process_Perforce
{
 my $prev_storable = shift;
 my $this_storable = shift;
 
 my $bartxt  = "\nPerforce Report\n\n";
 my $barhtml = "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=\"100%\">\n";
 $barhtml   .= "<TR><TD><H1><hr align=left noshade size=4 width=100%><TT>Perforce report</TT></H1></TD></TR>\n";
 
 #-- loop thru dependencies that have changed
 #-- this may not be necessary, Change list seems to do this
 
 #-- loop thru change lists, get their info
 my %changelists;
 my $deps = $this_storable->{'Dependencies'};
 foreach my $k ( keys %{$deps} )
 {
  if ( exists $deps->{$k}->{'Change'} ) 
  {
   $changelists{ $deps->{$k}->{'Change'} } = 1;
  }
  if ( exists $deps->{$k}->{'Changelist'} )
  {
   $changelists{$deps->{$k}->{'Changelist'}} = 1;
  }
 }
 
 foreach my $ch ( sort keys %changelists )
 {
  next unless ( $ch );
  $barhtml .= "<TR><TD><TT>&nbsp;&nbsp;&nbsp;&nbsp;Describe changelist $ch</TT></TD></TR>\n";
  $bartxt  .= "    Describe changelist $ch\n";
  my @ch_out = `p4 describe $ch`; 
  foreach my $l ( @ch_out )
  {
   chomp $l;
   $l =~ s{\t}{ }g;
   $l =~ s{^\s+}{};
   $l =~ s{\s+$}{};
   
   $barhtml .= "<TR><TD><TT>&nbsp;&nbsp;&nbsp;&nbsp;$l</TT></TD></TR>\n";
   $bartxt  .= "    $l\n";
  }
 }
 
 $bartxt  .= "\n";
 $barhtml .= "</TABLE></p>\n";
 return ( $barhtml, $bartxt);
}

#------------------------------------------------------------------
sub systeminfo
{
 if ( $^O =~ m{MSWin|dos}i )
 {
  return win32_systeminfo();
 }
 else
 {
  return unix_systeminfo();
 }
}

#------------------------------------------------------------------
sub unix_systeminfo()
{
 #-- look for uname, run that.
 my $uname_cmd = Openmake::FirstFoundInPath( 'uname' );
 return unless $uname_cmd;
 
 #my @uname_opts = ( ['-n', 'Node'], [ '-o', 'OS'], ['-s', 'Kernel'], ['-r -v', 'Release']);
 my @uname_opts = ( ['-n', 'Node'], ['-s', 'Kernel'], ['-r -v', 'Release']);
 my $format_string = '          %-8.8s: %s';
 my @out;
 foreach my $opt_ref ( @uname_opts )
 {
  my $t = `$uname_cmd $opt_ref->[0]`;
  chomp $t;
  push @out, sprintf( $format_string, $opt_ref->[1], $t);
 }
 wantarray ? return @out : return ( join "\n", @out );
}

#------------------------------------------------------------------
sub win32_systeminfo
{
 if ( $^O =~ m{MSWin|dos}i )
 {
  require Win32; import Win32;
  require Win32::OLE; import Win32::OLE qw(in with);
  require Win32::TieRegistry; import Win32::TieRegistry;
  require Time::Local; import Time::Local;
 }
 else
 {
  return;
 }
 
 my @return_array = ();

 #-- get info from systeminfo if it's installed
 my $systeminfo = Openmake::FirstFoundInPath('systeminfo.exe');
 if ( $systeminfo )
 {
  my @output = `"$systeminfo"`;
  @return_array = grep { $_ !~ /\s+\[\d+\]:\s*File/ } @output;
  wantarray ? return @return_array : return (join "\n", @return_array);
 }
 
 #-- get information from WMI if it's installed
 my $WMI = Win32::OLE->new('WbemScripting.SWbemLocator');
 my $WMI_Service;
 if ( UNIVERSAL::isa( $WMI, 'Win32::OLE') )
 {
  $WMI_Service = $WMI->ConnectServer('localhost');
 }
 return unless (UNIVERSAL::isa( $WMI_Service, 'Win32::OLE')  );

 my $format_string = "%-27.27s%s";
 push @return_array, sprintf $format_string, 'Host Name:', Win32::NodeName();
 my $domain_role;
 my @role_text = ( 'Standalone Workstation', 'Member Workstation' , 'Standalone Server',
                   'Member Server', 'Backup Domain Controller', 'Primary Domain Controller');
 my $comp = $WMI_Service->InstancesOf('Win32_ComputerSystem');
 foreach my $c ( in $comp )
 {
  $domain_role = $role_text[$comp->{DomainRole}];
  last;
 }
 my $os_set = $WMI_Service->InstancesOf( 'Win32_OperatingSystem' );
 foreach my $os ( in $os_set ) 
 {
  push @return_array, (sprintf $format_string, 'OS Name:', $os->{'Caption'});
  push @return_array, (sprintf $format_string, 'OS Version:', $os->{'Version'} . ' ' . $os->{'CSDVersion'} . ' Build ' . $os->{'BuildNumber'});
  push @return_array, (sprintf $format_string, 'OS Manufacturer:', $os->{'Manufacturer'});
  push @return_array, (sprintf $format_string, 'OS Configuration:', $domain_role);
  push @return_array, (sprintf $format_string, 'OS Build Type:', $os->{'BuildType'});
  push @return_array, (sprintf $format_string, 'Registered Owner:', $os->{'RegisteredUser'});
  push @return_array, (sprintf $format_string, 'Registered Organization:', $os->{'Organization'});
  push @return_array, (sprintf $format_string, 'Product ID:', $os->{'SerialNumber'});
  push @return_array, (sprintf $format_string, 'Original Install Date:', _parse_datetime($os->{'InstallDate'}));
  push @return_array, (sprintf $format_string, 'System Up Time:', _parse_uptime( $os->{'LastBootUpTime'}));
 }

 my $sys_set = $WMI_Service->InstancesOf('Win32_ComputerSystem');
 foreach my $sys ( in $sys_set ) 
 {  
  push @return_array, (sprintf $format_string, 'System Manufacturer:', $sys->{'Manufacturer'});
  push @return_array, (sprintf $format_string, 'System Model:', $sys->{'Model'});
  push @return_array, (sprintf $format_string, 'System type:', $sys->{'SystemType'});
 }

 my $processor_set = $WMI_Service->InstancesOf('Win32_Processor');
 my $proc_enum;
 if ( $processor_set )
 {
  $proc_enum = Win32::OLE::Enum->new($processor_set);
 }
 if ( $proc_enum )
 {
  my @procs = $proc_enum->All();
  my $n_procs = scalar @procs;
  my $proc_str = "$n_procs Processor(s) Installed.";
  push @return_array, (sprintf $format_string, 'Processor(s):', $proc_str);
 }
 
 my $i = 1;
 foreach my $proc (in $processor_set ) 
 {
  my $proc_str = sprintf( '[%2.2d]: %s %s ~%d Mhz', $i, $proc->{'Caption'},
                        $proc->{'Manufacturer'}, $proc->{'CurrentClockSpeed'}); 
  push @return_array, (sprintf $format_string, ' ', $proc_str);
  $i++;
 }

 my $bios_set = $WMI_Service->InstancesOf('Win32_BIOS');
 foreach my $bios (in $bios_set ) 
 {  
  push @return_array, ( sprintf $format_string, 'BIOS Version:', $bios->{'Version'});
 }
 
 foreach my $os (in $os_set ) 
 {
  push @return_array, (sprintf $format_string, 'Windows Directory:', $os->{'WindowsDirectory'});
  push @return_array, (sprintf $format_string, 'System Directory:', $os->{'SystemDirectory'});
  push @return_array, (sprintf $format_string, 'Boot Device:', $os->{'SystemDevice'});
  push @return_array, (sprintf $format_string, 'System Locale:', _format_locale($os->{'Locale'})); 
  push @return_array, (sprintf $format_string, 'Input Locale:', _format_locale($os->{'Locale'})); #-- how is this different?
 }
 
 my $loc_set = $WMI_Service->InstancesOf("Win32_TimeZone");
 foreach my $loc ( in $loc_set ) 
 {
  push @return_array, (sprintf $format_string, 'Time Zone:', $loc->{'Description'});  
 }

 foreach my $os ( in $os_set ) 
 {
  push @return_array, (sprintf $format_string, 'Total Physical Memory:', _format_memory($os->{'TotalVisibleMemorySize'}));
  push @return_array, (sprintf $format_string, 'Available Physical Memory:', _format_memory($os->{'FreePhysicalMemory'}));
  push @return_array, (sprintf $format_string, 'Virtual Memory: Max Size:', _format_memory($os->{'TotalVirtualMemorySize'}));
  push @return_array, (sprintf $format_string, 'Virtual Memory: Available:', _format_memory($os->{'FreeVirtualMemory'}));
  push @return_array, (sprintf $format_string, 'Virtual Memory: In Use:', _format_memory($os->{'TotalVirtualMemorySize'} - $os->{'FreeVirtualMemory'})); 
 } 
 
 my $page_set = $WMI_Service->InstancesOf( 'Win32_PageFile' );
 $i = 1;
 foreach my $page ( in $page_set )
 {
  if( $i == 1 )
  {
   push @return_array, (sprintf $format_string, 'Page File Location(s):', $page->{'EightDotThreeFileName'}); 
  }
  else
  {
   push @return_array, (sprintf $format_string, ' ', $page->{'EightDotThreeFileName'}); 
  }
 } 
 
 push @return_array, (sprintf $format_string, 'Domain:', Win32::DomainName());

 #------------------------------------------------------------------
 # get logon server?
 # my $logon = $WMI_Service->InstancesOf( 'Win32_NetworkLoginProfile' );
 # foreach my $l ( in $logon )
 # {
 #  $return_string .= sprintf $format_string, 'Logon Server:', $l->{LogonServer};
 #  last;
 # }

 my $qfe = $WMI_Service->InstancesOf('Win32_QuickFixEngineering');
 my $qfe_enum;
 if ( $qfe )
 {
  $qfe_enum =  Win32::OLE::Enum->new($qfe);
 }
 if ( $qfe_enum )
 {
  my @qfes = $qfe_enum->All();
  my $n_qfes = scalar @qfes;
  push @return_array, ( sprintf $format_string, 'Hotfix(s):', "$n_qfes Hotfix(s) Installed.");
  $i = 1;
  foreach my $fix (in $qfe )
  {
   if ( $fix->{HotFixID} !~ m{File 1} )
   {
    my $pstr = sprintf '[%2.2d]: %s', $i, $fix->{HotFixID};
    if ( $fix->{FixComments})
    {
     $pstr .= ' - ' . $fix->{FixComments};
    }
    push @return_array, ( sprintf $format_string, ' ', $pstr );
   }
   $i++;
  }
 }
 
 my $net = $WMI_Service->InstancesOf('Win32_NetworkAdapterConfiguration');
 my $net2 = $WMI_Service->InstancesOf('Win32_NetworkAdapter');
 
 my $nip_enabled = 0;
 foreach my $n ( in $net )
 {
  $nip_enabled++ if ( $n->{IPEnabled} );
 }
 push @return_array, ( sprintf $format_string, 'NetWork Card(s):', "$nip_enabled NIC(s) Installed.");  

 my $k = 1;
 foreach my $n ( in $net )
 {
  if ( $n->{IPEnabled} )
  {
   ( my $cap = $n->{Caption} ) =~ s{^\[\d+\]\s*}{}; 
   push @return_array, ( sprintf $format_string, ' ', ( sprintf( '[%2.2d]: %s', $k, $cap)));
   foreach my $m ( in $net2 )
   {
    if ( $n->{Caption} eq $m->{Caption})
    {
     push @return_array, ( sprintf $format_string, ' ', '      Connection Name: ' . $m->{NetConnectionID});
     last;
    }
   }
   my $dhcp = '    No';
   $dhcp = '    Yes' if ( $n->{DHCPEnabled} );
   push @return_array, ( sprintf $format_string, ' ', '      DHCP Enabled:' . $dhcp);
   push @return_array, ( sprintf $format_string, ' ', '      IP address(es)');
   my $j = 1;
   foreach my $ip (  @{$n->{IPAddress}} )
   {
    push @return_array, ( sprintf $format_string, ' ', (sprintf( "      [%2.2d]: $ip", $j)));
   }   
  }
 }

 wantarray ? return @return_array : return (join "\n", @return_array);

 #------------------------------------------------------------------
 sub _format_memory
 {
  #1,571,820 kb
  #1,535 MB
  my $m = shift;
  my $mb = int( $m / 1024 ) + 1;
  $mb = reverse $mb;
  $mb =~ s{(\d\d\d)(?=\d)(?!\d*\.)}{$1,}g;
  $mb = (reverse $mb) . ' MB'; 
  
  return $mb;
 }
 
 #------------------------------------------------------------------
 sub _format_locale
 {
  my $locale = shift;
  my $key = new Win32::TieRegistry "LMachine\\Software\\Classes\\MIME\\Database\\Rfc1766\\";
  my $val; 
  my @value_names = $key->ValueNames();
  foreach my $k ( @value_names )
  {
   if ( $k eq $locale )
   {
    $val = $key->GetValue($k);
    last;
   }
  }
  return $val;
 }
 
 #------------------------------------------------------------------
 sub _parse_uptime
 {
  my $boot = shift;
  
  #-- convert to a localtime
  my (@boot) = ( $boot =~ m{^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})} );
  foreach my $t ( @boot )
  {
   $t += 0;
  }
  $boot[0] -= 1900;
  $boot[1]--;
  
  @boot = reverse @boot;
  my $boott = timelocal(@boot);
  my $datet = time();
  my $secs = $datet - $boott;
 
  #-- 3600 sec/hr, 24 hrs/day 86400 sec/day
  my $days = int( $secs / 86400 );
  $secs -= 86400*$days;
  my $hours = int( $secs/3600);
  $secs -= 3600*$hours;
  my $mins = int( $secs/60);
  $secs -= 60*$mins;
  
  return sprintf( '%d Days, %d Hours, %d Minutes, %d Seconds', $days, $hours, $mins, $secs);
  }
 
 #------------------------------------------------------------------
 sub _parse_datetime
 {
  #20040116102039.000000-300
  #1/16/04, 10:20:39 AM
  my $date = shift;
  my ($y, $m, $d, $h, $min, $s ) = ( $date =~ m{^\d{2}(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})} );
  my $ap = ' AM';
  if ( $h > 12)
  {
   $h -= 12;
   $ap = ' PM';
  }
  
  return ($m+0) . '/' . ($d+0) . '/' . $y . ', ' . ($h+0) . ':' . ($min+0) . ':' . ($s+0). $ap;
 }
}
 
 
sub hsigget
{
 my $file = shift; 

 $file =~ s/\\/\//g;
 my $selfile = $file;
 $selfile =~ tr/A-Z/a-z/;
 my $sth = $dbh->prepare( "select verinfo, mtime, filesize from Stats where filename = '" . $selfile . "'");
 $sth->execute;

 my $verinfo;
 my $mtime;
 my $fsize;
 my $wdir = cwd();
 
 while (($verinfo, $mtime, $fsize) = $sth->fetchrow_array())
 {
   my @parts = split(/;/,$verinfo);
   return ($parts[0],$parts[1],$parts[2],$parts[3],$mtime,$fsize);
 }
 
 my $f = Openmake::File->new($file);

 my $Path = $f->getDP();

 $Path = $wdir if ($Path eq "");
 
 $sth = $dbh->prepare( "SELECT count(*) FROM Dirs where DirName = '" . $Path . "'" );
 $sth->execute;
  
 my ($cnt) = $sth->fetchrow_array();

 if ($cnt == 0)
 {
  $sth = $dbh->prepare( "INSERT INTO Dirs (DirName) VALUES ('$Path')");
  $sth->execute;
  
  unless ( chdir($Path) ) 
  {
   my $RC = 2;
   die "Cannot access directory \"$Path\""; 
  } 

  my $hsigcmd = "hsigget -t -a modtime size environment state version versionid";
  my @output = `$hsigcmd`;
  pop @output;

  chdir($wdir);
  
  $dbh->do('BEGIN');

  foreach my $line (@output)
  {
   $line =~ s/\n//g;
   my @hsigdata = split(/\t/,$line);
   my $filename = $Path . "\/" . $hsigdata[0];
   $filename =~ s/\\/\//g;
   $filename =~ tr/A-Z/a-z/;
   my $modtime = $hsigdata[1];
   my $filesize = $hsigdata[2];
   my $verinfo = join (';', $hsigdata[3] , $hsigdata[4] , $hsigdata[5] , $hsigdata[6]);
   my @t = $modtime =~ m!(\d{2})-(\d{2})-(\d{4})\;(\d{2}):(\d{2}):(\d{2})!;
   $t[0]--;
   $modtime = timelocal @t[5,4,3,1,0,2];
   my $fname = Openmake::File->new($filename);
   $sth = $dbh->prepare( "INSERT INTO Stats (FileName, mtime, filesize, verinfo) VALUES ('$filename',$modtime,$filesize,'$verinfo')");
   $sth->execute;
  }

  $dbh->do('COMMIT');
  $sth = $dbh->prepare( "select verinfo, mtime, filesize from Stats where filename = '" . $selfile . "'");
  $sth->execute;

  while (($verinfo, $mtime, $fsize) = $sth->fetchrow_array())
  {
   my @parts = split(/;/,$verinfo);
   return ($parts[0],$parts[1],$parts[2],$parts[3],$mtime,$fsize);
  }
 }   
 return ("","","","",0,0);
}
 



#------------------------------------------------------------------
sub _process_Accurev { return ; }

#------------------------------------------------------------------
sub _process_Clearcase { return ;}

#------------------------------------------------------------------
sub _process_CVS { return ;}

#------------------------------------------------------------------
sub _process_Harvest { return ;}

#------------------------------------------------------------------
sub _process_MKS { return ; }

#------------------------------------------------------------------
sub _process_SVN { return ;}

#-- need to add VSS, MSTF and Teamprise

1;
