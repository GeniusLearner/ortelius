use strict;
use LWP::Simple;
use Digest::MD5;
use File::Find();
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;


sub wantedDeps;

my $name = "";
my $lookfor = "";
my $lookfor_md5 = "";
my %found;
my %deplist;
my @DeployNeeded = ();
my @NoDeployNeeded = ();
my @DepVersionNotFound = ();
my @DepNotFound = ();

my $kbs = "http://xteamforge.gotdns.com:58080/openmake";

if (scalar @ARGV == 0)
{
 open(FP,"<deploy.lst");
 my @lines = <FP>;
 close(FP);
 foreach my $line (@lines)
 {
  $line =~ s/\n//g;
  my @parts = split(/=/,$line);
  my $url = $kbs . "/repository/" . $parts[0] . "/" . $parts[1] . "/" . $parts[2];
  $^O =~ /win/i ? $parts[3] =~ s/\//\\/g : $parts[3] =~ s/\\/\//g;
  print "Deploying " . $parts[0] . " Build " . $parts[1] . " - " . $parts[2] . " -> " .$parts[3] . "\n";
  getstore($url, $parts[3]);
 }
 exit(0);
}

my $project = shift @ARGV;
my $buildnum = shift @ARGV;
my $pkgs = shift @ARGV;

my @pkglist = split(/,/,$pkgs);

if ($buildnum =~ /buildnumber\.dat/i)
{
 open(FP,"<buildnumber.dat");
 my @lines = <FP>;
 close(FP);
 $buildnum = shift @lines;
 $buildnum =~ s/\n//g;
}

print "\n***** Deploying $project - Build $buildnum *****\n";

foreach my $pkg (@pkglist)
{
### At this point we have all primary dependencies firgured out for download
### Need to figure out deps of deps now
print "\n***** Gathering Dependencies *****\n";
my $url = $kbs . "/repository/" . $project . "/" . $buildnum . "/" . $pkg;
getstore($url, "work.txt");

open(FP,"<work.txt");
my @worklines = <FP>;
close(FP);

my @lines = ();

foreach my $line (@worklines)
{
 my @t = split(/\r/,$line);
 push(@lines,@t);	
}

foreach my $line (@lines)
{
 $line =~ s/\n//g;
    if ($line =~ /;/)
    {
        my @parts = split(/;/,$line);
        $deplist{$parts[0]} = $parts[1];
    }
}

foreach my $file (keys %deplist)
{
	print "Checking Dependency $file\n";
	
        $lookfor = $file;
        $lookfor_md5 = $deplist{$file};
        my $env = $file;
        if ($env =~ m/{(.*)}/)
        {
         $env = $1;
         $name = $file;
         my $v = $ENV{$env};
         $env = '${' . $env . '}';
         $name =~ s/\Q$env\E/$v/g;
         
        }
        
        $name =~ s/\\/\//g;
        my @parts = split(/\//,$name);
        $lookfor = pop(@parts);
        
        wantedDeps();

    if (! exists $found{$lookfor})
    {
        # file not found on FS look in DB for download
        # check to see if we have the file in the repo
        my $url = $kbs . "/reports/findfile.jsp?md5=" . $lookfor_md5;
        getstore($url, "work.txt");

        open(FP,"<work.txt");
        my @worklines = <FP>;
        close(FP);

        my @lines = ();

        foreach my $line (@worklines)
        {
         my @t = split(/\r/,$line);
         push(@lines,@t);	
        }

        my $foundit = 0;
        foreach my $line (@lines)
        {
         $line =~ s/\n//g;
            if ($line =~ /=/)
            {
                # if we do have the file then download
                $found{$lookfor} = 1;
 #               print "File $name has changed. Deploy.\n";
                push(@DeployNeeded,$line . '=' . $name);
                $foundit = 1;
            }
        }
        # else we do not have the file in the repo then fail deployment
        if (!$foundit)
        {
            push(@DepNotFound,$lookfor);
        }
    }
}
}

my $foundit = 0;

print "\n***** Validating Packages and Dependencies *****\n";

if (scalar @DepVersionNotFound > 0)
{
    print "The following files are the wrong version for this deployment:\n";
    foreach my $file (@DepVersionNotFound)
    {
        print "   " . $file . "\n";
    }
    $foundit = 1;
}


if (scalar @DepNotFound > 0)
{
    print "The following files are not installed and do not exist in repository:\n";
    foreach my $file (@DepNotFound)
    {
        print "   " . $file . "\n";
    }
    $foundit = 1;
}

exit(1) if ($foundit == 1);

print "\nPassed\n";

print "\n***** Up to Date *****\n";

foreach my $file (@NoDeployNeeded)
{
    print "   " . $file . "\n";
}
 
print "\n***** Deploy *****\n";

open(FP,">deploy.lst");

foreach my $file (@DeployNeeded)
{
 print FP $file . "\n";
 my @parts = split(/=/,$file);
 
    print "   " . $parts[0] . " Build " . $parts[1] . " - " . $parts[2] . "\n";
    
}

sub wantedDeps {

      return if (! -e $name);
      
      open(FILE, $name);
      binmode(FILE);
      my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
      close(FILE);
      
      
        if ($lookfor_md5 =~ /$md5/i)
        {
            $found{$lookfor} = 1;
#            print "File $name is up to date.  Don't deploy.\n";
            push(@NoDeployNeeded,$lookfor);
        }
        else
        {
            # check to see if we have the file in the repo
            my $url = $kbs . "/reports/findfile.jsp?md5=" . $lookfor_md5;
            getstore($url, "work.txt");

            open(FP,"<work.txt");
            my @worklines = <FP>;
            close(FP);

            my @lines = ();

            foreach my $line (@worklines)
            {
             my @t = split(/\r/,$line);
             push(@lines,@t);	
            }
 
            $found{$lookfor} = 1;
            my $foundit = 0;
            foreach my $x (@lines)
            {
             $x =~ s/\n//g;
                if ($x =~ /=/)
                {
                    # if we do have the file then download
                    
#                    print "File $name has changed. Deploy.\n";
                    my $tmp = $x;
                    $tmp .= '=' . $name;
                    $tmp =~ s/\n//g;
                    push(@DeployNeeded,$tmp);
                    $foundit = 1;
                }
            }
            # else we do not have the file in the repo then fail deployment
            if (!$foundit)
            {
                push(@DepVersionNotFound,$lookfor);
            }
        }
  
}
