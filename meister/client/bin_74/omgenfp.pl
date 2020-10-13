#! /usr/bin/perl

# OMGenFP.pl Version 1.0
#
# Openmake Generate Footprint Utility
#
# Catalyst Systems Corporation		September 4, 1999
#

# read in the three arguments
($DataFile,$TagFile,$TargetBin) = @ARGV;
# $DataFile is the Fully Qualified Path to the file
#		that contains the footprinting information.
# $TagFile is the Fully Qualified Path and name of the 
# 		c-file that will link the information.
# $TargetBin is the name of the final target binary with
# 		which footprinting information will be associated. 	

use Openmake;

if (@ARGV ne 3) # check that three arguments have been passed.
{
 # print usage note
 print "Usage: OMGenFP.pl <datafile> <tagfile> <targetbin>\n"; 
 exit(1); # exit with code 1
}

# try to open $DataFile
if( open(DAT,"<$DataFile") )
{ 				# success, 
 @TagList = <DAT>;	# read lines into @TagList,
 close(DAT);		# close file.
}
else
{				# failure,
 print "Could not open file: $DataFile.\n"; # print error message,
 exit(2); 			# exit with code 2.
}

# try to create $TagFile
unless ( open(TAG,">$TagFile") )
{ 				# failure, 
 print "Could not create file: $TagFile.\n"; # print error message. 
 exit(3);  			# exit with code 3.
}

my $fptxt = FormatFootPrint( $TargetBin, @TagList);
print "Data file $DataFile is empty.\n", exit(0) if ( $fptxt eq "" ) ;

print TAG $fptxt;

close(TAG);					     # close the TagFile,

exit(0);					     # and exit.
