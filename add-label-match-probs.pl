use strict;


# Check usage:
if($#ARGV != 1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <nt-pair-counts> <score-names>\n";
    print STDERR "where <nt-pair-counts> contains joint nonterminal pair counts (i.e. from\n";
    print STDERR "get-nt-pair-counts.pl) and where <score-names> is a space-delimited file of\n";
    print STDERR "score names already appearing in <rules>\n\n";
    print STDERR "Output goes to standard out and <score-names>.new\n";
    exit(1);
}

# Global constants and parameters:
my $PROB_MIN = 0.000000001;
my $LMSGT_SNAME = "lhs-SGT";
my $LMTGS_SNAME = "lhs-TGS";
my $PAIRS_FILE = $ARGV[0];
my $SN_FILE = $ARGV[1];

# Read in left-hand-side label pair counts:
my %JointCounts = ();
my %SrcCounts = ();
my %TgtCounts = ();
open(my $FILE, $PAIRS_FILE) or die "Can't open input file $PAIRS_FILE: $!";
while(my $line = <$FILE>)
{
    # Break apart the line:
    chomp $line;
    my ($src, $tgt, $count) = split(/\t/, $line);

    # Add counts to storage:
    $JointCounts{"$src\t$tgt"} += $count;
    $SrcCounts{$src} += $count;
    $TgtCounts{$tgt} += $count;
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

    # Figure out how to divide LHS label:
    # This is also in get-nt-pair-counts.pl; would make a nice library fn!
    my $src = "";
    my $tgt = "";
    if($lhs =~ /^\[(.*:)::(:.*)\]$/) # four colons
    {
	($src, $tgt) = ($1, $2);
    }
    elsif($lhs =~ /^\[(.*):::(.*)\]$/) # three colons
    {
	my ($left, $right) = ($1, $2);
	if($left eq "") { ($src, $tgt) = (":", $right); }
	elsif($right eq "") { ($src, $tgt) = ($left, ":"); }
	elsif(substr($left, -1) eq "-" && substr($left, -5) ne "-LRB-" &&
	      substr($left, -5) ne "-RRB-")
	{
	    ($src, $tgt) = ($left . ":", $right);
	}
	elsif(substr($right, 0, 1) eq "-" && substr($right, 0, 5) ne "-LRB-" &&
	      substr($right, 0, 5) ne "-RRB-")
	{
	    ($src, $tgt) = ($left, ":" . $right);
	}
    }
    elsif($lhs =~ /^\[(.+)::(.+)\]$/) # two colons
    {
	($src, $tgt) = ($1, $2);
    }

    # Compute LHS label-match proabilities:
    my $sgtProb = $PROB_MIN;
    my $tgsProb = $PROB_MIN;
    if($src ne "" && $tgt ne "")
    {
	$sgtProb = $JointCounts{"$src\t$tgt"} / $TgtCounts{$tgt};
	$tgsProb = $JointCounts{"$src\t$tgt"} / $SrcCounts{$src};
    }
    else { print STDERR "Malformed label: '$lhs'.  Faking it!\n"; }

    # Write out rule with label-match probabilities:
    print "$line $sgtProb $tgsProb\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $LMSGT_SNAME $LMTGS_SNAME\n";
close($FILE);
