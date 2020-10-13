use POSIX qw(strftime);
$now_string = strftime "%Y%m%d", localtime;

$xmlfile = $ARGV[0];
$BuildNum = $now_string . "_" . $ARGV[1];

open(FP,"<$xmlfile");
@lines = <FP>;
close(FP);

open(FP,">$xmlfile");
foreach $line (@lines)
{
 if ($line =~ "\<param-value\>2014")
 {
  $line = "    <param-value>$BuildNum</param-value>\n";	
 }	
 print FP $line;
}
close(FP);
