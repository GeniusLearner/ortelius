
my $config = $ARGV[0];
my $infile = $ARGV[1];
my $outfile = $ARGV[2];

$outfile = $infile if ($outfile eq "");

if ($config eq "" or ($config ne "" and $infile eq ""))
{
 print "\nUsage: omsearchandreplace.pl <properties> <input file> <output file>\n";
 print "  <properties> = Input file containing Key/Value pairs of Search and Replace data\n";
 print "  <input file> = Input file that will be replaced with values from the properties file\n";
 print "  <output file> = Output file for the results of the search and replace.  Input file name will be used if left blank\n";
 print "\n";
 exit 1;
}
open(FP,"<$infile") or die("Could not open input file: $infile");
@lines = <FP>;
close(FP);

open(FP,"<$config") or die ("Could not open properties file: $config");
@conflines = <FP>;
close(FP);

open(FP,">$outfile") or die ("Could not open output file: $outfile");

@outlines = ();
foreach $line (@lines)
{
 foreach $repl (@conflines)
 {
  $repl =~ s/\n//g;
  ($key,$value) = split(/=/,$repl);
  $line =~ s/$key/$value/g;
 }
 print FP $line;
}

close(FP);