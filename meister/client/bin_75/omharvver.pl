#!/usr/bin/perl
#
# omharvver.pl Version 1.2
#
# Openmake Harvest get version information Utility
#
# Catalyst Systems Corporation Mar 12, 2004
#   Updated for Openmake 6.3
#
#-- Perl wrapper to hsigget that plugs into Openmake build tool
#   to provide version control information.
#

=pod

=head1 OMHARVVER.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omharvver.pl is a perl script that "plugs-in" to om.exe
via the {-vp, -vc, -vr} command line flags. This script is used
to access version control information for items from Harvest.
It is a wrapper to the Harvest 'hsigget' function.

The plugs into om.exe, and passes information back to om.exe via
the $VERSIONTOOL_RETURN variable.

=head1 ARGUMENTS

Since 'hsigget' takes few arguments, only two arguments are necessary
for omharvver.pl, and both are added by om.exe.

=over 2

=item -h :

Prints header. Used by om.exe to determine the format of
the Bill of Materials log.

=item -f <filename>:

name of file to check. Used by om.exe.

=back

=head1 RETURN CODES

The script returns the following:

 0 : Success
 1 : File doesn't exist on file system
 2 : Could not change to directory in path part of the filename

 Hsigget errors are bitshifted up 8 bits.

 256 : Hsigget error 1 -- syntax error
 768 : Hsigget error 3 -- failed in an expected manner, unless the
                          log file states
                          "Warning: .. not in the signature file"
1024 : Hsigget error 4 -- failed in an unexpected manner

Note that hsigget error -1 (no .hsig file) is treated as a success,
because it's possible to call this script on a file not under harvest's
control.

Also, different versions of 'hsigget' treat not finding the file under
version control differently.

Recent versions will state:

 Information for file '<file>' is not in the signature file
 Harvest (hsigget) command completed successfully.

 RC = 0

Older versions will state:

 Warning: Information for file '<file>' is not in the signature file.
 Harvest (hsigget) command completed with warning.

 RC = 3

=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. If the -h option is passed, print the header to the
    $VERSIONTOOL_RETURN variable and exit
 3. Construct the 'hsigget' command
 4. Execute the hsigget command
 5. Set the $VERSIONTOOL_RETURN variable with the output
    from 'hsigget'
 6. Exit

=cut

#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN = "                                                                     ";
our $RC                 = 0;
our $File;
our $Debug = 0;
our $cwd = "";

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls hsigget
#-- hsigget -t -o %s %s -a environment state version versionid ,TempOutput,FullPath);

if ( $ARGV[0] eq '-h' )
{
 #-- return the default pre 6.2 header.
 $VERSIONTOOL_RETURN = "Project                  View                     Version Object Id  ";
}
elsif ( $ARGV[0] eq '-f' )
{
 $File = $ARGV[1];

 if ( -e $File )
 {
  use File::Temp qw/ tempfile /;
  my $tempout;

  #-- JAG - 11.07.03 - fix location of temp file, since we bounce around the
  #                    filesystem. Remove DIR => "." so that we pick up
  #                    tmpdir() location.
  #                    On UNIX, tmpdir() is
  #                       $ENV{TMPDIR}
  #                       /tmp
  #                    On Windows, tmpdir() is
  #                       $ENV{TMPDIR}
  #                       $ENV{TEMP}
  #                       $ENV{TMP}
  #                       C:/temp
  #                       /tmp
  #                       /
  ( undef, $tempout ) = tempfile( OPEN => 0 );
  print "Temp file: $tempout\n" if ( $Debug) ;

  my $hsigcmd = "hsigget";
  if ( $^O =~ /MSWin|os2|dos/i )
  {
   $hsigcmd = "hsigget.exe";
  }
  $hsigcmd = &FirstFoundInPath( $hsigcmd );
  unless ( $hsigcmd )
  {
   $VERSIONTOOL_RETURN = "                                                                     ";
   $RC                 = 0;
   goto EndOfScript;
  }

  #-- JAG - 03.11.04 - need to change to directory to run hsigget.
  #-- use `pwd` as SBT claims it's more reliable than Perl's
  
   $cwd = `pwd`;

  
  chomp $cwd;
  $cwd  =~ s/\\/\//g;
  $File =~ s/\\/\//g;
  my @t = split /\//, $File;
  my $file = pop @t;
  my $path = join "/", @t;

  if ( $path ) { #-- case 4941 opportunistic fix
   unless ( chdir($path) )
   {
    $RC = 2;
    goto EndOfScript;
   }
  }

  $hsigcmd .= " -t -o \"$tempout\" \"$file\" -a environment state version versionid";
  my @output = `$hsigcmd`;
  $RC = $? >> 8;
  if ( $RC == 0 )
  {
   #-- open the temp file and read it
   open( TMP, $tempout );
   my @hsigout = <TMP>;
   close TMP;
   unlink $tempout;

   #-- output should be one line only (for the one file, and tab separated)
   my $line = $hsigout[0];
   if ( $line =~ /Warning:/i || $line =~ /not in the signature file/ )
   {
    #-- there's no info in .hsig about this file. Return
    $VERSIONTOOL_RETURN = "                                                                     ";
    $RC = 0;
    goto EndOfScript;
   }

   chomp $line;
   my ( $file, $project, $state, $version, $verid ) = split /\t/, $line;

   #-- create the version control string, same format as before
   $VERSIONTOOL_RETURN = sprintf( " %-24.24s %-24.24s %-7.7s %-11.11s", $project, $state, $version, $verid );
  }
  else #-- non-zero exit code from Harvest.
  {
   #-- Hsigget does some bad things with RC.
   #    it returns -1 if it can't find the .hsig file, and -1 can get bitshifted around to be
   #    a nonsense variable
   #    1 -- syntax error
   #    3 -- failed expected
   #    4 -- failed unexpected
   if ( $RC == 1 || $RC == 4 )
   {
    #-- bit shift up 8 bits,
    $RC = $RC << 8;
   }
   elsif ( $RC == 3 )
   {
    #-- open the temp file and read it
    open( TMP, $tempout );
    my @hsigout = <TMP>;
    close TMP;
    unlink $tempout;

    #-- output should be one line only (for the one file, and tab separated)
    my $line = $hsigout[0];

    if ( $line =~ /Warning:/i || $line =~ /not in the signature file/ )
    {
     #-- there's no info in .hsig about this file. Return
     $VERSIONTOOL_RETURN = "                                                                     ";
     $RC = 0;
     goto EndOfScript;
    }
    else
    {
     $RC = 3;
     $RC = $RC << 8;
    }
   }
   else
   {
    $RC = 0;
   }
  }
 } ## end if ( -e $File )
 else
 {
  $RC = 1;
 }
} ## end elsif ( $ARGV[0] eq '-f' ...

EndOfScript:

#-- JAG - 08.04.04 - need to chdir back to location
chdir($cwd) if ( $cwd );

$VERSIONTOOL_RETURN;
$RC;
