#!/usr/bin/perl
#=============================================
# create-tar-installers.pl
#
#-- Creates tar installers from Meister eclipse plugins
#   Currently supports aix, hpux, linux, and solaris
#
# $Header: /CVS/openmake7/tools/headless_installer/create-tar-installers.pl,v 1.2 2012/04/13 19:15:09 steve Exp $
#
# Catalyst Systems Corp: (notifysupport@openmakesoftware.com)
# 
# Copyright 2012, Catalyst Systems Corp


use Getopt::Long;
use Archive::Extract;
use Archive::Tar;
use File::Path;
use File::Copy;
use File::Find;
use Cwd;
use strict;
use warnings;

our @filelist;

my $choose_os = "";
my $choose_dir = "";
my $plugins_dir = '/ombuild/750/linux-rocket/java/build/RELEASE/java';
my $installer_script = '/home/meister/git/openmake75/tools/headless_installer/installer.pl';

my $DL = ($^O =~ /win/i) ? "\\" : '/';

# we use $version and @OSes to find our plugins
my $version = '7.5.0';
my @OSes = ('aix', 'hp', 'linux', 'sun');

# Divide plugins into KBS plugins and client plugins
my @kbs_plugins = ('com.openmake.kbs.core.business_X_VERSION_X.jar', 'com.openmake.kbs.core.framework_X_VERSION_X.jar', 'com.openmake.kbs.core.meta.meister_X_VERSION_X.jar', 'com.openmake.kbs.core.meta_X_VERSION_X.jar');

my @client_plugins = ('com.openmake.meister.core.native_X_VERSION_X.jar', 'com.openmake.meister.core.native.X_OS_X_X_VERSION_X.jar', 
'com.openmake.workflow.core.native.X_OS_X_X_VERSION_X.jar', 'com.openmake.workflow.core.native_X_VERSION_X.jar'); 

#Note: X_OS_X and X_VERSION_X are delimited by underscores, "X_OS_X_X_VERSION_X" looks wrong but it's right


GetOptions( 'os:s' => \$choose_os, 
	    'dir:s' => \$choose_dir) 
	    or die "FATAL: Unrecognized option";

my $OSes_skipped = 0;
if ($choose_os)
{
 for (0 .. @OSes - 1)
 {
  next if $choose_os =~ /$OSes[$_]/i;
  $OSes[$_] = "";
  $OSes_skipped ++;
 }
}

$kbs_plugins[$_] =~ s{X_VERSION_X}{$version} for (0 .. @kbs_plugins - 1);
$client_plugins[$_] =~ s{X_VERSION_X}{$version} for (0 .. @client_plugins - 1);


die "-os option was selected but no valid OSes were specified!" if ($OSes_skipped == @OSes);

if ($choose_dir)
{
 die "Destination directory does not exist or is not writable!" unless ((-d $choose_dir) && (-w $choose_dir));
 chdir ($choose_dir) or die "Cannot change to directory: '$choose_dir'";
}

unless (-d 'kbserver')
{
 mkdir ('kbserver') or die "Cannot make directory: 'kbserver'"; 
}

unless (-d 'common_client')
{
 mkdir ('common_client') or die "Cannot make directory: 'common_client'"; 
}

print "\nCopying KB server and common client plugins ...\n\n";
foreach my $plugin (@kbs_plugins)
{
 copy ($plugins_dir . $DL . $plugin, 'kbserver');
}
foreach my $plugin (@client_plugins)
{
 next if $plugin =~ m/X_OS_X/;
 copy ($plugins_dir . $DL . $plugin, 'common_client');
}

foreach my $os (@OSes)
{
 next unless ($os);
 print "Beginning tar installer creation for OS: $os\nCreating client and kbserver directories ...\n";
 mkpath($os . $DL . 'client') unless (-d $os . $DL . 'client');
 mkpath($os . $DL . 'kbserver') unless (-d $os . $DL . 'kbserver');
 copy ($installer_script, $os) or die "Cannot copy file: 'installer.pl'";
 print "Copying and extracting needed KB server plugins ...\n";
 foreach my $plugin (@kbs_plugins)
 {
  copy('kbserver' . $DL . $plugin, $os . $DL . 'kbserver');
  my $ae = Archive::Extract->new( archive => $os . $DL . 'kbserver' . $DL . $plugin );
  my $ok = $ae->extract( to => $os . $DL . 'kbserver');
 } 
 print "Copying and extracting needed client plugins ...\n";
 foreach my $plugin (@client_plugins)
 {
  my $subbed_plugin = $plugin;
  if ($subbed_plugin =~ m/X_OS_X/)
  {
   $subbed_plugin =~ s/X_OS_X/$os/;
   copy ($plugins_dir . $DL . $subbed_plugin, $os . $DL . 'client');
  }
  else
  {
   copy('common_client' . $DL . $subbed_plugin, $os . $DL . 'client');
  }
  my $ae = Archive::Extract->new( archive => $os . $DL . 'client' . $DL . $subbed_plugin ); 
  my $ok = $ae->extract( to => $os . $DL . 'client'); 
 }
 my $cwd = cwd();
 chdir ($os) or die "Cannot change to directory: '$os'";
 @filelist = ();
 find(\&get_tar_contents, '.');
 Archive::Tar->create_archive( 'meister_' . $version . '_' . $os . '_headless_install.tgz', COMPRESS_GZIP, @filelist );
 chdir ($cwd) or die "Cannot change to directory: '$cwd'";
 print "Creation of tar installer for OS: $os complete!\n\n";
}

foreach my $os (@OSes)
{
 move ($os . $DL . 'meister_' . $version . '_' . $os . '_headless_install.tgz', '.') or die "Cannot move tar file for OS: $os";
}


sub get_tar_contents
{
 unless (($File::Find::name =~ m/META-INF/) || ($File::Find::name =~ m/com.openmake/) || ($File::Find::name =~ m/instom/))
 {
  my $relfile = $File::Find::name;
  $relfile =~ s{^\.\/}{};
  push ( @filelist, $relfile) if (-f $_);
 }
}
