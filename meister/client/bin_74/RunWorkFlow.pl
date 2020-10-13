use Cwd;

$dir = $ARGV[0];
$BuildJob = $ARGV[1];
$OpenmakeHome = "\/opt\/openmake\/bin";

if ($dir eq "" || $BuildJob eq "")
{
 print "Usage: RunBuildJob <Build Dir> <Build Job>\n";
 exit(1);
}

$olddir = chdir($dir);

# Start IUD-237 - MDG - 06.18.08
# determine the log file to watch for completion 
#$job = $BuildJob;
#$job =~ s/\s/_/g;
#$complete = ".log/Build_Job_complete_for_$job.log";
# End IUD-237 - MDG - 06.18.08

#unlink("$complete");

# Run omcmdline.jar in -SYNC mode	IUD-237 - MDG - 06.18.08
print "java -cp \"$OpenmakeHome\/omcmdline.jar\" com.openmake.cmdline.Main -BUILD \"$BuildJob\" -SYNC\n";
print `java -cp "$OpenmakeHome\/omcmdline.jar" com.openmake.cmdline.Main -BUILD "$BuildJob" -SYNC`;

#if ($? == 0)
#{
#while (! -f "$complete")
#{
# print "Watching for $complete...";
# sleep(10);
#}
#}
chdir($olddir);