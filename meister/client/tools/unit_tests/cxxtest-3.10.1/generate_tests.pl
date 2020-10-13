use strict;
use warnings;

use File::Spec::Functions qw{rel2abs};
use File::Basename;
use Getopt::Long;

my $test_file = 'test.cpp';
my $test_dir  = 't';
my @include_paths = ( 'C:\Work\Catalyst\eclipse\openmake7\as_features\plugins\om700-include', 
                      'C:\Work\Catalyst\3rd_Party_Tools\cxxtest\cxxtest-3.10.1', 
                      'C:\Progra~1\Microsoft Visual Studio\VC98\include',
                      'V:\rogue\release'
                    );
                    
my @lib_paths     = ( 'C:\Work\Catalyst\SourceCode\Openmake641_dev_Trunk\DEV\DEBUG\win32',
                      'C:\Progra~1\Microsoft Visual Studio\VC98\lib',
                      'V:\rogue\release\lib'
                    );
                    
my $include_path = join ';', @include_paths, @lib_paths;


$ENV{'INCLUDE'} = $include_path;
$ENV{'LIB'} = $include_path;

GetOptions
(
 'file|f=s' => \$test_file,
 'dir|d=s'  => \$test_dir
);

#-- find the cxxtestgen.pl script in same dir
( my $cxx_script = dirname( rel2abs($0)) . '/cxxtestgen.pl' ) =~ s{/}{\\}g; 

#-- chdir to the test dir
chdir( $test_dir ) or die "Cannot change to directory '$test_dir'\n";

#-- create the CPP files
print "$cxx_script --error-printer -o $test_file *.h \n";
print `$cxx_script --error-printer -o $test_file *.h`;

#-- compile the test file.
( my $exe_file = $test_file ) =~ s{\.cpp$}{.exe} ;
 
print "cl.exe /GX /Fe\"$exe_file\" $test_file rwto\n";
print `cl.exe /GX /Fe"$exe_file" $test_file`;
 
#-- run the test
print `$exe_file`;
