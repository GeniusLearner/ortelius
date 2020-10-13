#==========================================================================
package Parse::Compiler;

BEGIN
{
 use Exporter ();
 use strict;
 use Parse::Compiler::Config;
 use vars  qw(
                   @ISA
                   @EXPORT
                   $VERSION
                   $DEBUG
                  );
 
 @ISA     = qw( Exporter );
 @EXPORT  = qw( );
 $DEBUG   = 0;
 
 #-- define the version number for the Package
 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Parse/Compiler.pm,v 1.5 2011/04/27 20:42:02 steve Exp $'; 
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

     Parse::Compiler - Parse compiler output for warnings and error

=head1 VERSION

     This document describes Parse::Compiler version 6.4.1

=head1 SYNOPSIS

     use Parse::Compiler;

     #-- execute a compiler.
     @log = `compiler`;

     #-- parse its output
     my $parse = Parse::Compiler->new();
     my ( $nerrors, $nwarnings, $error_ref, $warn_ref ) 
      = $parse->check_log_lines( @log );

=head1 DESCRIPTION
 
     Parse::Compiler.pm is a module that contains object/methods 
     to parse the output of various compilers to determine if the 
     compiler threw an error or warning

=head1 INTERFACE

=head2 new( $Config Object)

     Creates a new Parse::Compiler object. The optional argument is a 
     Parse::Compiler::Config object that initializes how the Parse::Compiler 
     object will parse for compiler warnings and errors. If no argument is 
     passed, a default Parse::Compiler::Config object will be instantiated.

   USAGE:

     my $parse = Parse::Compiler->new();

   RETURNS:

    Parse::Compiler object

=head2 check_log_lines(@log)

    Parser that searches the compiler output @log for warnings and errors. 
    Uses the internal configuration of the object to do pattern matching. 
    Returns a 4-element array of number of errors and number of warnings, 
    and array references to the lines that match the errors and warnings

  USAGE:

    my ($nerrors, $nwarnings, $error_ref, $warn_ref ) 
       = $parse->check_log_lines( @log );
    foreach my $err ( @{$error_ref})
    {
     print $err, "\n";
    }

  RETURNS:

    4-element array of number of errors and number of warnings, 
    and array references to the lines that match the errors and warnings

=head2 find_compiler( $line)
 
    Given a line of compiler output, attempt to determine what type of
    compiler is being invoked. Uses the ->{Start} element in the 
    Parse::Compiler::Config object. Returns information about the 
    compiler, or undef if the line doesn't indicate which compiler
    is being used.

  USAGE:

   my ( $compiler, $start, $end, $warn, $error ) 
     = $parse->find_compiler($line);

  RETURNS:

    5-element array of (Compiler name, start regex, end regex, warning regex,
       error regex.)

=head1 CONFIGURATION AND ENVIRONMENT

    Parse::Compiler requires no configuration files or environment variables.

=head1 DEPENDENCIES

    Parse::Compiler::Config, included in this distribution

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

#------------------------------------------------------------------
sub new
{
 my $class   = shift;
 my $config  = shift;
 my $self    = {};

 #-- need to define everything for strict
 bless( $self, $class );

 unless( defined $config && $config->isa( "Parse::Compiler::Config" ) )
 {
  $config = Parse::Compiler::Config->new();
 }
 $self->{Compilers} = $config;
 
 return $self;
} #-- End: sub new

#------------------------------------------------------------------
sub check_log_lines
{
 my $self  = shift;
 my @lines = @_;
 
 my $nerrors   = 0;
 my $nwarnings = 0;
 my ( @errors, @warnings );
 my $compiler;
 my ( $start, $end, $warn, $error );  #-- regexs to search.

 foreach my $line ( @lines )
 {
  unless ( $compiler )  
  {
   ( $compiler, $start, $end, $warn, $error ) = $self->find_compiler($line);
   next;
  }
  
  my $we_match = 0;
  if ( defined $warn )
  {
   my @warn;
   if ( ref($warn) ne 'ARRAY' )
   {
    $warn[0] = $warn;
   }
   foreach my $w ( @warn)
   {
    if ( $line =~ /$w/ )
    {
     my $incr = 0;
     if ( defined $1 )
     {
      $incr = $1;
     }
     else
     {
      $incr = 1;
     }
     $nwarnings += $incr;
     $we_match++;
     
     push @warnings, $line;
     
     if ( $DEBUG )
     {
      chomp $line;
      print "DEBUG: check_log_lines: line '$line'\n\tmatches compiler '$compiler' warning, adding $incr\n\n";
     }
    }
   }
  }

  if ( defined $error )
  {
   my @error;
   if ( ref($error) ne 'ARRAY' )
   {
    $error[0] = $error;
   }
   foreach my $e ( @error)
   {
    if ( $line =~ /$e/ )
    {
     my $incr = 0;
     if ( defined $1 )
     {
      $incr = $1;
     }
     else
     {
      $incr = 1;
     }
     $nerrors += $incr;
     $we_match++;
     if ( $DEBUG )
     {
      chomp $line;
      print "DEBUG: check_log_lines: line '$line'\n\tmatches compiler '$compiler' error, adding $incr\n\n";
     }
     push @errors, $line;
    }
   }
  }

  next if ( $we_match );
  
  #-- see if we have an end indicator, otherwise recheck compiler
  if ( defined $end )
  {
   #-- defined, so see if we match
   if ( $line =~ /$end/ )
   {
    if ( $DEBUG )
    {
     chomp $line;
     print "DEBUG: check_log_lines: line\n\n\t'$line'\n\n\tmatches compiler '$compiler' end\n";
    }
    ( $compiler, $start, $end, $warn, $error ) = ( undef, undef, undef, undef, undef );
   }
  }
  else
  {
   #-- no end tag defined, so see if this line matches any new compiler
   my ( $next_compiler, $next_start, $next_end, $next_warn, $next_error )
      = $self->find_compiler($line);
   if ( $next_compiler)
   {
    ( $compiler, $start, $end, $warn, $error ) =
         ( $next_compiler, $next_start, $next_end, $next_warn, $next_error )
   }
  }
 }
 
 return ( $nerrors, $nwarnings, \@errors, \@warnings );
}

#------------------------------------------------------------------
sub find_compiler
{
 my $self = shift;
 my $line = shift;
 
 my ( $compiler, $start, $end, $warn, $error ) = ( undef, undef, undef, undef, undef );
 
 my $compilers = $self->{Compilers};
 foreach my $comp ( keys %{$compilers} )
 {
  my $lstart = $compilers->{$comp}->{Start};
  if ( defined $lstart &&  $line =~ /$lstart/ )
  {
   if ( $DEBUG )
   {
    chomp $line;
    print "\nDEBUG: find_compiler: line\n\n\t'$line'\n\n\tmatches compiler '$comp'\n";
   }
   $compiler = $comp;
   $start    = $lstart;
   $end      = $compilers->{$comp}->{End};
   $warn     = $compilers->{$comp}->{Warn};
   $error    = $compilers->{$comp}->{Error};
   last;
  }
 }
 
 return ( $compiler, $start, $end, $warn, $error );
}
1;
