#!/usr/bin/perl
#=====================================
#
# omemail.pl Version 2.0
#
# Openmake Email utility
#
#=====================================
#-- use declarations
use 5.006_001;
use strict;

use Openmake;
use Openmake::PrePost;
use File::Spec;

#-- following should be in core distributions later than 5.6.1
use Getopt::Long;
use IO::Socket::INET;

no warnings 'uninitialized';

#-- Mime is only in 5.8.x, so look for it
eval
  " require MIME::Base64; import MIME::Base64 qw(encode_base64 decode_base64) ";
if ($@) {

	#-- try to use MIME::Base64::Perl. This will be in the Openmake perl/lib
	#   directories for 6.41
	eval
" require MIME::Base64::Perl; import MIME::Base64::Perl qw(encode_base64 decode_base64); ";
	if ($@) {
		my $die_text = "$0: module MIME::Base64 is required to run $0 and\n";
		$die_text .= "is not included in the core Perl before v5.8.2\n";
		$die_text .=
		  "Attempted to load Pure Perl MIME::Base64::Perl, but failed\n";
		$die_text .=
		  "You must install one of these modules on this system to use $0\n";
		$die_text .= "\nError:\n$@\n";
		die $die_text;
	}
}

eval " require Digest::HMAC_MD5; import Digest::HMAC_MD5 qw(hmac_md5_hex); ";
if ($@) {
	my $die_text = "$0: module Digest::HMAC_MD5 is required to run $0\n";
	$die_text = "and should be included in your \@INC location.\n";
	$die_text = "Please confirm by running 'perl -V'\n";
	$die_text .= "\nError:\n$@\n";
	die $die_text;
}

#-- Look for ompw in same dir as omemail.pl
my (@full_path) = File::Spec->splitpath( File::Spec->rel2abs($0) );
pop @full_path;
$::ompw = ( join '', @full_path ) . "ompw";
$::ompw .= ".exe" if ( $^O =~ /MSWin|dos/i );

$::ompw = '' unless ( -x $::ompw );

#-- Munge ARGV for special characters
translate_special_arg();

#-- get local options and options from the kb server
#
#   Mail options has the following keys
#      Mail_Host Mail_Port Use_Login Use_Plain
#      Use_Cram_MD5 Use_Digest_MD5 Use_Auth
#      User Password EHLO Use_STARTTLS From
#      Subject Recipients Message Template_File
#      Build_Job_Name Build_Machine_Label
#      Build_Date Build_Owner Build_Activity
#      Build_Is_Public
#      Html_Format

my %mail_options = get_mail_parameters();
my $message_text = parse_message_text( \%mail_options );
my $subject_text = parse_subject_text( \%mail_options );

#-- if any authentication is required, dynamically require these packages.
if ( $mail_options{Use_STARTTLS} ) {
	eval
" require IO::Socket::SSL; import IO::Socket::SSL; require Net::SSLeay; import Net::SSLeay; ";
	if ($@) {
		my $die_text =
		  "$0: To use authentication, you are required to install\n";
		$die_text .= "\tIO::Socket::SSL\n\tNet::SSLeay\n";
		$die_text .= "\nError:\n$@\n";
		die $die_text;
	}
}

#-- Connect to the SMTP server.
my $mail_sock = IO::Socket::INET->new(
	PeerAddr => $mail_options{Mail_Host},
	PeerPort => $mail_options{Mail_Port},
	Proto    => 'tcp',
	Timeout  => 120
  )
  or die("$0: unable to connect to $mail_options{Mail_Host}: $!\n");

my ( $code, $text, $more );
my (%features);

#-- Wait for the welcome message of the server.
( $code, $text, $more ) = _get_line($mail_sock);
my ( $oc, $ot );
while ($more) {
	( $oc, $ot, $more ) = _get_line($mail_sock);
}
die("$0: Unknown welcome string: '$code $text'\n") if ( $code != 220 );

#-- JAG - 11.07.07 - case IUD-71. EHLO is a must on RFC-2821 compliant SMTP servers
#$mail_options{EHLO}-- if ($text !~ /ESMTP/);

#-- Send EHLO
my %server_options = _say_hello( $mail_sock, \%mail_options );
$server_options{AUTH} = "LOGIN" if ( $text =~ /Microsoft/i );

#-- Run the SMTP session
run_smtp(
	$mail_sock,       $subject_text, $message_text,
	\%server_options, \%mail_options
);

# Good bye...
_send_line( $mail_sock, "QUIT\n" );
( $code, $text, $more ) = _get_line($mail_sock);
die("$0: Unknown QUIT response '$code'.\n") if ( $code != 221 );

#-- log email sent
print "$0: sent email subject '", $mail_options{Subject}, "' to recipients:\n";
print "\t", $_, "\n" foreach ( @{ $mail_options{Recipients} } );

exit 0;

#------------------------------------------------------------------
sub run_smtp {
	my $socket   = shift;
	my $subject  = shift;
	my $message  = shift;
	my $features = shift;
	my $options  = shift;

	#-- See if we could start encryption
	if ( ( defined( $features->{'STARTTLS'} ) || defined( $features->{'TLS'} ) )
		&& $options->{Use_STARTTLS} )
	{

		#-- Do Net::SSLeay initialization
		Net::SSLeay::load_error_strings();
		Net::SSLeay::SSLeay_add_ssl_algorithms();
		Net::SSLeay::randomize();

		_send_line( $socket, "STARTTLS\n" );
		my ( $code, $text, $more ) = _get_line($socket);
		die("$0: Unknown STARTTLS response '$code'.\n") if ( $code != 220 );

		if (
			!IO::Socket::SSL::socket_to_SSL(
				$socket, SSL_version => 'SSLv3 TLSv1'
			)
		  )
		{
			die(    "$0: unable to convert STARTTLS: "
				  . IO::Socket::SSL::errstr()
				  . "\n" );
		}

		#-- Send EHLO again (required by the SMTP standard).
		_say_hello( $socket, $options )
		  or die "$0: unable to send second HELO\n";
	}

	#-- See if we should authenticate ourself
	if ( defined( $features->{'AUTH'} ) && $options->{Use_Auth} ) {

		#-- Try CRAM-MD5 if supported by the server
		if ( $features->{'AUTH'} =~ /CRAM-MD5/i && $options->{Use_Cram_MD5} ) {
			_send_line( $socket, "AUTH CRAM-MD5\n" );
			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 334 ) {
				die("$0: AUTH failed '$code $text'.\n");
			}

			my $response =
			  _encode_cram_md5( $text, $options->{User}, $options->{Password} )
			  ;    #-- JAG - 12.09.05 - case 6575
			_send_line( $socket, "%s\n", $response );
			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 235 ) {
				die("$0: AUTH failed: '$code'.\n");
			}
		}
		elsif ( $features->{'AUTH'} =~ /LOGIN/i && $options->{Use_Login} ) {
			_send_line( $socket, "AUTH LOGIN\n" );
			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 334 ) {
				die("$0: AUTH failed '$code $text'.\n");
			}

			_send_line( $socket, "%s\n",
				encode_base64( $options->{User}, "" ) );

			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 334 ) {
				die("$0: AUTH failed '$code $text'.\n");
			}

			_send_line( $socket, "%s\n",
				encode_base64( $options->{Password}, "" ) );

			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 235 ) {
				die("$0: AUTH failed '$code $text'.\n");
			}
		}
		elsif ( $features->{'AUTH'} =~ /PLAIN/i && $options->{Use_Plain} ) {
			my $str = join qw(\0), $options->{User}, $options->{User},
			  $options->{Password};
			_send_line( $socket, "AUTH PLAIN %s\n", encode_base64( $str, "" ) );
			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 235 ) {
				die("$0: AUTH failed '$code $text'.\n");
			}
		}
		else {
			die(
"$0: No supported authentication method\nadvertised by the server.\n"
			);
		}
	}

	# We can do a relay-test now if a recipient was set.
	if ( $options->{Recipients} ) {

		#-- JAG - 11.15.05 - case 6472
		_send_line( $socket, "MAIL FROM: <%s>\n", $options->{FromEmail} );
		( $code, $text, $more ) = _get_line($socket);
		if ( $code != 250 ) {
			die("$0: MAIL FROM failed: '$code $text'\n");
		}

		foreach my $to ( @{ $options->{Recipients} } ) {
			_send_line( $socket, "RCPT TO: <%s>\n", $to );
			( $code, $text, $more ) = _get_line($socket);
			if ( $code != 250 ) {
				die( "$0: RCPT TO <" . $to . "> failed: '$code $text'\n" );
			}
		}
	}

	#-- send message
	if ($message_text) {
		_send_line( $socket, "DATA\n" );
		( $code, $text, $more ) = _get_line($socket);
		if ( $code != 354 ) {
			die("DATA failed: '$code $text'\n");
		}

		#-- create the header of the message
		my @month = qw{ Jan Feb Mar Apr May Jun July Aug Sept Oct Nov Dec};
		my @days  = qw{ Sun Mon Tue Wed Thu Fri Sat };
		my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday ) =
		  gmtime(time);
		my $time = sprintf( " %2.2d:%2.2d:%2.2d -0000\n", $hour, $min, $sec );
		my $date = 'Date: '
		  . $days[$wday]
		  . ", $mday "
		  . $month[$mon] . " "
		  . ( $year + 1900 )
		  . $time;

		my $from = $options->{FromEmail} || '';
		if ( $options->{FromName} ) {
			$from = $options->{FromName};
			if ( $from !~ /</ and $from !~ />/ ) {
				$from .= " <$options->{FromEmail}>";
			}

		}

		$from = "From: $from\n";
		my $to = "To: " . ( join ",", @{ $options->{Recipients} } );
		$subject = "Subject: $subject";

		my @headers = ( $date, $from, $to, $subject );

		if ( $options->{Html_Format} ) {
			push @headers, 'Mime-Version: 1.0';
			push @headers, 'Content-type: text/html; charset="iso-8859-1"';
		}

		#-- the header
		foreach my $line (@headers) {
			chomp $line;
			$line .= "\015\012";
			$line =~ s/^\.$/\. /;
			$socket->print($line);
		}

		#-- null line to indicate end of header
		my $line = "\015\012";
		$socket->print($line);

		#-- message
		my @message_lines = split /\n/, $message_text;
		foreach my $line (@message_lines) {
			chomp $line;
			$line .= "\015\012";
			$line =~ s/^\.$/\. /;
			$line =~ s{\\\&}{&}g; #-- FLS-919 omsubmit is escaping ampersands in the command line
					      # Needed when the message is passed into omemail.pl and it contains
					      # a CGI format URL, such as the HTML Log URL
			$socket->print($line);
		}

		$socket->printf("\015\012.\015\012");

		( $code, $text, $more ) = _get_line($socket);
		if ( $code != 250 ) {
			die("$0: DATA not send: '$code $text'\n");
		}
	}

	return 1;
}

#------------------------------------------------------------------
# Get all lines of response from the server.
sub _get_line {
	my $sock = shift;
	my $fulltext;
	my ( $code, $sep, $text ) = ( $sock->getline() =~ /(\d+)(.)([^\r]*)/ );
	$fulltext = $text;
	while ( $sep eq "-" ) {
		( $code, $sep, $text ) = ( $sock->getline() =~ /(\d+)(.)([^\r]*)/ );
		$fulltext .= "\n" . $text;
	}

	#if ($sep eq "-") { $more = 1; } else { $more = 0; }
	return ( $code, $fulltext, 0 );
}

#------------------------------------------------------------------
sub _send_line {
	my $socket = shift;
	my @args   = @_;

	my $CRLF = "\015\012";
	$args[0] =~ s/\n/$CRLF/g;
	$socket->printf(@args);
}

#------------------------------------------------------------------
sub _encode_cram_md5 {
	my ( $ticket64, $username, $password ) = @_;
	my $ticket = decode_base64($ticket64)
	  or die("$0: Unable to decode Base64 encoded string '$ticket64'\n");

	my $password_md5 = hmac_md5_hex( $ticket, $password );
	return encode_base64( "$username $password_md5", "" );
}

#------------------------------------------------------------------
#-- get server option
sub _say_hello {
	my ( $sock, $options ) = @_;
	my %mail_features = ();
	my ( $feat, $param );
	my $hello_cmd = $options->{EHLO} > 0 ? "EHLO" : "HELO";
	my $hello_host = $ENV{COMPUTERNAME} || $ENV{HOSTNAME} || 'localhost';

	_send_line( $sock, "$hello_cmd $hello_host\n" );
	my ( $code, $text, $more ) = _get_line($sock);
	$mail_features{AUTH} = 'LOGIN' if ( $text =~ /Microsoft/i );

	if ( $code != 250 ) {
		warn("$hello_cmd failed: '$code $text'\n");
		return 0;
	}

	my @lines = split /\n/, $text;
	foreach my $text (@lines) {
		( $feat, $param ) = ( $text =~ /^(\w+)[= ]*(.*)$/ );
		$mail_features{$feat} = $param;
	}

	# Load all features presented by the server into the hash
	#while ( $more )
	#{
	# ($code, $text, $more) = _get_line($sock);
	# ($feat, $param) = ($text =~ /^(\w+)[= ]*(.*)$/);
	# $mail_features{$feat} = $param || 1;
	#}

	if (%mail_features) {
		return %mail_features;
	}
	return;

}

#------------------------------------------------------------------
sub get_mail_parameters {
	my %return_options;
	my @mail_parameters = qw( Mail_Host Mail_Port Use_Login Use_Plain
	  Use_Cram_MD5 Use_Digest_MD5 Use_Auth
	  User Password EHLO Use_STARTTLS
	  FromName FromEmail
	  Subject Recipients Message Template_File
	  Build_Job_Name Build_Machine_Label
	  Build_Date Build_Owner Build_Activity
	  Build_Is_Public
	  Html_Format Log_URL
	);
	%return_options = map { $_ => undef } @mail_parameters;

	#-- get local options
	my $recipients;
	Getopt::Long::Configure( "bundling", "pass_through" );
	GetOptions(
		's=s'  => \$return_options{Subject},
		'r=s'  => \$recipients,
		'm=s'  => \$return_options{Message},
		't=s'  => \$return_options{Template_File},
		'lj=s' => \$return_options{Build_Job_Name},
		'lm=s' => \$return_options{Build_Machine_Label},
		'ld=s' => \$return_options{Build_Date},
		'lo=s' => \$return_options{Build_Owner},
		'lp'   => \$return_options{Build_Public},
		'h'    => \$return_options{Html_Format},
		'u=s'  => \$return_options{Log_URL}
	);
	if ($recipients) {
		# if passed through omcmdline.jar multiple email addresses must be semi-colon delimitted - sub back to commas ADG 04.01.09
  		$recipients =~ s|\;|,|g;
		my @r = split /,/, $recipients;
		$return_options{Recipients} = \@r;
	}

	my $kb_server = $ENV{'OPENMAKE_SERVER'};
	$kb_server =~ s|/openmake$||;
	$kb_server =~ s|^http://||;

	#-- attempt connection to openmake server
	my $CRLF = "\015\012";

	#local $/ = $CRLF;
	local $\ = '';

	my $server = IO::Socket::INET->new(
		Proto    => "tcp",
		PeerAddr => $kb_server
	);
	die "$0: Cannot connect to server $kb_server: $!\n" unless $server;

	my $HTTPStr = "GET /openmake/InitServer?email HTTP/1.0";
	$server->autoflush(1);
	print $server "$HTTPStr\n\n";
	my @conf = <$server>;
	close $server;

	if ( $conf[0] =~ /404/ ) {
		die "$0: unable to read mail configuration from $kb_server: $1\n";
	}

	foreach (@conf) {
		local $/;
		my $index = index( $_, $CRLF );
		if ( $index > -1 ) {
			$/ = $CRLF;
		}
		else {
			$/ = "\012";
		}
		chomp;    #-- acts on $/
		if (/^([A-Z]\w+):(.+)$/) {
			if ( exists $return_options{$1} ) {
				$return_options{$1} = $2;
			}
		}
	}
	$return_options{EHLO} = 1;

	#-- If at least one --auth-* option was given, enable AUTH.

	#-- Need to change

	if ( $return_options{Use_Login} ) {
		$return_options{Use_Auth} = 1;

		$return_options{Use_Login}      = 1;
		$return_options{Use_Plain}      = 1;
		$return_options{Use_Cram_MD5}   = 1;
		$return_options{Use_Digest_MD5} = 1;
	}

	if ( $return_options{Use_Auth} && !defined $return_options{User} ) {
		die("$0: Requested SMTP AUTH support without supplying a Username \n");

		#-- need to decrypt username here
	}
	if ( $return_options{Use_Auth} ) {
		if ( !defined $return_options{Password} ) {
			die(
				"$0: Requested SMTP AUTH support without supplying a Password\n"
			);
		}
	}

	#-- Determine if the password is encrypted: Matches to hex RandomIV+
	if ( $return_options{Password} =~ /^52616e646f6d4956[0-9a-fA-F]+$/i ) {
		if ($::ompw) {
			$return_options{Password} =
			  `"$::ompw" --decrypt $return_options{Password}`;
		}
		else {
			die "$0: Used encrypted Password and no decryption tool.\n";
		}
	}

	return %return_options;
}

#--------------------------------------------
sub parse_message_text {
	my $options = shift;
	my $message;
	my $use_default = 1;
	if ( $options->{Template_File} and not $options->{Message} ) {

		print "Using template file " . $options->{Template_File} . "\n";

		#-- use Template file unless a message overrides
		my $t_file = $options->{Template_File};
		unless ( -e $t_file ) {
			$t_file = FirstFoundInPath($t_file);
		}

		if ( -e $t_file ) {
			$use_default = 0;
			unless ( open( MESS, '<', $t_file ) ) {
				warn
"$0: Cannot open Template file '$t_file': $!\nReverting to default message\n";
				$use_default = 1;
			}

			my @message_lines = <MESS>;
			$message = join "\n", @message_lines;
			close MESS;

			if ( $message =~ m|\$\(LOG_URL\)| ) {
				my $uri;
				if ( $options->{Log_URL} ) {
					$uri = $options->{Log_URL};

				}
				else {
					$uri = getOMLogURI(
						$options->{Build_Job_Name},
						$options->{Build_Machine_Label},
						$options->{Build_Date},
						$options->{Build_Owner},
						$options->{Build_Is_Public}
					);
				}

				$message =~ s|\$\(LOG_URL\)|$uri|g;
			}

		}
		else {
			warn
"$0: Template file $options->{Template_File} not found.\nReverting to default message\n";
			$use_default = 1;
		}

	}
	elsif ( $options->{Message} ) {

		#-- use message
		$message     = $options->{Message};
		$use_default = 0;
	}

	if ($use_default) {
		my $uri;
		if ( $options->{Log_URL} ) {
			$uri = $options->{Log_URL};
		}
		else {
			$uri = getOMLogURI(
				$options->{Build_Job_Name}, $options->{Build_Machine_Label},
				$options->{Build_Date},     $options->{Build_Owner},
				$options->{Build_Is_Public}
			);
		}

		$message =
"An Openmake build has been submitted for\n\n\t$options->{Build_Job_Name}\n\n";
		$message .= "The log can be viewed at:\n\n\t$uri\n\n";
	}

	#-- JAG 11.01.07 - case IUD-66 fix $message for special characters
	$message =~ s{\^\<BR\^\>}{\n}g;
	$message =~ s{\^&}{&}g;

	return $message;
}

#------------------------------------------------------------------
sub parse_subject_text {
	my $options = shift;
	my $subject;

	$subject = $options->{Subject}
	  || "Openmake Build for '$options->{Build_Job_Name}'";
	$subject =~ s/\n//g;
	return $subject;
}

__END__

=head1 NAME

    omemail.pl - Send SMTP email from within Build Jobs

=head1 VERSION

    This document describes omemail.pl version 2.0

=head1 USAGE

    > omemail.pl -s <subject> -r <list of recipients> \
                ( -m <message> | -t <template file> ) [logging options]

=head1 OPTIONS

=over

=item B<< -s <subject> >>

email subject line

=item B<< -r <recipients> >>

A comma-separated list of recipients.
If you require a large list, we suggest creating a distribution alias
on your mailserver

=item B<< -m <message> >>

Email message body. New lines can be represented as "<BR>" (properly escaped
for your OS)

=item B<< -t <Template File> >>

Text file containing the email message
body. Will be either an absolute path, or the script will search the
PATH Environment variable

If the template contains the string '$(LOG_URL)', then omemail
will replace it with the log URI if it can construct it from the
logging arguments. Typically you can use this with '-u "$(LOG_URL)"'
in a Meister or Mojo activity.

=item B<< -h >>

Indicates the message body is to be interpreted as HTML content. This
applies to either a message passed with '-m' or a template indicated
with '-t'

=item B<< Default Message >>

if neither -m or -t are used, omemail will use a
default message:

  An Openmake build has been submitted for

    <Build_Job_Name>

  The log can be viewed at:

    <URL>

=item B<< Logging Options >>

omemail supports the logging option '-u $(LOG_URL)' which
may be used in a Meister or Mojo activity command line. This
will pass the URI of the HTML log directly to omemail.

omemail also supports the following logging options,
through which it can construct the log URL.

=over

=item B<< -lj <Build Job Name> >> : Build Job Name

=item B<< -ld <YYYY-MM-DD HH_MM_SS> >> : Build Job Date

=item B<< -lo <user> >> : Build Job Owner

=item B<< -lm <Machine> >> : BUild Machine

=item B<< -lp >> : Build is public

=back

=back

=head1 CONFIGURATION AND ENVIRONMENT

    omemail uses the PATH environment variable to look for the
    Message Template file (-t option)

=head1 DEPENDENCIES

    omemail requires at least Perl 5.6.1

    omemail is dependent on the core following modules:

      C<< Getopt::Long >>

      C<< IO::Socket::INET >>

   Furthermore, omemail requires

      C<< MIME::Base64 >>

   which is non-core on Perls before 5.8.2. If this module is not installed
   omemail will default to

     C<< MIME::Base64::Perl >>

   which has been included in the distribution (check PERLLIB ). Also,
   omemail requires

     C<< Digest::HMAC_MD5 >>

   which is also included in the distribution

   Additional, if Use_Auth is specified in the configuation, the
   user must install the following non-core modules:

      C<< IO::Socket::SSL >>
      C<< Net::SSLeay >>

   We cannot distribute these modules as they are not pure-perl,
   and must be compiled for the version of OS, Compiler and version
   of perl on the user's system.

   Internally, omemail uses

      C<< Openmake::PrePost >>
      C<< Openmake.pm >>

=head1 INCOMPATIBILITIES

    None reported.

=head1 BUGS AND LIMITATIONS

    No bugs have been reported.

    Please report any bugs or feature requests to
    C< support@openmake.com >, or through the web interface at
    L< http://support.openmake.com >.

=head1 AUTHOR

 Catalyst Systems Corp, 2005

 This program is very closely based on C<<smtp_client.pl>>

   Simple SMTP client with STARTTLS and AUTH support.
   Michal Ludvig <michal@logix.cz>, 2003
   See http://www.logix.cz/michal/devel/smtp for details.

   This program can be freely distributed, used and modified
   without any restrictions. It's a public domain.
