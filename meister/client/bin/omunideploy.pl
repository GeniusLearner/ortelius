use Getopt::Long;

my ( $Item, $Version, $Proc, $Computer_List, $Group, $After, $At_Time);

&Getopt::Long::Configure( "pass_through" );
&GetOptions(
 'i=s' => \$Item,
 'v=s' => \$Version,
 'p=s' => \$Proc,
 'c=s' => \$Computer_List,
 'g=s' => \$Group,
 'a=s' => \$After,
 't=s' => \$At_Time
);

#-- format the cmd line call
my $cmd_line = 'cadsmcmd install ';

$cmd_line .= 'item="' . $Item . '" ' if ( $Item);
$cmd_line .= 'version="' . $Version . '" ' if ( $Version);
$cmd_line .= 'procedure="' . $Proc . '" ' if ( $Proc);
if ( $Computer_List)
{
 my @comps = split /,/, $Computer_List;
 $cmd_line .= 'computer="' . $_ . '" ' foreach ( @comps);

}
$cmd_line .= 'compgrp="' . $Group . '" ' if ( $Group);
$cmd_line .= 'after="' . $After . '" ' if ( $After);
$cmd_line .= 'attime="' . $At_Time . '" ' if ( $At_Time);

print `$cmd_line`;
exit $?;

