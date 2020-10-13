# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::ParseBOM;

#line 810 "C:/Work/Catalyst/SourceCode/Openmake640_Trunk/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\ParseBOM\new.al)"
#----------------------------------------------------------------
sub new
{
 my $proto = shift;
 my $class = ref( $proto ) || $proto;
 my $self  = {};

 my $bomrpt = shift;
 return unless ( -e $bomrpt );

 #--  parse the file
 open( BOM, "$bomrpt" );
 my $indep = 0;
 while ( <BOM> )
 {
  chomp;
  next if ( /^\s+$/ );
  if ( /Dependencies:/ )
  {
   $indep = 1;
   next;
  }
  if ( /END:/ )
  {
   $indep = 0;
   next;
  }

  if ( $indep )
  {

   #-- parse the dependencies.
   #         12/31/1969 19:00:00              (null)
   if ( /(.+)(\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}) (\d+)\s+(.+)/ )
   {

    #-- has a date/time stamp
    my $versioninfo = $1;
    my $datetime    = $2;
    my $size        = $3;
    my $file        = $4;

    #-- convert date/time back to epoch
    my ( $date, $time ) = split / /, $datetime;
    my ( $mon,   $mday, $year ) = split /\//, $date;
    my ( $hours, $min,  $sec )  = split /:/,  $time;

    $mon--;
    $year -= 1900;

    use Time::Local;
    my $localtime = timelocal( $sec, $min, $hours, $mday, $mon, $year );

    #-- add this to the object;
    $self->{$file} = {
     TStamp => $localtime,
     Size   => $size,
     VInfo  => $versioninfo
    };
   } #-- End: if ( /(.+)(\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}) (\d+)\s+(.+)/...
  } #-- End: if ( $indep )
 } #-- End: while ( <BOM> )

 bless( $self, $class );
 return $self;
} #-- End: sub new

# end of Openmake::ParseBOM::new
1;
