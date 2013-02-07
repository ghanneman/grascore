#!/usr/local/bin/perl

use strict;


# Check usage:
if($#ARGV != 2)
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | perl $0 <test-set-src> <test-set-tgt> <max-length>\n";
    print STDERR "where <max-length> is the longest phrase length to check against n-grams in\n";
    print STDERR "<test-set-src> and <test-set-tgt>\n\n";
    print STDERR "Output goes to standard out.\n";
    exit;
}

# Global constants and parameters:
my $TS_SRC_FILE = $ARGV[0];
my $TS_TGT_FILE = $ARGV[1];
my $N_LEN = $ARGV[2];

# Load source-side n-gram vocabulary from test set:
my %SrcTestVoc = ();
open(my $FILE, $TS_SRC_FILE) or die "Can't open input file $TS_SRC_FILE: $!";
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
	    $SrcTestVoc{"@NGram"}++;
	}
    }
}
print STDERR "Got " . keys(%SrcTestVoc) . " source test set n-grams.\n";

# Load target-side n-gram vocabulary from test set:
my %TgtTestVoc = ();
open(my $FILE, $TS_TGT_FILE) or die "Can't open input file $TS_TGT_FILE: $!";
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
	    $TgtTestVoc{"@NGram"}++;
	}
    }
}
print STDERR "Got " . keys(%TgtTestVoc) . " target test set n-grams.\n";

# Read (possibly hierarchical) grammar rules on standard in:
while(my $line = <STDIN>)
{
    # Break rule line into fields -- we mostly want the right-hand sides:
    chomp $line;
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $scores) = split(/\t/, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);

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
		$ok = CheckIfAllSrcMatch(@Phrase);
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
    if($#Phrase >= 0) { $ok = CheckIfAllSrcMatch(@Phrase); }

    # Carry out the same check on the rule's target side:
    if($ok)
    {
	@Phrase = ();
	foreach my $item (@TgtRhsList)
	{
	    if($item =~ /^\[.*,\d+\]$/)
	    {
		# Got a non-terminal: check previous terminal phrase, if any:
		if($#Phrase >= 0)
		{
		    $ok = CheckIfAllTgtMatch(@Phrase);
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
	if($#Phrase >= 0) { $ok = CheckIfAllTgtMatch(@Phrase); }
    }

    # Print the whole rule line if all terminals matched vocab:
    if($ok)
    {
	print "$line\n";
    }
}


# CheckIfAllSrcMatch(@Words) -- uses global $N_LEN and %SrcTestVoc
#     Checks all the words of the provided phrase to see if all the phrase's
#     n-grams up to length $N_LEN (from above) were seen in the source side
#     of the test set (%SrcTestVoc, from above).
#     Returns 1 if yes and 0 if not.
sub CheckIfAllSrcMatch
{
    # Get parameter:
    my @Words = @_;
    
    # Check each n-gram in the given phrase against the test set:
    foreach my $n (0..$N_LEN-1)
    {
	foreach my $i ($n..$#Words)
	{
	    my @NGram = @Words[$i-$n..$i];
	    if(!$SrcTestVoc{"@NGram"}) { return 0; }
	}
    }
    
    # Everything made it:
    return 1;
}


# CheckIfAllTgtMatch(@Words) -- uses global $N_LEN and %TgtTestVoc
#     Checks all the words of the provided phrase to see if all the phrase's
#     n-grams up to length $N_LEN (from above) were seen in the source side
#     of the test set (%TgtTestVoc, from above).
#     Returns 1 if yes and 0 if not.
sub CheckIfAllTgtMatch
{
    # Get parameter:
    my @Words = @_;
    
    # Check each n-gram in the given phrase against the test set:
    foreach my $n (0..$N_LEN-1)
    {
	foreach my $i ($n..$#Words)
	{
	    my @NGram = @Words[$i-$n..$i];
	    if(!$TgtTestVoc{"@NGram"}) { return 0; }
	}
    }
    
    # Everything made it:
    return 1;
}
