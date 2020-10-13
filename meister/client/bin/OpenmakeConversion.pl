$| = 1;

if ($^O =~ /Win/i)
{
 $DL = ';';
 $PathDL = '\\';
} 
else
{
 $DL = ':';
 $PathDL = '/';
} 

@dirs = split(/;/,$ENV{"PATH"});

foreach $dir (@dirs)
{
 $dir =~ s|\"||g;
 $dir .= $PathDL;
 
 $check4 = $dir . "openmake6.jar";
 if (-e $check4)
 {
  $found = $dir;
  $jarfile = $check4 . $DL;
  $jarfile .= $dir . "xerces.jar" . $DL;
  $jarfile .= $dir . "idooxoap.jar" . $DL;
  $jarfile .= $dir . "log4j.jar" . $DL;
  $jarfile .= $dir . "catsor.jar" . $DL;
  
  last;
 }
}

if ($found eq "")
{
 print "Could not find OpenmakeClient.jar in the path!\n";
 exit(1);
}

$server = "localhost:8080";
print "What is the Openmake KB Server name (include port number)? [localhost:8080]: ";
$input = <STDIN>;

$server = $input if ($input ne "");
$server =~ s/\n//g;

print "Please specify the full qualified path to vpath.kb? ";
$input = <STDIN>;

$vpathkb = $input if ($input ne "");
$vpathkb =~ s/\n//g;

print `java -cp $jarfile com.openmake.client.OpenmakeConversion http://$server/soap/servlet/openmakeserver $vpathkb`;

