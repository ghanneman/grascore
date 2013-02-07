use strict;


# Check usage:
if($#ARGV != 1)
{
	print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <score-names> <glue-file>\n";
	print STDERR "where <score-names> is a space-delimited file of score names already\n";
	print STDERR "appearing in <rules> and where <glue-file> is where the newly created glue\n";
	print STDERR "grammar should be written in Joshua format\n\n";
	print STDERR "Output goes to standard out, <score-names>.new, and <glue-file>\n";
	exit(1);
}


# Global constants and parameters:
my $GLUE_SNAME = "glue?";
my $SN_FILE = $ARGV[0];
my $GLUE_FILE = $ARGV[1];

# Read in list of score names already in rules:
open(my $FILE, $SN_FILE) or die "Can't open input file $SN_FILE: $!";
my $line = <$FILE>;
close($FILE);
chomp $line;
my @ScoreNames = split(/\s+/, $line);

# Read rule instances from standard in, one per line:
my %LhsSeen = ();
while(my $line = <STDIN>)
{
	# Break rule line into fields:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);

	# Add left-hand side to list of LHS labels seen:
	$LhsSeen{substr($lhs, 1, -1)}++;

	# Add glue rule feature (assumed negative):
	print "$line 0\n";
}

# Write out glue grammar to separate file:
#open glue file
open(my $FILE, "> $GLUE_FILE") or die "Can't open output file $GLUE_FILE: $!";
my $glueFeats = "";
foreach my $i (0..$#ScoreNames) { $glueFeats .= "0 "; }
$glueFeats .= "1";
print $FILE "[S] ||| [S,1] [X,2] ||| [S,1] [X,2] ||| $glueFeats\n";
print $FILE "[S] ||| [X,1] ||| [X,1] ||| $glueFeats\n";
foreach my $nt (keys %LhsSeen)
{
	print $FILE "[S] ||| [S,1] [$nt,2] ||| [S,1] [$nt,2] ||| $glueFeats\n";
	print $FILE "[S] ||| [$nt,1] ||| [$nt,1] ||| $glueFeats\n";
}
close($FILE);

# Write out new list of score names:
open(my $FILE, "> $SN_FILE.new") or die "Can't open output file $SN_FILE.new: $!";
print $FILE "@ScoreNames $GLUE_SNAME\n";
close($FILE);
