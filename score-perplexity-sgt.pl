use strict;


# Check usage:
if($#ARGV != 0)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names>\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>\n\n";
	print STDERR "Output goes to standard out and <score-names>.new\n";
	exit(1);
}


# Global constants and parameters:
my $COUNT_SNAME = "count";
my $PPSGT_SNAME = "perplexity-SGT";
my $SN_FILE = $ARGV[0];

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

# Accumulator for multiple rules with the same source right-hand side:
my @Rules = ();
my %SrcCounts = ();
my $currTgt = "";
my $totalCount = 0;

# Read rule instances from standard in, one per line:
# NOTE: This assumes rules are sorted by field 4!
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# If different tgt side than previously, write out and score old rules:
	if($tgtRhs ne $currTgt)
	{
		# Write out and score old rules:
		if($totalCount > 0)
		{
			# Calculate entropy over unique source sides:
			my $entropy = 0;
			foreach my $src (keys %SrcCounts)
			{
				my $sgt = $SrcCounts{$src} / $totalCount;
				$entropy = $entropy - ($sgt * log($sgt) / log(2));
			}

			# Add perplexity to each rule with this target side:
			foreach my $r (@Rules)
			{
				print "$r " . (2**$entropy) . "\n";
			}
		}

		# Reset accumulator:
		@Rules = ();
		%SrcCounts = ();
		$currTgt = $tgtRhs;
		$totalCount = 0;
	}

	# Add this rule and its count to the appropriate source-side accumulator:
	push(@Rules, "$type\t$lhs\t$srcRhs\t$tgtRhs\t$aligns\t$scores");
	$SrcCounts{$srcRhs} += $Scores[$countIndex];
	$totalCount += $Scores[$countIndex];
}

# At end, write out final rule still in accumulator:
if($totalCount > 0)
{
	# Calculate entropy over unique source sides:
	my $entropy = 0;
	foreach my $src (keys %SrcCounts)
	{
		my $sgt = $SrcCounts{$src} / $totalCount;
		$entropy = $entropy - ($sgt * log($sgt) / log(2));
	}

	# Add perplexity to each rule with this target side:
	foreach my $r (@Rules)
	{
		print "$r " . (2**$entropy) . "\n";
	}
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $PPSGT_SNAME\n";
close($FILE);
