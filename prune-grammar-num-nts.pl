use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


# Check usage:
if($#ARGV != 1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <min-num-nts> <max-num-nts>\n";
    print STDERR "where only rules whose right-hand sides have at least <min-num-nts> and at\n";
    print STDERR "most <max-num-nts> non-terminals are kept.\n";
    print STDERR "Output goes to standard out\n";
    exit(1);
}


# Global constants and parameters:
my $MIN_NTS = $ARGV[0];
my $MAX_NTS = $ARGV[1];

# Read rule instances from standard in, one per line:
my $numFiltered = 0;
my $numTotal = 0;
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    $numTotal++;

    # Count how many non-terminals are on the (source) right-hand side:
    my $numNTs = 0;
    foreach my $elt (@SrcRhsList)
    {
	$numNTs++ if($elt =~ /^\[.+,\d+\]$/);
    }

    # Print or don't print the rule accordingly:
    if(($numNTs < $MIN_NTS) || ($numNTs > $MAX_NTS)) { $numFiltered++; }
    else { print "$line\n"; }
}
print STDERR "Removed $numFiltered of $numTotal rules.\n";
