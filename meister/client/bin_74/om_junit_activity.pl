# $Header: /CVS/openmake7/shared/om_junit_activity.pl,v 1.1 2008/02/21 16:37:27 jim Exp $
#
# OpenMake activity plugin to wrapper JUnit activities
#
use strict;
use warnings;

use Getopt::Long;

my $classpath ;
my $classpath_file = '';
my $test_class;
my $cp_sep = ':';
if ( $^O =~ m{MSwin|dos}i ) { $cp_sep = ';' }

GetOptions
(
 'classpath|c=s' => \$classpath,
 'cpfile|f=s'    => \$classpath_file,
 'class|t=s'     => \$test_class
);

#-- read the classpath from the classpath file
if ( -e $classpath_file )
{
 $classpath = '';
 open ( my $fh, '<', $classpath_file ) or die "Cannot open file '$classpath_file': $!\n";
 while ( <$fh> )
 {
  chomp;
  $classpath = $_;
  #-- add this file to the cp
  my $jar = $classpath_file;
  $jar =~ s{\.classpath$}{.jar};
  $classpath .= $cp_sep . $jar;
  last;
 }
 close $fh;
}

#-- run junit
print `java -cp "$classpath" junit.textui.TestRunner "$test_class"`;

if ( $? )
{
 exit 1;
}
exit 0;

