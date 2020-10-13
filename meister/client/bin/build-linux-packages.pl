#!/usr/bin/perl
use strict;
use File::Find;
use Openmake::File;
use File::Copy 'cp', 'mv';
use File::Copy::Recursive 'dircopy';
use File::Remove 'remove';
use File::Path 'rmtree';
use Cwd;


my $k = "";

foreach $k (keys %ENV)
{
 print "$k=" . $ENV{$k} . "\n";
}

my $build_number = $ARGV[0];
my @build_file_list = ( 'bin/dm', 'bin/libdmapi.so', 'bin/libhttp.so', 'bin/libiisplugin.so', 'bin/librestful.so',
			 'lib/dmtransfer', 'trilogyd', 'trilogycli', 'setodbc', 'lib/libtrilogycli.so', 'lib/libtrilogy.so');
my @static_file_list = ( 'dm.odbc', 'dm.asc', 'trilogy.conf', 'trilogy.lic', 'README.txt', 'odbc.template', 'pre-install.sh', 'post-install.sh', 'post-install.pl', 'deployhub-engine.service', 'deployhub-engine.sh',  'post-rproxy-install.sh', 'post-rproxy-install.pl');
my @webadmin_static_files = ('webapp-runner.jar', 'deployhub-webadmin.sh', 'deployhub-webadmin.service', 'pre-install.sh', 'post-install.sh', 'post-install.pl');
my @webadmin_build_files = ('deployhub-webadmin.war');
my @wildcard_dir_list = ('demo', 'demorep', 'scripts','lib');
my $build_dir = $ENV{'PWD'} . '/../engine-64/DEBUG';
my $webadmin_build_dir = $ENV{'PWD'} . '/../webadmin';
my $git_files_dir = $ENV{'WORKSPACE'} . '/installers/linux';
my $engine_dir = 'engine';
my $webadmin_dir = 'webadmin';
my $package_prefix = 'opt/deployhub';
my $RC;


my $orig_cwd = cwd();
print "Cleaning current directory \'$orig_cwd\' ...\n";
remove (\1, '*');

rmtree($engine_dir);
mkdir ($engine_dir);
chdir ($engine_dir);
my $cwd = cwd();

print "Copying installer files to current directory ...\n";
foreach (@static_file_list) 
{
 print $git_files_dir . '/engine/' . $_ . "\n";
 cp ($git_files_dir . '/engine/' . $_,  $cwd);
} 

foreach my $file (@build_file_list)
{
 die "Can't find file \'$file\' in build directory \'$build_dir\': $!" unless (-f $build_dir . '/' . $file);
 my $dir = ".";
 if ($file =~ m/(.*)\/.*$/)
 {
  $dir = $1;
  mkdir ($dir) unless (-d $dir);
 }
 cp ($build_dir . '/' . $file, $dir);
}

foreach my $dir (@wildcard_dir_list)
{
 my $src_dir = $git_files_dir . '/engine/' . $dir;
 die "Can't find source directory \'$src_dir\': $!" unless (-d $src_dir);
 dircopy ($src_dir, $dir); 
}

# Now copy the webadmin files
chdir ($orig_cwd);
rmtree($webadmin_dir);
mkdir ($webadmin_dir);
chdir ($webadmin_dir);
$cwd = cwd();
cp ($git_files_dir . '/webadmin/' . $_,  $cwd) foreach (@webadmin_static_files);
cp ($webadmin_build_dir . '/' . $_,  $cwd) foreach (@webadmin_build_files);

# Run commands to create packages
print "Building Linux packages ...\n";
chdir ($orig_cwd);
`rm -f *.rpm`;
foreach my $component ("engine", "webadmin", "rproxy")
{
#  foreach my $pack_type ("rpm", "deb")
  foreach my $pack_type ("rpm")
  {
   my $fpm_cmd, my $pack_file, my @deps;

   my $pack_name = "deployhub-pro-$component";

   if ($component eq "engine" || $component eq "rproxy")
   {
     @deps = ( "unixODBC > 2.1", "postgresql-server > 9.2", "postgresql-odbc > 9.2",  "ansible", "python-winrm", "python3-winrm", "perl > 5.10", "sshpass > 1.0", "libiodbc > 3.50", "gnutls","glibc(x86-32)", "libstdc++(x86-32)" );
     if ($component eq "rproxy")
     {
      push(@deps,"python-requests");
     }
   }
   else #webadmin
   {
     @deps = ( "deployhub-pro-engine >= 8.0." . $build_number, "java-1.8.0-openjdk > 1.8.0.0");
   }

   my $fpm_deps = join ('" -d "', @deps); 
   $fpm_deps = "-d \"$fpm_deps\"";

   if ($pack_type eq "rpm") 
   {
     if ($component eq "rproxy")
     {
      $fpm_cmd =  "fpm -s dir -t $pack_type -n $pack_name -v 8.0." . $build_number . "  --directories /opt/deployhub --rpm-defattrfile \"755\" --prefix /opt/deployhub --after-install $orig_cwd/engine/post-rproxy-install.sh $fpm_deps engine";
     }
     else
     {
      $fpm_cmd =  "fpm -s dir -t $pack_type -n $pack_name -v 8.0." . $build_number . "  --directories /opt/deployhub --rpm-user omreleng --rpm-group omreleng --rpm-defattrfile \"755\" --before-install  $component/pre-install.sh --after-install $component/post-install.sh --prefix /opt/deployhub $fpm_deps $component";
     }
     $pack_file = $pack_name . "-8.0." . $build_number . "-1.x86_64.rpm"; 
   }
   elsif ($pack_type eq "deb")
   {
     $fpm_cmd =  "fpm -s dir -t $pack_type -n $pack_name -v 8.0." . $build_number . "  --before-install  $component/pre-install.sh --after-install $component/post-install.sh --prefix /opt/deployhub $fpm_deps $component";
     $pack_file = $pack_name . "_8.0." . $build_number . "_amd64.deb";
   }

   print "\n\nBuilding package \'$pack_file\' ...\nCurrent working directory is: " . cwd() . "\nfpm command is: $fpm_cmd\n\n";
   my @fpm_out = `$fpm_cmd 2>&1`;
   $RC = $?;
   print "Error running fpm command:\n" if $RC;
   print $_ foreach(@fpm_out);
   mv ($pack_file, $orig_cwd) or warn "Can't move file \'$pack_file\' to $orig_cwd: $!";
   print "Package \'$pack_file\' complete!\n\n"
  }
}

print "Complete!\n";
$RC ? exit (1) : exit(0);
