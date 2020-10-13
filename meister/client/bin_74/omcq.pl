use CQPerlExt;

# Env vars:
#	CQ_USER	- user id to logon to ClearQuest with
#	CQ_PASSWORD - password to logon to ClearQuest with
#	CQ_DBNAME	- ClearQuest Database Name
#	CQ_DBSET	- Connection string to the ClearQuest DB

# Cmd Line Vars:
#	State - "Submit","Resubmit","Retire","Complete","Failure"
#	Build Job
#	Build Label
#	Build Number
#	Build Log URL
#	

if ($ARGV[0] eq "" || $ARGV[0] eq "-?")
{
print "Usage: omcq.pl <State> <Build Job> <Build Label> <Build Number> <Log URL> <DateTime>\n";
exit(0); 
}

$State      = $ARGV[0];
$BuildJob	= $ARGV[1];
$BuildLabel = $ARGV[2];
$BuildNumber= $ARGV[3];
$BuildLogURL= $ARGV[4];
$BuildDateTime= $ARGV[5];

$releasename = "$BuildLabel - $BuildNumber";

$recfile = $BuildDateTime;
$recfile =~ s/:/_/g;
$recfile =~ s/./_/g;

# Create a connection to CQ.
my $Session = CQSession::Build();
my $CQ_Password = $ENV{'CQ_PASSWORD'} || "";	
my $DB_Set = $ENV{'CQ_DBSET'} || "";

print("Connecting To ClearQuest using the following Credentials:\n");
print("USER:$ENV{'CQ_USER'}\n");
# print("PASSWORD:$CQ_Password\n");
print("DBNAME:$ENV{'CQ_DBNAME'}\n");
print("DBSET:$DB_Set\n");
$Session->UserLogon($ENV{'CQ_USER'},$CQ_Password,$ENV{'CQ_DBNAME'},$DB_Set);


open(FP,"<$recfile.cq");
@lines = <FP>;
close(FP);

if ($lines[0] ne "")
{
 $recid = $lines[0];
 $recid =~ s/\n//g;
}

my $BuildRec;
my $action = "Created";

if ($recid eq "")
{
 $BuildRec = $Session->BuildEntity("btbuild");
 $BuildRec->SetFieldValue("start_datetime",genTimeStamp());
}
else
{
 $BuildRec = $Session->GetEntity("btbuild",$recid);
 $Session->EditEntity($BuildRec,"modify");
 $action = "Updated";
 if ($State =~ /Complete|Failure/i)
 {
  $BuildRec->SetFieldValue("end_datetime",genTimeStamp());
 }
}

$BuildRec->SetFieldValue("build_system_id",$BuildJob);
$BuildRec->SetFieldValue("releasename",$releasename);
$BuildRec->SetFieldValue("build_system_url",$BuildLogURL);
#$BuildRec->SetFieldValue("buildlog",);
my $RecordId = $BuildRec->GetDisplayName();

open(FP,">$recfile.cq");
print FP "$RecordId\n";
close(FP);

print "$action $RecordId\n";	
# Validate and Commit.

eval { $RetVal = $BuildRec->Validate(); }; 
if ($@){ print "Exception: '$@'\n";}
if ($RetVal eq "") 
{
 eval{$BuildRec->Commit();}
} 
else 
{
 exit(1); 
}
 if ($State =~ /Complete|Failure/i)
 {
  $Session->EditEntity($BuildRec,$State);
  $BuildRec->Validate();
  $BuildRec->Commit();
 }
CQSession::Unbuild($Session);

sub genTimeStamp 
{
 my @Time =localtime();
 return sprintf("%d/%d/%d %d:%02d:%02d %s",($Time[4]+1),$Time[3],($Time[5]+1900),($Time[2] > 12 ? ($Time[2]-12) : ($Time[2] == 0 ? 12 : $Time[2])),$Time[1],$Time[0],($Time[2] > 11 ? "P" : "A"));
}
