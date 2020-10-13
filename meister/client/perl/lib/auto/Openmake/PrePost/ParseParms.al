# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::PrePost;

#line 282 "C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\PrePost\ParseParms.al)"
#======================================================
# General functions

#----------------------------------------------------------------
sub ParseParms
{
 my $input  = shift;
 my %omargs = ();

 #-- bldmake options are
 #Usage: BldMake <Project> <Search Path Name> [Targets 1]...[Targets N] [-C <direc
 #tory>] [-m <output directory>]
 #          -c  = Change current working directory
 #          -f  = Use existing makefile for ApplId, Stage, and Targets
 #          -ld <Date Time> = Log: Build Date/Time
 #          -lj <Job Name>  = Log: Job Name
 #          -lm <Machine>   = Log: Build Machine Name
 #          -lo <Owner>     = Log: Owner Name
 #          -lp             = Log: Public Build
 #          -m  = Makefile output directory
 #          -ob = Output to Screen and HTML on KB Server
 #          -oh = Output to HTML on KB Server
 #          -os = Output to Screen
 #          -ov = Verbose Output
 #          -s  = Case Sensitive
 #          -v  = Version
 #          -?  = This message

 #-- om options are
 #Usage: OM [-f <Makefile Name>] [-c <Directory>] [-t <Job Name>] [-l <Log File Na
 #me>] [-b <Bill Of Mat Name> ] [-pd] [-pe] [-pm][-px] [-pf] [-pv] [-v] [Targets 1
 #]...[Targets N] [<var>=<value>]
 #          -a  = Force dependencies to be newer than the target
 #          -b  = Bill of Materials File Name for the Final Targets
 #          -c  = Change current working directory
 #          -d  = Don't Scan Source
 #          -e  = Embed Footprint in the Final Targets
 #          -f  = Makefile name, defaults to 'makefile.mak'
 #          -g  = Gather Impact Analysis
 #          -j  = Don't Scan Java Source
 #          -ld <Date Time> = Log: Build Date/Time
 #          -lj <Job Name>  = Log: Job Name
 #          -lm <Machine>   = Log: Build Machine Name
 #          -lo <Owner>     = Log: Owner Name
 #          -lp             = Log: Public Build
 #          -n  = (same as -a)
 #          -ob = Output to Screen and HTML on KB Server
 #          -oh = Output to HTML on KB Server
 #          -os = Output to Screen
 #         -ov = Verbose Output
 #          -ks = Keep Temporary Script
 #          -pd = Print dependencies as they are being checked
 #          -pe = Print environment
 #          -ph = Print Search Path Header
 #          -pl = Print loading of makefile dependencies
 #          -ps = Print script macros
 #          -pt = Print dependency tree
 #          -pv = Print Search Path being used
 #          -px = Print commands being executed
 #          -v  = Version
 #         -?  = This message

 #-- options with switches
 #   -C <directory>
 #   -ld <date/time>
 #   -lj <Job Name>  = Log: Job Name
 #   -lm <Machine>   = Log: Build Machine Name
 #   -lo <Owner>     = Log: Owner Name
 #   -m  <directory> = Makefile output directory
 #
 #   -f  <makefile name>
 #   -b  <Bill of Materials>

 $input =~ s/^\s+//;
 $input =~ s/\s+$//;

 #-- split on spaces.
 my @inargs = &quotespacesplit( $input );
 foreach my $a ( @inargs )
 {
  $a =~ s/^"//;
  $a =~ s/"$//;
 }

 while ( ( grep /^-/, @inargs ) || ( grep /=/, @inargs ) )
 {
  my $arg = shift @inargs;

  #-- remove leading, trailing "

  #-- if $arg starts with '-', add it to hash, look for necessary
  #   parameters.
  if ( substr( $arg, 0, 1 ) eq '-' )
  {
   $arg = substr( $arg, 1 );
   $omargs{$arg} = 1;

   #-- check cases that require an additional argument
   #
   if ( $arg =~ /^([bcCmf]|l[djmo]|[bra][pcr])$/ )
   {
    my $nextarg = shift @inargs;
    last unless $nextarg;
    if ( substr( $nextarg, 0, 1 ) eq '-' )
    {

     #-- need to error here except if (-f)
     if ( $arg ne 'f' )
     {
      print "Error: Argument $arg needs a value, but is followed by $nextarg\n";
     }
     else
     {
      unshift @inargs, $nextarg;    #-- push nextarg after -f back onto list
     }
    } #-- End: if ( substr( $nextarg,...
    else
    {
     while ( substr( $nextarg, 0, 1 ) ne '-' )
     {
      if ( $omargs{$arg} == 1 )
      {
       $omargs{$arg} = "$nextarg";
      }
      else
      {
       $omargs{$arg} .= " $nextarg";
      }
      $nextarg = shift @inargs;
      last unless $nextarg;
     } #-- End: while ( substr( $nextarg,...
     unshift @inargs, $nextarg;    #-- push nextarg back onto list
     $omargs{$arg} =~ s/^\s+//;
     $omargs{$arg} =~ s/\s+$//;
    } #-- End: else[ if ( substr( $nextarg,...
   } #-- End: if ( $arg =~ /^([bcCmf]|l[djmo]|[bra][pcr])$/...

   #-- match to env variable type info
   if ( $arg =~ /=/ )
   {
    my @t = split /=/, $arg;
    $omargs{ $t[0] } = $t[1];
   }
   next;
  } #-- End: if ( substr( $arg, 0, ...

 } #-- End: while ( ( grep /^-/, @inargs...
 return %omargs;

#----------------------------------------------------------------
 sub quotespacesplit
 {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;

  #-- Split on spaces
  my @split = split( /\s+/, $string );

  #-- Reconstruct quotes
  my @correctsplit = ();
  my $at           = "";

  #-- Loop through the arguments to match up quotes
  for ( $i = 0 ; $i < @split ; $i++ )
  {
   $at .= $split[$i];
   if ( $at !~ /\"/ || ( $at =~ /\".*\"$/ ) )
   {
    push( @correctsplit, $at );
    $at = "";
   }
   else
   {
    $at .= " ";
   }
  } #-- End: for ( $i = 0 ; $i < @split...

  #-- remove quotes
  return @correctsplit;
 } #-- End: sub quotespacesplit
} #-- End: sub ParseParms

# end of Openmake::PrePost::ParseParms
1;
