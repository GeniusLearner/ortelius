#!/usr/bin/perl
#######################################################################
#
# runant.pl
#
# wrapper script for invoking ant in a platform with Perl installed
# this may include cgi-bin invocation, which is considered somewhat daft.
# (slo: that should be a separate file which can be derived from this
# and returns the XML formatted output)
#
# the code is not totally portable due to classpath and directory splitting
# issues. oops. (NB, use File::Spec::Functions  will help and the code is
# structured for the catfile() call, but because of perl version funnies
# the code is not included.
#
# created:         2000-8-24
# last modified:   2004-3-4  (Jim Graham jim@openmake.com [comments as "JAG"])
#                            1. Changed file glob to a opendir/readdir
#                            2. Added \" quotes around classpath variables
#                            3. Changed "\" to "/" in classpath variables
# author:          Steve Loughran steve_l@sourceforge.net
#######################################################################
#
# Assumptions:
print "Running $0 @ARGV\n";

# - the "java" executable/script is on the command path
# - ANT_HOME has been set
# - target platform uses ":" as classpath separator or perl indicates it is dos/win32
# - target platform uses "/" as directory separator.

#be fussy about variables
use strict;

#platform specifics (disabled)
#use File::Spec::Functions;

#turn warnings on during dev; generates a few spurious uninitialised var access warnings
#use warnings;

#and set $debug to 1 to turn on trace info
my $debug=0;

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

#if Java home is defined, look for tools.jar & classes.zip and add to classpath
my $JAVA_HOME = $ENV{JAVA_HOME};
if ($JAVA_HOME ne "")
        {
        my $tools="$JAVA_HOME/lib/tools.jar";
        if (-e "$tools")
                {
                $localpath .= "$s$tools";
                }
        my $rtjar="$JAVA_HOME/jre/lib/rt.jar";
        if (-e "$rtjar")
                {
                $localpath .= "$s$rtjar";
                }
        my $classes="$JAVA_HOME/lib/classes.zip";
        if (-e $classes)
                {
                $localpath .= "$s$classes";
                }
        my $classes="$JAVA_HOME/lib/classes.jar";
        if (-e $classes)
                {
                $localpath .= "$s$classes";
                }
        my $classes="$JAVA_HOME/Classes/classes.jar";
        if (-e $classes)
                {
                $localpath .= "$s$classes";
                }
        my $classes="$JAVA_HOME/../Classes/classes.jar";
        if (-e $classes)
                {
                $localpath .= "$s$classes";
                }
        }
else
        {
    print "\n\nWarning: JAVA_HOME environment variable is not set.\n".
                "If the build fails because sun.* classes could not be found\n".
                "you will need to set the JAVA_HOME environment variable\n".
                "to the installation directory of java\n";
        }

#jikes
#-- JAG - add \" around JIKESPATH
my @ANT_OPTS=split " ", $ENV{ANT_OPTS};
if($ENV{JIKESPATH} ne "")
        {
        push @ANT_OPTS, "-Djikes.class.path=\"$ENV{JIKESPATH}\"";
        }

# Strip quotes from buildfile and Defines
# Can hose the static analysis commands in some cases
# on UNIX (found on Solaris)

map { s/\"//g } @ARGV
 unless $^O =~ /win/i;

#construct arguments to java

#-- JAG - add \" around $localpath and ant.home
my @ARGS;
push @ARGS, "-classpath", "\"$localpath\"", "-Dant.home=\"$HOME\"";
push @ARGS, @ANT_OPTS;
push @ARGS, "org.apache.tools.ant.Main";
push @ARGS, @ARGV;

print "\n $JAVACMD @ARGS\n\n" if ($debug);

my @returnValue =  `$JAVACMD @ARGS`;
my $RC = $?;

foreach my $line (@returnValue)
{
 if ($line =~ m{\[java\]\s*(\d)\s*errors})
 {
  $RC = 1 if ($1 > 0);
 }
 if ($line =~ m{Java Result: (\d)})
 {
  $RC = 1 if ($1 > 0);
 }
}

print @returnValue;	
if ($RC eq 0)
        {
		 exit 0;
        }
else
        {
        # only 0 and 1 are widely recognized as exit values
        # so change the exit value to 1
        exit 1;
        }
