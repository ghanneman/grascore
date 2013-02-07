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
my $ABS_SNAME = "abstract?";
my $SN_FILE = $ARGV[0];

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
	my @srcRhsList = split(/\s+/, $srcRhs);
	my @tgtRhsList = split(/\s+/, $tgtRhs);

	# Check if everything on the right-hand side is a nonterminal:
	my $allNT = 1;
	foreach my $elt (@srcRhsList)
	{
		if(!($elt =~ /^\[.+,\d+\]$/))
		{
			$allNT = 0;
			last;
		}
	}
	if($allNT)
	{
		foreach my $elt (@tgtRhsList)
		{
			if(!($elt =~ /^\[.+,\d+\]$/))
			{
				$allNT = 0;
				last;
			}
		}
	}

	# Add fully-abstract feature:
	print "$line $allNT\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $ABS_SNAME\n";
close($FILE);
