# omsvnver.pl Version 1.0
#
# Openmake Subversion version command utility
#
# Catalyst Systems Corporation          Dec 30, 2005
#
#-- Perl wrapper to Subversion commands that plugs into
#   Openmake build tool

=head1 omsvnver.pl

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omsvnver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script while the om.exe
executable is running, and has access to certain Openmake-specific
information.

This command will do a SVN 'log' on files in the Openmake
Search Path to determine if these files are under SVN Version Control.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file or the
rules file.

There must be a space between the switch and its argument


-h                      : print header.

-f <fullpath>/filename  : name of file to check.

=cut


#=====================================
#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN = "                                                                     ";
our @VERSIONTOOL_RETURN;
our $RC = 0;
our $File;
our $Debug = 0;
our $Format_String = "%-150.150s;  %-20.20s;  %-20.20s;";
our $Max_Cmd_Length = 512; #-- max length of the command line to run

#-- tell om that we support passing in an array of files.
our $Supports_Multifile = 1;

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls svn

if ( $ARGV[0] eq '-h' )
{
 $VERSIONTOOL_RETURN = sprintf( $Format_String, "URL", "Revision", "Last Change User");
}
else
{
 my @full_files = @_;
 my $verpgm = "svn";
 my %return_hash = ();

 $verpgm = FirstFoundInPath( $verpgm );
 unless ( $verpgm )
 {
  $RC                 = 0;
  goto EndOfScript;
 }
 my %lists = parse_input_list( \@full_files );

 #-- for each directory for which we list files, execute at least one SVN command
 foreach my $dir ( keys %lists )
 {
  my @cmds;
  chdir $dir;

  my $cmd = $verpgm . ' info --non-interactive';
  my @files = @{$lists{$dir}};

  my $file_list;
  my @cmd_files;
  foreach my $file ( @files)
  {
   if ( length( $cmd ) + length( $file ) < $Max_Cmd_Length - 3 )
   {
    push @cmd_files, $file;
    $file = " \"$file\"";
    $cmd .= $file;
   }
   else
   {
    #-- roll
    my $last_cmd = $cmd;
    $last_cmd .= " 2>&1";
    my @last_cmd_files = @cmd_files;
    push @cmds, [ $last_cmd, \@last_cmd_files];
    $cmd = $verpgm . " status \"$file\"";

    @cmd_files = ( $file );
    $file = " \"$file\"";
   }
  }
  $cmd .= ' 2>&1';
  push @cmds, [ $cmd, \@cmd_files]; # get the last one

  foreach my $cref ( @cmds )
  {
   my $cmd = $cref->[0];
   my @dir_files = @{$cref->[1]};
   my @cout = `$cmd`;

   my @out = parse_svn_log( $cref->[1], \@cout);
   my $i = 0;
 
   #-- create a hash of files -> output so that we can put them back in the
   #   order that we received them.
   foreach my $d_file ( @dir_files)
   {
    my $path .= $dir . "/$d_file";
    $path =~ s{\\}{/}g;
    my $o = $out[$i];
    if ($path =~ /:/)
    {
     my @parts = split(/:/,$path);
     $parts[0] =~ tr/A-Z/a-z/;
     $path = join(':',@parts);
    }
    $return_hash{$path} = $o;
    $i++;
   }
  }
 }

 #-- sort thru in correct order now;
 foreach my $f ( @full_files )
 {
  my $d = $f;
  $d =~ s{\\}{/}g;
  push @VERSIONTOOL_RETURN, $return_hash{$d};
 }
}

#------------------------------------------------------------------
sub parse_input_list
{
 #-- subroutine to parse the input list of files to find a set of common
 #   directories to wildcard patterns. This is because CVS doesn't like
 #   absolute paths!
 #
 #   Don't do anything fancy. Just look at the directory alone
 my $ref = shift;
 my %paths;
 foreach my $file_path ( @{$ref} )
 {
  my $dir  = Openmake::File->new($file_path)->getDP();
  my $file = Openmake::File->new($file_path)->getFE();

  push @{$paths{$dir}}, $file;
 }
 return %paths;
}

#------------------------------------------------------------------
sub parse_svn_log
{
 my ($fref, $oref ) = @_;
 my @lines = @{$oref};
 my $line;
 my @out;

 #>svn info "Areas.java" "ClipAnim.java" "Intersection.java" "foo.java"
 #Path: Areas.java
 #Name: Areas.java
 #URL: file:///x:/testbed/scm-rep/svn/Repository/JFREERAILS/Java2Ddemo/java2d/demo
 #s/Clipping/Areas.java
 #Repository Root: file:///x:/testbed/scm-rep/svn/Repository
 #Repository UUID: 89c28a29-a478-8340-a3ac-712b47d8e55d
 #Revision: 20
 #Node Kind: file
 #Schedule: normal
 #Last Changed Author: Sean
 #Last Changed Rev: 10
 #Last Changed Date: 2006-02-21 20:34:35 -0500 (Tue, 21 Feb 2006)
 #Text Last Updated: 2006-09-13 19:16:25 -0400 (Wed, 13 Sep 2006)
 #Properties Last Updated: 2006-09-13 19:16:24 -0400 (Wed, 13 Sep 2006)
 #Checksum: d7d7fe611e31ec01d72c76d2f07990ca
 #
 #Path: ClipAnim.java
 # ...
 #Checksum: e44fc1ab43732e534e703a67d630085c
 #
 #Path: Intersection.java
 # ...
 #Checksum: 2e17709b69f483a43888cd7329496bdd
 #
 #foo.java:  (Not a versioned resource)

 #-- files are in order so should output
 foreach my $file ( @{$fref})
 {
  my ($url, $revision, $user  ) = ( " ", " ", " " ) ;
  while ( $line = shift @lines )
  {
   chomp $line;
   last if ( $line =~ m{Checksum:} || $line =~ m{Not a versioned resource} ); #-- found next entry
   if ( $line =~ m{Url:\s*(.+)}i)
   {
    $url = $1;
    $url =~ s{\t}{ }g;
    $url =~ s{\s+$}{};
   }
   if ( $line =~ m{Last Changed Rev:\s*(.+)}i )
   {
    $revision = $1;
    $revision =~ s{\t}{ }g;
    $revision =~ s{\s+$}{};
   }
   if ( $line =~ m{Last Changed Author:\s*(.+)}i )
   {
    $user = $1;
    $user =~ s{\t}{ }g;
    $user =~ s{\s+$}{};
   }
  }
  #-- make sure we got something
  my $output = sprintf( $Format_String, $url, $revision, $user );

  push @out, $output;
 }

 return @out;
}

EndOfScript:
$RC;
