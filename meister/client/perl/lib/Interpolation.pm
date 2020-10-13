# -*- mode: cperl; cperl-indent-level: 2 -*-
#
# This module is copyright 1998 Mark-Jason Dominus.
# (mjd-perl-interpolation@plover.com)
#
# Version 0.53 alpha $Revision: 1.1.1.1 $ $Date: 2005/01/20 22:36:53 $

package Interpolation;
$VERSION = '0.53';

   

use Carp;
# use Symbol;

%builtin = (null => sub { $_[0] },
	    'eval' => sub { $_[0] },
	    identity => sub { $_[0] },
	    ucwords => 
	    sub { 
	      my $s = lc shift;
	      $s =~ s/\b(\w)/\u$1/g;
	      $s
	    },
	    commify => 
	    sub {
	      local $_ = sprintf("%.2f", shift());
	      1 while s/^(-?\d+)(\d{3})/$1,$2/;
	      $_;
	    },
	    'reverse' =>
	    sub { reverse $_[0] },
	    
	    # Idea for funky sprintf trick thanks to Ken Fox	
	    'sprintf' =>
	    sub {
	      my %fakehash;
	      my $format = shift;
	      tie %fakehash, Interpolation, 
	      sub { sprintf($format, split /$;/o,$_[0])};
	      \%fakehash;
	    },
	    'sprintf1' =>
	    sub {
	      my ($fmt, @args) = split(/$;/o, shift());
	      sprintf($fmt, @args);
	    }
	   );

sub import {
  my $caller_pack = caller;
#  print STDERR "exporter args: (@_); caller pack: $caller_pack\n";
  my $my_pack = shift;
  if (@_ % 2) {
    croak "Argument list in `use $my_pack' must be list of pairs; aborting";
  }
  while (@_) {
    my $hashname = shift;
    my $function = shift;

    # Probably should use ISA or something here, because
    # $function might be blessed
    unless (ref $function eq CODE || exists $builtin{$function}) {
      croak "Values in argument list in `use $my_pack' must be code refs; aborting\n";
    }

    my %fakehash;
    tie %fakehash, $my_pack, $function;
    *{$caller_pack . '::' . $hashname} = \%fakehash;
  }
}

sub unimport {
#  warn "Interpolation::unimport @_\n";
  my $caller_pack = caller;
  my $my_pack = shift;
  while (@_) {
    my $hashname = shift;
    my %fakehash;
    my $oldhash = *{$caller_pack . '::' . $hashname}{HASH};
    *{$caller_pack . '::' . $hashname} = \%fakehash;
    untie %$oldhash;
  }
  
}

sub TIEHASH {
  my $pack = shift;
  my $cref = shift;
  unless (ref $cref) {		# Convert symbolic name to function ref
    croak "Unknown builtin function `$cref'; aborting"
      unless exists $builtin{$cref};
    $cref = $builtin{$cref};
  }
  bless $cref => $pack;		# That's it?  Yup!
}

# Deprecated unless someone has a good idea of what it is good for.
{ 
  # To suppress the warning, set this variable to 1.
  $TIEARRAY_WARNED = 0;

  sub TIEARRAY {
    my $pack = shift;

    unless ($TIEARRAY_WARNED++) {
      carp "Tied $pack arrays are deprecated.\n  Send email to mjd-perl-interpolation\@plover.com\n  to prevent them from being removed in a future version.\n";
    }

    bless $builtin{identity} => $pack;
  }
}

# This is where the magic is.
sub FETCH {
  &{$_[0]}($_[1]);		# For pre-5.004_04 compatibility
  #$_[0]->($_[1]);		# Line of the day?
}

sub cut_it_out {
  my $object = shift;
  my $caller = (caller(1))[3];
  croak "Not allowed to use $caller on an Interpolation variable; aborting";
}

*STORE = \&cut_it_out;
*DELETE = \&cut_it_out;
*CLEAR = \&cut_it_out;
*EXISTS = \&cut_it_out;
*FIRSTKEY = \&cut_it_out;
*NEXTKEY = \&cut_it_out;

1;

=head1 NAME

Interpolation - Arbitrary string interpolation semantics

=head1 SYNOPSIS

  use Interpolation name => \&function, ...;
  print "la la la la $name{blah blah blah}";

  # This is like doing:
  $VAR = &function(blah blah blah);
  print "la la la la $VAR";

=head1 DESCRIPTION

Beginners always want to write this:

  print "The sum of three and four is: 3+4";

And they want the C<3+4> part to be evaluated, so that it prints
this:

  The sum of three and four is: 7

Of course, it's a double-quoted string, so it's not evaluated.  The
only things that are evaluated in double-quoted strings are variable
references. 

There are solutions to this, but most of them are ugly.  This module
is less ugly.  It lets you define arbitrary interpolation semantics.

For example, you can say

   use Interpolation money => \&commify_with_dollar_sign,
                     E     => 'eval',
                     placename => 'ucwords', 
       ;

And then you can write these:

   print "3 + 4 = $E{3+4}";
   # Prints  ``3 + 4 = 7''

   $SALARY = 57500;
   print "The salary is $money{$SALARY}";
   # Prints  ``The salary is $57,500.00''

   $PLACE1 = 'SAN BERNADINO HIGH SCHOOL';
   $PLACE2 = 'n.y. state';
   print "$placename{$PLACE1} is not near $placename{$PLACE2}";
   # Prints  ``San Bernadino High School is not near N.Y. State";

=head1 DETAILS

The arguments to the C<use> call should be name-function pairs.  If
the pair is C<($n, $f)>, then C<$n> will be the name for the semantics
provided by C<$f>.  C<$f> must either be a reference to a function
that you supply, or it can be the name of one of the built-in
formatting functions provided by this package.  C<Interpolation> will
take over the C<%n> hash in your package, and tie it so that acessing
C<$n{X}> calls C<f(X)> and yields its return value.

If for some reason you want to, you can add new semantics at run time
by using

  import Interpolation name => function, ...

You can remove them again with

  unimport Interpolation 'name', ...

=head2 Built-ins

C<Interpolation> provides a few useful built-in formatting functions;
you can refer to these by name in the C<use> or C<import> line.  They are:

      eval     Evaluate argument
      null     Same as eval
      identity Also the same as eval
      ucwords  Capitalize Input String Like This
      commify  1428571 => 1,428,571.00
      reverse  reverse string
      sprintf  makes "$S{'%.2f %03d'}{37.5,42}" turn into "37.50 042".
      sprintf1 makes "$S{'%.2f %03d', 37.5,42}" turn into "37.50 042".

=for comment
Examples:

=head1 Warnings

It's easy to forget that the index to a C<$hash{...}> is an arbitrary
expression, unless it looks like an identifier.  There are two gotchas here.  

=over 4

=item Trap 1. 

  print "$X{localtime}";

Here the C<X> formatter is used to format the literal string
C<localtime>; the C<localtime> built-in function is not invoked.  If
you really want the current time, use one of these:

  print "$X{+localtime}";
  print "$X{localtime()}";

=item Trap 2.

  print "$X{What ho?}";

This won't compile---you get `search pattern not terminated'.  Why?
Because Perl sees the C<?> and interprets it as the beginning of a
pattern match operator, similar to C</>.  (Ah, you forgot that C<?>
could be a pattern match delimiter even without a leading C<m>, didn't
you?)  You really need

  print "$X{'What ho?'}";

=back 

The rule is simple: That thing in the braces that looks like a hash
key really is a hash key, and so you need to put it in quotes under
the same circumstances that you need to put any other hash key in
quotes.  You probably wouldn't expect this to work either:

  $V = $X{What ho?};


=head1 Author

=begin text

Mark-Jason Dominus (C<mjd-perl-interpolation@plover.com>), Plover Systems co.

See the C<Interpolation.pm> Page at http://www.plover.com/~mjd/perl/Interpolation
for news and upgrades.  

=end text

=begin man

Mark-Jason Dominus (C<mjd-perl-interpolation@plover.com>), Plover Systems co.

See the C<Interpolation.pm> Page at http://www.plover.com/~mjd/perl/Interpolation
for news and upgrades.  

=end man

=begin html
<p>Mark-Jason Dominus (<a href="mailto:mjd-perl-interpolation@plover.com"><tt>mjd-perl-interpolation@plover.com</tt></a>), Plover Systems co.</p>
<p>See <a href="http://www.plover.com/~mjd/perl/Interpolation/">The <tt>Interpolation.pm</tt> Page</a> for news and upgrades.</p>

=end html


=cut


