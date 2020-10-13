# NOTE: Derived from C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Openmake::PrePost;

#line 465 "C:/Work/Catalyst/SourceCode/Openmake640_dev_Branch/perl/lib/Openmake/PrePost.pm (autosplit into perl\lib\auto\Openmake\PrePost\SetLogging.al)"
#------------------------------------------------------
sub SetLogging
{
 use Openmake::File;
 my $cmdline = shift;
 my %cmd     = ParseParms( $cmdline );

 #-- set the main variables that Openmake::Log.pm expects
 $main::Quiet          = $cmd{ov} ? "YES" : "NO";
 $main::JobMachineName = $cmd{lm};
 $main::MachineName    = $ENV{HOST} || $ENV{HOSTNAME} || $ENV{COMPUTERNAME};
 $main::LogOwner       = $cmd{lo};
 $main::JobDateTime    = $cmd{ld};
 $main::PublicBuildJob = $cmd{lp} ? "true" : "false";
 $main::JobName        = $cmd{lj};
 $main::OutputType     = "screen";
 $main::OutputType     = "html" if $cmd{oh};
 $main::OutputType     = "both" if $cmd{ob};
 $main::FinalTarget    = Openmake::File->new( $main::OMEMBEDTYPE );
 $main::Target         = Openmake::File->new( $main::OMEMBEDTYPE );
 return;
} #-- End: sub SetLogging

# end of Openmake::PrePost::SetLogging
1;
