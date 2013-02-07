use strict;


# Check usage:
if($#ARGV != 2)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <sgt-lex> <tgs-lex> <score-names>\n";
	print STDERR "where <sgt-lex> and <tgs-lex> are Moses lexical probability files and\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>\n\n";
	print STDERR "Output goes to standard out and <score-names>.new\n";
	exit(1);
}


# Global constants and parameters:
my $COUNT_SNAME = "count";
my $LSGT_SNAME = "lexical-SGT";
my $LTGS_SNAME = "lexical-TGS";
my $SGT_FILE = $ARGV[0];
my $TGS_FILE = $ARGV[1];
my $SN_FILE = $ARGV[2];

# Read in source-given-target lexical probabilities:
my %SGTProbs = ();
open(my $FILE, $SGT_FILE) or die "Can't open input file $SGT_FILE: $!";
while(my $line = <$FILE>)
{
	# Break apart the line:
	chomp $line;
	my ($src, $tgt, $prob) = split(/\s+/, $line);

	# Add probability to storage:
	$SGTProbs{"$src\t$tgt"} += $prob;
}
close($FILE);

# Read in target-given-source lexical probabilities:
my %TGSProbs = ();
open(my $FILE, $TGS_FILE) or die "Can't open input file $TGS_FILE: $!";
while(my $line = <$FILE>)
{
	# Break apart the line:
	chomp $line;
	my ($tgt, $src, $prob) = split(/\s+/, $line);

	# Add probability to storage:
	$TGSProbs{"$src\t$tgt"} += $prob;
}
close($FILE);

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

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @SrcRhsList = split(/\s+/, $srcRhs);
	my @TgtRhsList = split(/\s+/, $tgtRhs);
	my @AlignsList = split(/\s+/, $aligns);
	my @ScoresList = split(/\s+/, $scores);

	# Compute rule's lex trans probs by accumulating them over align links:
	my @SGTProbsBySrc = ();
	my @TGSProbsByTgt = ();
	my @SrcCounts = ();
	my @TgtCounts = ();
	foreach my $aln (@AlignsList)
	{
		if($aln =~ /^(\d+)-(\d+)\/(\d+)$/)
		{
			# Add probability of this align link, if it's between terminals:
			my $srcIndex = $1;
			my $tgtIndex = $2;
			my $linkCount = $3;
			my $srcWord = $SrcRhsList[$srcIndex];
			my $tgtWord = $TgtRhsList[$tgtIndex];
			if(!($srcWord =~ /^\[.+,\d+\]$/) && !($tgtWord =~ /^\[.+,\d+\]$/))
			{
				$SGTProbsBySrc[$srcIndex] +=
					($SGTProbs{"$srcWord\t$tgtWord"} * $linkCount);
				$TGSProbsByTgt[$tgtIndex] +=
					($TGSProbs{"$srcWord\t$tgtWord"} * $linkCount);
				#check if we just added 0 => looked up something that DNE
				$SrcCounts[$srcIndex] += $linkCount;
				$TgtCounts[$tgtIndex] += $linkCount;
			}
		}
		else
		{
			print STDERR "ERROR:  Malformed alignment link!\n";
			exit(1);
		}
	}

	# Add probabilities for unaligned words translating to NULL:
	for my $i (0..$#SrcRhsList)
	{
		if($SrcCounts[$i] < $ScoresList[$countIndex] &&
		   !($SrcRhsList[$i] =~ /^\[.+,\d+\]$/))
		{
			my $unalCount = $ScoresList[$countIndex] - $SrcCounts[$i];
			$SGTProbsBySrc[$i] +=
				($SGTProbs{"$SrcRhsList[$i]\tNULL"} * $unalCount);
			$TGSProbsByTgt[$#TgtRhsList+1] +=
				($TGSProbs{"$SrcRhsList[$i]\tNULL"} * $unalCount);
			#check if we just added 0 => looked up something that DNE
			$SrcCounts[$i] += $unalCount;
			$TgtCounts[$#TgtRhsList+1] += $unalCount;
		}
	}
	for my $i (0..$#TgtRhsList)
	{
		if($TgtCounts[$i] < $ScoresList[$countIndex] &&
		   !($TgtRhsList[$i] =~ /^\[.+,\d+\]$/))
		{
			my $unalCount = $ScoresList[$countIndex] - $TgtCounts[$i];
			$SGTProbsBySrc[$#SrcRhsList+1] +=
				($SGTProbs{"NULL\t$TgtRhsList[$i]"} * $unalCount);
			$TGSProbsByTgt[$i] +=
				($TGSProbs{"NULL\t$TgtRhsList[$i]"} * $unalCount);
			#check if we just added 0 => looked up something that DNE
			$SrcCounts[$#SrcRhsList+1] += $unalCount;
			$TgtCounts[$i] += $unalCount;
		}
	}

	# Compute final lex probs:
	my $totalSGT = 1;
	for my $i (0..$#SrcCounts)
	{
		if($SrcCounts[$i] > 0)
		{
			$totalSGT *= ($SGTProbsBySrc[$i] / $SrcCounts[$i]);
		}
	}
	my $totalTGS = 1;
	for my $i (0..$#TgtCounts)
	{
		if($TgtCounts[$i] > 0)
		{
			$totalTGS *= ($TGSProbsByTgt[$i] / $TgtCounts[$i]);
		}
	}

	# Write out rule with lexical probabilities:
	print "$line $totalSGT $totalTGS\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $LSGT_SNAME $LTGS_SNAME\n";
close($FILE);


# max($a, $b)
# Returns the maximum of two numbers:
sub max
{
	# Get parameters:
	my $a = shift @_;
	my $b = shift @_;
	if($b > $a) { return $b; }
	else { return $a; }
}
