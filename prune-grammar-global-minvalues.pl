use strict;


# Check usage:
if($#ARGV < 2 || $#ARGV % 2 != 0)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> [<feat-name> <min-value>]+\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>, and where <feat-name> and <min-value> pairs specify\n";
	print STDERR "the feature scores from <score-names> and their corresponding minimum\n";
	print STDERR "values that rules must have in order to be kept.\n\n";
	print STDERR "Output goes to standard out\n";
	exit(1);
}


# Global constants and parameters:
my $SN_FILE = $ARGV[0];
my @SCORE_VALS = @ARGV[1..$#ARGV];

# Store hash of features to judge rules on, along with their minimum values:
my %ScoreCutoffs = ();
for my $i (1..$#SCORE_VALS)
{
	if($i % 2 == 1) { $ScoreCutoffs{$SCORE_VALS[$i-1]} = $SCORE_VALS[$i]; }
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

# Make sure all score names to judge rules on exist in the rules:
foreach my $sn (keys %ScoreCutoffs)
{
	if(exists($ScoreIndexes{$sn}))
	{
		# Change from score name to score index in list of weights:
		my $weight = $ScoreCutoffs{$sn};
		delete($ScoreCutoffs{$sn});
		$ScoreCutoffs{$ScoreIndexes{$sn}} = $weight;
	}
	else
	{
		# Score name passed on command line not found in rule file:
		print STDERR "ERROR:  Score '$sn' not in rules, or else list of score names wrong.\n";
		exit(1);
	}
}

# Read rule instances from standard in, one per line:
my $totalRules = 0;
my $keptRules = 0;
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# See if this rule's scores pass the cutoff on all required features:
	my $ok = 1;
	foreach my $sindex (keys %ScoreCutoffs)
	{
		if($Scores[$sindex] < $ScoreCutoffs{$sindex})
		{
			$ok = 0;
			last;
		}
	}
	$totalRules++;

	# Print out rule if it passes the cutoffs:
	if($ok)
	{
		$keptRules++;
		print "$line\n";
	}
}
print STDERR "Kept $keptRules out of $totalRules rules.\n";
