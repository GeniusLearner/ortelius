#!/usr/bin/perl
use File::stat;
use File::Find;
use File::Path;
use File::Find::Rule;
use Getopt::Long;
use Openmake::File;
use constant false => 0;
use constant true  => 1;

# srcdir = Source directory
# todir  = Destination directory
# flatten = Ignore the directory structure of the source files, and copy all files into the directory specified by the todir attribute.
# attrib = Copy attributes including timestamp
# overwrite = Overwrite existing files even if the destination files are newer.
# newer = Copy only Newer files
# exists = Copy only if the destination does not exist
# symlink = Copy symlinks as new symlinks
# dontfollow = Dont follow symlinks
# verbose = Verbose Output

####### Set option defaults #######

$fromdir = "";
$todir = "";
$fromfile = "";
$tofile = "";
$flatten = false;
$attrib = false;
$overwrite = false;
$newer = false;
$exists = false;
$symlink = false;
$dontfollow = false;
$verbose = false;
$exclude = "";



GetOptions( 'fromdir=s' => \$fromdir,
            'todir=s' => \$todir,
			'fromfile=s' => \$fromfile,
            'tofile=s' => \$tofile,
			'flatten' => \$flatten,
			'attrib' => \$attrib,
			'overwrite' => \$overwrite,
			'newer' => \$newer,
			'exists' => \$exists,
			'symlink' => \$symlink,
			'dontfollow' => \$dontfollow,
			'verbose' => \$verbose,
			'exclude' => \$exclude
 ) or die "FATAL: Unrecognized option";


 ########################
 # -- fromdir/todir fromfile/tofile are mutually exclusive option pairs
 #    but one pair or the other is required

 die   "ERROR: fromdir/todir and fromfile/tofile are mutually exclusive option pairs\n" .
       "Your option string must specify one and only one of these option pairs.\nDetected these option settings:\n\n" .
	   "\tfromdir=$fromdir\n\ttodir=$todir\n\tfromfile=$fromfile\n\ttofile=$tofile\n\n"
	   unless ((($fromfile && $tofile) && !($fromdir || $todir)) || (($fromdir && $todir) && !($fromfile || $tofile)));

 if ($fromdir)  #We have a wildcard copy
 {
  $fromdir =~ s/\\/\//g;
  $todir =~ s/\\/\//g;
  @parts = split(/\//,$fromdir);
  
  $fromdir = "";
  
  $filepattern = pop @parts if ($parts[-1] =~ /\Q[*|?]\E/);
  $fromdir .= $_ . "/"  foreach (@parts);
  

  die "ERROR: directory does not exist: $fromdir\n" unless (-d $fromdir);

  if ($fromdir !~ /^[\/|[[A-Za-z]\:\\]]/)
  {
   $relsrcdir = $fromdir;
   $fromdir_obj = Openmake::File->new($fromdir);
   $fromdir = $fromdir_obj->getAbsolute();
   $fromdir =~ s/\\/\//g;
  }

  my $rule = File::Find::Rule->file();
  $filepattern ? $rule->name($filepattern) : $rule->readable();

  if ($exclude ne "")
  {
   @exclude_patterns = ();
   if ($exclude =~ /\,/)
   {
    my @patterns = split (/,/ , $exclude);
    $exclude = "";
    foreach my $pattern (@patterns)
    {
     $pattern =~ s/\s//g;
     push (@exclude_patterns, $pattern);
    }
   }
   else
   {
    @exclude_patterns = ($exclude)
   }
   $rule->not_name(@exclude_patterns);
  }

  if ($symlink eq "false")
  {
   $rule->not($rule->new->symlink)
  }

  @files = $rule->in($fromdir); #get the files
 }
 else #must be individual file copy
 {
  
  die "ERROR: file does not exist: $fromfile\n" unless (-f $fromfile);
  
  if ($symlink eq "false")
  {
   next if (-l $fromfile)
  }  
  
  $fromfile =~ s/\\/\//g;
  $tofile =~ s/\\/\//g;
  @fromdir_parts = split(/\//,$fromfile);
  @todir_parts = split(/\//,$tofile);
  $tofilename = pop @todir_parts;
  pop @fromdir_parts;
  $todir = "";
  $fromdir = "";

  foreach $p (@fromdir_parts)
  {
   $fromdir .= $p . "/";
  }

  if ($fromdir !~ /^[\/|[[A-Za-z]\:\\]]/)
  {
   $relsrcdir = $fromdir;
   $fromdir_obj = Openmake::File->new($fromdir);
   $fromdir = $fromdir_obj->getAbsolute();
   $fromdir =~ s/\\/\//g;
  }
  
  foreach $p (@todir_parts)
  {
   $todir .= $p . "/";
  }

  $fromdir =~ s/\/$//;  
  $todir =~ s/\/$//;
  @files = ($fromfile);
 }
 foreach $f (@files)
 {
  my $cmd = ($^O =~ /win32/i) ? "copy " : "cp ";
  $f =~ s/\\/\//g;
  $from = $f;
  $f =~ s/\Q$fromdir\E\///;
  $dontcopy = false;
  
  ######################
  #flatten on or off determines our destination directory  
  
  if ($flatten)
  {
   $dir = $todir;
   @parts = split(/\//,$f);
   $filename = pop @parts; #need filename in case this is a fromfile/tofile copy, not used otherwise
   unless (-d $dir)
   {
    mkpath($dir) or $RC=1;
   }
   $to = $tofile ? $tofilename : $todir . "/" . $filename;
  }
  else
  {
   unless ($tofile)
   {
    @parts = split(/\//,$f);
    pop @parts;
    $dir = $todir . "/" . join("/",@parts);
    $dir =~ s/\/$//;
   }
   else
   {
    $dir = $todir;
	$dir =~ s/\/$//;
   }
   unless (-d $dir)
   {
    mkpath($dir) or $RC=1;
   }
   $to = $tofile ? $tofile : $todir . "/" . $f;
  }

  die "ERROR: problems creating directory $dir: $!\n" if ($RC);

  if ($attrib)
  {
   $cmd .= ($^O =~ /win32/i) ? "/K " : "-p ";
  }

  if ($overwrite)
  {
   $cmd .= ($^O =~ /win32/i) ? "/Y " : "-f ";
  }
  else
  {
   if (-e $from && -e $to)
   {
 	$dontcopy = true;
   }
  }

  if ($verbose)
  {
   $cmd .= ($^O =~ /win32/i) ? "/F " : "-v ";
  }

  if ($^O =~ /win32/i)
  {
   $from =~ s/\//\\/g;
   $to =~ s/\//\\/g;
  }

  if (-l $from)
  {
   unless ($dontfollow)
   {
    $f = readlink;
   }
   else
   {
    $cmd .= ($^O =~ /win32/i) ? "/B " : "-s ";
   }
  }

  if ($newer)
  {
   if (-e $from && -e $to)
   {
    if (stat($from)->mtime <= stat($to)->mtime)
    {
 	 $dontcopy = true;
    }
   }
  }

  $cmd .= "\"" . $from . "\" \"" . $to . "\"";

  if ($exists)
  {
   if (-e $to)
   {
	$dontcopy = true;
   }
  }

  if ($dontcopy)
  {
	print "Skipping $to\n";
  }
  else
  {
   print "$cmd\n";
   my @CopyOut = `$cmd`;
   push (@CompilerOut, @CopyOut);
   $RC = $?;
   die "ERROR: could not copy file: $from\n" if ($RC);
  }
 }
