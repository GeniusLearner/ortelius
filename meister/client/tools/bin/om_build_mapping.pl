use warnings;
use strict;

use Cwd;
use POSIX;
use File::Copy;
use Getopt::Long;
use Pod::Usage;
use Net::Telnet;

my $Help = 0;
my $Version = 700;
my $Build_Number;
my $Build_Job;

GetOptions(
 'help|h'      => \$Help,
 'version|v=i' => \$Version,
 'number|n=s'  => \$Build_Number,
 'job|j=s'     => \$Build_Job

) or pod2usage( -verbose => 1) && exit;

pod2usage( -verbose => 1 ) if ( $Help );

#-- mapping of files. Can be added to later
#'700' => 'C:/CVS/openmake7/build'
#'700' => 'V:/openmake-700_TRUNK/build'
my %CVS_Root = ( '700' => 'F:/CVS/openmake7/build' 
                ); 
if ( ! $CVS_Root{$Version} )
{
 exit;
}

#-- get the time on CVS server. This is a hack
#my $prompt = '/\[steve\@schwinn steve\]\$/';
#my $telnet = Net::Telnet->new( 'Timeout' => 60, Prompt => $prompt );
#$telnet->open("schwinn");
#$telnet->login('steve', '1lbear'); #-- now you know my password
#my @lines = $telnet->cmd( 'date; date -u' );
#$telnet->close();
my @lines = `rsh schwinn -l steve date;date -u`;

foreach (@lines)
{
 print "$_ \n";
}

my $date = $lines[0];
chomp $date;
my $utc_date = $lines[1];
chomp $utc_date;

print "Time on CVS server is: ", $date, " UTC Time: ", $utc_date, "\n";
print "Adding Job: ", $Build_Job, " and Number: ", $Build_Number, "\n";

#-- format the string
my $format_build_job    = sprintf ( '%-40.40s', $Build_Job );
my $format_build_number = sprintf ( '%-10.10s', $Build_Number );

#-- check out the build mappings file
my $dir = cwd();
chdir $CVS_Root{$Version};

#-- open the file, and put the mapping at the top of the file
my $mapping_file = 'build_mappings.txt';
my $temp_file = $mapping_file. '.tmp';

print qx{ cvs update  };

open ( my $rfh, '<', $mapping_file );
open ( my $fh, '>', $temp_file);

my $line_in = 0;
while ( <$rfh> )
{
 if ( m{^\s*#} or $line_in)
 {
  print $fh $_; 
 }
 else
 {
  print $fh $format_build_job, "\t", $format_build_number, "\t", $date, "\t", $utc_date, "\n";
  print $fh $_;
  $line_in++;
 }
}
close $rfh;
close $fh;
move( $temp_file, $mapping_file);

print qx{ cvs commit -l -f -m "Update for $Build_Job - $Build_Number" };
chdir $dir;
 

__END__
