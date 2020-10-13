#!/usr/bin/perl

# list all of the perl modules installed
use File::Find ;

find(\&wanted,@INC);

@mods = sort {lc($a) cmp lc($b)} @mods;

foreach $module (@mods)
{
 print "$module\n";	
}

sub wanted {

  if ($File::Find::name =~ /\.pm$/) {
    open(F, $File::Find::name) || return;
    while(<F>) {
      if (/^ *package +(\S+);/) {
        push (@mods, $1);
        last;
      }
    }
    close(F);
  }
}


