#==========================================================================
package Parse::Compiler::Config;

BEGIN
{
 use Exporter ();
 use strict;
 use vars  qw(
                   @ISA
                   @EXPORT
                   $VERSION
                   
                  );
 use strict;
 use Config;
 
 @ISA     = qw( Exporter );
 @EXPORT  = qw( );

 #-- define the version number for the Package
 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Parse/Compiler/Config.pm,v 1.3 2006/02/24 20:30:21 jim Exp $'; 
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path    = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }
}

#----------------------------------------------------------------
=head1 NAME

     Parse::Compiler::Config - Configuration object for Parse::Compler

=head1 VERSION

     This document describes Parse::Compiler::Config version 6.4.1

=head1 DESCRIPTION
 
    Parse::Compiler::Config provides "build-in" regular expressions that
    are used by Parse::Compiler to determine the start and end of a 
    compiler log, and to determine warnings and errors.
    
=head1 INTERFACE

=head2 new()

     Creates a Parse::Compiler::Config object, which is a big hash indexed
     by compiler name, whose values are in turn a hash with the following 
     keys
     
       Start => <regular expression to indicate start of compiler call>
       End   => <regular expression to indicate end of compiler call> 
                (should be undef if the compiler doesn't print that it's 
                 finished)
       Warn  => <regular expression to indicate the compiler threw a warning>
       Error => <regular expression to indicate the compiler threw an error>

=head2 future methods

    We plan to introduce methods to load the configuration from an 
    externalized source.

=head1 CONFIGURATION AND ENVIRONMENT

    Parse::Compiler::Config requires no configuration files or environment variables.

=head1 DEPENDENCIES

    use Config;

=head1 INCOMPATIBILITIES

    None reported.

=head1 BUGS AND LIMITATIONS

    No bugs have been reported.

=head1 AUTHOR

    Catalyst Systems Corp  C<< support@openmake.com >>

=head1 LICENCE AND COPYRIGHT

    Copyright (c) 2006, Catalyst Systems Corp C<< support@openmake.com >>.
    All rights reserved. This code currently cannot be distributed.

=cut
sub new
{
 my $class   = shift;
 my $config_file = shift; #-- also will look for config in @INC eventually
 
 my $self    = {};

 #-- need to define everything for strict
 bless( $self, $class );

 #-- big hash that defines defaults
 #   These compilers can run on multiple OSs (including MS on Unix through MainWin)
 my $cmp_hash = { 
                  'devenv2003' => {
                                   'Start' => qr/-----\s+(Re?)build.+?started/i,
                                     'End' => qr/---------------------- Done/i,
                                    'Warn' => qr/^\s*\S+\s+-\s+\d+\s+error\(s\),\s+(\d+)\s+warning/i,
                                   'Error' => qr/^\s*\S+\s+-\s+(\d+)\s+error\(s\),\s+\d+\s+warning/i
                                  },
                  'vb6'        => {
                                   'Start' => undef,
                                     'End' => undef,
                                    'Warn' => undef,
                                   'Error' => undef
                                  },
                  'gcc'        => {
                                   'Start' => qr/gcc\s+/,
                                     'End' => undef,
                                    'Warn' => qr/:\d+:\s+warning:/,
                                   'Error' => qr/:\d+:\s+error:/
                                  },
                  'ant'        => {
                                   'Start' => qr/^\s*Buildfile:/,
                                     'End' => qr/^\s*BUILD (SUCCESSFUL|FAILED)/,
                                    'Warn' => qr/^\s*\[\w+\]\s+(\d+)\s+warning/i,
                                   'Error' => qr/^\s*\[\w+\]\s+(\d+)\s+error/i
                                  },
                  'msvc6'      => {
                                   'Start' => qr/(cl|link)(\.exe?)\s+/i,
                                     'End' => undef,
                                    'Warn' => qr/\s+:\s+warning/i,
                                   'Error' => qr/\s+:\s+(?:fatal\s+)?error/i
                                  }
                };
 #-- add items based on OS
 unless( $^O =~ /MSWin|DOS/i )
 {
  if ( $Config{'archname'} =~ /sun|solaris/ )
  {
   #-- sun compilers
  }
  elsif ( $Config{'archname'} =~ /pa-risc/ )
  {
   #-- hp
   # Error 399: "/lawson/usr/johnmu/Ace/ace/Strategies_T.i", line 330 # Cannot  
   # Error (future) 251: "Any.cpp", line 153 # An object cannot be deleted  
   # Warning 552: "/home/abisheks/xml4c2_3_1/include/util/Exception.hpp", line 37 #
   #
   $cmp_hash->{'aCC'}      = {
                               'Start' => qr|aCC\s+|,
                                 'End' => undef,
                                'Warn' => qr/^\s*Warning\s+(?:future\s+)?\d+\s*:/,
                               'Error' => qr/^\s*Error\s+(?:future\s+)?\d+\s*:/i
                              };
  }
  elsif ( $Config{'archname'} =~ /aix/ )
  {
   #-- aix
   #  "test.cpp", line 14.39: 1540-0300 (S) The "private" member "struct Foo<int>::Bar<char *>" cannot be accessed. 
   #
   #  "/usr/lpp/xlC/include/sys/time.h", line 13.5: 1540-089: (S) More than one function "setitimer" has non-C++ linkage. 
   
   # Codes: U & S are errors (no binary produced)
   #        U An unrecoverable error. Compilation failed because of an internal compiler error. 
   #        S A severe error. Compilation failed due to one of the following: 
   #        	- Conditions exist that the compiler could not correct. 
   #        	- An internal compiler table has overflowed. Processing of the program stops,
   # Codes: E & W are warnings (binary is produced)
   #        E C compilations only. The compiler detected an error in your source code and attempted to correct it. 
   #           The compiler will continue to compile your application, but might not generate the results you expect. 
   #        W Warning message. The compiler detected a potential problem in your source code, but did not attempt to correct it.
   #          The compiler will continue to compile your application, but might not generate the results you expect. 
   #        I Informational message. It does not indicate any error, just something that you should be aware of to avoid unexpected behavior.
   
   $cmp_hash->{'xlC'}      = {
                               'Start' => qr|[\\\/]xlC|i,
                                 'End' => undef,
                                'Warn' => qr/:\s+\d4-\d+\s+\(E|W\)/i,
                               'Error' => qr/:\s+\d4-\d+\s+\(U|S\)/i
                              };
   
  }
  elsif ( $Config{'archname'} =~ /linux/ )
  {
   #-- linux                
  }
 }
 $self = $cmp_hash;
 return $self;
} #-- End: sub new

1;