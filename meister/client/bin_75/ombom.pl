#! /usr/bin/perl
# 
# OMBoM.pl Version 1.0
#
# Openmake Bill of Materials Reporting Utility.
#
#
# Catalyst Systems Corporation          September 4, 1999
#
# JAG -- 04.24.03 -- modify to allow generic Version Control Info
#
# read in arguments
use Openmake;

($DataFile,$ReportFile,$ExeName) = @ARGV;

##print "$DataFile $ReportFile\n";
use File::Copy;
copy ($DataFile, $DataFile . ".bak");

# $DataFile is the Fully Qualified Path to the file
#               that contains the footprinting information.

# $ReportFile is the Fully Qualified Path to the file
#               that will contain the report.

# $ExeName is the name of the executable for which this report
#           is generated.

if (@ARGV ne 3) # check that three arguments have been passed.
{
 # print usage note
 print "Usage: OMBoM.pl <datafile> <reportfile> <executable name>\n"; 
 exit(1); # exit with code 1
}

# try to open $DataFile
if( open(DAT,"<$DataFile") )
{                               # success, 
 @TagList = <DAT>;      # read lines into @TagList,
 close(DAT);            # close file.
}
else
{                               # failure,
 print "Could not open input file: $DataFile.\n"; # print error message,
 exit(2);                       # exit with code 2.
}

# try to create $ReportFile
unless ( open(REP,">>$ReportFile") )
{                               # failure, 
 print "Could not open output file: $ReportFile.\n"; # print error message. 
 exit(3);                       # exit with code 3.
}

#-- Use Openmake.pm module to process text from @TagList
#   Done this way to allow us to get away from ombom.pl 
#   in the future.
my $filetxt = FormatBillofMat( $ExeName, @TagList );

#-- print the bill of materials to the file
print REP $billofmat;
close(REP);                                          # close the Report File,

exit(0);                                             # and exit.


