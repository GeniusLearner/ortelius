use POSIX;
use Getopt::Long;
use Pod::Usage;
use File::stat;
use File::Path;

my $Help = 0;
my $Version = 641;
my $Build_Number;
my $Meister_Build_Number;
my $File = 'omver.h';
#-- hardcoded for now
my $Meister_File = 'F:/CVS/openmake7/src/java/com.openmake.core/src/com/openmake/core/resources.properties';
my $Local_Meister_File = 'com.openmake.core/src/com/openmake/core/resources.properties';
my $Local_Meister_Dir  = 'com.openmake.core/src/com/openmake/core';
my $Year = (localtime())[5]+1900;

GetOptions(
 'help|h'      => \$Help,
 'version|v=i' => \$Version,
 'number|n=s'  => \$Build_Number,
 'meister|m=s' => \$Meister_Build_Number,
 'file|f=s'    => \$File

) or pod2usage( -verbose => 1) && exit;

pod2usage( -verbose => 1 ) if ( $Help );

#-- set results based on inputs
$Build_Number = POSIX::strftime( "%m%d%y", localtime()) unless ( $Build_Number) ;

#-- split off version
$Version =~ /(\d)(\d+)/;
my $major = $1;
my $minor = $2;

#-- get the timestamp of the current omver file
print "Local time is ", scalar localtime(), "\n";
my $mod_time = 0;
if ( -e $File )
{
 my $st = stat($File);
 $mod_time = $st->mtime();
 print "Mod time of $File is ", scalar localtime($mod_time), "\n";
}

#-- write the file
open( OMVER, '>', $File ) or die "Error: Cannot open '$File' for writing: $!\n";
print OMVER "#define OPENMAKE_VERSION \"${major}.${minor} Build $Build_Number\"\n";

my $lead_minor = substr( $minor, 0, 1);

#-- JAG - 10.11.07 - for 7.0 builds we want the version to report as 7.0,
#   but still use the OPENMAKE_MAJOR_VERSION as 6.4 (because that's what the
#   Perl modules use)
$lead_minor = 4 if ( $major >= 7 );

if ( $lead_minor >= 4 )
{
 print OMVER "\n#define OPENMAKE_MAJOR_VERSION \"6.${lead_minor}\"\n";
 print OMVER "#define OPENMAKE_COPYRIGHT \"Copyright 1995-$Year\"\n";
}

close OMVER; #-- has to come before utime

if ( $mod_time )
{
 utime $mod_time, $mod_time, $File;

 my $st = stat($File);

 print "Mod time of $File is ", scalar localtime($st->mtime()), "\n";

}

#-- do the resources
#-- get the timestamp of the current omver file
$mod_time = 0;
if ( -e $Meister_File )
{
 my $st = stat($Meister_File);
 $mod_time = $st->mtime();

 #-- write the file
 #-- make the directories
 mkpath( [ $Local_Meister_Dir ], 0777 );
 open( OMVER, '>', $Local_Meister_File ) or die "Error: Cannot open '$Local_Meister_File' for writing: $!\n";

 open( OMIN, '<', $Meister_File );

 while( <OMIN> )
 {
  if ( m{BUILD_NUMBER=XX_BUILD_NUMBER_XX} )
  {
   print OMVER "BUILD_NUMBER=$Meister_Build_Number\n";
  }
  else
  {
   print OMVER $_;
  }
 }
 close OMIN;
 close OMVER; #-- has to come before utime

 if ( $mod_time )
 {
  utime $mod_time, $mod_time, $Local_Meister_File;
  my $st = stat($Local_Meister_File);
  print "Mod time of $Local_Meister_File is ", scalar localtime($st->mtime()), "\n";
 }

 #-- also update the about.mappings file
 mkpath( [ 'com.openmake.application' ], 0777 );
 open ( OMVER, '>', 'com.openmake.application/about.mappings');
 print OMVER "0=$major.$minor\n";
 print OMVER "1=$Meister_Build_Number\n";
 print OMVER "2=$Year\n";
 close OMVER;


}
__END__

=pod

=head1 NAME

om_gen_omver.pl -- Generate omver.h for C/C++ command line build

=head1 VERSION

This document describes om_gen_omver.pl version 0.0.1

=head1 SYNOPSIS

     > om_gen_omver.pl [options]

     > om_gen_omver.pl -v 641 -n 051105

=head1 OPTIONS

=over 4

=item help|h

Print Help

=item version|v

Openmake version number. Defaults to '641'

=item number|n

Build Number (6 digit). Defaults to current 'yyMMdd'

=item file|f

Name of header file. Defaults to 'omver.h'

=back

=head1 DIAGNOSTICS

=over 4

=item C<Error: Cannot open '$File' for writing: $!>.

Could not open header file for output

=back

=head1 CONFIGURATION AND ENVIRONMENT

om_gen_omver.pl requires no configuration files or environment variables.

=head1 DEPENDENCIES

=over 4

=item C<POSIX>

=item C<Getopt::Long>

=item C<Pod::Usage>

=item C<File::Stat>

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 AUTHOR

Jim Graham

=head1 LICENCE AND COPYRIGHT

Copyright(c) 2006, Catalyst Systems Corp

This module is unpublished proprietary software; you cannot redistribute it
outside of Catalyst Systems Corp.

=cut
