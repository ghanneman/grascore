use strict;


# Check usage:
if($#ARGV < 0 || $#ARGV > 1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <input-type> [<score-names>]\n";
    print STDERR "where <input-type> is either 'newrl' for input coming right from new rule\n";
    print STDERR "learner or 'tab' for input in the grascore tab-separated format.  For 'tab'\n";
    print STDERR "format, <score-names> must be a space-delimited file of score names already\n";
    print STDERR "appearing in <rules>.\n";
    print STDERR "Output goes to standard out\n";
    exit(1);
}

# Get and check parameters:
my $TAB_INPUT = -1;
my $DELIM = "";
if(lc($ARGV[0]) eq "newrl") { $TAB_INPUT = 0; $DELIM = ' \|\|\| '; }
elsif(lc($ARGV[0]) eq "tab") { $TAB_INPUT = 1; $DELIM = '\t'; }
else
{
    print STDERR "ERROR: Invalid value '$ARGV[0]' for param <input-type>!\n";
    print STDERR "Use 'newrl' or 'tab' only!\n";
    exit(1);
}
if(($TAB_INPUT == 1) && ($#ARGV != 1))
{
    print STDERR "ERROR: Parameter <score-names> must be provided if <input-type> is 'tab'!\n";
    exit(1);
}
if(($TAB_INPUT == 0) && ($#ARGV != 0))
{
    print STDERR "Parameters after <input-type> are being ignored!\n";
}

# For tab format, read in score names and make sure the count is included:
my $SN_FILE = "";
my @ScoreNames = ();
my $COUNT_SNAME = "count";
my $countIndex = -1;
if($TAB_INPUT == 1)
{
    # Read in list of score names already in rules:
    $SN_FILE = $ARGV[1];
    open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
    my $line = <$FILE>;
    close($FILE);
    chomp $line;
    @ScoreNames = split(/\s+/, $line);

    # Make sure the rule count is one of the existing score names:
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
	print STDERR "ERROR: Input rules don't have count field, or score names file incorrect.\n";
	exit(1);
    }
}


# Read rules/instances from standard in, one per line:
my %NTPairCounts = ();
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    # If newrl input, then $scores is actually node types ("OO OV VV"):
    chomp $line;
    next if($line =~ /^Sentence/);
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) =
	split(/$DELIM/, $line);

    # newrl instances have count 1; tab rules include their counts:
    my $count = 1;
    if($TAB_INPUT == 1)
    {
	my @Scores = split(/\s+/, $scores);
	$count = $Scores[$countIndex];
    }

    # Figure out how to divide LHS label:
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

    # Add count to hash:
    if($src ne "" && $tgt ne "")
    {
	$NTPairCounts{"$src\t$tgt"} += $count;
    }
    else { print STDERR "Malformed label: '$lhs'\n"; }
}

# Now write out all the NT pair counts:
foreach my $k (keys %NTPairCounts)
{
    print "$k\t$NTPairCounts{$k}\n";
}
