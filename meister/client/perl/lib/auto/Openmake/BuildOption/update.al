# NOTE: Derived from C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::BuildOption;

#line 326 "C:/Work/Catalyst/CVS/openmake-640_TRUNK/perl/lib/Openmake/BuildOption.pm (autosplit into perl\lib\auto\Openmake\BuildOption\update.al)"
#----------------------------------------------------------------
sub update
{
 use Cwd;
 my $self    = shift;
 my $hashref = shift;

 my %set_btog_options;

 my $cwd = cwd();
 $cwd =~ s|\\|\\\/|g;

 return $self unless ( ref $hashref eq "HASH" );

 my @allowedtypes = qw( BTOG TBTOG DO RUL BRT TBRT);

 #-- invert the hash
 #-- JAG 01.13.03 - the reference is now keyed by FT->BT->OG->Name
 #   so we can look solely at "primary" targets (see below)
 #
 #-- JAG 02.04.03 - changed to Target->BT->OG->Name, so change here too
 #
 #   Update not to depend on DependencyParent
 #-- JAG 03.08.04 - have to be dependent on DepParetn

 my $Target = $main::Target->getDPFE;
 $Target =~ s|\\|\/|g;
 $Target =~ s|\/|\\\/|g;

 #-- the keys of the hashref are written by om to have "/"
 foreach my $target ( keys %{$hashref} )
 {
  foreach my $build_task ( keys %{ $hashref->{$target} } )
  {
   #   $file_type = 1 if  ( $build_task eq $main::BuildTask );

   foreach my $option_group ( keys %{ $hashref->{$target}->{$build_task} } )
   {
    foreach my $key ( keys %{ $hashref->{$target}->{$build_task}->{$option_group} } )
    {
     my $file      = $key;
     #my $depparent = $main::DependencyParent{$file};
     my $file_type = 2;                                #-- assume that the file does not belong to the build task
     $file_type = 1 if ( $::TargetDeps->in($file) );

     #-- all forward slashes
     $file =~ s|\\|\/|g;

     my $flatflags = "";
     my $value     = $hashref->{$target}->{$build_task}->{$option_group}->{$key};

     my $optionref;
     $optionref->{FileType} = $file_type;
     my $filebuildtask   = "";
     my $fileoptiongroup = "";

     #-- parse $value for a BuildTask/Rule/Dependency option key
     #-- this can get cleaned up, since we're already in the big loop

     #-- JAG - 05.21.04 - case 4693 - need to clean up Regex in case
     #       options have {} in them
     #while ( $value =~ s|^\s*([A-Z]{2,5})\((.+?)\)\[(\d+)\]\{(.*?)\}|| )

     #-- JAG - 09.30.04 - case 5078. Need to make () before [\d+] optional
     #                    so that DO[442] matches
     while (
      $value =~
      s!^\s*([A-Z]{2,5})((?:\(.+?\))?\[\d+\])\{(.*?)(\}\s+[A-Z]{2,5}|\}$)!! )
     {
      my $typekey               = $1;
      my $buildtask_and_bitmask = $2;
      my ( $buildtask, $bitmask );
      #my $bitmask = $3;
      my $flags     = $3;
      my $lastmatch = $4;

      #-- split buildtask_and_bitmask
      if ( $buildtask_and_bitmask =~ /^\((.+?)\)\[(\d+)\]$/ )
      {
       $buildtask = $1;
       $bitmask   = $2;
      }
      elsif ( $buildtask_and_bitmask =~ /^\[(\d+)\]$/ )
      {
       $buildtask = "";
       $bitmask   = $1;
      }

      if ( $lastmatch =~ /([A-Z]{2,5})/ )
      {
       $value = $1 . $value;
      }
      my $optiongroup = "";
      if ( $buildtask =~ /(.+?)\|(.+)/ )
      {
       $buildtask   = $1;
       $optiongroup = $2;
      }

      $flags =~ s|^\s+||;
      $flags =~ s|\s+$||;
      $flags =~ s|\s+| |g;

      #-- determine what to do with this guy
      #   If it's a primary dependency, do all the processing
      if ( $file_type == 1 )
      {
       if ( $typekey eq "BTOG" || $typekey eq "TBTOG" || $typekey eq "RUL" )
       {
        #-- test to see if we already have a defined build task
        if ( $filebuildtask && $filebuildtask ne $buildtask )
        {
         #-- error
         next;
        }

        $filebuildtask = $buildtask;
        if ( $fileoptiongroup && $optiongroup && $fileoptiongroup ne $optiongroup )
        {
         #-- error
         next;
        }
        $fileoptiongroup = $optiongroup;

        #-- if
        unless ( defined $set_btog_options{ $filebuildtask . "|" . $fileoptiongroup } )
        {
         my $existing_og_flag = $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$fileoptiongroup}->{"Options"};
         unless ( $existing_og_flag =~ /\Q$flags\E/ )
         {
          if ( $existing_og_flag )
          {
           $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$fileoptiongroup}->{"Options"} .= " ";
          }
          $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$fileoptiongroup}->{"Options"} .= $flags;
         }
        } #-- End: unless ( defined $set_btog_options...
       } #-- End: if ( $typekey eq "BTOG"...

       #-- special processing for the Root Build Type Option Group if not
       #   already present
       if ( $typekey eq "BRT" || $typekey eq "TBRT" )
       {
        #-- test to see if we already have a defin build task
        if ( $filebuildtask && $filebuildtask ne $buildtask )
        {
         #-- error
         next;
        }
        $filebuildtask = $buildtask;

        #-- test to see if we have root Build Task Option Group stuff
        unless ( defined $set_btog_options{ $filebuildtask . "|" . $OPTIONGROUP_DEFAULT_NAME } )
        {
         my $existing_og_flag = $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$OPTIONGROUP_DEFAULT_NAME}->{"Options"};
         unless ( $existing_og_flag =~ /\Q$flags\E/ )
         {
          if ( $existing_og_flag )
          {
           $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$OPTIONGROUP_DEFAULT_NAME}->{"Options"} .= " ";
          }
          $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$OPTIONGROUP_DEFAULT_NAME}->{"Options"} .= $flags;
         }
        } #-- End: unless ( defined $set_btog_options...
       } #-- End: if ( $typekey eq "BRT"...

       #-- keep creating the option ref;
       #   add in bitmask
       if ( grep /$typekey/, @allowedtypes )
       {
        if ( defined $optionref->{$typekey}->{$bitmask} )
        {
         $optionref->{$typekey}->{$bitmask} .= " ";
        }
        $optionref->{$typekey}->{$bitmask} .= $flags;
       }
      } #-- End: if ( $file_type == 1 )

      #-- add the flags to the flattened list.
      $flatflags .= " " if ( $flatflags );
      $flatflags .= $flags;
     } #-- End: while ( $value =~ s!^\s*([A-Z]{2,5})((?:\(.+?\))?\[\d+\])\{(.*?)(\}\s+[A-Z]{2,5}|\}$)!!...

     #-- add the file to the list
     if ( $file_type == 1 )
     {
      $fileoptiongroup = $OPTIONGROUP_DEFAULT_NAME unless ( $fileoptiongroup );
      $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$fileoptiongroup}->{"Files"}->{$file} = $optionref;

      #-- set the buildtype-og options
      $set_btog_options{ $filebuildtask . "|" . $fileoptiongroup } = 1;

      #-- test to see if the main Option Group was set, incase we are in the TBRT situation
      if ( $fileoptiongroup ne $OPTIONGROUP_DEFAULT_NAME )
      {
       if ( defined $self->{"Build Tasks"}->{$filebuildtask}->{"Option Groups"}->{$OPTIONGROUP_DEFAULT_NAME}->{"Options"} )
       {
        $set_btog_options{ $filebuildtask . "|" . $OPTIONGROUP_DEFAULT_NAME } = 1;
       }
      }
     } #-- End: if ( $file_type == 1 )
     #-- JAG - 12.29.05 - case 6290 - file can exist in more than one option group
     $self->{"Files"}->{$file}->{$fileoptiongroup} = $flatflags;
    } #-- End: foreach my $key ( keys %{ $hashref...
   } #-- End: foreach my $option_group ( ...
  } #-- End: foreach my $build_task ( keys...
 } #-- End: foreach my $target ( keys %...
 return $self;

} #-- End: sub update

# end of Openmake::BuildOption::update
1;
