use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


# Check usage:
if($#ARGV != 0)
{
    print STDERR "Usage: cat <scored-rules-tab-format> | \\ \n";
    print STDERR "       perl $0 <key-rules>\n";
    print STDERR "Rules from standard in that match, in terms of unlabled rule pattern, any\n";
    print STDERR "rule in <key-rules> are written out.  Output goes to standard out.\n";
    exit;
}

# For example, the rule
#     G    [PP::PP]    de [D::DT,1] session    of [D::DT,1] session    ...
# has the pattern "de [X,1] session \t of [X,1] session":

# Read key rules from file, anonymize their labels, and store their patterns:
my %KeyPatterns = ();
open(my $FILE, $ARGV[0]) or die "Can't open input file $ARGV[0]: $!";
binmode($FILE, ":utf8");
while(my $line = <$FILE>)
{
    # Break apart line:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);

    #"Unlabel" the right-hand side by turning all nonterminals to "X":
    foreach my $i (0..$#SrcRhsList)
    {
	if($SrcRhsList[$i] =~ /^\[.+,(\d+)\]$/)
	{
	    my $coindex = $1;
	    $SrcRhsList[$i] = "[X,$coindex]";
	}
    }
    foreach my $i (0..$#TgtRhsList)
    {
	if($TgtRhsList[$i] =~ /^\[.+,(\d+)\]$/)
	{
	    my $coindex = $1;
	    $TgtRhsList[$i] = "[X,$coindex]";
	}
    }

    # Add to list of saved patterns:
    $KeyPatterns{"@SrcRhsList\t@TgtRhsList"}++;
}
close($FILE);
print STDERR "Stored " . (keys %KeyPatterns) . " rule patterns...\n";

# Now we read the scored grammar from standard in, looking for rules whose
# patterns match one we've saved from the key rules:
my $lineNum = 0;
my $keptNum = 0;
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    $lineNum++;
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);

    # Figure out this rule's pattern:
    foreach my $i (0..$#SrcRhsList)
    {
	if($SrcRhsList[$i] =~ /^\[.+,(\d+)\]$/)
	{
	    my $coindex = $1;
	    $SrcRhsList[$i] = "[X,$coindex]";
	}
    }
    foreach my $i (0..$#TgtRhsList)
    {
	if($TgtRhsList[$i] =~ /^\[.+,(\d+)\]$/)
	{
	    my $coindex = $1;
	    $TgtRhsList[$i] = "[X,$coindex]";
	}
    }

    # See if this rule's pattern appeared in the key rules:
    if($KeyPatterns{"@SrcRhsList\t@TgtRhsList"} > 0)
    {
	print "$line\n";
	$keptNum++;
    }
}
print STDERR "Kept $keptNum of $lineNum rules.\n";
