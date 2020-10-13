# $Header: /CVS/openmake7/shared/om_mstest_activity.pl,v 1.1 2008/02/21 16:37:27 jim Exp $
#
# Openmake NUnit Activity Wrapper
#
use strict;
use warnings;

use File::Find;
use File::Glob qw{:glob};
use Getopt::Long;

no warnings 'uninitialized';

#/fixture=STR         Fixture to test
#/config=STR          Project configuration to load
#/xml=STR             Name of XML output file
#/transform=STR       Name of transform file
#/xmlConsole          Display XML to the console
#/output=STR          File to receive test output (Short format: /out=STR)
#/framework=STR       .NET Framework version to execute with (eg 'v1.0.3705')
#/err=STR             File to receive test error output
#/labels              Label each test in stdOut
#/include=STR         List of categories to include
#/exclude=STR         List of categories to exclude
#/domain=X            AppDomain Usage for Tests
#/noshadow            Disable shadow copy when running in separate domain
#/nothread            Disable use of a separate thread for tests
#/wait                Wait for input before closing console window
#/nologo              Do not display the logo
#/nodots              Do not display progress
#/help                Display help (Short format: /?)

my ($testcontainers, $fixture, $config, $other_options);

GetOptions
(
 'testcontainers|t=s' => \$testcontainers,
 'config|c=s'         => \$config,
 'fixture|f=s'        => \$fixture,
 'opts|o=s'           => \$other_options
);

my @testcontainers = split /,/, $testcontainers;
my $options = '';
$options .= ' /fixture=' . $fixture if $fixture;
$options .= ' /config='  . $config  if $config;
$options .= ' ' . $other_options if $other_options;

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

my $rc = 0;
foreach my $container  ( @runcontainers )
{
 my $cmd = "nunit-console.exe $container $options";
 print `$cmd`;
 $rc += $?;
}

exit $rc;


