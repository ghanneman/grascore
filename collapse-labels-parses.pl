#!/usr/local/bin/perl

use strict;
use bytes;


# Check usage:
if($#ARGV != 0)
{
	print STDERR "Usage: cat <parse-trees> | \\ \n";
	print STDERR "       perl $0 <label-map-file>\n";
	print STDERR "Output goes to standard out.\n";
	exit;
}

# Create label map:
my %LabelMap = ();
open(my $MFILE, $ARGV[0]) or die "Can't open input label map file $ARGV[0]: $!";
while(my $line = <$MFILE>)
{
	my ($full, $mapped) = split(/\s+/, $line);
	$LabelMap{$full} = $mapped;
}

# Process parse-tree file and change labels:
while(my $line = <STDIN>)
{
	# Tokenize line:
	chomp $line;
	my @Tokens = split(/\s+/, $line);

	# Nonterminals appear after an open paren and last up until a space:
	foreach my $tok (@Tokens)
	{
		if($tok =~ /^(.*)\(([^()]+)$/)
		{
			# Replace nonterminal label if it appears in map:
			my $prefix = $1;
			my $label = $2;
			if(exists($LabelMap{$label}))
			{
				$label = $LabelMap{$label};
				$tok = "$prefix($label";
			}
		}
	}

	# Write out the parse, now possibly with modified labels:
	print "@Tokens\n";
}
