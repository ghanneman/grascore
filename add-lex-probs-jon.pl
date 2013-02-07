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
my $LSGT_SNAME = "lexical-SGT";
my $LTGS_SNAME = "lexical-TGS";
my $PROB_MIN = 0.000000001;
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
	my @UsedSrc = ();
	my @UsedTgt = ();
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
				$UsedSrc[$srcIndex]++;
				$UsedTgt[$tgtIndex]++;
			}
		}
		else
		{
			print STDERR "ERROR:  Malformed alignment link!\n";
			exit(1);
		}
	}

	# Scale total probability for each word by how often it was aligned:
	foreach my $i (0..$#SrcRhsList)
	{
		if($SrcCounts[$i] > 0)
		{
			$SGTProbsBySrc[$i] = $SGTProbsBySrc[$i] / $SrcCounts[$i];
		}
	}
	foreach my $i (0..$#TgtRhsList)
	{
		if($TgtCounts[$i] > 0)
		{
			$TGSProbsByTgt[$i] = $TGSProbsByTgt[$i] / $TgtCounts[$i];
		}
	}

	# Add probabilities for always-unaligned words translating to NULL:
	for my $i (0..$#SrcRhsList)
	{
		if($UsedSrc[$i] < 1 && !($SrcRhsList[$i] =~ /^\[.+,\d+\]$/))
		{
			$SGTProbsBySrc[$i] += $SGTProbs{"$SrcRhsList[$i]\tNULL"};
			$TGSProbsByTgt[$#TgtRhsList+1] += $TGSProbs{"$SrcRhsList[$i]\tNULL"};
			#check if we just added 0 => looked up something that DNE
			$UsedSrc[$i]++;
			$UsedTgt[$#TgtRhsList+1]++;
		}
	}
	for my $i (0..$#TgtRhsList)
	{
		if($UsedTgt[$i] < 1 && !($TgtRhsList[$i] =~ /^\[.+,\d+\]$/))
		{
			$SGTProbsBySrc[$#SrcRhsList+1] += $SGTProbs{"NULL\t$TgtRhsList[$i]"};
			$TGSProbsByTgt[$i] += $TGSProbs{"NULL\t$TgtRhsList[$i]"};
			#check if we just added 0 => looked up something that DNE
			$UsedSrc[$#SrcRhsList+1]++;
			$UsedTgt[$i]++;
		}
	}

	# Compute final lex probs according to the Moses formula:
	my $totalSGT = 1;
	for my $i (0..$#UsedSrc)
	{
		if($UsedSrc[$i] > 0)
		{
			#$totalSGT *= (1 / $UsedSrc[$i] * $SGTProbsBySrc[$i]);
			$totalSGT *= $SGTProbsBySrc[$i];
		}
	}
	my $totalTGS = 1;
	for my $i (0..$#UsedTgt)
	{
		if($UsedTgt[$i] > 0)
		{
			#$totalTGS *= (1 / $UsedTgt[$i] * $TGSProbsByTgt[$i]);
			$totalTGS *= $TGSProbsByTgt[$i];
		}
	}

	# If we got a 0 probability, back off to set minimum
	if($totalSGT == 0.0)
	{
		print STDERR "WARNING:  SGT probability of 0!  Faking it...\n";
		$totalSGT = $PROB_MIN;
	}
	if($totalTGS == 0.0)
	{
		print STDERR "WARNING:  TGS probability of 0!  Faking it...\n";
		$totalTGS = $PROB_MIN;
	}

	# Write out rule with lexical probabilities:
	print "$line $totalSGT $totalTGS\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $LSGT_SNAME $LTGS_SNAME\n";
close($FILE);
