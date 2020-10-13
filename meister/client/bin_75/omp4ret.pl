# omp4ret.pl Version 1.0
#
# Openmake Perforce Retrieve command utility
#
# Catalyst Systems Corporation		11/30/2005
#
#-- Perl wrapper to Perforce commands that plugs into 
#   Openmake build tool

=head1 omp4ret.pl

=head1 LOCATION

<openmake clc install path>/bin

=head1 DESCRIPTION

omp4ret.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-rp, -rc, -rr} command line flags. This script executes while
the executable runs, and has access to certain Openmake-specific
information. The script "retrieves" code from Perforce by executing
a 'p4 sync' command to update a snapshot view.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file.
There has been an attempt for these arguments to match as close
as possible to the Perforce p4 sync command arguments.

=over 2

=item Item Name

Item description

=back
 
=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. Construct the 'p4 sync' command
 3. Execute the 'p4 sync' command
 
=head1 TODO

=over 2

=item Add verbose option to print stdout into log

=item Parse stdout for log name, read it and dump out to the om log

=cut

#-- use declarations
use Openmake::Log;
use Cwd;

#-- Openmake Variables
my $RC = 0;

#-- global variables
our ( $ConfigSpec, $StepDescription,
      $SCMCmdLine );

#-- Get the arguments from the command line
#   The following sticks all of the options into the hash arguments
#   indexed by argument letter. We then stick it into each specific 
#   variable
#
&GetOptions( "P4CLIENT=s" => \$P4CLIENT
           );

#-- Set the P4CLIENT environment variable if passed on the command line

#-- Note: If P4CLIENT is used in the search path, it still must be set externally
#   prior to execution of om

$ENV{P4CLIENT} = $P4CLIENT if defined $P4CLIENT;

my $cwd = `pwd`; #-- use `pwd` as SBT claims it's more reliable than Perl's
$cwd  =~ s/\\/\//g;
$cwd =~ s/\s+$//;
  
#-- create the p4 sync command;
$SCMCmdLine  = qq(p4 sync -f 2>&1);

$StepDescription = "omp4ret.pl: Executing p4 sync of $ENV{P4CLIENT}\n";
#&omlogger("Begin",$StepDescription,"FAILED",$StepDescription,$SCMCmdLine,"","",$RC, $StepDescription);

#-- parse the input
unless ( defined $ENV{P4CLIENT} )
{
 $ENV{P4CLIENT} = $OMPROJECT;
 
# $RC = 1;
# #-- omlogger
# $ErrMessage = "omp4ret.pl: Must define P4CLIENT environment variable to the snapshot view location.";
# &omlogger("Final",$StepDescription,"FAILED",$ErrMessage,$SCMCmdLine,"","",$RC, $StepDescription);
# goto EndOfScript;
}

#-- execute the command line
my @output = `$SCMCmdLine`;
$RC = ($? >> 8 );

#debug: print "omp4ret.pl: @output\n";

#-- log the output
$StepDescription = "Execution of p4 sync of $ENV{P4CLIENT}";
&omlogger("Final",$StepDescription,"ERROR:","omp4ret.pl: ERROR: $StepDescription failed!",$SCMCmdLine,"","",$RC,@output), $RC = 1 if ($RC != 0);
&omlogger("Final",$StepDescription,"ERROR:","omp4ret.pl: $StepDescription succeeded.",$SCMCmdLine,"","",$RC,@output) if ($RC == 0);

chdir $cwd or die;

#-- end of script
EndOfScript:
$RC;

#-------------------------------------------------------------------
sub GetOptions
{
 my @input = @_;
 my $opt;
 my %linkage;
 my %type;
 my $error = "";
 my $pkg = (caller)[0]; 

 #-- parse what we want
 while ( @input > 0 ) 
 {
  my $opt = shift (@input);
  
  #-- match to a=s if necessary.
  if ( $opt =~ /(.+?)=s/)
  {
   $opt = $1;
   $type{$opt} = "s";
  }
  
  #--  Copy the linkage. If omitted, link to global variable.
  if ( @input > 0 && ref($input[0]) ) 
  {
   if ( ref($input[0]) =~ /^(SCALAR|CODE)$/ ) 
   {
    $linkage{$opt} = shift (@input);
   }
   else 
   {
    $error .= "Invalid option linkage for \"$opt\"\n";
   }
  }
  else 
  {
   my $ov = $opt;
   $ov =~ s/\W/_/g;
   eval ("\$linkage{\$linko} = \\\$".$pkg."::opt_$ov;");
  }
 }
 # Bail out if errors found.
 return ($error) if $error;
 $error = 0;

 #-- parse what we have
 while( grep /^-/, @ARGV )
 {
  my $flag = shift @ARGV;
  
  if ( $flag =~ /^-(.+)/ )
  {
   $opt = $1;
   if ( defined $linkage{$opt} )
   {
    if ( $type{$opt} eq "s" )
    { 
     #-- get the next argument and put it in the 
     #   link
     my $arg = shift @ARGV;
     if ( $arg =~ /^-/ )
     {
      $error = "Flag $opt requires an option";
      return $error;
     }
     else
     {
      ${$linkage{$opt}} = $arg;
     }
    }
    else
    {
     #-- increment counter
     ${$linkage{$opt}}++;
    }
   } #-- if defined $linkage
  } #-- if flag
 }
 return 0;
}
