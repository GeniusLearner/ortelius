package Crypt::Blowfish::Openmake;

BEGIN
{

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.00';
$VERSION = eval $VERSION;

my %module = (
              '5.008' => "Openmake58",
              '5.006' => "Openmake56"
             );

my $ver = substr( $], 0, 5);
my $module = $module{$ver} || '5.008';
my $require = "Crypt/Blowfish/$module";
my $isa     = $require;
$isa =~ s|/|::|g;
$require .= ".pm";

print "$require $isa\n";
require $require;

foreach my $sub ( qw(
                      blocksize keysize min_keysize max_keysize
                     	new encrypt decrypt
                     )
                 )
{
 print __PACKAGE__, "::$sub -> $isa", "::", $sub, "\n";
 eval<<EOF;
sub ${sub}
{
 return ${isa}::${sub}( \@_);
}
EOF

 }
}
1;

