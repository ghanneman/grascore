#!/usr/local/bin/perl

use strict;


# Check usage:
if($#ARGV != 0)
{
    print STDERR "Usage:\n";
	print STDERR "    cat <rules-lines> | perl $0 <src-only>\n;";
    print STDERR "where <src-only> is 'true' if abstract is meant to apply only to the source.\n";
    print STDERR "Use 'false' if abstract means both source and target sides must qualify.\n\n";
	print STDERR "Output goes to standard out.\n";
    exit;
}

# Get parameter:
my $SRC_ONLY = 0;
if(lc($ARGV[0]) eq "true") { $SRC_ONLY = 1; }

# Process rules one per line from standard in and change types:
while(my $line = <STDIN>)
{
	# Break apart line:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @srcRhsList = split(/\s+/, $srcRhs);
	my @tgtRhsList = split(/\s+/, $tgtRhs);

	# Check if everything's NTs on the right-hand side:
	my $allNT = 1;
	foreach my $i (0..$#srcRhsList)
	{
		if(!($srcRhsList[$i] =~ /^\[.+,\d+\]$/))
		{
		    $allNT = 0;
		    last;
		}
	}
	if($allNT && !$SRC_ONLY)
	{
	    foreach my $i (0..$#tgtRhsList)
	    {
			if(!($tgtRhsList[$i] =~ /^\[.+,\d+\]$/))
			{
				$allNT = 0;
				last;
			}
	    }
	}
	
	# If all non-terminals, change rule type:
	if($allNT) { $type = "A"; }

	# Reprint line:
	print "$type\t$lhs\t$srcRhs\t$tgtRhs\t$aligns\t$scores\n";
}
