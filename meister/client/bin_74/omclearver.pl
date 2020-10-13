#!/usr/bin/perl
#
# omclearver.pl Version 1.1
#
# Openmake Clearcase get version information Utility
#
# Catalyst Systems Corporation 6/28/04
#   Updated for Openmake 6.3
#
#-- Perl wrapper to cleartool that plugs into Openmake build tool
#   to provide version control information.
#

=pod

=head1 OMCLEARVER.PL

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omclearver.pl is a perl script that "plugs-in" to om.exe
via the {-vp, -vc, -vr} command line flags. This script is used
to access version control information for items from Clearcase.
It is a wrapper to the Clearcase 'cleartool ls <file>' function.

The plugs into om.exe, and passes information back to om.exe via
the $VERSIONTOOL_RETURN variable.

=head1 ARGUMENTS

Since 'cleartool ls' takes few arguments, only two arguments are necessary
for omclearver.pl, and both are added by om.exe.

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


=head1 STRUCTURE

The execution of this script is as follows:

 1. parse the command line flags
 2. If the -h option is passed, print the header to the
    $VERSIONTOOL_RETURN variable and exit
 3. Construct the 'cleartool ls' command
 4. Execute the cleartool command
 5. Set the $VERSIONTOOL_RETURN variable with the output
    from 'cleartool'
 6. Exit

=cut

#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN = "                                                                     ";
our $RC                 = 0;
our $File;
our $Debug = 0;

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls cleartool
#-- cleartool ls %s ,FullPath);

if ( $ARGV[0] eq '-h' )
{
 #-- return the default pre 6.2 header.
	 $VERSIONTOOL_RETURN = "Version                                                              ";
}
elsif ( $ARGV[0] eq '-f' )
{
 $File = $ARGV[1];
 

 if ( -e $File )
 {
  my $cwd = `pwd`; #-- use `pwd` as SBT claims it's more reliable than Perl's
  $cwd  =~ s/\\/\//g;
  $cwd =~ s/\s+$//;

  $File =~ s/\\/\//g;
  my @t = split /\//, $File;
  my $file = pop @t;
  my $path = join "/", @t;

  chdir $path or die;

  my $verpgm = "cleartool";

  $verpgm = &FirstFoundInPath( $verpgm );
  unless ( $verpgm )
  {
   $VERSIONTOOL_RETURN = "                                                                     ";
   $RC                 = 0;
   goto EndOfScript;
  }

  $Tmp = Openmake::File->new($File);
  
  $verpgm .= " ls \"". $Tmp->getFE ."\"";
  print "Executing $verpgm\n";
  
  my @output = `$verpgm 2>&1`;
  $RC = $? >> 8;
 
  chdir $cwd or die "Couldn't change back to origin directory, '$cwd'.\n";
  
  my $line = $output[0];
  
  if ( $line =~ /ERROR 501|Pathname is not within a VOB/ ) {
  
   $VERSIONTOOL_RETURN = $Tmp->getFE . " is not in a VOB";
   $? = 0;
   $RC = 0;
   
   goto EndOfScript;
   
  } elsif ( $? == 0 ) {
  
   my $Rule = "";
   $RC = 0;
   
   ($VERSIONTOOL_RETURN,$Rule) = split(/Rule:/i,$line);

   
  } else {
  
   print "OMCLEARVER.PL ERROR (2):" . ($? >> 8) . "\n";
   print "$line\n\n";
   
   $VERSIONTOOL_RETURN = "";
   $RC = $? >> 8;
  }
  
 } ## end if ( -e $File )
 else
 {
  $? = 0;
  $RC= 0;
 }
 
} ## end elsif ( $ARGV[0] eq '-f' ...

EndOfScript:
$VERSIONTOOL_RETURN;
$RC;
