# $Header: /CVS/openmake7/shared/om_mstest_activity.pl,v 1.1 2008/02/21 16:37:27 jim Exp $
#
# Openmake Microsoft MSTest Activity Wrapper
#
use strict;
use warnings;

use File::Find;
use File::Glob qw{:glob};
use Getopt::Long;

no warnings 'uninitialized';

my $testcontainers;
my $testmetadata;
my $testlists;
my $tests;
my $other_options;

#  /testcontainer:[file name]        Load a file that contains tests. You can
#                                    Specify this option more than once to
#                                    load multiple test files.
#                                    Examples:
#                                      /testcontainer:mytestproject.dll
#                                      /testcontainer:loadtest1.loadtest
#
#  /testmetadata:[file name]         Load a metadata file.
#                                    Example:
#                                      /testmetadata:testproject1.vsmdi
#
#  /runconfig:[file name]            Use the specified run configuration file.
#                                    Example:
#                                      /runconfig:mysettings.testrunconfig
#
#  /resultsfile:[file name]          Save the test run results to the specified
#                                    file.
#                                    Example:
#                                      /resultsfile:c:\temp\myresults.trx
#
#  /testlist:[test list path]        The test list, as specified in the metadata
#                                    file, to be run. You can specify this
#                                    option multiple times to run more than
#                                    one test list.
#                                    Example:
#                                      /testlist:checkintests/clientteam
#
#  /test:[test name]                 The name of a test to be run. You can
#                                    specify this option multiple times to run
#                                    more than one test.
#
#  /unique                           Run a test only if one unique match is
#                                    found for any given /test.
#
#  /noisolation                      Run tests within the MSTest.exe process.
#                                    This choice improves test run speed but
#                                    increases risk to the MSTest.exe process.
#
#  /noresults                        Do not save the test results in a TRX file.
#                                    This choice improves test run speed but
#                                    does not save the test run results.


GetOptions
(
 'testcontainers|c=s' => \$testcontainers,
 'testmetadata|m=s'   => \$testmetadata,
 'testlists|l=s'      => \$testlists,
 'tests|t=s'          => \$tests,
 'opts|o=s'           => \$other_options
);


my @testcontainers = split /,/, $testcontainers;
my @testlists      = split /,/, $testlists;
my @tests          = split /,/, $tests;

#-- find wildcards in testcontainers
my @runcontainers = ();
foreach my $container ( @testcontainers )
{
 if ( $container =~ m{\*} )
 {
  my @globbed;
  my %seen;
  find( { wanted => sub {
                         my @local_files = bsd_glob($container);
                         foreach my $f ( @local_files)
                         {
                          if ( ! $seen{ lc $f} )
                          {
                           push @globbed, $File::Find::dir . '/' . $f;
                           $seen{ lc $f } = 1;
                          }
                         }
                        }
        }, '.');

  push @runcontainers, @globbed;
 }
 else
 {
  push @runcontainers, $container;
 }
}

#-- format the call
my $cmd = 'mstest ';
foreach my $c ( @runcontainers) { $cmd .= ' /testcontainer:"' . $c . '"'; }
foreach my $l ( @testlists)     { $cmd .= ' /testlist:"' . $l . '"'; }
foreach my $t ( @tests)         { $cmd .= ' /test:"' . $t . '"'; }
if ( $other_options )           { $cmd .= $other_options; }

print `$cmd`;
my $rc = $?;
exit $rc;


