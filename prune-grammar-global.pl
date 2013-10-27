use lib "/home/ghannema/tools/git/grascore";
use ScoreUtils;
use strict;


# Check usage:
if($#ARGV < 4 || $#ARGV % 2 != 0)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> <tmp-file> <max-rules> [<feat-name> <weight>]+\n";
    print STDERR "where <score-names> is a space-delimited file of score names already\n";
    print STDERR "appearing in <rules>, where <tmp-file> is a temporary file location, where\n";
    print STDERR "<max-rules> is the max number of rules from the whole grammar to allow, and\n";
    print STDERR "where <feat-name> and <weight> pairs specify the feature scores from\n";
    print STDERR "<score-names> and their corresponding weights used in ranking rules.\n\n";
    print STDERR "Output goes to standard out\n";
    exit(1);
}


# Global constants and parameters:
my $SN_FILE = $ARGV[0];
my $TMP_FILE = $ARGV[1];
my $MAX_RULES = $ARGV[2];
my @SCORE_WTS = @ARGV[3..$#ARGV];

# Store hash of scores to weight rules on, along with their weights:
my %ScoreWeights = ();
for my $i (1..$#SCORE_WTS)
{
    if($i % 2 == 1) { $ScoreWeights{$SCORE_WTS[$i-1]} = $SCORE_WTS[$i]; }
}

# Read in list of score names already in rules and where they are:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my %ScoreIndexes = ();
my @ScoreNames = split(/\s+/, $line);
foreach my $i (0..$#ScoreNames)
{
    $ScoreIndexes{$ScoreNames[$i]} = $i;
}

# Make sure all score names to weight rules on exist in the rules:
foreach my $sn (keys %ScoreWeights)
{
    if(exists($ScoreIndexes{$sn}))
    {
	# Change from score name to score index in list of weights:
	my $weight = $ScoreWeights{$sn};
	delete($ScoreWeights{$sn});
	$ScoreWeights{$ScoreIndexes{$sn}} = $weight;
    }
    else
    {
	# Score name passed on command line not found in rule file:
	print STDERR "ERROR:  Score '$sn' not in rules, or else list of score names wrong.\n";
	exit(1);
    }
}

# Keep track of the highest scores seen at any point:
my @WeightedScores = ();
my $totalRules = 0;

# Read rule instances from standard in, one per line:
open(my $TMP, "> $TMP_FILE") or die "Can't open output file $TMP_FILE: $!";
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @Scores = split(/\s+/, $scores);

    # Everything gets written out to the temp file too:
    print $TMP "$line\n";

    # Add this rule's weighted score to the list of top scores:
    my $score = 0;
    foreach my $sindex (keys %ScoreWeights)
    {
	$score += ($Scores[$sindex] * $ScoreWeights{$sindex});
    }
    push(@WeightedScores, $score);
    $totalRules++;

    # Periodically sort and trim the list of top scores:
    if($totalRules % (2 * $MAX_RULES) == 0)
    {
	my @Tmp = sort {$b <=> $a} @WeightedScores;
	@WeightedScores = @Tmp[0..$MAX_RULES-1];
	@Tmp = ();
    }
}
close($TMP);

# At end, sort and trim once more to find the minimum qualifying score:
my @Tmp = sort {$b <=> $a} @WeightedScores;
@WeightedScores = @Tmp[0..ScoreUtils::Min($#Tmp, $MAX_RULES-1)];
@Tmp = ();
my $cutoff = $WeightedScores[-1];
print STDERR "Weighted score cutoff = $cutoff\n";

# Now read the whole set of rules back from the temp file:
open(my $TMP, $TMP_FILE) or die "Can't open input file $TMP_FILE: $!";
while(my $line = <$TMP>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# Calculate this rule's weighted score:
	my $score = 0;
	foreach my $sindex (keys %ScoreWeights)
	{
		$score += ($Scores[$sindex] * $ScoreWeights{$sindex});
	}
	
	# Print rule out if its score passes the minimum cutoff:
	if($score >= $cutoff)
	{
		print "$line\n";
	}
}
close($TMP);
