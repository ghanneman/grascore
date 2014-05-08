use strict;


# Check usage:
if($#ARGV != -1)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <wide-rules> | perl $0\n";
    print STDERR "where <wide-rules> is in the wider seven-column grammar format\n";
    print STDERR "Output goes to standard out\n";
    exit(1);
}

# Read wide rule instances from standard in, one per line:
while(my $line = <STDIN>)
{
    # Break rule line into fields:
    chomp $line;
    my ($type, $srcLhs, $tgtLhs, $srcRhs, $tgtRhs, $aligns, $scores) =
	split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);

    # Combine source and target sides of LHS label:
    my $lhs = "[$srcLhs:" . ":$tgtLhs]";

    # Build combined names of RHS labels, one side at a time;
    # By the time we get to the target side, we can drop in combined labels:
    my @NtNames = ();
    foreach my $elt (@SrcRhsList)
    {
	if($elt =~ /^\[(.+),(\d+)\]$/)
	{
	    my $nt = $1;
	    my $ind = $2;
	    $NtNames[$ind] = $nt . "::";
	}
    }
    foreach my $elt (@TgtRhsList)
    {
	if($elt =~ /^\[(.+),(\d+)\]$/)
	{
	    my $nt = $1;
	    my $ind = $2;
	    $NtNames[$ind] .= $nt;
	    # Now we know the full name; just insert on target side:
	    $elt = "[$NtNames[$ind],$ind]";
	}
    }

    # Now update the source labels as well:
    foreach my $elt (@SrcRhsList)
    {
	if($elt =~ /^\[.+,(\d+)\]$/)
	{
	    my $ind = $1;
	    $elt = "[$NtNames[$ind],$ind]";
	}
    }

    # Write out narrow (regular) six-column format:
    print "$type\t$lhs\t@SrcRhsList\t@TgtRhsList\t$aligns\t$scores\n";
}
