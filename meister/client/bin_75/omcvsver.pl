# omcvsver.pl Version 2.0
#
# Openmake CVS version command utility
#
# Catalyst Systems Corporation          Jan 13, 2006
#
#-- Perl wrapper to CVS commands that plugs into
#   Openmake build tool

=head1 omcvsver.pl

=head1 LOCATION

program files/openmake6/bin

=head1 DESCRIPTION

omcvsver.pl is a perl script that "plugs-in" to bldmake.exe and om.exe
via the {-vp, -vc, -vr} command line flags. This script while the om.exe
executable is running, and has access to certain Openmake-specific
information.

This command will do a CVS 'log' on files in the Openmake
Search Path to determine if these files are under CVS Version Control.

=head1 ARGUMENTS

The following arguments can be placed in the configuration file or the
rules file.

There must be a space between the switch and its argument

-h                      : print header.

-f <fullpath>/filename  : name of file to check.

=cut


#=====================================
#Main


#-- Use statements
use Openmake;

#-- Openmake specific variables. Read by om.exe
our $VERSIONTOOL_RETURN = "                                                                     ";
our @VERSIONTOOL_RETURN;
our $RC                 = 0;
our $File;
our $Debug = 1;

#-- tell om that we support passing in an array of files.
#   Comment this out if you want to run CVS file by file
our $Supports_Multifile = 1;
our $Format_String = "%-40.40s  %-40.40s  %-160.160s  %-30.30s";
my @output = ();

#-- provides two sets of functionality.
#   1. if called with -h flag, provides a header
#   2. if called with -f <file>, calls svn

if ( $ARGV[0] eq '-h' )
{
 #-- return the default pre 6.2 header.
 $VERSIONTOOL_RETURN = sprintf( $Format_String, "Working Rev", "Rep Revision", "Module Path", "Status" );
}
else
{
 my @full_files = @_;
 my $verpgm = "cvs";
 my %return_hash = ();

 $verpgm = FirstFoundInPath( $verpgm );
 unless ( $verpgm )
 {
  $RC                 = 0;
  goto EndOfScript;
 }

 my $max_length = 512;
 my %lists = parse_input_list( \@full_files );

 foreach my $dir ( keys %lists )
 {
  my @cmds;
  chdir $dir;

  my $cmd = $verpgm . ' status';
  my @files = @{$lists{$dir}};

  my $file_list;
  my @cmd_files;
  foreach my $file ( @files)
  {
   if ( length( $cmd ) + length( $file ) < $max_length - 3 )
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
  $cmd .= " 2>&1";
  push @cmds, [ $cmd, \@cmd_files];; # get the last one

  foreach my $cref ( @cmds )
  {
   my $cmd = $cref->[0];
   my @dir_files = @{$cref->[1]};
   my @cout = `$cmd`;

   my @out = parse_vlog( $cref->[1], \@cout);
   my $i = 0;
   foreach my $d_file ( @dir_files)
   {
    my $path .= $dir . "/$d_file";
    $path =~ s{\\}{/}g;
    my $o = $out[$i];
    $return_hash{$path} = $o if ($return_hash{$path} eq "");
    $i++;
   }


   #push @VERSIONTOOL_RETURN, @out;
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


EndOfScript:
$RC;

#foreach my $o ( @VERSIONTOOL_RETURN ) { print $o, "\n"; }

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
sub parse_vlog
{
 my ($fref, $oref ) = @_;
 my @lines = @{$oref};
 my $line;
 my @out;

 # Example output from cvs status...
 #
 # ===================================================================
 # File: AquaMetalTheme.java       Status: Locally Modified
 #   Working revision:    1.1.1.1
 #   Repository revision: 1.1.1.1 /CVS/openmake6/examples/ref/metalworks/release/src/AquaMetalTheme.java,v
 #   Sticky Tag:          (none)
 #   Sticky Date:         (none)
 #   Sticky Options:      (none)

 if ( $lines[0] =~ m{=====} ) { shift @lines; }
 #-- files are in order so should output
 foreach my $file ( @{$fref})
 {
  my ($status, $working_revision, $rep_revision, $mod_path ) = ( " ", " ", " ", " ") ;
  while ( $line = shift @lines )
  {
   chomp $line;
   last if ( $line =~ m{=====} ); #-- found next entry
   if ( $line =~ m{File:\s*$file\s*Status:\s*(.+)}i)
   {
    $status = $1;
    $status =~ s{\t}{ }g;
    $status =~ s{\s+$}{};

   }
   if ( $line =~ m{Working\s+revision:\s*(.+)}i )
   {
    $working_revision = $1;
    $working_revision =~ s{\t}{ }g;
    $working_revision =~ s{\s+$}{};
   }
   if ( $line =~ m{Repository\s+revision:\s*(.+)}i )
   {
    $rep_revision = $1;
    $rep_revision =~ s{\t}{ }g;
    $rep_revision =~ s{\s+$}{};

    my @m_path;
    ($rep_revision, @m_path) = split /\s+/, $rep_revision;
    $mod_path = join ' ', @m_path;
   }
  }
  #-- make sure we got something
  my $output = sprintf( $Format_String, $working_revision, $rep_revision, $mod_path, $status);
  push @out, $output;
 }

 return @out;
}

