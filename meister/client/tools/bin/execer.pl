#!/opt/freeware/bin/perl


my $cmd ='perl -S omrun.pl -dn "sh" -ds "Execute shell command 3" -di "1872589762" -dl -la "Execute shell command" -lj "FORTIS PD" -ld "2007-09-05 13_17_42" -lm "tonka" -lo "jim" -lp -sd "/shared/catalyst/fortis_pd"  \'cd "/shared/catalyst/fortis_pd";sh /shared/catalyst/bin/pd.sh \'';

my @largs = ( 'sh', '-c', $cmd );
