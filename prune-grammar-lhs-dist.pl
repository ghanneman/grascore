use strict;


# Check usage:
if($#ARGV != 1)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> <lhs-dist-amt>\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>, and where <lhs-dist-amt> is the fraction of\n";
	print STDERR "the LHS label distribution to keep for each unique RHS.  The least\n";
	print STDERR "frequent LHS labels will be removed.\n\n";
	print STDERR "Output goes to standard out\n";
	exit(1);
}


# Global constants and parameters:
my $COUNT_SNAME = "count";
my $SN_FILE = $ARGV[0];
my $PCT = $ARGV[1];
if($PCT < 0 || $PCT > 1)
{
	print STDERR "ERROR:  Given fraction $PCT is not between 0 and 1!\n";
	exit(1);
}

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# Make sure the rule count is one of the existing score names:
my $countIndex = -1;
for my $i (0..$#ScoreNames)
{
	if($ScoreNames[$i] eq $COUNT_SNAME)
	{
		$countIndex = $i;
		last;
	}
}
if($countIndex == -1)
{
	print STDERR "ERROR:  Input rules don't have count field, or score names file incorrect.\n";
	exit(1);
}

# Accumulator for multiple rules with the same right-hand side:
my %RulesByCount = ();        # hash of arrays: key = score, value = rules
my $currRhs = "";
my $totalCount = 0;

# Read rule instances from standard in, one per line:
# NOTE: This assumes rules are sorted by fields 3-4!
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# If different RHS than previously, write out most frequent old rules:
	if("$srcRhs\t$tgtRhs" ne $currRhs)
	{
		# Write out the most frequent rules, up to the max dist fraction:
		if($totalCount > 0)
		{
			# Break ties by letting all tied rules through:
			my $desiredCount = int($PCT * $totalCount);
			if($desiredCount == 0) { $desiredCount = 1; }
			my $writtenCount = 0;
			foreach my $count (sort {$b <=> $a} keys %RulesByCount)
			{
				foreach my $rule (@{$RulesByCount{$count}})
				{
					print "$rule\n";
					$writtenCount += $count;
				}
				last if($writtenCount >= $desiredCount);
			}
		}

		# Reset accumulator:
		%RulesByCount = ();
		$currRhs = "$srcRhs\t$tgtRhs";
		$totalCount = 0;
	}

	# Add this rule and its count to the accumulator:
	my $count = $Scores[$countIndex];
	push(@{$RulesByCount{$count}}, $line);
	$totalCount += $count;
}

# At end, write out top-scoring rules still in accumulator:
if($totalCount > 0)
{
	# Be strict in determining count: no more than $PCT:
	my $desiredCount = int($PCT * $totalCount);
	if($desiredCount == 0) { $desiredCount = 1; }
	my $writtenCount = 0;
	
	# Be loose in breaking ties: let all tied rules through:
	foreach my $count (sort {$b <=> $a} keys %RulesByCount)
	{
		foreach my $rule (@{$RulesByCount{$count}})
		{
			print "$rule\n";
			$writtenCount += $count;
		}
		last if($writtenCount >= $desiredCount);
	}
}
