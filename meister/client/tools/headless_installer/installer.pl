#!/usr/bin/perl
#=============================================
# installer.pl
#
#-- Configures headless tar install of client and KB server
#   For use only with Linux and Unix OS types
#
# $Header: /CVS/openmake7/tools/headless_installer/installer.pl,v 1.5 2012/10/03 18:10:40 quinn Exp $
#
# Catalyst Systems Corp: (notifysupport@openmakesoftware.com)
# 
# Copyright 2012, Catalyst Systems Corp

#open DEBUG, ">debug.log";


#-- Set up
#-- use statements

use Getopt::Long;
use Pod::Usage;
use File::Path;
use File::Copy;
use File::Spec::Functions qw/rel2abs/;
use Cwd;
use strict;
use warnings;

#=============================================

#----------------------------------------------
#-- Globals. Use MixedCase

our (
 $Verbose,
 $InstallLocation,
 $KBServerLocation,
 $ClientLocation,
 $JavaLocation,
 $PerlLocation,
 $JREDir,
 $JavaHome,
 $UserHome,
 $do_server,
 $do_client,
 $do_agent,
 $DL,
 $PathDL,
 %KBValues,
 $KBHost,
 $KBHome,
 $jettyPort,
 $ompwFile,
 $ompwCommand,
 $postgresUsername,
 $postgresPassword,
 %omEnvValues,
 $copy_omenv,
 $ClientHost
 );

$DL = "/";
$PathDL = ":";

$InstallLocation = Cwd::abs_path($0);
$InstallLocation =~ s/installer\.pl$//;
$KBServerLocation = $InstallLocation . 'kbserver/';
$ClientLocation = $InstallLocation . 'client/';


###########################################
# -- Print informative intro message 

print( "\n" . "=" x 70 . "\n");
print("= This installer will configure the client and kbserver directories\n");
print("= that have been extracted from the archive file to become functioning\n");
print("= OpenMake installs.  Wherever the tar has been extracted will become\n");
print("= the OpenMake install directory.");
print( "\n" . "=" x 70 . "\n\n");

die "\nThe installer.pl script has been moved from the extraction directory, aborting install ..." unless ((-d $ClientLocation) && (-d $KBServerLocation)) ;

print "Setting permissions on client and kbserver files to prepare for install ...\n\n";
my @chmod_output = `chmod -R 754 $ClientLocation $KBServerLocation`;
my $chmod_RC = $?;
print "chmod of client and kbserver files failed:\n@chmod_output" if ($chmod_RC);

print "Do you want to configure the Knowledge Base server (Y/N)?";
my $serverchoice = <STDIN>;
chomp($serverchoice);

if ($serverchoice =~ m{^y}i)
{
	$do_server = 1;
}
else
{
	$do_server = 0;
}

#-- Get the location of Java and Perl
$JavaLocation = get_java_and_perl_location("java");
$PerlLocation = get_java_and_perl_location("perl");
$JREDir = $JavaLocation;

if($JREDir =~ m{bin[\\/]+java[\.ex]*$}i)
{
	$JREDir =~ s{[\\/]+bin[\\/]+java[\.ex]*$}{}i;
}
elsif ($JREDir =~ m{bin$}i)
{
	$JREDir =~ s{[\\/]+bin[\\/]*$}{}i;
}

my $JRETempDir;
	
if ($JREDir !~ m{jre$}i)
{
	$JRETempDir = $JREDir . $DL . "jre";
	if(-e $JRETempDir)
	{
		$JREDir = $JRETempDir;
	}
}
else
{
	print "Could not find JRE directory" unless(-e $JREDir);
}

$JavaHome = $JREDir;
$JavaHome =~ s{[\\/]+jre}{};

if ($do_server)
{
 #-- print to note start of kbserver portion
 print( "\n" . "=" x 70 . "\n");
 print( "OpenMake installer: Starting install of 'kbserver'\n");
 
 $KBHost = `hostname`;
 chomp($KBHost);
 
 $KBHome = $KBServerLocation . 'tomcat/webapps/openmake.ear';
 
 %KBValues = ('kbHome',$KBHome,
		'kbHost', $KBHost,
		'kbPort', "58080", 
		'bmsPort', "58585", 
		'serverFormat', "STANDARD", 
		'smtpHost',"", 
		'smtpPort',"",
		'useLogin',"",
		'useStartTls',"",
		'senderName',"",
		'senderEmail',"",
		'id',"",
		'password',"",
		'httpAuthDir',"",
		'httpAuthURL',"",
		'ldapAuthType', 'none');
 
 
 $ompwFile = $ClientLocation . 'bin/ompw';
 chmod 0755, $ompwFile;
 
 print "Please provide the database user for Postgres database:\n";	
 postgres_values_prompt('username');
 print "Please provide the postgres database user password:\n";
 postgres_values_prompt('password');
 
 write_web_xml();
 create_ini('kbs.ini');
 create_server_xml();
 create_index_html();
 copy ($KBServerLocation . 'tomcat/webapps/openmake.ear/openmake.war/omint.jar' , $KBServerLocation . 'tomcat/webapps/openmake.ear/openmake.war/WEB-INF/lib');
 print( "\nOpenMake installer: install of 'kbserver' complete\n");
}
else
{
 # delete kbserver files if no kbserver install
 print "\nOpenMake installer: Knowledge Base Server install was declined.  Deleting Knowledge Base server files ...\n";
 unlink ($InstallLocation . 'kbserver');
}

# Always do client install

#-- print to note start of client portion
print( "\n" . "=" x 70 . "\n");
print( "OpenMake installer: Starting install of 'client'\n");

my $username = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
print "The installer detected that the current user is: $username\n";
$copy_omenv = prompt_copy_omenv();

$ClientHost = $do_server ? $KBHost : `hostname`;
chomp $ClientHost;

create_omenv_properties();

unless ($do_server)
{
 my ($junk, $ClientKBHost, $ClientKBPort) = split (':', $omEnvValues{'OPENMAKE_SERVER'});
 $ClientKBHost =~ s{^//}{};
 $ClientKBPort =~ s{/openmake$}{};
 chomp ($ClientKBPort, $ClientKBHost);
 $KBValues{'kbHost'} = $ClientKBHost;
 $KBValues{'kbPort'} = $ClientKBPort;
}

create_buildserver_dir();
create_tools_properties();

print( "\nOpenMake installer: install of 'client' complete\n");

print( "\n" . "=" x 70 . "\n");
print( "\nOpenMake install completed successfully!\n");
print( "\n" . "=" x 70 . "\n");

##############
# End main
##############

####################################
# Start subroutine section
####################################

sub get_java_and_perl_location
{
	my $Java_Perl = shift;

	my $javaExe = "java";
	my $perlExe = "perl";
	my $executable;
	my $javaHome;
	my $javaLocation = "";
	my $javaLocFound = 0;
	my $perlLocFound = 0;
	my $fullpathJavaExe = "";
	my $fullpathPerlExe = "";
	my $perlLocation = "";
	my $osPath = $ENV{'PATH'};
	my @pathDirs;
	
	if ($Java_Perl =~ m{java}i)
	{
		$javaHome = $ENV{'JAVA_HOME'};
		
		$javaHome = "" if(!defined $javaHome);
	
		if ($javaHome =~ m{\w+})
		{
			$fullpathJavaExe = $javaHome . $DL . "bin" . $DL . $javaExe;
			if(-e $fullpathJavaExe)
			{
				$javaLocation = $fullpathJavaExe;
				$javaLocFound = 1;
			}
		}
		
		if($javaLocFound == 0)
		{
			@pathDirs = split( ":",$osPath);
					
			foreach(@pathDirs)
			{
				$fullpathJavaExe = $_ . $DL . $javaExe;
					
				if(-e $fullpathJavaExe)
				{
					$javaLocation = $_;
					$javaLocFound = 1;
				}
			}
	
			my $attempts = 0;
			
			while ($javaLocFound == 0)
			{
				($javaLocation, $attempts) = prompt_for_java_perlloc($attempts, $javaLocation, $javaExe, $Java_Perl);
				
				if (-e $javaLocation)
				{
					$javaLocFound = 1;
				}
			}
		}

		return $javaLocation;
	}
	elsif ($Java_Perl =~ m{perl}i)
	{
		if($perlLocFound == 0)
		{
			@pathDirs = split( ":",$osPath);
					
			foreach(@pathDirs)
			{
				$fullpathPerlExe = $_ . $DL . $perlExe;
					
				if(-e $fullpathPerlExe)
				{
					$perlLocation = $_;
					$perlLocFound = 1;
				}
			}
			
			my $attempts = 0;
			
			while ($perlLocFound == 0)
			{
				($perlLocation, $attempts) = prompt_for_java_perlloc($attempts, $perlLocation, $perlExe, $Java_Perl);
				
				if (-e $perlLocation)
				{
					$perlLocFound = 1;
				}
			}
		}
		
		return $perlLocation;
	}
}
sub prompt_for_java_perlloc
{	
	my $Attempts = shift;
	my $Location = shift;
	my $Exe = shift;
	my $Java_Perl = shift;
	my $JavaLocation;
	my $PerlLocation;
	my $javaExe;
	my $perlExe;
	
	if ($Java_Perl =~ m{java})
	{
		$javaExe = $Exe;
		$JavaLocation = $Location;
	}
	elsif ($Java_Perl =~ m{perl})
	{
		$perlExe = $Exe;
		$PerlLocation = $Location;
	}
	
	
	print "\n";
	if ($Attempts == 0)
	{
			print "Java was not found in the PATH. " if ($Java_Perl =~ m{java});
			print "Perl was not found in the PATH. " if ($Java_Perl =~ m{perl});
	}
	else
	{
			print "The location $JavaLocation did not contain $javaExe executable. " if ($Java_Perl =~ m{java});
			print "The location $PerlLocation did not contain $perlExe executable. " if ($Java_Perl =~ m{perl});	
	}
	
	print "Under which directory is java installed? \n" if($Java_Perl =~ m{java});
	print "Under which directory is perl installed? \n" if($Java_Perl =~ m{perl});
	$JavaLocation = <STDIN> if($Java_Perl =~ m{java});
	$PerlLocation = <STDIN> if($Java_Perl =~ m{perl});
	chomp($JavaLocation) if($Java_Perl =~ m{java});
	chomp($PerlLocation) if($Java_Perl =~ m{perl});
	
	if ($Java_Perl =~ m{java})
	{
		if ($JavaLocation !~ m{bin$})
		{
			$JavaLocation = $JavaLocation . $DL . "bin"
		}
		elsif ($JavaLocation =~ m{quit})
		{
			exit;
		}
	
		$JavaLocation = $JavaLocation . $DL . $javaExe;
		++$Attempts;
	
		return $JavaLocation, $Attempts;
	}
	elsif ($Java_Perl =~ m{perl})
	{
		if ($PerlLocation !~ m{bin$})
		{
			$PerlLocation = $PerlLocation . $DL . "bin"
		}
		elsif ($PerlLocation =~ m{quit})
		{
			exit;
		}
		
		$PerlLocation = $PerlLocation . $DL . $perlExe;
		++$Attempts;
		
		return $PerlLocation, $Attempts;
	}
}
sub write_web_xml
{
	print "\nDo you want to use the default values for:\n 
	kbHost ($KBValues{kbHost})?\n";
	kb_values_prompt("kbHost", "def");
	
	print "kbPort ($KBValues{kbPort})?\n";
	kb_values_prompt("kbPort","def");
	
	$jettyPort = $KBValues{'kbPort'} + 1;
	print "Jetty startup port for Web Management Console will be $jettyPort\n";
	
	print "Build Manager Server Port ($KBValues{bmsPort})?\n";
	kb_values_prompt("bmsPort","def");
	
	print ("-" x 50 . "\n");
	
	print "Do you want to enable email? ";
	my $emailYN = kb_values_prompt("","emailYN");
	
	if ($emailYN == 1)
	{
		print "Please enter the SMTP Host:\n";
		kb_values_prompt("smtpHost","emailVal");
		
		print "Please enter the SMTP Port:\n";
		kb_values_prompt("smtpPort","emailVal");
		
		print "Please enter the display name of the sender:\n";
		kb_values_prompt("senderName","emailVal");
		
		print "Please enter the email address of the sender:\n";
		kb_values_prompt("senderEmail","emailVal");
	
		print "Do you use a login and password for email?\n";
		my $requireLogin = kb_values_prompt("","reqLogin");
		
		print "Do you require SSL?\n";
		kb_values_prompt("","reqSSL");
		
		if ($requireLogin == 1)
		{
			print "Please enter the email login:\n";
			kb_values_prompt("id","emailVal");
			print "Please enter the email password:\nNote: Password will not be encrypted on this prompt, but will be encrypted on the web.xml file\n";
			kb_values_prompt("password","emailVal");
		}
	}
    if ($KBValues{'password'})
	{
	 print "\nRunning ompw to encrypt smtp password ...\n";
     $ompwCommand = $ompwFile . " --encrypt $KBValues{'password'}";
     my @output = run_ompw($ompwCommand);
     $KBValues{'password'} = $output[0];
	}
	 
	my %WebXmlValues = ('X_EARDIR_X',$KBValues{'kbHome'},
		'X_HOST_X', $KBValues{'kbHost'},
		'X_PORT_X', $KBValues{'kbPort'}, 
		'X_BMPORT_X', $KBValues{'bmsPort'}, 
		'X_SMTP_HOST_X',$KBValues{'smtpHost'}, 
		'X_SMTP_PORT_X',$KBValues{'smtpPort'},
		'X_SMTP_USE_LOGIN_X',$KBValues{'useLogin'},
		'X_SMTP_USE_SSL_X',$KBValues{'useStartTls'},
		'X_SENDER_NAME_X',$KBValues{'senderName'},
		'X_SENDER_EMAIL_X',$KBValues{'senderEmail'},
		'X_SMTP_LOGIN_ID_X',$KBValues{'id'},
		'X_SMTP_PASSWORD_X',$KBValues{'password'},
		'X_DBDRIVER_X',"org.postgresql.Driver",
		'X_DBUSERID_X', $postgresUsername,
		'X_DBPASSWORD_X',$postgresPassword,
		'X_DBNAME_X',"jdbc:postgresql:postgres");
 
	my $web_xml = $KBServerLocation . 'tomcat/webapps/openmake.ear/openmake.war/WEB-INF/web.xml';
	my $web_xml_template = $KBServerLocation . 'tomcat/webapps/openmake.ear/openmake.war/WEB-INF/web.xml.template';
 
	open WEBTMP, "$web_xml_template" or die "Unable to open '$web_xml_template': $!";
	my @WebXmlLines = <WEBTMP>;
	close WEBTMP;
 
    open WEBXML, ">$web_xml" or die "Unable to open '$web_xml': $!";;
 
	foreach my $line (@WebXmlLines)
	{
	 if ($line =~ m{(X_.*?_X)})
	 {
	  my $param = $1;
	  $line =~ s{$param}{$WebXmlValues{$param}} if ($WebXmlValues{$param});
      print WEBXML $line;
	 }
	 else
	 {
	  print WEBXML $line;
	 }
	}
	close WEBXML;
}
sub kb_values_prompt
{
	my $key = shift;
	my $updateType = shift;
	
	
	if ($updateType =~ m{def})
	{
		print "Y\\N? ";
		my $YN = <STDIN>;
		if ($YN =~ m{^n}i)
		{
			print "What value do you want for $key? ";
			my $value = <STDIN>;
			chomp($value);
			$KBValues{$key} = $value;
			print "The new value for $key is $KBValues{$key}. Is this correct? ";
			kb_values_prompt($key,$updateType);
		}
		elsif ($YN !~ m{^y}i)
		{
			print "I didn't understand that option.";
			kb_values_prompt($key,$updateType);
		}
	}
	elsif ($updateType =~ m{emailYN}i)
	{
		print "Y\\N? ";
		my $emailYN;
		my $YN = <STDIN>;
		if ($YN =~ m{^n}i)
		{
			$emailYN = 0;

		}
		elsif ($YN !~ m{^y}i)
		{
			print "I didn't understand that option.";
			kb_values_prompt($key,$updateType);
		}
		else
		{
			$emailYN = 1;
		}
		return $emailYN;
	}
	elsif (($updateType =~ m{emailval}i) || ($updateType =~ m{postgres}i))
	{
		my $value = <STDIN>;
		chomp($value);
		$KBValues{$key} = $value;
	}
	elsif ($updateType =~ m{reqlogin}i)
	{
		print "Y\\N? ";
		my $requireLogin;
		my $YN = <STDIN>;
		if ($YN =~ m{^n}i)
		{
			$requireLogin = 0;
		}
		elsif ($YN !~ m{^y}i)
		{
			print "I didn't understand that option.";
			kb_values_prompt($key,$updateType);
		}
		else
		{
			$requireLogin = 1;
			$KBValues{useLogin} = "1";
		}
		return $requireLogin;
	}
	elsif ($updateType =~ m{reqssl}i)
	{
		print "Y\\N? ";
		my $requireSSL;
		my $YN = <STDIN>;
		if ($YN =~ m{^n}i)
		{
			$requireSSL = 0;
		}
		elsif ($YN !~ m{^y}i)
		{
			print "I didn't understand that option.";
			kb_values_prompt($key,$updateType);
		}
		else
		{
			$requireSSL = 1;
			$KBValues{useStartTls} = "1";
		}
		return;
	}
}
sub postgres_values_prompt
{
 my $value_type = shift;
 my $value = <STDIN>;
 chomp($value);
 print "The value for postgres $value_type is $value. Is this correct(Y\\N)?\n";
 my $YN = <STDIN>;
 chomp($YN);
 if ($YN !~ m{^y}i)
 {
  print "Please re-enter $value_type\n";
  postgres_values_prompt($value_type);
 }
 if ($value_type =~ /username/)
 {
  $postgresUsername = $value;
 }
 elsif ($value_type =~ /password/)
 {
  $postgresPassword = $value;
  print "\nRunning ompw to encrypt postgres password ...\n";
  $ompwCommand = $ompwFile . " --encrypt $postgresPassword";
  my @output = run_ompw($ompwCommand);
  $postgresPassword = $output[0];
 }
}
sub create_ini
{
 my $ini_file = shift;
 
 $ini_file = ($ini_file =~ m{kbs}i) ? $KBServerLocation . 'kbs.ini' : $ClientLocation . 'buildserver/rbs.ini';
 open INI, ">$ini_file" or die "Unable to open '$ini_file': $!";
 print INI "JRE_DIR=$JREDir\n";
 close INI;
}
sub create_server_xml
{
 my $server_xml = $KBServerLocation . 'tomcat/conf/server.xml';
 my $server_xml_template = $KBServerLocation . 'tomcat/conf/server.xml.template';
 
 open SRVTMP, "$server_xml_template" or die "Unable to open '$server_xml_template': $!";;
 my @ServerXmlLines = <SRVTMP>;
 close SRVTMP;
 
 open SRVXML, ">$server_xml";
 
 foreach my $line (@ServerXmlLines)
 {
  if ($line =~ m{X_PORTNO_X})
  {
   $line =~ s{X_PORTNO_X}{$KBValues{'kbPort'}};
   print SRVXML $line;
  }
  else
  {
   print SRVXML $line;
  }
 }
 close SRVXML;
}
sub create_index_html
{
 my $index_html = $KBServerLocation . 'tomcat/webapps/openmake.ear/openmake.war/index.html';
 my $index_html_template = $KBServerLocation . 'tomcat/webapps/openmake.ear/openmake.war/index.html.template';
 
 open IDXTMP, "$index_html_template";
 my @IndexHtmlLines = <IDXTMP>;
 close IDXTMP;
 
 open IDXHTML, ">$index_html_template";
 
 foreach my $line (@IndexHtmlLines)
 {
  if ($line =~ m{X_HOST_X:X_PORT_X})
  {
   $line =~ s{X_HOST_X:X_PORT_X}{$KBValues{'kbHost'}:$jettyPort};
   print IDXHTML $line;
  }
  else
  {
   print IDXHTML $line;
  }
 }
 close IDXHTML;
}

sub run_ompw
{
 my $ompw_command = shift;
 my @ompwOutput = `$ompw_command`;
 my $ompwRC = $?;
 if ($ompwRC !~ m{^0})
 {
 	print "\nThe ompw command did not execute correctly.\n" ;
 }
 else
 {
  	print "\nExecution of ompw succesful.\n" ;
 }
 return @ompwOutput;
}
sub create_omenv_properties
{

 my $omenv_properties = $ClientLocation . 'bin/omenvironment.properties';
 
 print "\nNow creating omenvironment.properties file in client/bin directory ...\n";
 
 open OMENV, ">$omenv_properties"  or die "Unable to open '$omenv_properties': $!";
 
 if($do_server)
 {
  my $openmakeServer = "http://" . $KBValues{'kbHost'} . ":" . $KBValues{'kbPort'} . "/openmake";
  $omEnvValues{OPENMAKE_SERVER} = $openmakeServer;
 }
 else
 {
  if($ENV{OPENMAKE_SERVER})
  {
   $omEnvValues{OPENMAKE_SERVER} = $ENV{OPENMAKE_SERVER};
  }
  else
  {
   my $om_server_bad = 1;
   while ($om_server_bad)
   {
    print "\n\nPlease enter a value for OPENMAKE_SERVER: ";
    my $openmakeServer = <STDIN>;
    chomp($openmakeServer);
	if ($openmakeServer =~ m{http://.*:{1}.*/openmake})
	{
     $omEnvValues{OPENMAKE_SERVER} = $openmakeServer;
	 $om_server_bad = 0;
	}
	else
	{
	 print "The proper format for OPENMAKE_SERVER is: http://<host>:<port>/openmake. Please try again\n";
	}
   }
  } 
 }
 
 $InstallLocation .= $DL unless ($InstallLocation =~ m/$DL$/);
 
 my $openmakeHome = $InstallLocation . "client";
 my $perlLib = $openmakeHome . $DL . "perl" . $DL . "lib";
 my $refDir = $openmakeHome . $DL . "examples" . $DL . "ref";
 $omEnvValues{PERLLIB} = $perlLib;
 $omEnvValues{REFDIR} = $refDir;
 $omEnvValues{OPENMAKE_HOME} = $openmakeHome;
 $omEnvValues{JAVA_HOME} = $JavaHome;
 
 foreach my $key (keys %omEnvValues)
 {
  print OMENV $key . '=' . $omEnvValues{$key} . "\n";
 }
 close OMENV;
 if ($copy_omenv)
 {
  my $home_dot_openmake = $ENV{HOME} . $DL . '.openmake';
  print "\nNow attempting to move omenvironment.properties to $home_dot_openmake directory ...\n";
  unless (-d $home_dot_openmake)
  {
   mkpath($home_dot_openmake) or warn "Unable to create directory '$home_dot_openmake'";
  }
  copy ($omenv_properties, $home_dot_openmake) or warn "Unable to copy omenvironment.properties";;
 }
}
sub create_buildserver_dir
{
 my $buildserver_dir = $ClientLocation . 'buildserver';
 my $rbs_startup_xml = $ClientLocation . 'buildserver/rbs_startup.xml';
 
 mkpath($buildserver_dir) or die "Unable to create directory '$buildserver_dir': $!";
 
 create_ini('rbs.ini');
 
 open RBSXML, ">$rbs_startup_xml";
 
 my $rbs_xml_contents = <<RXML;
<?xml version="1.0" encoding="UTF-8"?>
<web-app id="WebApp_ID"><display-name>Openmake Remote Build Agent</display-name><description>Openmake</description><servlet id="Servlet_1"><servlet-name>InitServer</servlet-name><display-name>InitServer</display-name><description>The servlet initializes the Openmake Remote Build Agent.</description><servlet-class>com.openmake.servlet.InitServer</servlet-class><init-param id="InitParam_1"><param-name>-home</param-name><param-value>$buildserver_dir</param-value></init-param><init-param id="InitParam_2"><param-name>-kbHost</param-name><param-value>$KBValues{'kbHost'}</param-value></init-param><init-param id="InitParam_3"><param-name>-kbPort</param-name><param-value>$KBValues{'kbPort'}</param-value></init-param><init-param id="InitParam_4"><param-name>-host</param-name><param-value>$ClientHost</param-value></init-param><init-param id="InitParam_5"><param-name>-port</param-name><param-value>59090</param-value></init-param><init-param id="InitParam_6"><param-name>-localMode</param-name><param-value>true</param-value></init-param><init-param id="InitParam_7"><param-name>-debug</param-name><param-value>false</param-value></init-param><init-param id="InitParam_8"><param-name>-hostAlias</param-name><param-value>$ClientHost</param-value></init-param><load-on-startup>1</load-on-startup></servlet></web-app>
RXML
 print RBSXML "$rbs_xml_contents\n";
 close RBSXML;

}
sub create_tools_properties
{
 my $tools_properties = $InstallLocation. 'client/bin/tools.properties';
 
 open TOOLS, ">$tools_properties";
 
 my $ToolsLines = "TOOLS_DIR=" . $InstallLocation . "/client/tools\n";
 $ToolsLines .= "PERLLIB=" . $InstallLocation . "/client/perl/lib\n";
 $ToolsLines .= "OPENMAKE_HOME=" . $InstallLocation . "/client\n";
 $ToolsLines .= "DOXYGEN_BIN_DIR=\n";
 $ToolsLines .= "NCOVER_BIN_DIR=\n";
 $ToolsLines .= "NUNIT_BIN_DIR=\n";
 
 print TOOLS $ToolsLines;
 close TOOLS;
}

sub prompt_copy_omenv
{
 print "Would you like to have the omenvironment.properties file created in the \$HOME/.openmake directory of $username? (Y\\N)?:\n";
 my $YN = <STDIN>;
 chomp($YN);
 if ($YN =~ m{^y}i)
 {
  print "\nomenvironment.properties will be copied into $ENV{HOME}\n";
  return 1;
 }
 elsif ($YN =~ m{^n}i)
 {
   print "\nomenvironment.properties will not be copied.  In order for a user to run Meister workflows,\nthey will need to copy omenvironment.properties into their user's \$HOME/.openmake directory.\n";
   return 0;
 }
 else
 {
  print "\nI didn't understand that selection.\n";
  my $return = prompt_copy_omenv();
  return $return;
 }
}
