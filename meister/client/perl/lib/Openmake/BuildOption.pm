#==========================================================================
package Openmake::BuildOption;

BEGIN
{
 use Exporter ();

 #-- JAG - 01.16.05 - begin to use AutoLoader for 6.4
 use AutoLoader;
 use strict;
 use vars qw(
   @ISA
   @EXPORT
   $VERSION
   $REQUIRED_FLAG
   $USES_PARAM
   $LOCKED_PARAM
   $RELEASE
   $DEBUG
   $CUSTOM_FLAG
   $TASK_FLAG
   $RULE_FLAG
   $FILE_DEP
   $TASK_DEP
   $OPTIONGROUP_DEFAULT_NAME
   );
 use Openmake qw(EvalEnvironment);

 @ISA    = qw( Exporter AutoLoader );
 @EXPORT = qw( );
 my $HEADER = '$Header: /CVS/openmake64/perl/lib/Openmake/BuildOption.pm,v 1.13 2008/02/11 19:31:35 steve Exp $';
 if ($HEADER =~ /^\s*\$Header:\s*(\S+),v\s+(\S+)\s+(\S+)\s+(\S+)/ )
 {
  my $path = $1;
  my $version = $2;
  $version =~ s/\.//g;
  my @t = split /\//, $path;
  my ( $major ) = $t[2] =~ /6\.?(\d+)/ ;
  $VERSION = "6." . $major . $version;
 }

 #-- these are constants for bitmasks of option types
 $REQUIRED_FLAG            = 1;
 $USES_PARAM               = 2;
 $LOCKED_PARAM             = 4;
 $RELEASE                  = 8;
 $DEBUG                    = 16;
 $CUSTOM_FLAG              = 32;
 $TASK_FLAG                = 64;
 $RULE_FLAG                = 128;
 $FILE_DEP                 = 1;
 $TASK_DEP                 = 2;
 $OPTIONGROUP_DEFAULT_NAME = "Build Task Options";

} #-- End: BEGIN

#----------------------------------------------------------------
=head1 DESCRIPTION

Openmake::BuildOption.pm is a reusable PERL module that contains object/methods
to deal with the Openmake 6.3 format of parsing build options.

=head1 CONSTANTS

Openmake::BuildOption exports the following constants:

=over 4

=item REQUIRED_FLAG

If this bit is set, the flag is a required flag.

=item USES_PARAM

If this bit is set, the flag uses an accompanying parameter.

=item LOCKED_PARAM

If this bit is set, the flag's accompanying parameter cannot be changed by
the user, only by the administrator at the Build Type level.

=item RELEASE

If this bit is set, the flag is to be used in Release Builds.

=item DEBUG

If this bit is set, the flag is to be used in Debug Builds.

=item CUSTOM_FLAG

If this bit is set, the flag was set in the Target Definition file

=item TASK_FLAG

If this bit is set, the flag was set at the Build Task or Option Group level.

=item RULE_FLAG

If this bit is set, the flag was set at the rule level.

=item OPTIONGROUP_DEFAULT_NAME

Name of the default Option Group used by the Build Task

=back 4

=head2 AutoLoading

Because not all BuildTypes use the Openmake::BuildOption module, all methods
in this module are AutoLoaded (compiled when invoked, not at run-time).

=head2 new($DebugFlags|$ReleaseFlags)

Creates a new Openmake::BuildOption object. The optional argument is a hash
reference pointing to a hash that is keyed by filename and has values of the
options passed to the script from the Build Control file.

Typically, this hash reference is one of the Openmake script variables
$DebugFlags or $ReleaseFlags.

USAGE:

my $build_option = Openmake::BuildOption->new($DebugFlags);

RETURNS:

Openmake::BuildOption object

See update

=head2 update( $hashref)

Updates the Openmake::BuildOption object based on the contents of the $hashref.
reference pointing to a hash that is keyed by filename and has values of the
options passed to the script from the Build Control file.

Typically, this hash reference is one of the Openmake script variables
$DebugFlags or $ReleaseFlags.

USAGE:

$build_option->update($ReleaseFlags);

RETURNS:

The updated Openmake::BuildControl object;

See new();

=head2 getBuildTasks

Gets a list of defined Build Tasks, as listed in the options for all
dependencies. This list is not necessarily one element long (the current
Build Task), because dependencies can be inherited from previous Build
Tasks. Note that the current Build Task is defined in the Openmake global
variable $BuildTask.

USAGE:

my @build_tasks = $build_opt->getBuildTasks();

 or

my $build_task_ref = $build_opt->getBuildTasks();

RETURNS:

Array, or reference to array, of build task names, depending if the
method is called in scalar context.

=head2 getOptionGroups( $build_task)

Gets a list of defined Option Groups for the given Build Task $build_task,
as listed in the options for all dependencies.

USAGE:

my @option_groups = $build_opt->getOptionGroups($build_task);

 or

my $option_groups_ref = $build_opt->getOptionGroups($build_task);

RETURNS:

Array, or reference to array, of option group names, depending if the
method is called in scalar context.

=head2 getBuildTaskFiles( $BuildTask, $OptionGroup, $all)

Gets the files and options for the files, for the files that
match to a given Build Task and Option Group. If Option Group is not passed,
the routine will assume the standard option group as defined in
$OPTIONGROUP_DEFAULT_NAME. Returns references to file list and option list.

If $all is true, we return all files listed as dependencies. Otherwise,
we only return the files that are listed in TargetDeps as belonging to
the Target that is being built.

For example, in the Javac task for abc.jar.

    $Target = "abc.javac";
    $TargetDeps->in("a.java") == 1
    $TargetDeps->in("rt.jar") == 0

If $all is true, both a.java and rt.jar are returned. If $all is not true,
only a.java is returned. This is because rt.jar is inherited from the
previous Build Task.


USAGE:

my ( $file_ref, $option_ref ) = $build_options->getBuildTaskFiles( "Ant Javac" );
my @files = @{$file_ref};
my @options = @{$option_ref};

RETURNS:

References to two lists, the files and the matching options for those files.

=head2 getBuildTaskOption( $option_name, $build_task, $option_group)

For a Build Task $build_task and an Option Group $option_group, gets
the value of an option specified by $option_name. To retrieve the
option value, the option must be defined as either

  option=value

or

 -option value
 --option value

If Option Group is not passed, the routine will assume the standard
option group as defined in $OPTIONGROUP_DEFAULT_NAME.

The first usage is the default. To specify the second usage, include
the leading dash or double dash.

USAGE:

for 'manifest="META-INF/manifest.mf"'

 my $manifest_file = $build_option->getBuildTaskOption( "manifest", $BuildTask);
 $manifest_file =~ s|^"||g;
 $manifest_file =~ s|"$||g;

for '-p 58080'

 my $port = $build_option->getBuildTaskOption( "-p", $BuildTask);

RETURNS:

The value of the option, in either the <option>=<value> or -<option> <value>
construction. Note that quotes aren't stripped from options like
manifest="META-INF/manifest.mf"

See getBuildTaskOptions

=head2 getBuildTaskOptions( $build_task, $option_group)

Gets all the options specified by $option_name for a given Build Task
and Option Group. If Option Group is not passed, the routine will
assume the standard option group as defined in $OPTIONGROUP_DEFAULT_NAME.

USAGE:

my $options_str = $build_option->getBuildTaskOptions( $BuildTask);

  or

my @options = $build_option->getBuildTaskOptions( $BuildTask);

RETURNS:

A string of the options, or an array of options, depending if the method
is called in scalar context or not.

See getBuildTaskOption

=head2 getOption4File( $file_name )

Gets all the options associated to a file.

USAGE:

my $options_str = $build_option->getOption4File("c:\\hello\\hello.cpp");


RETURNS:

A string of the options.

=cut
#================================================================
#-- __END__ Statement for autoloading. All subroutines/methods
#           below here are autoloaded when invoked

#1;
#__END__

#----------------------------------------------------------------
sub new
{
 my $class   = shift;
 my $hashref = shift;
 #my $class   = ref( $proto ) || $proto;
 my $self    = {};

 #-- need to define everything for strict
 $self->{"Build Tasks"} = ();
 $self->{"Files"}       = ();

 bless( $self, $class );

 #-- if $hashref is passed, update with the dude.
 if ( ref $hashref eq "HASH" )
 {
  $self->update( $hashref );
 }

 return $self;
} #-- End: sub new

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
 # SBT 02.11.08 - Update for performance
 my %InList = {};
 my @f = $::TargetDeps->getList();
 @InList{@f} = ();

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
     #-- Remove extra info if present
     if ( $file =~ m{\|} )
     {
      my @t = split /\|/, $file;
      $file = shift @t;
     }
     #my $depparent = $main::DependencyParent{$file};
     my $file_type = 2;                                #-- assume that the file does not belong to the build task
  # SBT 02.11.08 - Update for performance
#     $file_type = 1 if ( $::TargetDeps->in($file) );
     $file_type = 1 if ( exists $InList{$file} );

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

#----------------------------------------------------------------
sub getBuildTasks
{
 my $self       = shift;
 my @buildtasks = keys %{ $self->{"Build Tasks"} };
 return wantarray ? @buildtasks : \@buildtasks;
}

#----------------------------------------------------------------
sub getOptionGroups
{
 my $self      = shift;
 my $buildtask = shift;

 my @optiongroups = keys %{ $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"} };

 return wantarray ? @optiongroups : \@optiongroups;
}

#----------------------------------------------------------------
sub getBuildTaskFiles
{
 my $self        = shift;
 my $buildtask   = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;
 my $all         = shift;

 my @files   = ();
 my @options = ();
 my $ref     = $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"}->{$optiongroup};

 return ( undef, undef ) unless ( $ref );

 foreach my $file ( keys %{ $ref->{"Files"} } )
 {
  if ( !$all )
  {
   next if ( $ref->{"Files"}->{$file}->{FileType} != 1 );
  }

  if ( ref $ref->{"Files"}->{$file} )
  {
   push @files, $file;

   #-- JAG - 12.28.05 - case 6290 - if the file is in 2 option groups
   #   need to get the correct one.
   my $option = $self->{"Files"}->{$file}->{$optiongroup};
   push @options, EvalEnvironment($option);
  }

 } #-- End: foreach my $file ( keys %{ ...

 return ( \@files, \@options );
} #-- End: sub getBuildTaskFiles

#----------------------------------------------------------------
sub getOption4File
{
 my $self        = shift;
 my $file        = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;

 $file =~ s/\\/\//g;

 #-- JAG - case 5172, expand envs
 return EvalEnvironment($self->{"Files"}->{$file}->{$optiongroup});

} ## end sub getOption4File

#----------------------------------------------------------------
sub getBuildTaskOption
{
 my $self        = shift;
 my $option      = shift;
 my $buildtask   = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;

 my $option_type = 1;    #-- equals construction
 $option_type = 2 if ( $option =~ /^\-/ );    #-- dash construction

 my $ref = $self->{"Build Tasks"};
 if ( !$buildtask )
 {
  if ( scalar( keys %{$ref} ) == 1 && !$buildtask )
  {
   my @t = keys %{$ref};
   $buildtask = $t[0];
  }
  else
  {
   return undef;
  }
 } #-- End: if ( !$buildtask )

 #-- find the option that matches, ie. manifest= or webxml=
 my $optionvalue = $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"}->{$optiongroup}->{"Options"};

 #-- match like moduledir in Openmake.pm, loop over each to find our guy
 my @optionvalues = &Openmake::SmartSplit( $optionvalue );

 my $i = 0;
 foreach my $opt ( @optionvalues )
 {
  $i++;    #-- increment here so we get the next one as our value
  if ( $option_type == 1 )
  {
   if ( $opt =~ /^$option=(.+)/ )
   {
    $optionvalue = $1;
    return EvalEnvironment($optionvalue);
   }
  }
  else     #-- dash notation
  {
   if ( $opt eq $option )
   {
    $optionvalue = $optionvalues[$i];
    return EvalEnvironment($optionvalue);
   }
  }
 } #-- End: foreach my $opt ( @optionvalues...

 return undef;
} #-- End: sub getBuildTaskOption

#----------------------------------------------------------------
sub getBuildTaskOptions
{
 my $self        = shift;
 my $buildtask   = shift;
 my $optiongroup = shift || $OPTIONGROUP_DEFAULT_NAME;

 my $ref = $self->{"Build Tasks"};
 if ( !$buildtask )
 {
  if ( scalar( keys %{$ref} ) == 1 && !$buildtask )
  {
   my @t = keys %{$ref};
   $buildtask = $t[0];
  }
  else
  {
   return undef;
  }
 } #-- End: if ( !$buildtask )

 my $optionvalue = $self->{"Build Tasks"}->{$buildtask}->{"Option Groups"}->{$optiongroup}->{"Options"} || undef;

 #-- see if we want to split this up
 $optionvalue = EvalEnvironment($optionvalue);
 my @optionvalues = Openmake::SmartSplit( $optionvalue );

 return wantarray ? @optionvalues : $optionvalue;

} #-- End: sub getBuildTaskOptions


1;
__END__
