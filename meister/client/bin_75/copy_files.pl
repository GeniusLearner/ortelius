#ADG 06.28.2007
#|-SAB 08.04.2008, error checking, pod

=head1 Name

copy_files.pl

=head1 Synopsis

copy_files.pl <file1>[,<file2>,<file3>,...] <dir1>[,<dir2>,<dir3>,...]

=head1 Description

Works in conjunction with the Copy Files activity descriptor to perform
copies of one or many files to one or many destination directories. Is cross
platform for Unix and Windows. Runs xcopy commands for Windows and cp commands
for Unix.

=cut

my $source_args = 0;
my $dest_args   = 0;
my @source_files;
my @dest_dirs;
my $OS = $^O;
my $rc = 0;

#build up the source files and dest dirs arrays from the args passed in
foreach (@ARGV) {
	if ( $_ =~ /-source/ ) {
		$source_args = 1;
		next;
	}
	if ( $source_args == 1 ) {
		@source_files = split( /,/, $_ );
		$source_args = 0;
		next;
	}
	if ( $_ =~ /-dest/ ) {
		$dest_args = 1;
		next;
	}
	if ( $dest_args == 1 ) {
		@dest_dirs = split( /,/, $_ );
		$dest_args = 0;
		next;
	}
}

#create copy commands
foreach $source_file (@source_files) {
	print "Copying $source_file...\n";
	unless ( -f $source_file ) {
		print "ERROR: $source_file does not exist!";
		$rc++;
		next;
	}
	foreach $dest_dir (@dest_dirs) {
		print "... to $dest_dir\n";

		unless ( -d $dest_dir ) {
			print "ERROR: $dest_dir does not exist!";
			$rc++;
			next;
		}
		if ( $OS =~ /win/i ) {
			print `xcopy /Y /F \"$source_file\" \"$dest_dir\"`;
			$rc += $?;
		}
		else                           #assume it is a unix copy
		{
			print `cp -fv \"$source_file\" \"$dest_dir\"`;
			$rc += $?;
		}
	}
}

exit $rc;
