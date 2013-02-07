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
my $GAIN_PREFIX = "gain-";
my $LOSS_PREFIX = "loss-";
my $GAIN_END = "-gain?";
my $LOSS_END = "-loss?";
my $SN_FILE = $ARGV[0];

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# Find indexes of gain and loss scores, and convert names to binary names:
my @GainIndexes = ();
my @LossIndexes = ();
for my $i (0..$#ScoreNames)
{
	if($ScoreNames[$i] =~ /^$GAIN_PREFIX/)
	{
		push(@GainIndexes, $i);
		$ScoreNames[$i] =~ s/^$GAIN_PREFIX(.+)$/\1$GAIN_END/;
	}
	if($ScoreNames[$i] =~ /^$LOSS_PREFIX/)
	{
		push(@LossIndexes, $i);
		$ScoreNames[$i] =~ s/^$LOSS_PREFIX(.+)$/\1$LOSS_END/;
	}
}
if($#GainIndexes == -1 && $#LossIndexes == -1)
{
	print STDERR "WARNING:  There are no gain or loss scores in the input, or score names file\n";
	print STDERR "incorrect.  This script is wasting your time.\n";
}

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# Change the gain/loss scores of this rule into binary features:
	foreach my $i (@GainIndexes, @LossIndexes)
	{
		if($Scores[$i] > 0) { $Scores[$i] = 1; }
	}
	print "$type\t$lhs\t$srcRhs\t$tgtRhs\t$aligns\t@Scores\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames\n";
close($FILE);
