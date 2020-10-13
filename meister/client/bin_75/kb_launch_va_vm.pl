use strict;
use Getopt::Long;
use Switch;
use LWP::Simple;

my $DL;
if ($^O =~ /Win/)
{
 $DL = '\\';
}
else
{
 $DL = '/';
}

my @va_output;
my $booted = 0;
my @VM_Platforms = ("ec2", "vcenter", "hyperv");
my ($OM_agent, $VM_Platform, $VA_Home, $ws_user, $ws_password, $openmake_server, $hypervhost, $datacenter, $vm_name, $image, $keypair, $zone, $type, $instance, $security_group, $vc_server, $vc_user, $vc_password, $terminate, $powerop);

GetOptions( 'agent=s'     => \$OM_agent,
			'vm_platform=s'     => \$VM_Platform,
            'va_user=s'    => \$ws_user,
            'va_password=s'    => \$ws_password,	
			'va_home=s'    => \$VA_Home,
            'openmake_server=s'    => \$openmake_server,				
            'hypervhost:s'    => \$hypervhost,
            'datacenter:s' => \$datacenter,			
            'vmname:s'    => \$vm_name,
			'image:s'    => \$image,
			'keypair:s'    => \$keypair,
			'zone:s'    => \$zone,
			'type:s'    => \$type,
			'instance:s'    => \$instance,
			'security_group:s'    => \$security_group,
			'vcserver:s'    => \$vc_server,
			'vcuser:s'    => \$vc_user,
			'vcpassword:s'    => \$vc_password,
			'terminate'    => \$terminate
) or die "FATAL: Unrecognized option";

my $counter = 0;
my $VA = ($VA_Home =~ m/bin$/) ? $VA_Home : $VA_Home . $DL . 'bin' . $DL;

do
{
 #Run isAgentRunning.jsp?agent=$OM_agent on KB server

 my $url = $openmake_server . '/reports/isAgentRunning.jsp?agent=' . $OM_agent;
 my $agent_status = get $url;
 if ((($agent_status =~ m/true/i) && $counter == 0) && !($terminate))
 {
  print "VM agent $OM_agent is already running. Exiting ...\n";
  exit(0);
 }

 if ($agent_status =~ m/does not exist/)
 {
  print "\nAgent $OM_agent does not exist on the Knowledge Base Server at $openmake_server";
  exit (1);
 }
 
 $agent_status = ($agent_status =~ m/true/i) ? 1 : 0;
 
 my $cmd;
 if (($agent_status ==  0 && $booted == 0) || ($terminate))
 {
  
  switch ($VM_Platform) {
  
  case "ec2"	{
				 if ($terminate)
				 {
				  die "Missing EC2 required terminate option: instance\n" unless ($instance);
				  $cmd = "\"" . $VA . "dpmec2\" manage -ws_user $ws_user -ws_password $ws_password -instance $instance -operation terminate";
				 }
				 else
				 {
				  die "Missing one or more of EC2 required options: image and\/or key_pair\n" unless ($image && $keypair);				 
				  $cmd = "\"" . $VA . "dpmec2\" run -ws_user $ws_user -ws_password $ws_password -image $image -key_pair $keypair";
				  $cmd .= ' -zone ' . $zone if ($zone);
				  $cmd .= ' -type ' . $type if ($type);
				  $cmd .= ' -group ' . $security_group if ($security_group);
				 }
				}
  case "vcenter"{
				 die "Missing one or more of vCenter required options: datacenter and\/or vm_name\n" unless ($datacenter && $vm_name);
				 $powerop = $terminate ? "shutdown guest" : "poweron";
				 $cmd = "\"" . $VA . "dpmvc\" cycle -ws_user $ws_user -ws_password $ws_password -datacenter_name $datacenter -vm_name $vm_name -powerop $powerop";
				 $cmd .= ' -vc_server ' . $vc_server if ($vc_server);
				 $cmd .= ' -vc_user ' . $vc_user if ($vc_user);
				 $cmd .= ' -vc_password ' . $vc_password if ($vc_password);
				}
  case "hyperv"	{
				  die "Missing one or more of Hyper-V required options: hypervHost and\/or vm_name\n" unless ($hypervhost && $vm_name);
				  $powerop = $terminate ? "Shutdown" : "Start";
				  $cmd = "\"" . $VA . "dpmhyperv\" ChangeVMState -ws_user $ws_user -ws_password $ws_password -hypervHost $hypervhost -vm $vm_name -state $powerop";
				}
  }
  
  
  my @va_output = `$cmd`;
  print "@va_output";
  if ($?)
  {
   print $terminate ? "\nError terminating $VM_Platform VM through CA Virtual Automation\n" : "\nError launching $VM_Platform VM through CA Virtual Automation\n";
   exit(1);
  }
  $booted = 1;
  
  
 } 
 
 if (($agent_status == 1 ) && !($terminate))
 {
  print "Succesfully launched VM agent $OM_agent\n";
  exit(0);
 }
 elsif($terminate)
 {
  print "Succesfully terminated VM agent $OM_agent\n";
  exit(0);
 }
sleep 5 if ($counter < 1);
sleep 1;
$counter ++; 
} while (1);
