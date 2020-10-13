#==========================================================================
package Openmake::Load;

BEGIN
{
 use Exporter ();
 use Carp;
 
 #-- JAG - 01.16.05 - begin to use AutoLoader for 6.4
 use vars qw(@ISA @EXPORT $VERSION);

 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/Load.pm,v 1.4 2008/04/09 21:52:47 jim Exp $'; 
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  # SBT 02.11.08 - Update for performance
  $VERSION = "7.1" . $version;
 }
 @ISA     = qw( );
 @EXPORT  = qw( Load );
 
} #-- End: BEGIN

#----------------------------------------------------------------
=head1 NAME

Openmake::Load

=head1 LOCATION

program files/openmake6/perl/lib/Openmake

=head1 DESCRIPTION

=cut
#================================================================
#-- methods 
sub load
{
 #-- try to load from the data array
 my $self = shift;
 my $var_name = shift;
 my $var = '$' . $var_name;
 my @perl_data = @_;
 
 return @perl_data if ( $self->{Loaded} > 0) ;

 # SBT 02.11.08 - Update for performance
 if (!grep(/$var_name/,@AlreadyLoaded))
 {
  push(@AlreadyLoaded,$var_name);
 }
 else
 {
  return @perl_data;
 }
 
 #-- do the loading 
 my $lookfor = '^\\$' . $var_name . '|^push\(@' . $var_name;
 
 my @work_data = grep(/$lookfor/,@perl_data);
 my @ret_perl_data = grep(!/$lookfor/,@perl_data);
 
 foreach my $line ( @work_data)
 {
   #-- Variable needs to live in the main namespace.
   $line =~ s|([\$\@])$var_name|$1::$var_name|;
   eval( $line);
 }

 $self->{Loaded} = 1;
 return @ret_perl_data;
}

#================================================================
#-- subroutines (not methods)
#----------------------------------------------------------------
#----------------------------------------------------------------
sub Load
{
 #-- try to load from the data array
 my $var_name = shift;
 my $var = '$' . $var_name;
 my @perl_data = @_;
 # SBT 02.11.08 - Update for performance
 my @t = split(/,/,$var_name);
 my $lookfor = "";
 
 foreach $var (@t)
 {
  next if ($var eq "");
  
  if (!grep(/$var/,@AlreadyLoaded))
  {
   push(@AlreadyLoaded,$var);
   $lookfor .= '|^\\$' . $var . '|^push\(@' . $var;
  }
 }
 
 if ($lookfor eq "")
 {
  return @perl_data;
 }
  
 $lookfor = substr($lookfor,1);
 
 my @work_data = grep(/$lookfor/,@perl_data);
 my @ret_perl_data = grep(!/$lookfor/,@perl_data);
 
 foreach my $line ( @work_data)
 {
   #-- Variable needs to live in the main namespace.
   $line =~ s|push\(\@|push\(\@::|;
   $line =~ s|^\$|\$::|;

   eval( $line);
 }
 return @ret_perl_data;
}

#================================================================
1;
