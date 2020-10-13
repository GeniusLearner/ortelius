#!/bin/perl
use strict;
use warnings;

#update build number
use POSIX qw(strftime);

my $build_number = $ENV{'JENKINS_BUILD_NUMBER'};

my $date_string = strftime '%Y%m%d', gmtime();
my $build_string = $date_string . '_' . $build_number;

my $web_xml;
$web_xml = $ENV{'WORKSPACE'} . "/dmadminweb/WebContent/WEB-INF/web.xml";

open (FP, "<$web_xml");
my @lines = <FP>;
close FP;

my @updated = ();
foreach my $line (@lines)
{
  $line =~ s{X_BUILD_VERSION_X}{\Q$build_string\E};
  push(@updated,$line);
}

mkdir("dmadminweb");
mkdir("dmadminweb/WebContent");
mkdir("dmadminweb/WebContent/WEB-INF");

open (FP, ">dmadminweb/WebContent/WEB-INF/web.xml");
foreach my $line (@updated)
{
 print FP $line; 
}
close FP;
