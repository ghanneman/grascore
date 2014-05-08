use lib "/home/ghannema/tools/git/grascore";
use ScoreUtils;
use strict;


# Check usage:
if($#ARGV != -1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0\n";
    print STDERR "Output goes to standard out\n";
    exit(1);
}

# Read rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);

    # Divide LHS label into source and target sides:
    my ($srcLhs, $tgtLhs) = ScoreUtils::ReadNonterminal($lhs);

    # Replace nonterminals in the source RHS with their source-only verions:
    foreach my $elt (@SrcRhsList)
    {
	if($elt =~ /^\[(.+),(\d+)\]$/)
	{
	    my $nt = $1;
	    my $ind = $2;
	    my ($src, $tgt) = ScoreUtils::ReadNonterminal("[$nt]");
	    $elt = "[$src,$ind]";
	}
    }

    # Replace nonterminals in the target RHS with their target-only verions:
    foreach my $elt (@TgtRhsList)
    {
	if($elt =~ /^\[(.+),(\d+)\]$/)
	{
	    my $nt = $1;
	    my $ind = $2;
	    my ($src, $tgt) = ScoreUtils::ReadNonterminal("[$nt]");
	    $elt = "[$tgt,$ind]";
	}
    }

    # Write out expanded seven-column format:
    print "$type\t$srcLhs\t$tgtLhs\t@SrcRhsList\t@TgtRhsList\t$aligns\t$scores\n";
}
