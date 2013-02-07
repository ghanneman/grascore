use strict;


# Check usage:
if($#ARGV != 1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <take-neg-log> <score-names>\n";
    print STDERR "where <take-neg-log> is 'true' or 'false' for whether the conversion should\n";
    print STDERR "take the negative ln of most features or not, and where <score-names> is a\n";
    print STDERR "space-delimited file of score names already appearing in <rules>\n\n";
    print STDERR "Output goes to standard out and <score-names>.new\n";
    exit(1);
}


# Global constants and parameters:
my $COUNT_SNAME = "count";
my $TAKE_LOG = 0;
if(lc($ARGV[0]) eq "true") { $TAKE_LOG = 1; }
my $SN_FILE = $ARGV[1];

# Not taking the negative log could impact decoder behavior:
if(!$TAKE_LOG)
{
    print STDERR "WARNING:  You've asked for features to not be converted to log space!\n";
}

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# See if/where the count feature is stored, and warn it will come out negative:
my $countIndex = -1;
for my $i (0..$#ScoreNames)
{
    if($ScoreNames[$i] eq $COUNT_SNAME)
    {
	$countIndex = $i;
	last;
    }
}
if($countIndex >= 0 && $TAKE_LOG)
{
    print STDERR "WARNING:  The count feature will come out negative in negative log space!\n";
}

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);
    my @Scores = split(/\s+/, $scores);

    # cdec doesn't allow "," in nonterminal names:
    $lhs =~ s/,/COM/g;
    foreach my $tok (@SrcRhsList)
    {
	if($tok =~ /^\[(.+),(\d+)\]$/)
	{
	    my $nt = $1;
	    my $ind = $2;
	    $nt =~ s/,/COM/g;
	    $tok = "[$nt,$ind]";
	}
    }
    foreach my $tok (@TgtRhsList)
    {
	if($tok =~ /^\[(.+),(\d+)\]$/)
	{
	    my $nt = $1;
	    my $ind = $2;
	    $nt =~ s/,/COM/g;
	    $tok = "[$nt,$ind]";
	}
    }

    # Write out necessary pieces of the rule in cdec format:
    print "$lhs ||| @SrcRhsList ||| @TgtRhsList |||";
    foreach my $i (0..$#Scores)
    {
	# cdec uses negative logs for feature values, but don't convert
	# binary, entropy, or gain/loss features
	# (because that would take the log of 0):
	my $scoreOut = $Scores[$i];
	unless((!$TAKE_LOG) ||
	       (substr($ScoreNames[$i], -1) eq "?") ||
	       (substr($ScoreNames[$i], 0, 8) eq "entropy-") ||
	       (substr($ScoreNames[$i], 0, 5) eq "gain-") ||
	       (substr($ScoreNames[$i], 0, 5) eq "loss-"))
	{
	    $scoreOut = -log($scoreOut);
	    if($scoreOut eq "-0") { $scoreOut = "0"; }
	}
	# Different conversion for gain/loss features:
	if($TAKE_LOG &&
	   ((substr($ScoreNames[$i], 0, 5) eq "gain-") ||
	    (substr($ScoreNames[$i], 0, 5) eq "loss-")))
	{
	    #$scoreOut = -log(1 - $scoreOut);
	    $scoreOut = log(70*$scoreOut + 1);
	    if($scoreOut eq "-0") { $scoreOut = "0"; }
	}
	
	print " $ScoreNames[$i]=$scoreOut";
    }
    $aligns =~ s/(\d+-\d+)\/\d+/\1/g;
    print " ||| $aligns\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames\n";
close($FILE);
