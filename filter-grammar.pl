#!/usr/local/bin/perl

use strict;


# Check usage:
if($#ARGV != 1)
{
    print STDERR "Usage:\n";
	print STDERR "    cat <rules> | perl $0 <test-set> <max-length>\n";
	print STDERR "where <max-length> is the longest phrase length to check against <test-set>\n\n";
	print STDERR "Output goes to standard out.\n";
    exit;
}

# Global constants and parameters:
my $TS_FILE = $ARGV[0];
my $N_LEN = $ARGV[1];

# Load n-gram vocabulary from test set:
my %TestSetVoc = ();
open(my $FILE, $TS_FILE) or die "Can't open input file $TS_FILE: $!";
while(my $line = <$FILE>)
{
    # Collect n-gram counts from each test sentence:
    chomp $line;
    my @Words = split(/\s+/, $line);
	foreach my $n (0..$N_LEN-1)
	{
		foreach my $i ($n..$#Words)
		{
			my @NGram = @Words[$i-$n..$i];
			$TestSetVoc{"@NGram"}++;
		}
	}
}
print STDERR "Got " . keys(%TestSetVoc) . " test set n-grams.\n";

# Read (possibly hierarchical) grammar rules on standard in:
while(my $line = <STDIN>)
{
	# Break rule line into fields -- we mostly want the source right-hand side:
	chomp $line;
	my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
	my @SrcRhsList = split(/\s+/, $srcRhs);

    # Check if each terminal n-gram on the source RHS is in test set:
    # Do this by breaking the source words into contiguous terminal phrases:
    my $ok = 1;
    my @Phrase = ();
    foreach my $item (@SrcRhsList)
    {
		if($item =~ /^\[.*,\d+\]$/)
		{
			# Got a non-terminal: check previous terminal phrase, if any:
			if($#Phrase >= 0)
			{
				$ok = CheckIfAllMatch(@Phrase);
				last if(!$ok);
				@Phrase = ();
			}
		}
		else
		{
			# Got a terminal: add it to current phrase:
			push(@Phrase, $item);
		}
    }
    if($#Phrase >= 0) { $ok = CheckIfAllMatch(@Phrase); }

    # Print the whole rule line if all terminals matched vocab:
    if($ok)
    {
		print "$line\n";
    }
}


# CheckIfAllMatch(@Words) -- uses global $N_LEN and %TestSetVoc
#     Checks all the words of the provided phrase to see if all the phrase's
#     n-grams up to length $N_LEN (from above) were seen in the test set
#     (%TestSetVoc, from above).  Returns 1 if yes and 0 if not.
sub CheckIfAllMatch
{
    # Get parameter:
    my @Words = @_;

	# Check each n-gram in the given phrase against the test set:
	foreach my $n (0..$N_LEN-1)
	{
		foreach my $i ($n..$#Words)
		{
			my @NGram = @Words[$i-$n..$i];
			if(!$TestSetVoc{"@NGram"}) { return 0; }
		}
	}

    # Everything made it:
    return 1;
}
