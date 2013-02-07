use strict;


# Check usage:
if($#ARGV != 1)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> <max-num-terms>\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules> and where <max-num-terms> is the maximum allowable\n";
	print STDERR "number of target-side terminals in <rules>\n\n";
	print STDERR "Output goes to standard out and <score-names>.new\n";
	exit(1);
}


# Global constants and parameters:
my $TCOUNT_SNAME_PREF = "numTTerms";
my $TCOUNT_SNAME_SUFF = "?";
my $SN_FILE = $ARGV[0];
my $MAX_TERMS = $ARGV[1];

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @TgtRhsList = split(/\s+/, $tgtRhs);

	# Compute number of target-side terminals in this rule:
	my $numTerms = 0;
	foreach my $t (@TgtRhsList)
	{
	    $numTerms++ unless($t =~ /^\[.+,\d+\]$/);
	}

	# Turn that into one feature for each possible number of terminals:
	my $newFeats = "";
	foreach my $i (0..$MAX_TERMS)
	{
	    if($numTerms == $i) { $newFeats .= " 1"; }
	    else { $newFeats .= " 0"; }
	}
	print "$type\t$lhs\t$srcRhs\t$tgtRhs\t$aligns\t$scores$newFeats\n";
}

# Update and write out new list of score names:
my $newScoreNames = "";
for my $i (0..$MAX_TERMS)
{
    $newScoreNames .= " $TCOUNT_SNAME_PREF$i$TCOUNT_SNAME_SUFF";
}
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames$newScoreNames\n";
close($FILE);
