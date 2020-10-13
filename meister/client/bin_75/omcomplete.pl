#!/usr/bin/perl
#
# $Header: /CVS/openmake64/shared/omcomplete.pl,v 1.24 2010/01/27 16:28:48 steve Exp $
#
# omcomplete.pl Version 1.0
#
#  Utility to postprocess build information
#
# Catalyst Systems Corporation 06.14.05
#
=pod

=head1 OMCOMPLETE.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

Generic "clean-up script" that runs after all components of a build
are complete.

Currently the script:

=over 2

=item creates the '.om_complete' file.
=item removes temporary Perl Build Task scripts.
=item attempts to "glue" XML log files back together.

=back

=head1 ARGUMENTS

=over 2

=item -dn <name>     Dependency Name:
=item -di <number>   Dependency ID
=item -la <activity> Build Activity
=item -lj <job name> Build Job Name
=item -li <build ID> Build Label,
=item -lm <machine>  Build Machine Label,
=item -ld <YYYY_MM_DD HH-MM-SS> Build Date,
=item -lo <user>     Build Owner,
=item -lp            Build Public,
=item -sd <dir>      Submit Build Dir
=item -ks            KeepScripts
=item -r <RC>        RC code to exit with (Build Success | Build Failure)
=item -ox <xml logfile>
=item -g             Do impact analysis
=item -gu <name>     Upload impact analysis (used for 'fork' emulation on Windows)

=back

=cut

use warnings;
use strict;
use Cwd;
use File::Temp qw(tempfile);
use File::stat;
use File::Spec;
use Getopt::Long;
use Openmake;
use Openmake::File;
use Openmake::Log;
use POSIX ();

my  $BUILD_COMPLETE_NAME = 'Build Job complete';

our $Dependency_ID = -1;
our $Dependency_Name;
our $Build_Job_Name = "";
our $Build_Label = "";
our $Build_Machine_Label = "";
our $Build_Date = "";
our $Build_Owner = "";
our $Build_Public = 0;
our $Build_Activity = "";
our $Submit_Build_Dir = "" ;
our $Xml_Log_File = "";
our $Keep_Scripts = 0;
our $RC = 0;
our $Impact = 0;
our $Upload_Impact = 0;

my @largs = @ARGV;

&Getopt::Long::Configure( "pass_through" );
&GetOptions(
 'dn=s' => \$Dependency_Name,
 'di=i' => \$Dependency_ID,
 'lj=s' => \$Build_Job_Name,
 'li=s' => \$Build_Label,
 'lm=s' => \$Build_Machine_Label,
 'ld=s' => \$Build_Date,
 'lo=s' => \$Build_Owner,
 'ox=s' => \$Xml_Log_File,
 'la=s' => \$Build_Activity,
 'lp'   => \$Build_Public,
 'sd=s' => \$Submit_Build_Dir,
 'ks'   => \$Keep_Scripts,
 'r=i'  => \$RC,
 'g'    => \$Impact,
 'gu=s' => \$Upload_Impact
);

$RC = 1 if ($RC != 0);

if (-e "delete_temp_projects.bat")
{
 print `delete_temp_projects.bat`;
}

#-- check if we've been spawned as the child to do uploading of the impact analysis
if ( $Upload_Impact and $^O =~ m{MSWin|dos}i )
{
 upload_impact( $Upload_Impact);
 exit 0;
}

#-- JAG - 02.02.06 - if the dependency name is "Build Complete", just send
#   details via UDP.
if ( $Dependency_Name eq $BUILD_COMPLETE_NAME )
{
 #-- some function to update the KB server as to the status of the build job
 open( OMC, '>', '.build_job_complete' );
 print OMC "$RC\n";
 close OMC;

 if ( $RC != 0 )
 {
  print "Build Job '$Build_Job_Name' completed unsuccessfully\n";
 }
 else
 {
  print "Build Job '$Build_Job_Name' completed successfully\n";
 }

 #-- JAG - 02.22.06 - case 6802 - end of the build job should run without 
 #    throwing an error, even if previous steps failed
 #-- JAG - 03.13.06 - case 6949. Since metrics don't report this, have it fail
 #   according to the RC as necessary
 exit $RC;
}

#-- touch .om_complete
#-- JAG - 11.18.05 - case ???? - place RC into build complete file
open( OMC, '>', '.om_complete' );
print OMC "$RC\n";
close OMC;

if ( $RC != 0 )
{
 print "Build completed unsuccessfully\n";
}
else
{
 print "Build completed\n";
}

#-- delete temporary scripts
#-- JAG - 03.24.06 - case 6995 - this isn't safe in a multiple build build dir
#unless ( $Keep_Scripts )
#{
# opendir ( SUBDIR, '.submit' );
# my @pl_files = grep { /\/om_.+?\.(pl|txt)$/ } map ".submit/$_", readdir SUBDIR;
# closedir SUBDIR;
# unlink @pl_files;
#}

#-- glue XML files back together.
my $xml_cnt = 1;
if ( $Xml_Log_File)
{
 unless ( open( XML, '>>', $Xml_Log_File ) )
 {
  print "omcomplete.pl: Unable to open '$Xml_Log_File' for write: $!\n";
  exit 1;
 }

 my $xml_in;
 while ( -e ( $xml_in = $Xml_Log_File . '.' . $xml_cnt ) )
 {
  if( open( XMLIN, $xml_in))
  {
   while ( <XMLIN>){ print XML $_ };
   close XMLIN;
   unlink $xml_in;
  }
  $xml_cnt++;
 }
 print XML "</BuildSummary>\n";
 close XML;
}

#-- see if we should update Impact analysis
update_depend() if ( $Impact);

#-- Check for pre scripts (once per build, not once per activity)
my $log_file = join ('', '.log/', $Build_Job_Name, '-', $Build_Date, '.log');
$log_file =~ s|\s+|_|g;
$log_file = lc $log_file;
( my $log_job_file = $Build_Job_Name ) =~ s|\s+|_|g ;
$log_job_file = lc $log_job_file;

my $om_log_dir = $Submit_Build_Dir || "";
$om_log_dir    =~ s/[\\\/]$//;
my $om_log     = $om_log_dir . '/' . $log_file;

#-- determine # of preceding log files to keep
my $max_log = $ENV{OM_PREV_LOGS} || 5;
$max_log++ if ( -e $om_log );

opendir( LOGS, "$om_log_dir/.log" );
my @logs = map "$om_log_dir/.log/$_",
            grep { /^$log_job_file/ && -f "$om_log_dir/.log/$_" } readdir(LOGS);
closedir LOGS;

my $n_log = scalar @logs;
if ( $n_log > $max_log )
{
 #-- oldest listed first, so take last $max_log;
 $#logs = ( $n_log - $max_log );
 unlink @logs;
}

#-- JAG - 02.22.06 - case 6802. Even though a previous step failed with RC != 0
#   we have to exit like this b/c further steps depend on us.
exit $RC;

#------------------------------------------------------------------
sub update_depend
{
 my $file        = 'depend.xml';
 my @exts        = Openmake::getSubTaskExts();
 my @lookup      = qw( Level	ParentName	Name	FileDateTime Size URL Version HarvestEnv HarvestState);
 my $in_deparray = 0;
 my $in_header   = 1;
 my @add_nodes;
 my $last_dep;
 my $cur_dep;
 my %node;
 my ( $fh_out, $out_filename ) = tempfile( 'omdependXXXXXX', SUFFIX => '.xml', UNLINK => 0 );

 open( XML, '<', $file ) or die "$!: cannot open '$file'!\n";
 while ( <XML> )
 {
  if ( $in_header )
  {
   if ( /<Dependencies id=/ ) 
   {
    $in_header = 0; 
   }
   else
   {
    print $fh_out $_;
    next;
   }
  }
  if ( /<Dependencies id="deparray"/ )
  {
   $in_deparray++;
  }

  #-- see if we have the last dependency
  if ( /<Dependencies href="#dep(\d+)"/ )
  {
   $last_dep = $1;
   next;
  }

  if ( /<Dependencies id="dep(\d+)/ ) #"
  {
   $cur_dep = $1;
   next;
  }

  foreach my $k ( @lookup )
  {
   if ( /<$k\s+.+?>(.*?)<\/$k>/ )
   {
    $node{$k} = $1;
    next;
   }
  }

  if ( defined $node{"HarvestState"} )
  {
   #-- update the node if necessary
   %node = update_node( %node);
   print_node( $fh_out, $cur_dep, \%node);

   my @files;
   if ( @files = Openmake::getSubTaskFiles( $node{"Name"} ) )
   {
    #-- add to elements to spin $fh_out
    foreach my $file ( @files )
    {
     my $st        = stat( $file );
     my $full_path = cwd() . "/" . $file;
     if ( $^O =~ /MSWin|dos/i )
     {
      $full_path =~ s/\//\\/g;
     }
     else
     {
      $full_path =~ s/\\/\//g;
     }
  
     my %new_node = (
      Level        => $node{Level},
      ParentName   => $node{ParentName},
      Name         => $file,
      Size         => $st->size,
      FileDateTime => POSIX::strftime( "%m/%d/%Y %H:%M:%S", localtime($st->mtime()) ),
      URL          => $full_path
     );
     #print "Adding node $file Parent $node{ParentName} Level $node{Level}\n";
     push @add_nodes, \%new_node;
    } #-- End: foreach my $file ( @files )
   } #-- End: if ( @files = Openmake::getSubTaskFiles...


   undef %node;
  } #-- End: if ( defined $node{"Name"...
 } #-- End: while ( <XML> )

 close XML;

 #-- write out remaining XML

 if ( ! defined $last_dep ) { $last_dep = 0; } #-- JAG 10.16.06 - case 7502
 foreach my $node ( @add_nodes )
 {
  print_node( $fh_out, ++$last_dep, $node);
 } #-- End: foreach my $node ( @add_nodes...
 
 print $fh_out '<Dependencies id="deparray" xmlns:ns0="http://www.openmake.com" SOAP-ENC:arrayType="ns0:ImpactDependency[' , ($last_dep+1 ), ']" >', "\n";
 foreach my $n ( 0 .. $last_dep )
 {
  print $fh_out " <Dependencies href=\"#dep$n\"/>\n";
 }
 print $fh_out "</Dependencies>\n</SOAP-ENV:Body>\n</SOAP-ENV:Envelope>\n";
 close $fh_out;

 #-- push XML to KB Server via soap
 #-- TODO need to fork? here so that the upload can go on it's own
 print "Impact Analysis now uploading asynchronously.\n";
 if ( $^O =~ m{MSWin|dos}i )
 {
  #-- create the child process and let it run
  my $proc;
  my $cwd = cwd();
  my $prog_path = File::Spec->rel2abs($0);
  close STDOUT;
  close STDERR;
  my $perl = Win32::GetShortPathName($^X);
  my $ierr = 1;
  eval q{use Win32::Process ; use File::Spec; $ierr = Win32::Process::Create($proc, $perl, 'perl -S omcomplete.pl -gu '.$out_filename, 0, DETACHED_PROCESS| NORMAL_PRIORITY_CLASS, $cwd); };
  die "Unable to fork Impact analysis uploading because module 'Win32::Process' is missing: $@\n" if ( $@ );

  #-- create the child process and let it run
#  my $proc;
#  my $cwd = Cwd();
#  my $prog_path = rel2abs($0);
#  close STDOUT;
#  close STDERR;
#  Win32::Process::Create($proc, $prog_path, '-gu '.$out_filename, 0, DETACHED_PROCESS| NORMAL_PRIORITY_CLASS, $cwd);
 }
 else
 {
  #-- fork
  $SIG{CHLD} = 'IGNORE';
  my $pid = fork();
  if ( $pid == 0 )
  {
   POSIX::setsid;
   open STDOUT, '>/dev/null';
   open STDERR, '>/dev/null';
   upload_impact( $out_filename);
  }
 }
 
 #--
 #rename $out_filename, $file;

} #-- End: sub update_depend

#------------------------------------------------------------------
sub update_node
{
 my %node = @_;
 if ( -e $node{Name} && $node{Size} == 0 )
 {
  my $st = stat( $node{Name} );
  my $full_path = cwd() . "/" . $node{Name};
  if ( $^O =~ /MSWin|dos/i )
  {
   $full_path =~ s/\//\\/g;
  }
  else
  {
   $full_path =~ s/\\/\//g;
  }
  my %new_node = %node;
  $new_node{Size} = $st->size;
  $new_node{FileDateTime} = POSIX::strftime( "%m/%d/%Y %H:%M:%S", localtime($st->mtime()) );
  $new_node{URL} = $full_path;
  
  %node = %new_node
 }
 
 return %node;
}

#------------------------------------------------------------------
sub print_node
{
 no warnings 'uninitialized';
 
 my $fh_out = shift;
 my $dep    = shift;
 my $node   = shift;

 print $fh_out "<Dependencies id=\"dep$dep\" xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"ns0:ImpactDependency\" xsi:type=\"ns0:ImpactDependency\">\n";
 print $fh_out " <Level xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{Level}</Level>\n";
 print $fh_out " <ParentName xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{ParentName}</ParentName>\n";
 print $fh_out " <Name xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{Name}</Name>\n";
 print $fh_out " <FileDateTime xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{FileDateTime}</FileDateTime>\n";
 print $fh_out " <Size xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{Size}</Size>\n";
 print $fh_out " <URL xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{URL}</URL>\n";
 print $fh_out " <Version xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">Not Found</Version>\n";
 print $fh_out " <HarvestEnv xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{HarvestEnv}</HarvestEnv>\n";
 print $fh_out " <HarvestState xmlns:ns0=\"http://www.openmake.com\" xsi2:type=\"xsd2:string\" xsi:type=\"xsd2:string\">$node->{HarvestEnv}</HarvestState>\n";
 print $fh_out "</Dependencies>\n";
 
 return ;
}

#------------------------------------------------------------------
sub upload_impact
{
 my $out_filename = shift;
 Openmake::Log::HttpPost( $out_filename, "soap" );
 unlink $out_filename;
 return ;
}
