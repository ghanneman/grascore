use strict;


# Check usage:
if($#ARGV != 0)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names>\n";
    print STDERR "where <score-names> is a space-delimited file of score names already\n";
    print STDERR "appearing in <rules>\n\n";
    print STDERR "Output goes to standard out\n";
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

# Accumulator for multiple copies of the same rule with different word aligns:
my $currRule = "";
my @CurrScores = ();
my $totalCount = 0;
my $maxCount = 0;
my @AlignCounts = ();

# Read rule instances from standard in, one per line:
# NOTE: This assumes rules are sorted by fields 1-4!
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @Aligns = split(/\s+/, $aligns);
    my @Scores = split(/\s+/, $scores);

    # If different rule than previous one, write out old rule with counts:
    if("$type\t$lhs\t$srcRhs\t$tgtRhs" ne $currRule)
    {
	# Write out old rule with summed aligns and count:
	if($totalCount > 0)
	{ 
	    my $alignString = "";
	    foreach my $i (0..$#AlignCounts)
	    {
		foreach my $j (0..$#{$AlignCounts[$i]})
		{
		    if($AlignCounts[$i][$j] > 0)
		    {
			$alignString .= "$i-$j/$AlignCounts[$i][$j] ";
		    }
		}
	    }
	    $alignString =~ s/\s+$//;
	    $CurrScores[$countIndex] = $totalCount;
	    print "$currRule\t$alignString\t@CurrScores\n";
	}

	# Reset accumulator:
	$currRule = "$type\t$lhs\t$srcRhs\t$tgtRhs";
	@CurrScores = @Scores;
	$CurrScores[$countIndex] = 0;
	$totalCount = 0;
	$maxCount = 0;
	@AlignCounts = ();
    }

    # Add this rule's word alignment link counts to the accumulator:
    my $addCount = $Scores[$countIndex];
    foreach my $link (@Aligns)
    {
	if($link =~ /^(\d+)-(\d+)$/)
	{
	    $AlignCounts[$1][$2] += $addCount;
	}
	else
	{
	    print STDERR "ERROR:  Malformed alignment link!\n";
	    exit(1);
	}
    }
    $totalCount += $addCount;

    # Check that all other feature scores for the same rule are the same;
    # in case of difference, the highest-count variant wins:
    $Scores[$countIndex] = 0;   # destructive to this rule's count feature
    my $equal = 1;
    if($#Scores != $#CurrScores) { $equal = 0; }
    else
    {
	foreach my $i (0..$#Scores)
	{
	    if($Scores[$i] != $CurrScores[$i]) { $equal = 0; last; }
	}
    }
    if(!$equal)
    {
	print STDERR "WARNING:  Same rule, different features.  ";
	if($addCount > $maxCount)
	{
	    print STDERR "Keeping those of higher count.\n";
	    $maxCount = $addCount;
	    @CurrScores = @Scores;
	}
	else
	{
	    print STDERR "Ignoring those of lower count.\n";
	}
    }
}

# At end, write out final rule still in accumulator:
if($totalCount > 0)
{ 
    my $alignString = "";
    foreach my $i (0..$#AlignCounts)
    {
	foreach my $j (0..$#{$AlignCounts[$i]})
	{
	    if($AlignCounts[$i][$j] > 0)
	    {
		$alignString .= "$i-$j/$AlignCounts[$i][$j] ";
	    }
	}
    }
    $alignString =~ s/\s+$//;
    $CurrScores[$countIndex] = $totalCount;
    print "$currRule\t$alignString\t@CurrScores\n";
}
