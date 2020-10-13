# dpmhyperv ChangeVMState -ws_user <username> -ws_password <password> -hypervHost <hypervhost> -vm <vmname> -state {Start|Stop}
# dpmvc cycle -ws_user <username> -ws_password <password> -datacenter_name <datacentername> -vm_name <vmname> -powerop {poweron|shutdown guest}
# dpmec2 run -ws_user <username> -ws_password <password> -image <imageID> -key_pair <keypair>
# dpmec2 manage –instance <instanceID> –operation terminate

use strict;
use Getopt::Long;
use Switch;
use LWP::Simple;

my $booted = 0;
my @missing_args = ();
my @VM_Platforms = ("ec2", "vcenter", "hyperv");
my ($OM_agent, $VM_Platform, $hypervhost, $datacenter, $vm_name, $image, $keypair, $zone, $type, $instance, $security_group, $vc_server, $vc_user, $vc_password, $terminate, $args);

GetOptions( 'agent=s'     => \$OM_agent,
			'vm_platform=s'     => \$VM_Platform,		
            'hypervhost:s'    => \$hypervhost,
            'datacenter:s' => \$datacenter,			
            'vmname:s'    => \$vm_name,
			'image:s'    => \$image,
			'keypair:s'    => \$keypair,
			'zone:s'    => \$zone,
			'type:s'    => \$type,
			'instance:s'    => \$instance,
			'security_group:s'    => \$security_group,
			'vc_server:s'    => \$vc_server,
			'vc_user:s'    => \$vc_user,
			'vc_password:s'    => \$vc_password,
			'terminate'    => \$terminate
) or die "FATAL: Unrecognized option";

unless ($OM_agent && $VM_Platform)
{
 print "\nMissing one or more required options: agent and\/or vm_platform\n";
 exit 1;
}
switch ($VM_Platform) 
{
  
  case "ec2"	{
				 @missing_args = ('EC2', 'image', 'keypair') unless ($image && $keypair);
				 $args = 'agent=' . $OM_agent . '&vm_platform=' . $VM_Platform . '&image=' . $image . '&keypair=' . $keypair;
				 $args .= '&zone=' . $zone if ($zone);
				 $args .= '&type=' . $type if ($type);
				 $args .= '&security_group=' . $security_group if ($security_group);
				 $args .= '&instance=' . $instance if ($instance);
				}
  case "vcenter"{
				 @missing_args = ('vCenter', 'datacenter', 'vm_name') unless ($datacenter && $vm_name);
				 $args = 'agent=' . $OM_agent . '&vm_platform=' . $VM_Platform . '&datacenter=' . $datacenter . '&vm_name=' . $vm_name;
				 $args .= '&vc_server=' . $vc_server if ($vc_server);
				 $args .= '&vc_user=' . $vc_user if ($vc_user);
				 $args .= '&vc_password=' . $vc_password if ($vc_password);
				}
  case "hyperv"	{
				 @missing_args = ('Hyper-V', 'hypervhost', 'vm_name') unless ($hypervhost && $vm_name);
				 $args = 'agent=' . $OM_agent . '&vm_platform=' . $VM_Platform . '&hypervhost=' . $hypervhost . '&vm_name=' . $vm_name;
				}
	else		{ die "\nInvalid VM Platform specified.  Valid values are \"ec2\", \"vcenter\", or \"hyperv\"\n";}
}

if ($missing_args[0])
{
 print "\nMissing one or more $missing_args[0] required options: $missing_args[1] and\/or $missing_args[2]\n";
 exit 1;
}

$args .= '&terminate=true' if ($terminate);

my $url = $ENV{OPENMAKE_SERVER} . '/reports/launch_va_vm.jsp?' . $args;
my $agent_status = get $url;

print "\n$agent_status\n";
exit (1) if ($agent_status =~ m/Execution FAILED/);