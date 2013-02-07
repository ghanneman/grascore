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
my $LEX_SNAME = "lexical?";
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

	# Check if everything on the right-hand side is a terminal:
	my $allLex = 1;
	foreach my $elt (@srcRhsList)
	{
		if($elt =~ /^\[.+,\d+\]$/)
		{
			$allLex = 0;
			last;
		}
	}
	if($allLex)
	{
		foreach my $elt (@tgtRhsList)
		{
			if($elt =~ /^\[.+,\d+\]$/)
			{
				$allLex = 0;
				last;
			}
		}
	}

	# Add fully-lexicalized feature:
	print "$line $allLex\n";
}

# Write out new list of score names:
open($FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $LEX_SNAME\n";
close($FILE);
