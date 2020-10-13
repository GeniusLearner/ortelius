#======================================================
package Openmake::PrePost;

BEGIN
{
 use Exporter ();
 use AutoLoader;
 use vars qw(@ISA @EXPORT $VERSION);

 @ISA     = qw(Exporter AutoLoader);
 @EXPORT  = qw( &ParseParms
                &SetLogging
                &getOMLogURI
                &translate_special_arg
   );
 my $HEADER = '$Header: /CVS/openmake64/perl/lib/DEBUG/Openmake/PrePost.pm,v 1.3 2005/11/10 18:47:46 jim Exp $';
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }
} #-- End: BEGIN

#----------------------------------------------------------------
=head1 NAME

Openmake::PrePost

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

This package exists to provide functionality that may be useful in
pre/post processing scripts that are called from bldmake.exe and om.exe

Note that the following variables are prepended to the top of any script
running as a pre or post execution script.

 $OMCOMMANDLINE  -- the command line passed to bldmake or om
 $OMERRORRC      -- the error Return Code that bldmake or om will exit with
 $OMPROJECT      -- name of the Openmake Project
 $OMVPATHNAME    -- name of the Openmake Search Path
 $OMVPATH        -- ";" delimited list of directories in the Search Path
 $OMPROJECTVPATH -- ";" delimited list of directories marked as
                    "Project Dirs" in the Search Path
 $OMBOMRPT       -- File containing the Bill of materials report.

 $OMTEMPKEY      -- a temporary number that is constant across invocations
                    of the trigger. Only available in om.exe
 $OMEMBEDTYPE    -- one of "pre", "ret", "ver", "post"

 Some of these variables may be null in some cases.

By default, the internal Perl parser will add the following lines to the
top of your script:

 use Openmake::PrePost;
 &SetLogging($OMCOMMANDLINE);

The first line will use this module.
The second line will configure the necessary 'main' variables so that your
script can use the Openmake::Log.pm functionality to log information to
the Openmake KB Server.

=head1 AutoLoad

All functions are AutoLoaded.

=head1 FUNCTIONS

=head2 GENERAL FUNCTIONS

=head3 ParseParms( $OMCOMMANDLINE )

 subroutine to parse openmake commandline arguments
 passed to either bldmake or om.

 input: $commandlinestr = string of arguments passed to om.
        Available as global $OMCOMMANDLINE in pre/post/retrieve
        scripts.

 returns a hash, keyed by command line switches. Switches without
  a value have hash value of 1.

 Note that due to the fact that arguments are not quoted, it's not
 possible to create a perfect parsing of the commandline. For example
 the following

 > om -b bom.txt bingo_server.jar

 will be parsed as

  $omref{b} = "bom.txt bingo_server.jar"

 This is because one could call

 > om -b "my bom.txt" -s bingo_server.jar

 and we must allow for the space in the argument

 USAGE: %omref = &ParseParms( $OMCOMMANDLINE)

=head3 SetLogging( $OMCOMMANDLINE )

 To log information to the Openmake KB Server, a set of information
 that is derived from the command-line call of om/bldmake is necessary.
 This function sets the necessary variables that the
 Openmake::Log::omlogger function will require.

 By default, this will be added to the top of embedded Perl scripts

 USAGE: SetLogging( $OMCOMMANDLINE)

=head3 translate_special_arg

 Removes and replaces special characters in the @ARGV array that may have 
 been placed by omsubmit. 
 
 Current list of replacements are:
 
   <BR> => \n

=head2 Openmake::ParseBOM

This object contains information gleaned from the Bill of Materials (BOM)
report, and methods to access that information.

It can be used to determine files that went into a given build. Further
use of this information might be to label each file with a build number
within an SCM tool.

=head3 Openmake::ParseBOM Methods

=head4 new($OMBOMRPT)

The new method creates the object based on the information in the
text file $OMBOMRPT.

Note that $OMBOMRPT is a standard variable that gets prepended to the
top of the Pre/Post command script before it is executed. However, it
may be null.

=head4 getFiles

Returns a list of files in the BOM

=head4 getSize( $file)

Returns from the ParseBOM object the size of the file $file

=head4 getTimeStamp( $file)

Returns from the ParseBOM object the timestamp of the file $file.
The timestamp is in "localtime" format

=head4 getVersionInfo( $file)

Returns the text string detailing the version control tool information
as stored in the BOM report. This information may have project or version
information in it. Because Openmake interfaces with multiple SCM tools,
it is up to the user to parse the output of this method.

=cut

#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked
#
#           Symbol table magic. Don't know if this works
#-- removed for DEBUG Version
#1;
#__END__

#======================================================
# General functions

#----------------------------------------------------------------
sub ParseParms
{
 my $input  = shift;
 my %omargs = ();

 #-- bldmake options are
 #Usage: BldMake <Project> <Search Path Name> [Targets 1]...[Targets N] [-C <direc
 #tory>] [-m <output directory>]
 #          -c  = Change current working directory
 #          -f  = Use existing makefile for ApplId, Stage, and Targets
 #          -ld <Date Time> = Log: Build Date/Time
 #          -lj <Job Name>  = Log: Job Name
 #          -lm <Machine>   = Log: Build Machine Name
 #          -lo <Owner>     = Log: Owner Name
 #          -lp             = Log: Public Build
 #          -m  = Makefile output directory
 #          -ob = Output to Screen and HTML on KB Server
 #          -oh = Output to HTML on KB Server
 #          -os = Output to Screen
 #          -ov = Verbose Output
 #          -s  = Case Sensitive
 #          -v  = Version
 #          -?  = This message

 #-- om options are
 #Usage: OM [-f <Makefile Name>] [-c <Directory>] [-t <Job Name>] [-l <Log File Na
 #me>] [-b <Bill Of Mat Name> ] [-pd] [-pe] [-pm][-px] [-pf] [-pv] [-v] [Targets 1
 #]...[Targets N] [<var>=<value>]
 #          -a  = Force dependencies to be newer than the target
 #          -b  = Bill of Materials File Name for the Final Targets
 #          -c  = Change current working directory
 #          -d  = Don't Scan Source
 #          -e  = Embed Footprint in the Final Targets
 #          -f  = Makefile name, defaults to 'makefile.mak'
 #          -g  = Gather Impact Analysis
 #          -j  = Don't Scan Java Source
 #          -ld <Date Time> = Log: Build Date/Time
 #          -lj <Job Name>  = Log: Job Name
 #          -lm <Machine>   = Log: Build Machine Name
 #          -lo <Owner>     = Log: Owner Name
 #          -lp             = Log: Public Build
 #          -n  = (same as -a)
 #          -ob = Output to Screen and HTML on KB Server
 #          -oh = Output to HTML on KB Server
 #          -os = Output to Screen
 #         -ov = Verbose Output
 #          -ks = Keep Temporary Script
 #          -pd = Print dependencies as they are being checked
 #          -pe = Print environment
 #          -ph = Print Search Path Header
 #          -pl = Print loading of makefile dependencies
 #          -ps = Print script macros
 #          -pt = Print dependency tree
 #          -pv = Print Search Path being used
 #          -px = Print commands being executed
 #          -v  = Version
 #         -?  = This message

 #-- options with switches
 #   -C <directory>
 #   -ld <date/time>
 #   -lj <Job Name>  = Log: Job Name
 #   -lm <Machine>   = Log: Build Machine Name
 #   -lo <Owner>     = Log: Owner Name
 #   -m  <directory> = Makefile output directory
 #
 #   -f  <makefile name>
 #   -b  <Bill of Materials>

 $input =~ s/^\s+//;
 $input =~ s/\s+$//;

 #-- split on spaces.
 my @inargs = &quotespacesplit( $input );
 foreach my $a ( @inargs )
 {
  $a =~ s/^"//;
  $a =~ s/"$//;
 }

 while ( ( grep /^-/, @inargs ) || ( grep /=/, @inargs ) )
 {
  my $arg = shift @inargs;

  #-- remove leading, trailing "

  #-- if $arg starts with '-', add it to hash, look for necessary
  #   parameters.
  if ( substr( $arg, 0, 1 ) eq '-' )
  {
   $arg = substr( $arg, 1 );
   $omargs{$arg} = 1;

   #-- check cases that require an additional argument
   #
   if ( $arg =~ /^([bcCmf]|l[djmo]|[bra][pcr])$/ )
   {
    my $nextarg = shift @inargs;
    last unless $nextarg;
    if ( substr( $nextarg, 0, 1 ) eq '-' )
    {

     #-- need to error here except if (-f)
     if ( $arg ne 'f' )
     {
      print "Error: Argument $arg needs a value, but is followed by $nextarg\n";
     }
     else
     {
      unshift @inargs, $nextarg;    #-- push nextarg after -f back onto list
     }
    } #-- End: if ( substr( $nextarg,...
    else
    {
     while ( substr( $nextarg, 0, 1 ) ne '-' )
     {
      if ( $omargs{$arg} == 1 )
      {
       $omargs{$arg} = "$nextarg";
      }
      else
      {
       $omargs{$arg} .= " $nextarg";
      }
      $nextarg = shift @inargs;
      last unless $nextarg;
     } #-- End: while ( substr( $nextarg,...
     unshift @inargs, $nextarg;    #-- push nextarg back onto list
     $omargs{$arg} =~ s/^\s+//;
     $omargs{$arg} =~ s/\s+$//;
    } #-- End: else[ if ( substr( $nextarg,...
   } #-- End: if ( $arg =~ /^([bcCmf]|l[djmo]|[bra][pcr])$/...

   #-- match to env variable type info
   if ( $arg =~ /=/ )
   {
    my @t = split /=/, $arg;
    $omargs{ $t[0] } = $t[1];
   }
   next;
  } #-- End: if ( substr( $arg, 0, ...

 } #-- End: while ( ( grep /^-/, @inargs...
 return %omargs;

#----------------------------------------------------------------
 sub quotespacesplit
 {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;

  #-- Split on spaces
  my @split = split( /\s+/, $string );

  #-- Reconstruct quotes
  my @correctsplit = ();
  my $at           = "";

  #-- Loop through the arguments to match up quotes
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

  #-- remove quotes
  return @correctsplit;
 } #-- End: sub quotespacesplit
} #-- End: sub ParseParms

#------------------------------------------------------
sub SetLogging
{
 use Openmake::File;
 my $cmdline = shift;
 my %cmd     = ParseParms( $cmdline );

 #-- set the main variables that Openmake::Log.pm expects
 $main::Quiet          = $cmd{ov} ? "YES" : "NO";
 $main::JobMachineName = $cmd{lm};
 $main::MachineName    = $ENV{HOST} || $ENV{HOSTNAME} || $ENV{COMPUTERNAME};
 $main::LogOwner       = $cmd{lo};
 $main::JobDateTime    = $cmd{ld};
 $main::PublicBuildJob = $cmd{lp} ? "true" : "false";
 $main::JobName        = $cmd{lj};
 $main::OutputType     = "screen";
 $main::OutputType     = "html" if $cmd{oh};
 $main::OutputType     = "both" if $cmd{ob};
 $main::FinalTarget    = Openmake::File->new( $main::OMEMBEDTYPE );
 $main::Target         = Openmake::File->new( $main::OMEMBEDTYPE );
 return;
} #-- End: sub SetLogging

#----------------------------------------------------------------
sub translate_special_arg
{
 foreach my $arg ( @ARGV )
 {
  $arg =~ s/<BR>/\n/gi;
 }
}

#======================================================
# Email functions

1;


#########################################
#-- A class has to be a separate package
package Openmake::ParseBOM;

BEGIN
{
 use Exporter ();
 use AutoLoader;
 use vars qw(@ISA @EXPORT $VERSION);

 $VERSION = 6.400;
 @ISA    = qw(Exporter AutoLoader);
 @EXPORT = qw( &new
   &getFiles
   &getSize
   &getTimeStamp
   &getVersionInfo
   );
} #-- End: BEGIN

#----------------------------------------------------------------
sub new
{
 my $proto = shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 my $bomrpt = shift;
 return unless ( -e $bomrpt );

 #--  parse the file
 open( BOM, "$bomrpt" );
 my $indep = 0;
 while ( <BOM> )
 {
  chomp;
  next if ( /^\s+$/ );
  if ( /Dependencies:/ )
  {
   $indep = 1;
   next;
  }
  if ( /END:/ )
  {
   $indep = 0;
   next;
  }

  if ( $indep )
  {

   #-- parse the dependencies.
   #         12/31/1969 19:00:00              (null)
   if ( /(.+)(\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}) (\d+)\s+(.+)/ )
   {

    #-- has a date/time stamp
    my $versioninfo = $1;
    my $datetime    = $2;
    my $size        = $3;
    my $file        = $4;

    #-- convert date/time back to epoch
    my ( $date, $time ) = split / /, $datetime;
    my ( $mon,   $mday, $year ) = split /\//, $date;
    my ( $hours, $min,  $sec )  = split /:/,  $time;

    $mon--;
    $year -= 1900;

    use Time::Local;
    my $localtime = timelocal( $sec, $min, $hours, $mday, $mon, $year );

    #-- add this to the object;
    $self->{$file} = {
     TStamp => $localtime,
     Size   => $size,
     VInfo  => $versioninfo
    };
   } #-- End: if ( /(.+)(\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}) (\d+)\s+(.+)/...
  } #-- End: if ( $indep )
 } #-- End: while ( <BOM> )

 bless( $self, $class );
 return $self;
} #-- End: sub new

#----------------------------------------------------------------
sub getFiles
{
 my $self = shift;
 return keys %{$self};
}

#----------------------------------------------------------------
sub getSize
{
 my $self = shift;
 my $file = shift;
 return $self->{$file}->{Size};
}

#----------------------------------------------------------------
sub getTimeStamp
{
 my $self = shift;
 my $file = shift;
 return $self->{$file}->{TStamp};
}

#----------------------------------------------------------------
sub getVersionInfo
{
 my $self = shift;
 my $file = shift;
 return $self->{$file}->{VInfo};
}

#-- removed for DEBUG Version
#1;
#__END__

1;
__END__
