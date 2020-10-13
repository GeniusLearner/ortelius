use Cwd;

$JavaExe = $ENV{'JAVA_HOME'} . "\\bin\\java";

#######################################################################
#
# check to make sure environment is setup
#

my $HOME = $ENV{ANT_HOME};

$HOME = $ENV{'PERLLIB'} . "/../.." if ($HOME eq "");

if ($HOME eq "../..")
        {
    die "\n\nANT_HOME *MUST* be set!\n\n";
        }


my $JAVACMD = $ENV{JAVACMD};
$JAVACMD = "java" if $JAVACMD eq "";

#build up standard classpath
my $localpath=$ENV{CLASSPATH};
if ($localpath eq "")
{
 print "warning: no initial classpath\n" if ($debug);
 #-- JAG - add localdir

 $localpath=".";
}

#ISSUE: what java wants to split up classpath varies from platform to platform
#and perl is not too hot at hinting which box it is on.
#here I assume ":" 'cept on win32 and dos. Add extra tests here as needed.

my $s=":";
if ($^O =~ /MSWin|dos/i)
{
 $s=";";
 #-- JAG switch slashes in ANT_HOME and CLASSPATH
 $HOME =~ s/\\/\//g;
 $localpath =~ s/\\/\//g;
}

#add jar files. I am sure there is a perl one liner to do this.
#-- JAG - if $HOME has a space, this glob gets messed up.
#my $jarpattern="$HOME/lib/*.jar";
#my @jarfiles =glob($jarpattern);

opendir (DIR, "$HOME/lib" );
my @jarfiles = grep { $_ =~ /\.jar$/ } map "$HOME/lib/$_", readdir DIR;
close DIR;

print "jarfiles=@jarfiles\n" if ($debug);
my $jar;
foreach $jar (@jarfiles )
        {
        $localpath.="$s$jar";
        }

$ClassPath = $ENV{'OPENMAKE_HOME'} . "\\bin\\omint.jar;" . 
             $ENV{'OPENMAKE_HOME'} . "\\bin\\commons-codec-1.3.jar;" .
             $ENV{'OPENMAKE_HOME'} . "\\bin\\commons-httpclient-3.1.jar;" .
             $ENV{'OPENMAKE_HOME'} . "\\bin\\commons-logging.jar;" .
            $localpath . ";";
$AntHome =   $HOME;

$cwd = getcwd;

if ( $^O =~ /MSWin|dos/i )
{
 $JavaExe =~ s/\//\\/g;
 $ClassPath =~ s/\//\\/g;
 $AntHome =~ s/\//\\/g;
 $cwd =~ s/\//\\/g;
}
else
{
 $JavaExe =~ s/\\/\//g;
 $ClassPath =~ s/\\/\//g;
 $ClassPath =~ s/;/:/g;
 $AntHome =~ s/\\/\//g;
 $cwd =~ s/\\/\//g;
}

$ENV{'ANT_HOME'} = $AntHome;

for ( $i = 0 ; $i < @ARGV ; $i++ )
{

 $_ = $ARGV[$i];

 $ArgType = "class", $i++ if ( /^-class$/i );
 $ArgType = "log", $i++ if ( /^-log$/i );
 $ArgType = "src", $i++ if ( /^-src$/i);
 $ArgType = "rn",  $i++ if ( /^-rn$/i );
 $ArgType = "cp",  $i++ if ( /^-cp$/i );
 $ArgType = "usercp",  $i++ if ( /^-usercp$/i ); 
 $ArgType = "if",  $i++ if ( /^-if$/i ); 
 $ArgType = "ef",  $i++ if ( /^-ef$/i );  
 $ArgType = "wf",  $i++ if ( /^-wf$/i );
 $ArgType = "config",  $i++ if ( /^-config$/i ); 
 print "ArgType: $ArgType\n" if $debug;

 if ( $i < @ARGV )
 {
  $classfile .= "$ARGV[$i] " if ( $ArgType eq "class" );
  $log .= "$ARGV[$i] " if ( $ArgType eq "log" );
  $src .= "$ARGV[$i] " if ( $ArgType eq "src" );
  $rn  .= "$ARGV[$i] " if ( $ArgType eq "rn" );
  $cp  .= "$ARGV[$i] " if ( $ArgType eq "cp" );
  $usercp  .= "$ARGV[$i] " if ( $ArgType eq "usercp" );  
  $incf  .= "$ARGV[$i] " if ( $ArgType eq "if" );  
  $excf  .= "$ARGV[$i] " if ( $ArgType eq "ef" );    
  $wf  .= "$ARGV[$i] " if ( $ArgType eq "wf" );
  $config  .= "$ARGV[$i] " if ( $ArgType eq "config" );  
 }
} ## end for ( $i = 0 ; $i < @ARGV...

$classfile =~ s/\s$//g;
$log =~ s/\s$//g;
$log =~ s/\\&/&/g;
$src =~ s/\s$//g;
$rn =~ s/\s$//g;
$cp =~ s/\s$//g;
$usercp =~ s/\s$//g;
$incf =~ s/\s$//g;
$excf =~ s/\s$//g;
$wf =~ s/\s$//g;
$config =~ s/\s$//g;

@parts = split(/&|\?/,$log);

foreach $part (@parts)
{
 $part =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
 @keyval = split(/=/,$part);
 $loginfo{$keyval[0]} = $keyval[1];
}

$kb = $parts[0];
$kb = substr($kb,0,length($kb) - length("/OMDisplayLog"));

@parts = split(/ /,$loginfo{'DateTime'});

$loginfo{'LogDate'} = $parts[0];
$loginfo{'LogTime'} = $parts[1];

$cmd = "\"" . $JavaExe . "\" " . $classfile . " -wf \"" . $wf .  "\" -rn \"" . $rn .  "\" -kb " . $kb . " -wd \"" . $cwd . "\"" .
 " -lm \"" . $loginfo{'Machine'} . "\" -lo \"" . $loginfo{'UserName'} . "\" -ld " . $loginfo{'LogDate'} . " -lt " . $loginfo{'LogTime'};

$cmd .= " -lp" if ($loginfo{'PublicBuildJob'} =~ /true/i);
$cmd .= " -src \"" . $src . "\"" if ($src ne "");
$cmd .= " -usercp \"" . $usercp . "\""  if ($usercp ne "");
$cmd .= " -toolcp \"" . $cp . "\""  if ($cp ne "");
$cmd .= " -if \"" . $incf . "\""  if ($incf ne "");
$cmd .= " -ef \"" . $excf . "\""  if ($excf ne "");
$cmd .= " -config \"" . $config . "\""  if ($config ne "");

$ENV{'CLASSPATH'} = $ClassPath;
#printf "CLASSPATH=$ClassPath\n$cmd 2>&1\n";  


print "$cmd\n";
@lines = `$cmd 2>&1`;
$rc = $? >> 8;

foreach $line (@lines)
{
 $line =~ s/</&lt;/g;	
 $line =~ s/>/&gt;/g;	
 print $line;
}
exit($rc);  
