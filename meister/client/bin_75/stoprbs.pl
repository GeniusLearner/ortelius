use warnings;
use strict;
use File::Spec;

#-- everything is hardwired

#-- find the install directory
my $full_path = File::Spec->rel2abs($0);
$full_path =~ s{\\}{/}g;
my @p = split /\//, $full_path;
pop @p; #-- script name
if ( $p[-1] eq 'bin')
{
 pop @p;
} 
my $install_dir = join '/', @p;

if ( $^O !~ m{mswin|dos}i )
{
 #-- see if we can open the pid file
 open my $fh, '<', $install_dir . '/buildserver/rbs.pid';
 my @lines = <$fh>;
 my $pid = $lines[0];
 chomp $pid;
 close $fh;
 if ( $pid )
 {
  
  
 } 
 else
 {
  #-- find the ps of the build server
  my @ps = `ps -ef | grep omremotebuildserver`;
  foreach my $p ( @ps )
  {
   chomp;
   $p =~ s{^\s+}{};
   my @l = split /\s+/, $p;
   $pid = $l[1];
   last;
  }
 }
 print `kill $pid`;
 
 exit;
}
else
{
 #-- do windows
 
 eval "use Win32::OLE( 'in' ); "; die $@ if $@;
 
 my $wbemFlagReturnImmediately = 0x10;
 my $wbemFlagForwardOnly       = 0x20;
 
 my $objWMIService = Win32::OLE->GetObject( "winmgmts:\\\\localhost\\root\\CIMV2" );
 my $colItems = $objWMIService->ExecQuery( "SELECT * FROM Win32_Process", "WQL", $wbemFlagReturnImmediately | $wbemFlagForwardOnly );
 
 foreach my $objItem ( in $colItems)
 {
  # SBT 09.15.08 - IUD-183 - checked for defined vars
  if ( defined $objItem->{'Name'} && defined $objItem->{'CommandLine'})
  {
   if ( $objItem->{'Name'} =~ m{java}i && $objItem->{'CommandLine'} =~ m{omremotebuildserver} )
   {
    $objItem->Terminate();
    last;
   }
  } 
 } #-- End: foreach my $objItem ( in $colItems...
}
