use strict;


# Check usage:
if($#ARGV < 3 || $#ARGV % 2 != 1)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> <max-tgts> [<feat-name> <weight>]+\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>, where <max-tgts> is the max number of target sides per\n";
	print STDERR "source side, and where <feat-name> and <weight> pairs specify the feature\n";
	print STDERR "scores from <score-names> and their corresponding weights used in ranking\n";
	print STDERR "variant target sides for the same source.\n\n";
	print STDERR "Output goes to standard out\n";
	exit(1);
}


# Global constants and parameters:
my $SN_FILE = $ARGV[0];
my $MAX_TGTS = $ARGV[1];
my @SCORE_WTS = @ARGV[2..$#ARGV];

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

# Accumulator for multiple rules with the same source right-hand side:
my %WeightedScores = ();        # hash of arrays: key = score, value = rules
my $currSrc = "";
my $totalRules = 0;

# Read rule instances from standard in, one per line:
# NOTE: This assumes rules are sorted by field 3!
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# If different src side than previously, write out top-scoring old rules:
	if($srcRhs ne $currSrc)
	{
		# Write out and score old rules:
		if($totalRules > 0)
		{
			if($totalRules <= $MAX_TGTS)
			{
				# If fewer rules than maximum, just write them all out:
				foreach my $score (keys %WeightedScores)
				{
					foreach my $rule (@{$WeightedScores{$score}})
					{
						print "$rule\n";
					}
				}
			}
			else
			{
				# Otherwise, keep only the ones with highest score:
				my $numOut = 0;
				foreach my $score (sort {$b <=> $a} keys %WeightedScores)
				{
					last if($numOut > 0 &&
							$numOut + $#{$WeightedScores{$score}} >= $MAX_TGTS);
					foreach my $rule (@{$WeightedScores{$score}})
					{
						print "$rule\n";
						$numOut++;
					}
				}
			}
		}

		# Reset accumulator:
		%WeightedScores = ();
		$currSrc = $srcRhs;
		$totalRules = 0;
	}

	# Add this rule and its weighted score to the accumulator:
	my $score = 0;
	foreach my $sindex (keys %ScoreWeights)
	{
		$score += ($Scores[$sindex] * $ScoreWeights{$sindex});
	}
	push(@{$WeightedScores{$score}}, $line);
	$totalRules++;
}

# At end, write out top-scoring rules still in accumulator:
if($totalRules > 0)
{
	if($totalRules <= $MAX_TGTS)
	{
		# If fewer rules than maximum, just write them all out:
		foreach my $score (keys %WeightedScores)
		{
			foreach my $rule (@{$WeightedScores{$score}})
			{
				print "$rule\n";
			}
		}
	}
	else
	{
		# Otherwise, keep only the ones with highest score:
		my $numOut = 0;
		foreach my $score (sort {$b <=> $a} keys %WeightedScores)
		{
			last if($numOut > 0 &&
					$numOut + $#{$WeightedScores{$score}} >= $MAX_TGTS);
			foreach my $rule (@{$WeightedScores{$score}})
			{
				print "$rule\n";
				$numOut++;
			}
		}
	}
}
