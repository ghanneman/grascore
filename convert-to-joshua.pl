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
my $SN_FILE = $ARGV[0];

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# See if/where the count feature is stored, and remove it:
my $countIndex = -1;
for my $i (0..$#ScoreNames)
{
	if($ScoreNames[$i] eq $COUNT_SNAME)
	{
		$countIndex = $i;
		last;
	}
}
if($countIndex >= 0)
{
	print STDERR "WARNING:  The count feature will be removed!\n";
	splice(@ScoreNames, $countIndex, 1);
}

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# Write out necessary pieces of the rule in Joshua format:
	print "$lhs ||| $srcRhs ||| $tgtRhs |||";
	if($countIndex >= 0) { splice(@Scores, $countIndex, 1); }
	foreach my $i (0..$#Scores)
	{
		# Joshua uses negative logs for feature values, but don't convert
		# binary, entropy, perplexity, or gain/loss features
		# (because that would take the log of 0):
		my $scoreOut = $Scores[$i];
		unless((substr($ScoreNames[$i], -1) eq "?") ||
			   (substr($ScoreNames[$i], 0, 8) eq "entropy-") ||
			   (substr($ScoreNames[$i], 0, 11) eq "perplexity-") ||
			   (substr($ScoreNames[$i], 0, 5) eq "gain-") ||
			   (substr($ScoreNames[$i], 0, 5) eq "loss-"))
		{
			$scoreOut = -log($scoreOut);
			if($scoreOut eq "-0") { $scoreOut = "0"; }
		}
		# Different conversion for gain/loss features:
		if((substr($ScoreNames[$i], 0, 5) eq "gain-") ||
		   (substr($ScoreNames[$i], 0, 5) eq "loss-"))
		{
			#$scoreOut = -log(1 - $scoreOut);
			$scoreOut = log(70*$scoreOut + 1);
			if($scoreOut eq "-0") { $scoreOut = "0"; }
		}

		print " $scoreOut";
	}
	print "\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames\n";
close($FILE);
