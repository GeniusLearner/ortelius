#==========================================================================
#-- $Header: /CVS/openmake64/perl/lib/Openmake/Log.pm,v 1.31 2011/04/27 20:42:02 steve Exp $
#==========================================================================
package Openmake::Log;

#-- JAG - 01.16.05 - note that Log.pm does not use autoloader
#
#-- JAG - 10.11.05 - attempt to clean up this kruft.
#                     1. All calls from the script to HTML are cached in memory
#                     2. Final call (either to 'Final' or via END sub) make
#                        the connection to the omlogger daemon

BEGIN
{
 use Exporter ();
 use vars qw(@ISA @EXPORT %EXPORT_TAGS @EXPORT_OK $VERSION
             $INFO_EVENTTYPE $ERROR_EVENTTYPE $WARNING_EVENTTYPE
             $SUMMARY_EVENTTYPE $DETAIL_EVENTTYPE
             $HTML_Log_Message $HTML_Short_Message $HTML_Event_Type
             $Begun $HTTP_POST_HEADER $SOAP_POST_HEADER
             );
 use Cwd;

 #use Openmake::IPC; #-- JAG - 07.17.07 - case MSD-184

 $INFO_EVENTTYPE    = 0;
 $ERROR_EVENTTYPE   = 1;
 $WARNING_EVENTTYPE = 2;
 $SUMMARY_EVENTTYPE = 4;
 $DETAIL_EVENTTYPE  = 8;
 $BOM_EVENTTYPE     = 64;

 $Begun             = 0;

 #-- JAG - 05.31.06 - case 7156
 $HTTP_POST_HEADER = <<EOF;
POST /openmake/LogUpload HTTP/1.1\r
Host: XX_IP_XX:XX_PORT_XX
Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/msword, application/pdf, application/x-shockwave-flash, */*\r
Accept-Language: en-us\r
Connection: close\r
Content-Type: multipart/form-data; boundary=---------------------------7d3cc298904e2\r
Accept-Encoding: gzip, deflate\r
User-Agent: Openmake Logger 6.2\r
EOF

 #-- JAG - 05.31.06 - case 7156
 $SOAP_POST_HEADER = <<EOF;
POST /soap/servlet/openmakeserver HTTP/1.1\r
Content-type: text/xml\r
Connection: close\r
SOAPAction: ""\r
Host: XX_IP_XX:XX_PORT_XX
User-Agent: Java1.3.0_01\r
EOF

 @ISA = qw(Exporter);

 %EXPORT_TAGS = (
  'all' => [ qw( &omlogger &omlogger_ev &setupJob &setLogVariables &SendSoapMessage
                 $INFO_EVENTTYPE $ERROR_EVENTTYPE $WARNING_EVENTTYPE
                 $SUMMARY_EVENTTYPE $DETAIL_EVENTTYPE $BOM_EVENTTYPE) ],
  'constants' => [ qw( $INFO_EVENTTYPE $ERROR_EVENTTYPE $WARNING_EVENTTYPE
                 $SUMMARY_EVENTTYPE $DETAIL_EVENTTYPE $BOM_EVENTTYPE $HTTP_POST_HEADER) ]
    );

# @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
 @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );
 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/Log.pm,v 1.31 2011/04/27 20:42:02 steve Exp $';
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }
}

#----------------------------------------------------------------
sub omlogger
{
 my @input = @_;

 my $input_ref;
 #-- test to see if we get a hash ref, instead of crazy lists.
 if ( ref($input[0]) eq 'HASH' )
 {
  $input_ref = $input[0];
  #-- check for 'EventType'
  $input_ref->{'EventType'} = $DETAIL_EVENTTYPE unless ( $input_ref->{'EventType'});
 }
 else
 {
  #-- this is the old-style format
  my ( $StepStatus, $StepDescription, $RegExp, $LastLine, $Compiler,
       $CompilerArguments, $IncludeNL, $RC, @CompilerOut ) = @_;

  #-- create the hash here
  $input_ref->{EventType}       = $DETAIL_EVENTTYPE;
  $input_ref->{StepStatus}      = $StepStatus;
  $input_ref->{StepDescription} = $StepDescription;
  $input_ref->{RegExp}   = $RegExp;
  $input_ref->{LastLine} = $LastLine;
  $input_ref->{Compiler} = $Compiler;
  $input_ref->{CompilerArguments} = $CompilerArguments;
  $input_ref->{IncludeNL} = $IncludeNL;
  $input_ref->{RC} = $RC;
  $input_ref->{CompilerOut} = \@CompilerOut;
 }
 #-- JAG 12.12.07 - case FLS-253 -  remove nulls
 map { s{\0}{\n}g; } @{$input_ref->{'CompilerOut'}};

 ################################################
 # The main function for logging
 die( "Illegal StepStatus: $input_ref->{StepStatus} passed to omlogger\n" )
  if ( $input_ref->{StepStatus} !~ /Begin|Intermediate|Final|Abort|Bom/i );

 if ( $input_ref->{StepStatus} eq "Begin" && $Begun == 0 )
 {
  $Begun = 1;
 }

 omlogger_screen( $input_ref ) if ( $main::OutputType =~ /screen|both/i );
 #-- JAG - 07.17.07 - case MSD-193
 if ( $main::OutputType =~ /html|both/i || $input_ref->{StepStatus} =~ m{BOM}i )
 {
  omlogger_html( $input_ref );
 }
 omlogger_xml( $input_ref )    if ( $main::OutputType =~ /xml/i );
} #-- End: sub omlogger

#----------------------------------------------------------------
sub omlogger_ev
{
 my $EventType = shift;
 my @input     = @_;
 my $input_ref;
 if ( ref($input[0]) eq 'HASH' )
 {
  $input_ref = $input[0];
 }
 else
 {
  #-- this is the old-style format
  my ( $StepStatus, $StepDescription, $RegExp, $LastLine, $Compiler,
       $CompilerArguments, $IncludeNL, $RC, @CompilerOut ) = @_;

  #-- create the hash here
  $input_ref->{StepStatus}      = $StepStatus;
  $input_ref->{StepDescription} = $StepDescription;
  $input_ref->{RegExp}   = $RegExp;
  $input_ref->{LastLine} = $LastLine;
  $input_ref->{Compiler} = $Compiler;
  $input_ref->{CompilerArguments} = $CompilerArguments;
  $input_ref->{IncludeNL} = $IncludeNL;
  $input_ref->{RC} = $RC;
  $input_ref->{CompilerOut} = \@CompilerOut;
 }
 #-- JAG 12.12.07 - case FLS-253 -  remove nulls
 map { s{\0}{\n}g; } @{$input_ref->{'CompilerOut'}};

 $input_ref->{EventType} = $EventType;

 die( "Illegal StepStatus: $input_ref->{StepStatus} passed to omlogger\n" )
  if ( $input_ref->{StepStatus} !~ /Begin|Intermediate|Final|Abort|Bom/i );

 if ( $input_ref->{StepStatus} eq "Begin" && $Begun == 0 )
 {
  $Begun = 1;
 }

 omlogger_screen( $input_ref) if ( $main::OutputType =~ /screen|both/i );
 omlogger_html(   $input_ref) if ( $main::OutputType =~ /html|both/i );
}

#----------------------------------------------------------------
sub omlogger_screen
{
 my ( $EventType, $StepStatus, $StepDescription, $RegExp,
      $LastLine, $Compiler, $CompilerArguments,
      $IncludeNL, $RC, @CompilerOut ) = _parse_input_hash(shift);

 # we need the following set of additional parameters:

 my $Footer        = $main::ScriptFooter;
 my $Header        = $main::ScriptHeader;
 my $ScriptVersion = $main::ScriptVersion;
 my $Quiet         = $main::Quiet;
 my $Source        = $Compiler;

 return if ( $StepStatus =~ /BOM/i);

 if ( $StepStatus =~ /Begin/i )
 {
  if ( $Quiet !~ /yes/i )
  {
   print '-' x 70 . "\n";
   print " $StepDescription\n" if ( $StepDescription );
   print "$Header $ScriptVersion\n" if ( $Header ne '' );
   my $create_string = 'Creating ' . $main::Target->get;
   if ( $StepDescription !~ m{\Q$create_string\E} )
   {
    print " Creating " . $main::Target->get . "\n\n";
   }

   @CompilerOut = split( /\n/, "$Compiler $CompilerArguments\n$IncludeNL" );
   foreach $line ( @CompilerOut )
   {
    #-- don't use SplitLine for screen dumps
    print '   ', $line, "\n";
   }
  } #-- End: if ( $Quiet !~ /yes/i ...
  else
  {
   print "Creating " . $main::Target->get . "\n";
  }
 } #-- End: if ( $StepStatus =~ /Begin/i...
 else
 {
  print "\n" if ( $Quiet !~ /yes/i );
  foreach $line ( @CompilerOut )
  {
   #-- don't use SplitLine for screen dumps
   print '   ', $line;
  }
 }
} #-- End: sub omlogger_screen

#----------------------------------------------------------------
sub omlogger_html
{
 # ET: 4,
 # SStatus: "Begin",
 # SDesc: "Creating $TargetFile\n",
 # Regexp: "ERROR:",
 # LastLine: "Creating $TargetFile\n",
 # Compiler: "Creating $TargetFile\n");

 my ( $EventType, $StepStatus, $StepDescription, $RegExp,
      $LastLine, $Compiler, $CompilerArguments,
      $IncludeNL, $RC, @CompilerOut ) = _parse_input_hash(shift);

 # we need the following set of additional parameters:
 my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdist ) = localtime( time );

 $EventType        |= $DETAIL_EVENTTYPE;
 my $JobName        = $main::JobName;
 my $JobDateTime    = $main::JobDateTime;
 my $DateTime       = sprintf "%02d/%02d/%02d %02d:%02d:%02d", $mon, $mday, $year - 100, $hour, $min, $sec;
 my $MachineName    = $main::JobMachineName;
 my $PublicBuildJob = $main::PublicBuildJob;
 my $UserId         = $main::LogOwner;
 my $Quiet          = $main::Quiet;

 my $Event       = "Running";
 my $Source      = "$main::ScriptHeader $ScriptVersion";
 my $DetailGroup = $main::FinalTarget->get();

 my $Footer        = $main::ScriptFooter;
 my $Header        = $main::ScriptHeader;
 my $ScriptVersion = $main::ScriptVersion;

 $HTML_Event_Type |= $EventType; #-- get all the event types that are sent

 if ($StepStatus eq "BOM")
 {
  SendBomSoapMessage($JobName, $JobDateTime, $MachineName, $UserId, $PublicBuildJob,$CompilerArguments);
  return;
 }
 else
 {
  if ( ( $RC != 0 && $StepStatus !~ /Begin/i ) || $StepStatus =~ /Abort/i )
  {
   $EventType |= ($DETAIL_EVENTTYPE | $ERROR_EVENTTYPE ) ;
   $Event     = "ERROR";
   $HTML_Event_Type |= $EventType; #-- get all the event types that are sent
   $HTML_Short_Message  = $LastLine || $StepDescription; #-- JAG 11.15.05 - case 6427
  }

  if ( $StepStatus =~ /Begin/i )
  {
   if ( $Begun == 1 )
   {
    $HTML_Short_Message = $StepDescription;

    #-- add header to $HTML_Message
    $HTML_Log_Message .= "$Header $ScriptVersion\n" if ( $Header ne '' );
    $Begun++;
   }

   if ( $Quiet !~ /yes/i )
   {
    #$HTML_Log_Message .= "\nCreating " . $main::Target->get . "\n";
    #-- JAG 12.01.05 - case 6536
    @CompilerOut = ();
    my $split_line;
    $split_line .= $Compiler if ( $Compiler );
    $split_line .= " $CompilerArguments\n" if ( $CompilerArguments);
    $split_line .= $IncludeNL if ( $IncludeNL);

    if ( $split_line )
    {
     @CompilerOut = split( /\n/, $split_line );

     foreach my $line ( @CompilerOut )
     {
	  $line =~ s/</\&lt;/g;   #Escape <  SBT 12.26.07 FLS-108
	  $line =~ s/>/\&gt;/g;   #Escape >  SBT 12.26.07 FLS-108
	
      $HTML_Log_Message .= SplitLine( "   $line\n" );
     }
    }
   }
   else
   {
    $HTML_Log_Message = "Creating " . $main::Target->get . "\n";
   }
  } #-- End: if ( $StepStatus =~ /Begin/i...
  else
  {
   #-- not the beginning ...
   foreach $line ( @CompilerOut )
   {
	$line =~ s/</\&lt;/g;   #Escape <  SBT 12.26.07 FLS-108
	$line =~ s/>/\&gt;/g;   #Escape >  SBT 12.26.07 FLS-108
    $HTML_Log_Message .= SplitLine( "    $line" );
   }
  }


#  #-- send message after caching all messages.
#  if ( $StepStatus =~ /Final/i || $StepStatus =~ /Abort/i )
#  {
#   SendSoapMessage( $EventType, $JobName, $JobDateTime, $MachineName, $UserId,
#                    $PublicBuildJob, $Event, $DetailGroup, $DateTime, $Source,
#                    $HTML_Short_Message, $HTML_Log_Message );
#  }
 }

} #-- End: sub omlogger_html

#----------------------------------------------------------------
sub omlogger_xml
{
 my ( $EventType, $StepStatus, $StepDescription, $RegExp,
      $LastLine, $Compiler, $CompilerArguments,
      $IncludeNL, $RC, @CompilerOut ) = _parse_input_hash(shift);

 # we need the following set of additional parameters:

 my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdist ) = localtime( time );

 $EventType        |= $DETAIL_EVENTTYPE;
 my $JobName        = $main::JobName;
 my $JobDateTime    = $main::JobDateTime;
 my $DateTime       = sprintf "%02d/%02d/%02d %02d:%02d:%02d", $mon + 1, $mday, $year - 100, $hour, $min, $sec;
 my $MachineName    = $main::JobMachineName;
 my $PublicBuildJob = $main::PublicBuildJob;
 my $UserId         = $main::LogOwner;
 my $Quiet          = $main::Quiet;

 my $Event       = "Running";
 my $Source      = "$main::ScriptHeader $ScriptVersion";
 my $DetailGroup = $main::FinalTarget->get();
 my $ShortMsg    = "";
 my $Message     = "";

 return if ( $StepStatus =~ /BOM/i);
 return if ( $StepStatus !~ /Final/i );

 if ( ( $RC != 0 && $StepStatus !~ /Begin/i ) || $StepStatus =~ /Abort/i )
 {
  $EventType |= ( $ERROR_EVENTTYPE | $DETAIL_EVENTTYPE );
  $Event     = "ERROR";
  $ShortMsg  = $LastLine;
 }

 my $logname = $main::XmlBuildLog;

 open( FP, ">>$logname" );

 #-- JAG 12.17.04 - case 5341 - fix for malformed XML
 print FP " <TargetItem>\n";
 print FP "  <Name>", escapeLine( $main::Target->getFE ), "</Name>\n";
 print FP "  <Path>", escapeLine( $main::Target->getP ),  "</Path>\n";
 print FP "  <BuildType>",   escapeLine( $main::BuildType ),  "</BuildType>\n";
 print FP "  <BuildScript>", escapeLine( $main::ScriptName ), "</BuildScript>\n";
 print FP "  <Options>", escapeLine( "$Compiler $CompilerArguments $Include" ), "</Options>\n";
 print FP "  <MetaData>", escapeLine( $main::TargetVersionInfo ), "</MetaData>\n";
 print FP "  <ReturnCode>", escapeLine( $RC ), "</ReturnCode>\n";

 #-- following code got regressed
 print FP $_, "\n" foreach (@main::XMLDepList);

 print FP " </TargetItem>\n";

 close( FP );
} #-- End: sub omlogger_xml

#----------------------------------------------------------------
sub SplitLine()
{
 my $line    = shift;
 my $tmpline = $line;
 my $indent  = 0;

 $tmpline =~ s/^\s+//;
 $indent = length( $line ) - length( $tmpline );

 if ( length( $line ) < 75 )
 {
  return $line;
 }

 my @wlist = split( /\s+/, $tmpline );

 $len = 0;
 my $newline = sprintf ' ' x $indent;

 foreach $w ( @wlist )
 {
  if ( $len + length( $w ) + 1 < 75 )
  {
   $newline .= "$w ";
   $len += length( $w ) + 1;
  }
  else
  {
   $newline .= "\n";
   $newline .= sprintf ' ' x $indent;
   $newline .= "$w ";
   $len = length( $w );
  }
 } #-- End: foreach $w ( @wlist )
 $newline .= "\n";
 return $newline;
} #-- End: sub SplitLine()

#----------------------------------------------------------------
sub SendSoapMessage
{
 my ( $EventType,
      $JobName,
      $JobDateTime,
      $MachineName,
      $UserId,
      $PublicBuildJob,
      $Event,       #-- not used ?
      $DetailGroup, #-- not used ?
      $DateTime,    #-- not used ?
      $Source,      #-- not used ?
      $ShortMsg,
      $Message ) = @_;


 if ($main::OutputType eq "screen")
 {
  push(@CompilerOut,$Message);	
  omlogger("Intermediate", " ", " ", " ", " "," "," "," ",@CompilerOut );
  return 0;
 }

 #-- override if this is a local build. Check if the queue is available
 #-- JAG - 07.16.07 - case MSD-184. Only need to log directly to the KB Server
 return SendDirectSoapMessage( @_ );

} #-- End: sub SendSoapMessage

#----------------------------------------------------------------
sub SendBomSoapMessage
{
 my ($JobName, $JobDateTime, $MachineName, $UserId, $PublicBuildJob,$Message ) = @_;
 my $IsBomRpt = "true";
 my ( $ipaddr, $Port) = getIPPortKBServer( $ENV{"OPENMAKE_SERVER"});

 my $file         = "/openmake/LogUpload";
 my $Url          = "http://$ipaddr:$Port/$file";
 my $BuildJobName = "$JobName-$MachineName-$JobDateTime";
 my $FileName     = "D:\\tmp\\";

 $FileName .= $BuildJobName;

 (my $Header = $HTTP_POST_HEADER ) =~ s/XX_IP_XX/$ipaddr/ ;
 $Header =~ s/XX_PORT_XX/$Port/;

 my $SoapMessage = "";

 $SoapMessage = <<SEOF;
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="JobName"\r
\r
$JobName\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="Owner"\r
\r
$UserId\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="Machine"\r
\r
$MachineName\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="PublicBuildJob"\r
\r
$PublicBuildJob\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="BomReport"\r
\r
$IsBomRpt\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="JobDateTime"\r
\r
$JobDateTime\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="Type"\r
\r
SEOF

 $SoapMessage .= "\r\n";
 $SoapMessage .= "-----------------------------7d3cc298904e2\r\n";

 $SoapMessage .= "Content-Disposition: form-data; name=\"mptest\"; filename=\"";
 $SoapMessage .= $FileName . "-BOM.html\"\r\n";
 $SoapMessage .= "Content-Type: text/html\r\n";
 $SoapMessage .= "\r\n";
 $SoapMessage .= $Message;
 $SoapMessage .= "\r\n";
 $SoapMessage .= "-----------------------------7d3cc298904e2--\r\n";
 $SoapMessage .= "\r\n";

 $Header .= sprintf "Content-Length: %ld\n", length( $SoapMessage );

 #-- use generic post
 TcpPost( "$Header\n$SoapMessage\n\n");

} #-- End: sub SendBomSoapMessage

#------------------------------------------------------------------
sub HttpPost
{ 
 my $file_or_message = shift;
 my $type = shift;
 my ( $ipaddr, $port ) = getIPPortKBServer( $ENV{"OPENMAKE_SERVER"});
 my $message;
 if ( -e $file_or_message )
 {
  unless ( open ( FILE, '<', $file_or_message))
  {
   return;
  }
  my @lines = <FILE>;
  close FILE;
  $message = join "\n", @lines;
 }
 else
 {
  $message = $file_or_message;
 }

 #-- create Header based on type
 my $header = $HTTP_POST_HEADER;
 if ( (lc $type) eq "soap" )
 {
  $header = $SOAP_POST_HEADER;
 }
 $header =~ s/XX_IP_XX/$ipaddr/ ;
 $header =~ s/XX_PORT_XX/$port/;
 $header .= sprintf "Content-Length: %ld\n", length( $message );

 #-- use generic post
 TcpPost( "$header\n$message\n\n");

 return ;
}

#------------------------------------------------------------------
sub TcpPost
{

 if ($main::SocketInit == 0)
 {
  eval("require IO::Socket;");
  $main::SocketInit = 1;
 }

 #-- Generic function to post a message to a KB Server
 my $message  = shift;
 my ( $ipaddr, $port) = getIPPortKBServer( $ENV{"OPENMAKE_SERVER"});

 #-- Check if address is a name and then make sure it resolves
 unless ( $ipaddr =~ /^\d+\.\d+\.\d+\.\d+$/ )
 {
  die "Couldn't resolve hostname $ipaddr.  Exiting Log.pm ...\n"
    unless gethostbyname( $ipaddr );
 }
 $server = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "$ipaddr:$port")
  or warn "ERROR: Couldn't establish socket with KB server.";

 print $server $message;

 local $_;
 while ( <$server> )
 {
  #-- JAG - 10.10.06 - case 7409 -  wait for the log upload to be complete and
  #   written to disk. May need a timeout on this?
  #
  if ( m{!!!LOG_UPLOAD_COMPLETE!!!} )
  {
   last;
  }
 }
 close $server;

 return ;
}

#------------------------------------------------------------------
sub getIPPortKBServer
{
 my $kbserver = substr( shift, 7 );
 my $port     = 80;
 my $pos      = index $kbserver, ":";
 my $ipaddr   = "localhost";

 if ( $pos >= 0 )
 {
  $ipaddr   = substr( $kbserver, 0, $pos );
  $kbserver = substr( $kbserver, $pos + 1 );
 }
 else
 {
  $pos = index $kbserver, "/";
  if ( $pos >= 0 )
  {
   $ipaddr   = substr( $kbserver, 0, $pos );
   $kbserver = substr( $kbserver, $pos + 1 );
  }
 }

 $pos = index $kbserver, "/";
 if ( $pos > 0 )
 {
  $port = substr( $kbserver, 0, $pos );
 }
 return ( $ipaddr, $port ) ;
}

#----------------------------------------------------------------
sub setupJob
{
 #-- JAG 06.20.05 - case 5940 - too much junk
 # print "IN Openmake::setupJob\n";

 if ($main::SocketInit == 0)
 {
  eval("require IO::Socket;");
  $main::SocketInit = 1;
 }

 my $cmd = shift;
 my $RC  = shift;

 #-- test that $cmd is as expected
 return 1 unless ( ref $cmd eq "HASH" );

 if (
  !(
   defined $cmd->{lj}
   &&
   defined $cmd->{lm} &&
   defined $cmd->{lo} &&
   defined $cmd->{ld} ) )
 {
  return 2;
 } #-- End: if ( !( defined $cmd->...

 #-- edit check on log-date.
 return 3 unless ( $cmd->{ld} =~ /2\d{3}-\d{2}-\d{2} \d{2}_\d{2}_\d{2}/ );

 #-- if we're not uploading to the KB Server, exit normally
 return unless ( $cmd->{ob} || $cmd->{oh} );

 #-- initialize the job
 my $kbserver          = substr( $ENV{"OPENMAKE_SERVER"}, 7 );
 my $Port              = 80;
 my $pos               = index $kbserver, ":";
 my $ipaddr            = "localhost";
 my $INFO_EVENTTYPE    = 0;
 my $ERROR_EVENTTYPE   = 1;
 my $WARNING_EVENTTYPE = 2;
 my $SUMMARY_EVENTTYPE = 4;
 my $DETAIL_EVENTTYPE  = 8;

 if ( $pos >= 0 )
 {
  $ipaddr = substr( $kbserver, 0, $pos );
  $kbserver = substr( $kbserver, $pos + 1 );
 }
 else
 {
  $pos = index $kbserver, "/";
  if ( $pos >= 0 )
  {
   $ipaddr = substr( $kbserver, 0, $pos );
   $kbserver = substr( $kbserver, $pos + 1 );
  }
 }

 $pos = index $kbserver, "/";
 if ( $pos > 0 )
 {
  $Port = substr( $kbserver, 0, $pos );
 }

 my $file         = "/openmake/LogUpload";
 my $Url          = "http://$ipaddr:$Port/$file";
 my $BuildJobName = $cmd->{lj} . "-" . $cmd->{lm} . "-" . $cmd->{ld};
 my $FileName     = "D:\\tmp\\";

 $FileName .= $BuildJobName . "-Summary.html";

 my $header = "";
 $header .= "POST /openmake/LogUpload HTTP/1.1\r\n";
 $header .= "Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/msword, application/pdf, application/x-shockwave-flash, */*\r\n";
 $header .= "Accept-Language: en-us\r\n";
 $header .= "Connection: close\r\n"; #-- JAG - 05.31.06 - case 7156
 $header .= "Content-Type: multipart/form-data; boundary=---------------------------7d3cc298904e2\r\n";
 $header .= "Accept-Encoding: gzip, deflate\r\n";
 $header .= "User-Agent: Openmake Logger 6.2\r\n";

 my $SOAPStr = "";
 $SOAPStr .= "-----------------------------7d3cc298904e2\r\n";
 $SOAPStr .= "Content-Disposition: form-data; name=\"JobName\"\r\n";
 $SOAPStr .= "\r\n";
 $SOAPStr .= $cmd->{lj};
 $SOAPStr .= "\r\n";
 $SOAPStr .= "-----------------------------7d3cc298904e2\r\n";
 $SOAPStr .= "Content-Disposition: form-data; name=\"Owner\"\r\n";
 $SOAPStr .= "\r\n";
 $SOAPStr .= $cmd->{lo};
 $SOAPStr .= "\r\n";
 $SOAPStr .= "-----------------------------7d3cc298904e2\r\n";
 $SOAPStr .= "Content-Disposition: form-data; name=\"Machine\"\r\n";
 $SOAPStr .= "\r\n";
 $SOAPStr .= $cmd->{lm};
 $SOAPStr .= "\r\n";
 $SOAPStr .= "-----------------------------7d3cc298904e2\r\n";
 $SOAPStr .= "Content-Disposition: form-data; name=\"JobDateTime\"\r\n";
 $SOAPStr .= "\r\n";
 $SOAPStr .= $cmd->{ld};
 $SOAPStr .= "\r\n";
 $SOAPStr .= "-----------------------------7d3cc298904e2\r\n";
 $SOAPStr .= "Content-Disposition: form-data; name=\"PublicBuildJob\"\r\n";
 $SOAPStr .= "\r\n";
 if ( $cmd->{lp} )
 {
  $SOAPStr .= "true\r\n";
 }
 else
 {
  $SOAPStr .= "false\r\n";
 }

 $SOAPStr .= "\r\n";
 $SOAPStr .= "-----------------------------7d3cc298904e2\r\n";
 $SOAPStr .= "Content-Disposition: form-data; name=\"mptest\"; filename=\"";
 $SOAPStr .= $FileName;
 $SOAPStr .= "\"\r\n";
 $SOAPStr .= "Content-Type: text/html\r\n";
 $SOAPStr .= "\r\n";
 $SOAPStr .= "\r\n";
 $SOAPStr .= "-----------------------------7d3cc298904e2--\r\n";
 $SOAPStr .= "\r\n";

 $header .= sprintf "Content-Length: %ld\n", length( $SOAPStr );

 # Check if address is a name and then make sure it resolves
 unless ( $ipaddr =~ /^\d+\.\d+\.\d+\.\d+$/ )
 {
  die "Couldn't resolve hostname $ipaddr.  Exiting Log.pm ...\n"
    unless gethostbyname( $ipaddr );

 }

 #5320, 5667: $server = OMGetServer($ipaddr,$Port);
 $server = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "$ipaddr:$Port")
  or warn "ERROR: Couldn't establish socket with KB server.";

 print $server "$header\n$SOAPStr\n\n";

 local $_;
 while ( <$server> )
 {
  #-- JAG - 10.10.06 - case 7409 -  wait for the log upload to be complete and
  #   written to disk. May need a timeout on this?
  #
  if ( m{!!!LOG_UPLOAD_COMPLETE!!!} )
  {
   last;
  }
 }
 close $server;

} #-- End: sub setupJob

#----------------------------------------------------------------
sub setLogVariables
{
 my $cmd  = shift;
 my $name = shift;

 #-- test that $cmd is as expected
 return 1 unless ( ref $cmd eq "HASH" );

 if (
  !(
   defined $cmd->{lj}
   &&
   defined $cmd->{lm} &&
   defined $cmd->{lo} &&
   defined $cmd->{ld} ) )
 {
  return 2;
 } #-- End: if ( !( defined $cmd->...

 #-- edit check on log-date.
 return 3 unless ( $cmd->{ld} =~ /2\d{3}-\d{2}-\d{2} \d{2}_\d{2}_\d{2}/ );

 #-- if we're not uploading to the KB Server, exit normally
 return unless ( $cmd->{ob} || $cmd->{oh} );

 $main::Quiet          = $cmd->{ov} ? "YES" : "NO";
 $main::JobMachineName = $cmd->{lm};
 $main::MachineName    = $ENV{HOST} || $ENV{HOSTNAME} || $ENV{COMPUTERNAME};
 $main::LogOwner       = $cmd->{lo};
 $main::JobDateTime    = $cmd->{ld};
 $main::PublicBuildJob = $cmd->{lp} ? "true" : "false";
 $main::JobName        = $cmd->{lj};
 $main::OutputType     = "screen";
 $main::OutputType     = "html" if $cmd->{oh};
 $main::OutputType     = "both" if $cmd->{ob};
 $main::FinalTarget    = Openmake::File->new( $name );
 $main::Target         = Openmake::File->new( $name );
 $main::ScriptHeader   = $name;
} #-- End: sub setLogVariables

#----------------------------------------------------------------
sub escapeLine
{

 #-- JAG - 12.17.04 - case 5351 - update to be more robust

 my @input = @_;
 foreach my $line ( @input )
 {
  $line =~ s|(?<!\\)&(?!amp;)|&amp;|g;    #-- this first! the (?<!\\) is a look-behind so that we don't match to \&
                                          #-- the second (?!amp;) will not replace already escaped &amp; to &amp;amp;
  $line =~ s|'|&apos;|g;                  #'
  $line =~ s|<|&lt;|g;
  $line =~ s|>|&gt;|g;

  #  $line =~ s/&/&amp;/g;
  #  $line =~ s/>/&gt;/g;
  #  $line =~ s/</&lt;/g;
 } #-- End: foreach my $line ( @input )
 return wantarray ? @input : "@input"

}

#------------------------------------------------------------------
sub _parse_input_hash
{
 #-- point of this routine is to take a hash with named params and return a
 #   list in the correct order for the previous format of the Log routines
 my $input = shift;
 unless ( ref($input) eq 'HASH' )
 {
  die "Input to ", __PACKAGE__, "::_parse_input_hash not a hash ref\n";
 }

 return ( $input->{EventType}, $input->{StepStatus}, $input->{StepDescription},
          $input->{RegExp}, $input->{LastLine}, $input->{Compiler},
          $input->{CompilerArguments}, $input->{IncludeNL}, $input->{RC},
          @{$input->{CompilerOut}} );

}

#------------------------------------------------------------------
sub END
{
 #-- if we get here, need to call logging
 # we need the following set of additional parameters:
 return unless ($HTML_Log_Message || $HTML_Short_Message);

 my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdist ) = localtime( time );

 my $JobName        = $main::JobName;
 my $JobDateTime    = $main::JobDateTime;
 my $DateTime       = sprintf "%02d/%02d/%02d %02d:%02d:%02d", $mon, $mday, $year - 100, $hour, $min, $sec;
 my $MachineName    = $main::JobMachineName;
 my $PublicBuildJob = $main::PublicBuildJob;
 my $UserId         = $main::LogOwner;
 my $Quiet          = $main::Quiet;
 my $Event          = "Running";
 my $Source         = "$main::ScriptHeader $ScriptVersion";
 my $DetailGroup    = $main::FinalTarget->get();

 #-- send message after caching all messages.
 SendSoapMessage( $HTML_Event_Type, $JobName, $JobDateTime, $MachineName, $UserId,
                  $PublicBuildJob, $Event, $DetailGroup, $DateTime, $Source,
                  $HTML_Short_Message, $HTML_Log_Message );

}

#------------------------------------------------------------------
sub LogMissingDeps
{
 my @poss_missing_deps = @_;

 #-- Attempt to find in the SP, also using the Proj SP and hte intdir
 my @missing_deps;
 my @search_path_dirs = ($::ProjectVPath->get(), $::VPath->get()); #-- JAG 10.11.06 - case 5574

 while ( my $dep = shift @poss_missing_deps )
 {
  my $found = 0;
  foreach my $dir ( @search_path_dirs )
  {
   my $file = $dir . "/" . $dep;
   if ( -e $file )
   {
    $found = 1;
    last;
   }
  }
  push @missing_deps, $dep unless ($found);
 }

 foreach my $dep ( @missing_deps )
 {
  omlogger_ev( 13, {
                StepStatus => "Final",
                StepDescription => "Creating $::TargetFile",
                RC => 1,
                CompilerOut => [ "ERROR 40: The source dependency $dep was not found.\n" ]
               }
             );
 }
 Openmake::ExitScript( 1, @::DeleteFileList ) if ( @missing_deps);
 return;
}

#------------------------------------------------------------------
sub SendDirectSoapMessage
{
 #-- this is the old SendSoapMessage from pre-641 that logs direct to the KB
 #   server, instead of thru omsubmit log queue. Used for local builds if
 #   omsubmit is not running
 my ($EventType,$JobName,$JobDateTime,$MachineName,$UserId,$PublicBuildJob,$Event,$DetailGroup,$DateTime,$Source,$ShortMsg,$Message) = @_;

 
 if ($main::SocketInit == 0)
 {  
  eval("require IO::Socket;");
  $main::SocketInit = 1;
 }

 
 #-- JAG - 12.27.05 - case 6629 - .NET can embed nulls in the log
 $Message  =~ s/\0//g;
 $ShortMsg =~ s/\0//g;

 my $kbserver = substr($ENV{"OPENMAKE_SERVER"},7);
 my $Port = 80;
 my $pos  = index $kbserver, ":";
 my $ipaddr = "localhost";
 my $INFO_EVENTTYPE    = 0;
 my $ERROR_EVENTTYPE   = 1;
 my $WARNING_EVENTTYPE = 2;
 my $SUMMARY_EVENTTYPE = 4;
 my $DETAIL_EVENTTYPE  = 8;

 if ($pos >= 0)
 {
  $ipaddr   = substr($kbserver,0,$pos);
  $kbserver = substr($kbserver,$pos+1);
 }
 else
 {
  $pos = index $kbserver, "/";
  if ($pos >= 0)
  {
   $ipaddr   = substr($kbserver,0,$pos);
   $kbserver = substr($kbserver,$pos+1);
  }
 }

 $pos = index $kbserver, "/";
 if ($pos > 0)
 {
  $Port = substr($kbserver,0,$pos);
 }

 my $file = "/openmake/LogUpload";
 my $Url = "http://$ipaddr:$Port/$file";
 my $BuildJobName = "$JobName-$MachineName-$JobDateTime";
 my $FileName = "D:\\tmp\\";

 $FileName .= $BuildJobName;

 #-- JAG - 05.31.06 - case 7154
 my $Header =<<EOF;
POST /openmake/LogUpload HTTP/1.1\r
Host: $ipaddr:$Port
Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/msword, application/pdf, application/x-shockwave-flash, */*\r
Accept-Language: en-us\r
Connection: close\r
Content-Type: multipart/form-data; boundary=---------------------------7d3cc298904e2\r
Accept-Encoding: gzip, deflate\r
User-Agent: Openmake Logger 6.2\r
EOF

my $SoapMessage = "";

$SoapMessage =<<SEOF;
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="JobName"\r
\r
$JobName\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="Owner"\r
\r
$UserId\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="Machine"\r
\r
$MachineName\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="PublicBuildJob"\r
\r
$PublicBuildJob\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="JobDateTime"\r
\r
$JobDateTime\r
-----------------------------7d3cc298904e2\r
Content-Disposition: form-data; name="Type"\r
\r
SEOF


 if (($EventType & $ERROR_EVENTTYPE) == $ERROR_EVENTTYPE)
 {
  $SoapMessage .= "Error";
 }
 elsif (($EventType & $WARNING_EVENTTYPE) == $WARNING_EVENTTYPE)
 {
  $SoapMessage .= "Warning";
 }
 elsif (($EventType & $INFO_EVENTTYPE) == $INFO_EVENTTYPE)
 {
  $SoapMessage .= "Information";
 }
 else
 {
  $SoapMessage .="Sucess";
 }

 $SoapMessage .= "\r\n";
 $SoapMessage .= "-----------------------------7d3cc298904e2\r\n";

 if (($EventType & $SUMMARY_EVENTTYPE) == $SUMMARY_EVENTTYPE)
 {
  $SoapMessage .= "Content-Disposition: form-data; name=\"mptest\"; filename=\"";
  $SoapMessage .= $FileName;
  $SoapMessage .= "-Summary.html\"\r\n";
  $SoapMessage .= "Content-Type: text/html\r\n";
  $SoapMessage .= "\r\n";
  $SoapMessage .= &escapeLine($ShortMsg);
  $SoapMessage .= "\r\n";
  $SoapMessage .= "-----------------------------7d3cc298904e2\r\n";
 }

 $Message = escapeLine($Message);
 $Message = "<HR SIZE=1 WIDTH=30% ALIGN=LEFT>" . $Message if ($Message =~ /^Creating / || $Message =~ /Using script/);

 $SoapMessage .= "Content-Disposition: form-data; name=\"mptest\"; filename=\"";
 $SoapMessage .= $FileName;
 $SoapMessage .= "-Detail.html\"\r\n";
 $SoapMessage .= "Content-Type: text/html\r\n";
 $SoapMessage .= "\r\n";
 $SoapMessage .= $Message;
 $SoapMessage .= "\r\n";
 $SoapMessage .= "-----------------------------7d3cc298904e2--\r\n";
 $SoapMessage .= "\r\n";

 $Header .= sprintf "Content-Length: %ld\n", length($SoapMessage);

 # Check if address is a name and then make sure it resolves
 unless( $ipaddr =~ /^\d+\.\d+\.\d+\.\d+$/ )
 {
  die "Couldn't resolve hostname $ipaddr.  Exiting Log.pm ...\n"
   unless gethostbyname($ipaddr);
 }

 # Establish the log file names being utilized on the KB server.
 if ($PublicBuildJob eq 'false')
 {
  $LogDetail = "/openmake/logs/${UserId}/${BuildJobName}/${BuildJobName}-Detail.html";
 }
 else
 {
  $LogDetail = "/openmake/logs/public/${BuildJobName}/${BuildJobName}-Detail.html";
 }

 $server = IO::Socket::INET->new(Proto => "tcp", PeerAddr => "$ipaddr:$Port")
  or warn "ERROR: Couldn't establish socket with KB server.";

 print $server "$Header\n$SoapMessage\n\n";
 local $_;
 while ( <$server> )
 {
  #-- JAG - 10.10.06 - case 7409 -  wait for the log upload to be complete and
  #   written to disk. May need a timeout on this?
  #
  if ( m{!!!LOG_UPLOAD_COMPLETE!!!} )
  {
   last;
  }
 }
 close $server;
}

1;

__END__
#----------------------------------------------------------------
=head1 NAME

Openmake::Log

=head1 DESCRIPTION

This package contains functions to be
called to in an Openmake .sc file to print to STDOUT and
to create html logging.  Many of the variables
defined in the calling build step are referenced directly
within the Openmake::Log package via $main::var type
references.  In addition, these variables may be
set as well.  This prevents the
need to define and pass a reference to a very large hash.
It can create a confusing situation if attention is not paid to this.

=head1 FUNCTIONS

=head2 omlogger($StepStatus, @StepArgs)

Below are the list of arguments that must be passed. Defaults are
not inherited from the program body. This is to avoid picking up
unintended values. The arguments in the order in which they have to
be supplied are:

        $StepStatus
        $StepDescription
        $RegExp
        $LastLine
        $Compiler
        $CompilerArguments
        $IncludeNL
        $RC
        @CompilerOut

$StepStatus is ignored.

To facilitate passing arguments, the argument block can be passed as a hash
(usually an anonymous hash)

 omlogger( {
            'EventType'       => $DETAIL_EVENTTYPE,
            'StepStatus'      => $StepStatus,
            'StepDescription' => $StepDescription,
            'RegExp'          => $RegExp,
            'LastLine'        => $LastLine,
            'Compiler'        => $Compiler,
            'CompilerArguments' => $CompilerArguments,
            'IncludeNL'       => $IncludeNL,
            'RC'              => $RC,
            'CompilerOut'     => \@CompilerOut
          }
        )

 omlogger("Begin",$StepDescription,"ERROR:","$StepDescription succeeded.",
          $Compiler,$CompilerArguments,"",$RC,@CompilerOut);
 @CompilerOut = `$Compiler $CompilerArguments 2>&1`;
 $RC = $?;
 omlogger("Final",$StepDescription,"ERROR:","ERROR: $StepDescription failed",
          $Compiler,$CompilerArguments,"",$RC,@CompilerOut), $RC = 1 if ($RC != 0);
 omlogger("Final",$StepDescription,"ERROR:","$StepDescription succeeded.",
          $Compiler,$CompilerArguments,"",$RC,@CompilerOut), push(@DeleteFileList,$Rsp) if ($RC == 0);

=head1 MAIN PACKAGE SYMBOLS REFERENCED

The objects used by Openmake::Log that must be defined
in package main are listed.  If the variable is an object,
then its type is listed in parentheses.  Otherwise, it will
be a normal string or list.  These variables are referenced
in the form of $main::$Project in the subroutines below.
Ideally they should be of the form $SUPER::$Project, but
this didn't seem to work as the authors expected.

=head2 Symbols Normally Defined By om

=over 4

=item $VPath (Openmake::SearchPath)

=item $Project

=item $VPathName

=item $User

=item $BuildDirectory

=item $BuildMachine

=item $LogfileName

=item $Target (Openmake::File)

=item $BuildType

=item $FinalTarget (Openmake::File)

=item $Defines

User specified defines from the .tgt file.

=back

=head2 omlogger_ev($EventType, $StepStatus, @StepArgs)

This is the same call as C<omlogger>, except one can
specify the event type as something different than
"Detail". $EventType is a bit mask of the following
event types:

=over 4

=item  INFO_EVENTTYPE    = 0;
 
=item  ERROR_EVENTTYPE   = 1;
 
=item  WARNING_EVENTTYPE = 2;
 
=item  SUMMARY_EVENTTYPE = 4;
 
=item  DETAIL_EVENTTYPE  = 8;

=back

From within build type scripts, one should use C<omlogger>.

=head2 setupJob( $cmdref, $RC)

Subroutine to initialize logging on the KB Server.
B<<This routine is not used in scripts called from within
bldmake or om (build types, retrieve programs, etc). It
is only used in external programs.>>

The input is a reference to a hash containing

=over 2

=item $cmdref->{lj}
The log job name

=item $cmdref->{lo}
The log owner

=item $cmdref->{lm}
The machine on which the build ran.

=item $cmdref->{ld}
The date that the build ran, in YYYY-MM-DD HH_MM_SS format.

=item $cmdref->{lp}
If set, TRUE that the build was a public build.

=item $cmdref->{ob} or $cmdref->{oh}
If set, TRUE that the log should be loaded to the KB Server

=back

and the run code $RC ( = 0 if everything is okay.)

C<setupJob> will return the following

=over 2

=item 1 = no $cmdref hash reference was passed.

=item 2 = the correct hash values were not present.

=item 3 = the 'ld' parameter was not in the correct
format.

=back.

USAGE: $err = &setupJob( $cmdref, $RC);

=cut

#------------------------------------------
#
# Openmake/Log.pm
# $Header: /CVS/openmake64/perl/lib/Openmake/Log.pm,v 1.31 2011/04/27 20:42:02 steve Exp $
#
# Functionality for Perl connections to Logging.
#
#------------------------------------------
# JAG - 05.31.06 - case 7156
# DESCRIPTION: POST HTTP/1.1 on 1.1-enabled webservers (WAS, new Tomcat) holds
#  a persistent connection until forced closed. This will lead to long time-outs.
#
# RESOLUTION:
#  Add
#    Connection:close
#  to HTML header
#
#------------------------------------------
# JAG - 12.12.07 - case FLS-253
#
# DESCRIPTION: Some compilers (devenv, I'm looking at you) add embedded nulls to
#  the log. These nulls have the effect of truncating the log in the HTML
#  version
#
# RESOLUTION: grep nulls to \n in the text log.
#
#------------------------------------------


