#!/usr/bin/perl
use warnings;
use strict;
use File::Path;
use File::Spec;
use File::Copy;
use Getopt::Long;

my $Directory = File::Spec->curdir();
my $File = '';
my $Full_File = '';
my $Backup_File = '';
my $KB_Directory = '/catalyst_kb';
my $Backup_Directory = '/catalyst_kb/backup';
my $Max_Logs = 5;

GetOptions(
  'dir|d=s'  => \$Directory,
  'file|f=s' => \$File
          );

die "$0: Directory $Directory does not exist\n" unless ( -d $Directory );

#-- create the filename if necessary
unless ( $File )
{
 $File = sprintf 'catalyst_kb_bak_%4.4d%2.2d%2.2d.zip', (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3];
}
$Full_File = File::Spec->catfile( File::Spec->tmpdir(), $File);
$Backup_File = File::Spec->catfile( $Backup_Directory, $File);

#zip -r /tmp/foo.zip /catalyst_kb -x \*backup\*.zip
my $cmd = 'zip -r ' . $Full_File . ' ' . $KB_Directory . ' -x \*backup\*.zip';

#-- run the zip command
chdir '/' or die "$0: cannot chdir to root /: $!";
`$cmd`;
my $rc = $?;
if ( $rc )
{
 exit $rc;
}

#-- move and clean up zip files. Keep last 5 ?
move $Full_File, $Backup_File or die "$0: cannot move '$Full_File' -> '$Backup_File': $!";
opendir( my $lfh, $Backup_Directory );
my @logs = map "$Backup_Directory/$_", grep { /.zip$/ && -f "$Backup_Directory/$_" } readdir( $lfh);
closedir $lfh;

my $n_log = scalar @logs;
if ( $n_log > $Max_Logs )
{
 #-- oldest listed first, so take last $max_log;
 $#logs = ( $n_log - $Max_Logs );
 unlink @logs;
}

exit $rc;
