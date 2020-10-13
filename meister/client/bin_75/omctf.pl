$rel = $ARGV[0];
$binaries = $ARGV[1];

open(FP,">ctf.rsp");
print FP "connect cu042\n";
print FP "go $rel upload $binaries\n";
close(FP);

print "ctf --script ctf.rsp\n";
print `ctf --script ctf.rsp`;
