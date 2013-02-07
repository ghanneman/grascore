use strict;


# Check usage:
if($#ARGV != 1)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> <tmp-file>\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules> and where <tmp-file> is the file to write intermediate\n";
	print STDERR "results for sorting to.\n\n";
	print STDERR "Output goes to standard out and <score-names>.new\n";
	exit(1);
}


# Global constants and parameters:
my $COUNT_SNAME = "count";
my $GSRC_SNAME = "gain-src loss-src";
my $SN_FILE = $ARGV[0];
my $TMP_FILE = $ARGV[1];

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


# Open temp file for rules with unlabeled source sides added:
open(my $FILE, "> $TMP_FILE") or die "Can't open output file $TMP_FILE: $!";

# Read rule instances from standard in, one per line, and write to temp file:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @SrcRhsList = split(/\s+/, $srcRhs);

	# Anonymize nonterminals by calling everything X:
	foreach my $srcWord (@SrcRhsList)
	{
		if($srcWord =~ /^\[.+,(\d+)\]$/)
		{
			$srcWord = "[X,$1]";
		}
	}

	# Write out rule with unlabeled source side as additional field:
	print $FILE "$type\t$lhs\t@SrcRhsList\t$srcRhs\t$tgtRhs\t$aligns\t$scores\n";
}
close($FILE);

# Sort rules in temp file by unlabeled source side:
`LC_ALL=C sort -t '\t' -k 3 $TMP_FILE > $TMP_FILE.sort`;


# Accumulator for multiple rules with same unlabeled source right-hand side:
my %RuleSrcSides = ();
my %SrcCounts = ();
my $currUlSrc = "";
my $totalCount = 0;

# Read rule instances from sorted temp file, one per line:
# NOTE: Assumes rules are sorted by field 3 and include unlabeled src sides!
open(my $FILE, "$TMP_FILE.sort") or
	die "Can't open input file $TMP_FILE.sort: $!";
while(my $line = <$FILE>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $ulSrc, $srcRhs, $tgtRhs, $aligns, $scores) =
		split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# If different unlabeled source right-hand side than previously,
	# write out and score old rules:
	if($ulSrc ne $currUlSrc)
	{
		# Write out and score old rules:
		if($totalCount > 0)
		{
			# Calculate entropy over unique source sides:
			my $entropy = 0;
			foreach my $l (keys %SrcCounts)
			{
				my $prob = $SrcCounts{$l} / $totalCount;
				$entropy = $entropy - ($prob * log($prob) / log(2));
			}

			# Add the difference between actual prob and expected prob to
			# each rule, expressed as one gain and one loss feature:
			my $baseProb = 2 ** (-$entropy);
			foreach my $r (keys %RuleSrcSides)
			{
				my $psrc = $SrcCounts{$RuleSrcSides{$r}} / $totalCount;
				my $diff = $psrc - $baseProb;
				if($diff > 0) { print "$r $diff 0\n"; }
				elsif($diff < 0) { print "$r 0 " . (-$diff) . "\n"; }
				else { print "$r 0 0\n"; }
			}
		}

		# Reset accumulator:
		%RuleSrcSides = ();
		%SrcCounts = ();
		$currUlSrc = $ulSrc;
		$totalCount = 0;
	}

	# Add this rule and its count to the appropriate source-side accumulator:
	$RuleSrcSides{"$type\t$lhs\t$srcRhs\t$tgtRhs\t$aligns\t$scores"} = $srcRhs;
	$SrcCounts{$srcRhs} += $Scores[$countIndex];
	$totalCount += $Scores[$countIndex];
}
close($FILE);

# At end, write out final rule still in accumulator:
if($totalCount > 0)
{
	# Calculate entropy over unique source sides:
	my $entropy = 0;
	foreach my $l (keys %SrcCounts)
	{
		my $prob = $SrcCounts{$l} / $totalCount;
		$entropy = $entropy - ($prob * log($prob) / log(2));
	}

	# Add the difference between actual prob and expected prob to
	# each rule, expressed as one gain and one loss feature:
	my $baseProb = 2 ** (-$entropy);
	foreach my $r (keys %RuleSrcSides)
	{
		my $psrc = $SrcCounts{$RuleSrcSides{$r}} / $totalCount;
		my $diff = $psrc - $baseProb;
		if($diff > 0) { print "$r $diff 0\n"; }
		elsif($diff < 0) { print "$r 0 " . (-$diff) . "\n"; }
		else { print "$r 0 0\n"; }
	}
}

# Write out new list of score names:
open(my $FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $GSRC_SNAME\n";
close($FILE);
