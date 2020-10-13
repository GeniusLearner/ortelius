#==========================================================================
package Openmake::UserExit;

BEGIN
{
 use Exporter ();
 use vars qw(@ISA @EXPORT $VERSION);
 
 @ISA    = qw(Exporter );
 @EXPORT = qw( &PreScriptExit &PostScriptExit);

 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/UserExit.pm,v 1.2 2005/01/24 21:10:09 jim Exp $'; 
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
=head1 DESCRIPTION

Openmake::UserExit is a template for allowing User specific Perl
subroutines to be called immediately before the Build Type script
is about to exit.

=cut

#----------------------------------------------------------------
sub PreScriptExit()
{

}

#----------------------------------------------------------------
sub PostScriptExit()
{

}

# The very important positive return result
1;
