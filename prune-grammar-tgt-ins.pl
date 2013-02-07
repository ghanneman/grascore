use strict;


# Check usage:
if($#ARGV < 2)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <parses> <x> [<good-pos>]+\n";
	print STDERR "where <parses> is a set of target-side parse trees from which to infer\n";
	print STDERR "label distributions over terminals.  Rules that insert unaligned target words\n";
	print STDERR "that are more than <x> parsed as one of the <good-pos>s are kept; other\n";
	print STDERR "unaligned target insertion rules are removed.\n\n";
	print STDERR "Output goes to standard out\n";
	exit(1);
}


# Global constants and parameters:
my $PARSE_FILE = $ARGV[0];
my $FRAC_CUTOFF = $ARGV[1];
my %GOOD_LABELS = ();
foreach my $arg (@ARGV[2..$#ARGV])
{
    $GOOD_LABELS{$arg} = 1;
}

# Read parses to build up label distribution for all terminals:
my %GoodCounts = ();
my %TotalCounts = ();
open(my $FILE, $PARSE_FILE) or die "Can't open input file $PARSE_FILE: $!";
while(my $line = <$FILE>)
{
    while($line =~ /\(([^() ]*) ([^()]*)\)/g)
    {
	# Update stats on how often this word was parsed with a "good" label:
	my $label = $1;
	my $word = $2;
	if(exists($GOOD_LABELS{$label})) { $GoodCounts{$word}++; }
	$TotalCounts{$word}++;
    }
}
close($FILE);

# Read rule instances from standard in, one per line:
my $numFiltered = 0;
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @TgtRhsList = split(/\s+/, $tgtRhs);
    my @AlignsList = split(/\s+/, $aligns);

    # Remove all aligned elements from the list of target-side words:
    foreach my $aln (@AlignsList)
    {
	if($aln =~ /^\d+-(\d+)\/\d+$/)
	{
	    my $tgtIndex = $1;
	    $TgtRhsList[$tgtIndex] = "";
	}
    }

    # Among what's left, elements are either nonterminals or unaligned words.
    # Find out if any word fails the "good POS" cutoff:
    my $keep = 1;
    foreach my $elt (@TgtRhsList)
    {
	if(length($elt) > 0 && !($elt =~ /^\[.+,\d+\]$/))
	{
	    my $goodPct = -1; # starting under cutoff means reject unseen words
	    if($TotalCounts{$elt} > 0)
	    { 
		$goodPct = $GoodCounts{$elt} / $TotalCounts{$elt};
	    }
	    if($goodPct < $FRAC_CUTOFF)
	    {
		$keep = 0; 
		print STDERR "Filtered:\t$srcRhs\t$elt\t$goodPct\n";
		$numFiltered++;
		last;
	    }
	    else { print STDERR "Kept:\t$srcRhs\t$elt\t$goodPct\n"; }
	}
    }

    # Print or don't print the rule accordingly:
    if($keep) { print "$line\n"; }
}
