use strict;


# Check usage:
if($#ARGV < 4 || $#ARGV % 2 != 0)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <ignore-tgt> <score-names> <tmp-file> [<feat-name> <weight>]+\n";
	print STDERR "where <ignore-tgt> is 'true' or 'false' for whether or not to ignore the\n";
	print STDERR "tgt RHS, where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules>, where <tmp-file> is a temporary file location, and\n";
	print STDERR "where <feat-name> and <weight> pairs specify the feature scores from\n";
	print STDERR "<score-names> and their corresponding weights used in ranking rules.\n\n";
	print STDERR "Output goes to standard out\n";
	exit(1);
}


# Global constants and parameters:
my $IGNORE_TGT = 0;
if(lc($ARGV[0]) eq "true") { $IGNORE_TGT = 1; }
my $SN_FILE = $ARGV[1];
my $TMP_FILE = $ARGV[2];
my @SCORE_WTS = @ARGV[3..$#ARGV];

# Store hash of scores to weight rules on, along with their weights:
my %ScoreWeights = ();
for my $i (1..$#SCORE_WTS)
{
    if($i % 2 == 1) { $ScoreWeights{$SCORE_WTS[$i-1]} = $SCORE_WTS[$i]; }
}

# Read in list of score names already in rules and where they are:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my %ScoreIndexes = ();
my @ScoreNames = split(/\s+/, $line);
foreach my $i (0..$#ScoreNames)
{
    $ScoreIndexes{$ScoreNames[$i]} = $i;
}

# Make sure all score names to weight rules on exist in the rules:
foreach my $sn (keys %ScoreWeights)
{
    if(exists($ScoreIndexes{$sn}))
    {
	# Change from score name to score index in list of weights:
	my $weight = $ScoreWeights{$sn};
	delete($ScoreWeights{$sn});
	$ScoreWeights{$ScoreIndexes{$sn}} = $weight;
    }
    else
    {
	# Score name passed on command line not found in rule file:
	print STDERR "ERROR:  Score '$sn' not in rules, or else list of score names wrong.\n";
	exit(1);
    }
}

# Keep track of the unary rules seen at any point:
my %UnaryRules = ();  # hash of hashes: outer key = RHS, inner key = unary LHSs
my %LinkScores = ();
my $numUnary = 0;

# Read rule instances from standard in, one per line:
open(my $TMP, "> $TMP_FILE") or die "Can't open output file $TMP_FILE: $!";
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @Scores = split(/\s+/, $scores);

    # Everything gets written out to the temp file too:
    print $TMP "$line\n";

    # We have work to do if this is a unary rule:
    if(($IGNORE_TGT && $srcRhs =~ /^\[(\S+),\d+\]$/) ||
       ($srcRhs =~ /^\[\S+,\d+\]$/ && $tgtRhs =~ /^\[(\S+),\d+\]$/))
    {
	# Get the nonterminals that make up the unary link:
	my $ntRight = $1;
	my $ntLeft = substr($lhs, 1, -1);

	# Compute this rule's weighted score:
	my $score = 0;
	foreach my $sindex (keys %ScoreWeights)
	{
	    $score += ($Scores[$sindex] * $ScoreWeights{$sindex});
	}

	# Add it to list of unary rules:
	$UnaryRules{$ntRight}{$ntLeft}++;
	$LinkScores{"$ntRight $ntLeft"} += $score;
	$numUnary++;
    }
}
close($TMP);
print STDERR "Found a total of $numUnary unary rules.\n";

# Check for cycles via depth-first search from each NT starting point:
my %ToRemove = ();
my %SafeStarts = ();
foreach my $right (keys %UnaryRules)
{
    #print STDERR "===== Checking $right as RHS =====\n";
    UnaryCycleDfs($right);
    $SafeStarts{$right} = 1;
}

# Now read the whole set of rules back from the temp file:
open(my $TMP, $TMP_FILE) or die "Can't open input file $TMP_FILE: $!";
while(my $line = <$TMP>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @Scores = split(/\s+/, $scores);
	
    # Print rule out unless it's a unary rule on the to-remove list:
    if(($IGNORE_TGT && $srcRhs =~ /^\[(\S+),\d+\]$/) ||
       ($srcRhs =~ /^\[\S+,\d+\]$/ && $tgtRhs =~ /^\[(\S+),\d+\]$/))
    {
	my $ntRight = $1;
	my $ntLeft = substr($lhs, 1, -1);
	unless($ToRemove{"$ntRight $ntLeft"}) { print "$line\n"; }
    }
    else { print "$line\n"; }
}
close($TMP);


# UnaryCycleDfs(@History)
#    Uses outside variables %UnaryRules and %SafeStarts.
#    If a unary rule from %UnaryRules can apply on the end of the sequence of
#    nonterminals in @History and produce a nonterminal that was already
#    present in @History, removes the lowest-scoring link from that sequence
#    of NTs as a detected cycle.  The actual cycle-breaking is done by a
#    separate subroutine.
sub UnaryCycleDfs
{
    # Get parameters:
    my @History = @_;
    #print STDERR "Checking @History ___\n";

    # Report a cycle if this step takes us back to an NT we had before:
    for my $i (0..$#History)
    {
	if($UnaryRules{$History[-1]}{$History[$i]})
	{
	    BreakCycle(@History[$i..$#History], $History[$i]);
	}
    }

    # Otherwise, also try to find a cycle after another rule application:
    foreach my $next (keys %{$UnaryRules{$History[-1]}})
    {
	unless($SafeStarts{$next})
	{
	    UnaryCycleDfs(@History, $next);
	}
    }

    # Finally, if no next step, there is no cycle:
    return;
}


# BreakCycle(@Cycle)
#    Uses outside variables %UnaryRules, %ToRemove, $numUnary, and %LinkScores.
#    Takes in a derivable sequence of NTs and removes the adjancent NT pair
#    with the lowest score accoring to %LinkScores.  The removed rule is
#    deleted from %UnaryRules and added to %ToRemove, and the unary rule
#    counter $numUnary is also decremented.
sub BreakCycle
{
    # Get parameters:
    my @Cycle = @_;

    if($#Cycle == 1)
    {
	# Remove an immediate unary cycle:
	print STDERR "Removing $Cycle[0] $Cycle[0] (x$UnaryRules{$Cycle[0]}{$Cycle[0]})\n";
	$ToRemove{"$Cycle[0] $Cycle[0]"} = 1;
	$numUnary -= $UnaryRules{$Cycle[0]}{$Cycle[0]};
	delete($UnaryRules{$Cycle[0]}{$Cycle[0]});
	$LinkScores{"$Cycle[0] $Cycle[0]"} = 0;  ####
    }
    elsif($#Cycle > 1)
    {
	# Remove the lowest-scoring link of a multi-NT cycle:
	my $minScore = 999999999999999999;   # hopefully big enough
	my $minI = "";
	foreach my $i (1..$#Cycle)
	{
	    if($LinkScores{"$Cycle[$i-1] $Cycle[$i]"} < $minScore)
	    {
		$minScore = $LinkScores{"$Cycle[$i-1] $Cycle[$i]"};
		$minI = $i;
	    }
	}
	if($UnaryRules{$Cycle[$minI-1]}{$Cycle[$minI]} > 0)
	{
	    print STDERR "From chain @Cycle removing $Cycle[$minI-1] $Cycle[$minI] (x$UnaryRules{$Cycle[$minI-1]}{$Cycle[$minI]})\n";
	    $ToRemove{"$Cycle[$minI-1] $Cycle[$minI]"} = 1;
	    $numUnary -= $UnaryRules{$Cycle[$minI-1]}{$Cycle[$minI]};
	    delete($UnaryRules{$Cycle[$minI-1]}{$Cycle[$minI]});
	    $LinkScores{"$Cycle[$minI-1] $Cycle[$minI]"} = 0;  ####
	}
    }
    return;
}
