# $Header: /CVS/openmake7/src/java/com.openmake.workflow.core.native/bin/startrbs.pl,v 1.12 2011/07/05 20:01:22 steve Exp $
#
#-- script to find and start the RB Server. Needs to put the script into the background
#   so that the Server persists after the Client is closed
#
use warnings;
use strict;
use File::Spec;

#-- everything is hardwired
$| = 1; 

#-- find the install directory
my $full_path = File::Spec->rel2abs($0);
$full_path =~ s{\\}{/}g;
my @p = split /\//, $full_path;
pop @p; #-- script name
if ( $p[-1] eq 'bin')
{
 pop @p;
} 
my $install_dir = join '/', @p;
my $stdout      = $install_dir . '/buildserver/startrbs_stdout.log';
my $stderr      = $install_dir . '/buildserver/startrbs_stderr.log';

if ( $^O !~ m{mswin|dos}i )
{
 $ENV{PATH} = $ENV{PATH} . ":" . $install_dir . "/bin";
 chmod 0755, $install_dir . "/bin/omcpu";
}


my $java_cmd = 'java';
$java_cmd .= 'w.exe' if ( $^O =~ m{mswin|dos}i );

#-- configure the classpath
my $classpath = "";

if (-e $install_dir . "/bin/xerces.jar")
{
$classpath = 'XX_INSTALLDIR_XX/bin/omint.jar;XX_INSTALLDIR_XX/bin/log4j.jar;XX_INSTALLDIR_XX/bin/omcmdline.jar;XX_INSTALLDIR_XX/bin/IdooXoap.jar;XX_INSTALLDIR_XX/bin/commons-logging.jar;XX_INSTALLDIR_XX/bin/xerces.jar;XX_INSTALLDIR_XX/bin/castor.jar;XX_INSTALLDIR_XX/bin/omremotebuildserver.jar';
}
else
{
$classpath = 'XX_INSTALLDIR_XX/bin/omint.jar;XX_INSTALLDIR_XX/bin/log4j.jar;XX_INSTALLDIR_XX/bin/omcmdline.jar;XX_INSTALLDIR_XX/bin/IdooXoap.jar;XX_INSTALLDIR_XX/bin/commons-logging.jar;XX_INSTALLDIR_XX/bin/xercesImpl.jar;XX_INSTALLDIR_XX/bin/castor.jar;XX_INSTALLDIR_XX/bin/omremotebuildserver.jar';
}

$classpath =~ s{XX_INSTALLDIR_XX}{$install_dir}g;
$classpath =~ s{;}{:}g if ( $^O !~ m{mswin|dos}i );
$classpath =~ s{\\}{/}g;

#-- format the arguments
my $cmd;
if ( -e $install_dir . "/buildserver/rbs.ini" )
{
 open my $fh , '<', $install_dir . "/buildserver/rbs.ini";
 while ( <$fh> )
 {
  chomp;
  if ( s{^\s*JRE_DIR=}{} )
  {
   $cmd = $_ .'/bin/' . $java_cmd;
   $cmd =~ s{/}{\\}g if ( $^O =~ m{mswin|dos}i );
   last;
  }
 }
 close $fh;
}
unless ( -e $cmd )
{
 $cmd = FirstFoundInPath( $java_cmd );
}

my @args = ();
if ( $^O =~ m{mswin|dos}i )
{
 push @args, $java_cmd;
}
else
{
 push @args, $cmd;
}
push @args, '-Xms128m';
push @args, '-Xmx512m';
# push @args, '-Djava.class.path="' . $classpath . '"';  # SBT - Remove to shorten cmd line
push @args, '-cp';
push @args, $classpath;
push @args, 'com.openmake.remotebuildmanager.Main';
push @args, '-home';
push @args,  $install_dir . '/buildserver';
my $cmd_line = join ' ', @args;

if ( $^O !~ m{mswin|dos}i )
{
 require POSIX;
 import POSIX;
 
 #-- find and call the Start_KB scripts
 #-- fork before calling exec
 my $pid = fork;
 if ( $pid )
 {
  #-- write the pid into a temp file
  open my $fh, '>', $install_dir . '/buildserver/rbs.pid';
  print $fh "$pid\n";
  close $fh;
  
  #-- exit based as we are the parent shell;
  exit;
 }
 
 die "Could Not Fork: $!" unless defined( $pid );

 open STDOUT, '>', $stdout;
 open STDERR, '>', $stderr;

 print "Install Dir: $install_dir\n";
 print "Using: $cmd\n"; 
 print "CmdLine: $cmd_line\n";

 POSIX::setsid() or die "Could Not Start New Session: $!";
 exec ( @args);
} #-- End: if ( $^O !~ m{mswin|dos}i...
else
{
 #-- run the command. Use create process if it's available so that we can put it in the background
 #-- do the windows.
 #-- find a java command
 close STDOUT;
 close STDERR;
 
 open STDOUT, '>', $stdout;
 open STDERR, '>', $stderr;
 
 eval "use Win32; use Win32::Process; ";
 if ( $@ )  
 {
  #-- can't use create process, use next best thing;
  system( 1, @args);
 }
 else
 {
  no strict qw{ subs };  #-- prevents bareword subs error on NORMAL_PRIORITY_CLASS b/c it's loaded at run time 
  sub ErrorReport
  {
   print Win32::FormatMessage( Win32::GetLastError() );
  }
  my $process;
  
  #-- need to quote some args
  foreach my $a ( @args )
  {
   if ( $a =~ m{\s+} && $a !~ m{"} )
   {
    $a = '"' . $a . '"';
   }
  }
  $cmd_line = join ' ', @args;
  
   
  print "Install Dir: $install_dir\n";
  print "Using: $cmd\n"; 
  print "CmdLine: $cmd_line\n";
 
  Win32::Process::Create( $process,
                          $cmd,
                          $cmd_line,
                          0,
                          NORMAL_PRIORITY_CLASS | DETACHED_PROCESS, $install_dir )
                          || die ErrorReport();
                          ;
 
 }
}

#------------------------------------------------------------------
sub FirstFoundInPath
{
 my $cmd = shift;
 my @ele = split /;/, $ENV{'PATH'};
 foreach my $d ( @ele )
 {
  if ( -e $d . '/' . $cmd )
  {
   $cmd = $d . '/' . $cmd;
   last;
  }
 }
 
 $cmd =~ s{/}{\\}g;
 return $cmd ;
}




