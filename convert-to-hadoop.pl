use strict;


# Check usage:
if($#ARGV != 0)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names>\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>\n\n";
	print STDERR "Output goes to standard out, <score-names>.new, and suffStatNames\n";
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

# See if/where the count feature is stored:
my $countIndex = -1;
for my $i (0..$#ScoreNames)
{
	if($ScoreNames[$i] eq $COUNT_SNAME)
	{
		$countIndex = $i;
		last;
	}
}

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @Scores = split(/\s+/, $scores);

	# Write out necessary pieces of the rule in Jon's Hadoop format:
	if($type eq "L") { $type = "P"; }
	print "$type ||| $lhs ||| $srcRhs ||| $tgtRhs |||";
	foreach my $i (0..$#Scores)
	{
		# Jon uses negative logs for feature values, but don't convert
		# binary features (because that would take the log of 0):
		my $scoreOut = $Scores[$i];
		unless(substr($ScoreNames[$i], -1) eq "?")
		{
			$scoreOut = -log($scoreOut);
			if($scoreOut eq "-0") { $scoreOut = "0"; }
		}
		unless($i == $countIndex) { print " $scoreOut"; }
	}
	print " ||| $aligns ||| ";
	if($countIndex >= 0) { print "$Scores[$countIndex]"; }
	print "\n";
}

# Write out new list of score names:
if($countIndex >= 0) { splice(@ScoreNames, $countIndex, 1); }
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames\n";
close($FILE);

# Write out new list of sufficient statistic names:
open($FILE, "> suffStatNames") or
	die "Can't open output file suffStatNames: $!";
print $FILE "$COUNT_SNAME\n";
close($FILE);
