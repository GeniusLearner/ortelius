my $find = $ARGV[0];
my $replace = $ARGV[1];
my $glob = $ARGV[2];

@filelist = <*$glob>;

if ( (!$find) || (!$replace) || (!$glob) ) {
    print "Search and replace recursively through the current directory\n";
    print "replacing <find> with <replace> in each file specified.\n";
    print "To use wildcards leave off the * Ex: '.txt' \n\n";
    print "    mksr <find> <replace> <file>\n";
    
    exit(0);
}


# process each file in file list
foreach $filename (@filelist) {

	print "    P: $filename\n";

	# retrieve complete file
    open (IN, "$filename") || die("Error Reading File: $filename $!");
	{
		undef $/;          
		$infile = <IN>;
	}
    close (IN) || die("Error Closing File: $filename $!");

	$infile =~ s/$find/$replace/g;
	

	# write complete file 
     open (PROD, ">$filename") || die("Error Writing to File: $filename $!");
	 print PROD $infile;
     close (PROD) || die("Error Closing File: $filename $!");

}

   print "\nFinished.\n";


   exit(0);
