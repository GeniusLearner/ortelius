#!/usr/bin/perl
$names++, shift if $ARGV[0] eq "-l";
$negative++, shift if $ARGV[0] eq "-v";
$search = shift;
$showname = @ARGV > 1;
@ARGV = "-" unless @ARGV;
@ARGV = grep { -T or $_ eq "-" } @ARGV;
exit 0 unless @ARGV;
while (<>) {

if ($negative)
{
        if ( $_ !~ /$search/o)
		{
         if ($names) {
                print "$ARGV\n";
                close ARGV;
         } else {
                print "$ARGV: " if $showname;
                print;
         }
		} 
}
else
{
        next unless /$search/o;
        if ($names) {
                print "$ARGV\n";
                close ARGV;
        } else {
                print "$ARGV: " if $showname;
                print;
        }
}
}