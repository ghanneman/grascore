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
my $RARITY_SNAME = "rarity";
my $SN_FILE = $ARGV[0];

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# Make sure the rarity feature is one of the existing score names:
my $rarityIndex = -1;
for my $i (0..$#ScoreNames)
{
	if($ScoreNames[$i] eq $RARITY_SNAME)
	{
		$rarityIndex = $i;
		last;
	}
}
if($rarityIndex == -1)
{
	print STDERR "ERROR:  Input rules don't have rarity field, or score names file incorrect.\n";
	exit(1);
}
print STDERR "WARNING:  This step will replace the rarity field.\n";

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# Replace exponential rarity score with count and reprint rule:
	my $ct = 1 / log($Scores[$rarityIndex]*exp(1) - $Scores[$rarityIndex] + 1);
	$ct = int($ct + 0.5);
	$Scores[$rarityIndex] = $ct;
	print "$type\t$lhs\t$srcRhs\t$tgtRhs\t$aligns\t@Scores\n";
}

# Update and write out new list of score names:
$ScoreNames[$rarityIndex] = $COUNT_SNAME;
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames\n";
close($FILE);
