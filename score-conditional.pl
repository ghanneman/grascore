use lib "/home/ghannema/tools/git/grascore";
use ConditionalParamParser;
use ScoreUtils;
use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


# Check usage and get parameters hash:
my %Params = ConditionalParamParser::GetParams(@ARGV);

# Read in list of score names already in rules:
open(my $FILE, $Params{'snfile'}) or
    die "Can't open input file $Params{'snfile'}: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# Make sure the rule count is one of the existing score names:
my $countIndex = -1;
for my $i (0..$#ScoreNames)
{
    if($ScoreNames[$i] eq ScoreUtils::COUNT_SNAME())
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

# Figure out scoring function to call and make sure it exists:
my $scoreFn = $Params{'type'};
$scoreFn =~ s/^(.)/uc($1)/e;
if(!exists(&{"Score$scoreFn"}))
{
    print STDERR "ERROR:  Could not find expected scoring function 'Score$scoreFn'.\n";
    exit(1);
}

# If we're writing a count log, open it:
my $CLOG_FILE;
if($Params{'clogfile'} ne "")
{
    open($CLOG_FILE, "> $Params{'clogfile'}") or
	die "Can't open output count-log file $Params{'clogfile'}: $!";
    binmode($CLOG_FILE, ":utf8");
}

# Accumulator for multiple rules with the same denominator columns:
my %RuleNumerCols = ();
my %NumerColCounts = ();
my $currDenom = "";
my $totalCount = 0;

# Read rule instances from standard in, one per line:
# NOTE: This assumes rules are sorted by the denominator columns!
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my @RuleParts = split(/\t/, $line);
    my @Scores = split(/\s+/, @RuleParts[-1]);

    # Assemble numerator and denominator columns, separated by tabs:
    my $numer = join("\t", @RuleParts[split(/\s+/, $Params{'num'})]);
    my $denom = join("\t", @RuleParts[split(/\s+/, $Params{'denom'})]);

    # If different denominator than previously, write out and score old rules:
    if($denom ne $currDenom)
    {
	# Write out and score old rules:
	if($totalCount > 0)
	{
	    eval "Score$scoreFn" . '(\%RuleNumerCols, \%NumerColCounts, $totalCount);';
	    if($CLOG_FILE) { print $CLOG_FILE "$currDenom\t$totalCount\n"; }
	}

	# Reset accumulator ("undef" seems faster than "= ()"):
	undef %RuleNumerCols;
	undef %NumerColCounts;
	$currDenom = $denom;
	$totalCount = 0;
    }

    # Add this rule and its count to the appropriate numerator accumulator:
    $RuleNumerCols{join("\t", @RuleParts)} = $numer;
    $NumerColCounts{$numer} += $Scores[$countIndex];
    $totalCount += $Scores[$countIndex];
}

# At end, write out final rule still in accumulator:
if($totalCount > 0)
{
    eval "Score$scoreFn" . '(\%RuleNumerCols, \%NumerColCounts, $totalCount);';
    if($CLOG_FILE) { print $CLOG_FILE "$currDenom\t$totalCount\n"; }
}
if($CLOG_FILE) { close($CLOG_FILE); }

# Write out new list of score names:
open($FILE, "> $Params{'snfile'}") or die "Can't open output file $Params{'snfile'}: $!";
print $FILE "@ScoreNames $Params{'name'}\n";
close($FILE);


# SUBROUTINES FOR DIFFERENT TYPES OF SCORING: ################################


# ScoreProb(\%RulesToNumerCols, \%NumerColsToCounts, $denomCount):
#    Takes as input (1) a mapping from full rules all sharing the same
#    denominator value to their numerator values, (2) a mapping from numerator
#    values to numerator counts, and (3) the total count of the relevant
#    denominator.  Prints out each of the rules found plus its corresponding
#    conditional probability.
sub ScoreProb
{
    # Get parameters (Hungarian "h" denotes hash reference):
    my $hRulesToNumerCols = shift @_;
    my $hNumerColsToCounts = shift @_;
    my $denomCount = shift @_;

    # Now compute conditional probability for each rule:
    foreach my $r (keys %{$hRulesToNumerCols})
    {
	my $prob = ${$hNumerColsToCounts}{${$hRulesToNumerCols}{$r}} / $denomCount;
	print "$r $prob\n";
    }
}


# ScoreCounts(\%RulesToNumerCols, \%NumerColsToCounts, $denomCount):
#    Takes as input (1) a mapping from full rules all sharing the same
#    denominator value to their numerator values, (2) a mapping from numerator
#    values to numerator counts, and (3) the total count of the relevant
#    denominator.  Prints out each of the rules found plus the numerator and
#    denominator counts, in the form "num/denom".
sub ScoreCounts
{
    # Get parameters (Hungarian "h" denotes hash reference):
    my $hRulesToNumerCols = shift @_;
    my $hNumerColsToCounts = shift @_;
    my $denomCount = shift @_;

    # Now compute numerator and denominator counts for each rule:
    foreach my $r (keys %{$hRulesToNumerCols})
    {
	my $num = ${$hNumerColsToCounts}{${$hRulesToNumerCols}{$r}};
	print "$r $num/$denomCount\n";
    }
}


# ScoreEntropy(\%RulesToNumerCols, \%NumerColsToCounts, $denomCount):
#    Takes as input (1) a mapping from full rules all sharing the same
#    denominator value to their numerator values, (2) a mapping from numerator
#    values to numerator counts, and (3) the total count of the relevant
#    denominator.  Prints out each of the rules found plus the entropy over
#    the probabilities for this denominator.
sub ScoreEntropy
{
    # Get parameters (Hungarian "h" denotes hash reference):
    my $hRulesToNumerCols = shift @_;
    my $hNumerColsToCounts = shift @_;
    my $denomCount = shift @_;

    # Now compute entropy over the unique numerators:
    my $entropy = 0;
    foreach my $numer (keys %{$hNumerColsToCounts})
    {
	my $prob = ${$hNumerColsToCounts}{$numer} / $totalCount;
	$entropy = $entropy - ($prob * log($prob) / log(2));
    }

    # Add it to each rule with this denominator:
    foreach my $r (keys %{$hRulesToNumerCols})
    {
	print "$r $entropy\n";
    }
}


# ScorePerp(\%RulesToNumerCols, \%NumerColsToCounts, $denomCount):
#    Takes as input (1) a mapping from full rules all sharing the same
#    denominator value to their numerator values, (2) a mapping from numerator
#    values to numerator counts, and (3) the total count of the relevant
#    denominator.  Prints out each of the rules found plus the perplexity over
#    the probabilities for this denominator.
sub ScorePerp
{
    # Get parameters (Hungarian "h" denotes hash reference):
    my $hRulesToNumerCols = shift @_;
    my $hNumerColsToCounts = shift @_;
    my $denomCount = shift @_;

    # Now compute entropy over the unique numerators:
    my $entropy = 0;
    foreach my $numer (keys %{$hNumerColsToCounts})
    {
	my $prob = ${$hNumerColsToCounts}{$numer} / $totalCount;
	$entropy = $entropy - ($prob * log($prob) / log(2));
    }

    # Add perplexity to each rule with this denominator:
    foreach my $r (keys %{$hRulesToNumerCols})
    {
	print "$r " . (2**$entropy) . "\n";
    }
}
