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
if($#ScoreNames > 0)
{
	print STDERR "WARNING:  This step will remove all rule scores other than the count.\n";
}

# Accumulator for multiple copies of the same rule with different word aligns:
my $currRule = "";
my $totalCount = 0;
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
			print "$currRule\t$alignString\t$totalCount\n";
		}

		# Reset accumulator:
		$currRule = "$type\t$lhs\t$srcRhs\t$tgtRhs";
		$totalCount = 0;
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
	print "$currRule\t$alignString\t$totalCount\n";
}

# Write out new list of score names, which is just the count:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "$COUNT_SNAME\n";
close($FILE);
