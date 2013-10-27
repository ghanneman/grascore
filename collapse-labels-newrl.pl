#!/usr/local/bin/perl

use strict;
use bytes;


# Check usage:
if($#ARGV != 1)
{
    print STDERR "Usage: cat <new-rule-learner-output> | \\ \n";
    print STDERR "       perl $0 <src-pos-map-file> <tgt-pos-map-file>\n";
    print STDERR "Output goes to standard out.\n";
    exit;
}

# Create source label map:
my %SrcLabelMap = ();
open(my $SPFILE, $ARGV[0]) or die "Can't open input source label map file $ARGV[0]: $!";
while(my $line = <$SPFILE>)
{
    my ($full, $mapped) = split(/\s+/, $line);
    $SrcLabelMap{$full} = $mapped;
}
close($SPFILE);

# Create target label map:
my %TgtLabelMap = ();
open(my $TPFILE, $ARGV[1]) or die "Can't open input target label map file $ARGV[1]: $!";
while(my $line = <$TPFILE>)
{
    my ($full, $mapped) = split(/\s+/, $line);
    $TgtLabelMap{$full} = $mapped;
}
close($TPFILE);

# Process rule-instance file and change labels:
#G ||| [PP::PP] ||| de [D::DT,1] session ||| of [D::DT,1] session ||| 0-0 1-1 2-2 ||| OO OO
while(my $line = <STDIN>)
{
    # Break apart line:
    chomp $line;
    next if(substr($line, 0, 9) eq "Sentence ");
    my ($type, $lhs, $srcRhs, $tgtRhs, $aligns, $nodeTypes) =
	split(/ \|\|\| /, $line);
    my @SrcRhsList = split(/\s+/, $srcRhs);
    my @TgtRhsList = split(/\s+/, $tgtRhs);
    my ($srcLhs, $tgtLhs) = ParseJoshuaPOSPair($lhs);

    # TEMP PRINT BLOCK:
    #print "Got [$srcLhs]:" . ":[$tgtLhs] -> [@srcRhsList]::[@tgtRhsList]\n";

    # Replace labels on the left-hand side:
    if(exists($SrcLabelMap{$srcLhs})) { $srcLhs = $SrcLabelMap{$srcLhs}; }
    if(exists($TgtLabelMap{$tgtLhs})) { $tgtLhs = $TgtLabelMap{$tgtLhs}; }
    
    # Replace labels on the right-hand side:
    foreach my $i (0..$#SrcRhsList)
    {
	if($SrcRhsList[$i] =~ /^\[(.+),(\d+)\]$/)
	{
	    my $posPair = $1;
	    my $coindex = $2;
	    my ($src, $tgt) = ParseJoshuaPOSPair($posPair);
	    if(exists($SrcLabelMap{$src})) { $src = $SrcLabelMap{$src}; }
	    if(exists($TgtLabelMap{$tgt})) { $tgt = $TgtLabelMap{$tgt}; }
	    $SrcRhsList[$i] = "[$src:" . ":$tgt,$coindex]";
	}
    }
    foreach my $i (0..$#TgtRhsList)
    {
	if($TgtRhsList[$i] =~ /^\[(.+),(\d+)\]$/)
	{
	    my $posPair = $1;
	    my $coindex = $2;
	    my ($src, $tgt) = ParseJoshuaPOSPair($posPair);
	    if(exists($SrcLabelMap{$src})) { $src = $SrcLabelMap{$src}; }
	    if(exists($TgtLabelMap{$tgt})) { $tgt = $TgtLabelMap{$tgt}; }
	    $TgtRhsList[$i] = "[$src:" . ":$tgt,$coindex]";
	}
    }
    
    # Reprint line:
    print "$type\t[$srcLhs:" . ":$tgtLhs]\t@SrcRhsList\t@TgtRhsList\t$aligns\t1\n";
}


# ParseJoshuaPOSPair($pair)
#    Extracts the source and target side from a Joshua non-terminal and
#    returns them.  Handles things like "[PUNCT:::]" with or without the
#    braces.  The LHS may be something like "[::::]" or "[PUNCT:::]" or
#    "[:::PUNCT]" in addition to "[N::NNS]".
sub ParseJoshuaPOSPair
{
    # Get parameters:
    my $lhs = shift @_;
    chomp $lhs;
    #print "Got [$lhs]\n";

    my $srcLHS = "";
    my $tgtLHS = "";

    # Cases with four colons:
    if($lhs =~ /^\[?(.*:)::(:[^\]]*)\]?$/)
    {
	($srcLHS, $tgtLHS) = ($1, $2);
    }

    # Cases with three colons:
    elsif($lhs =~ /^\[?(.*):::([^\]]*)\]?$/)
    {
	my ($left, $right) = ($1, $2);
	if($left eq "") { ($srcLHS, $tgtLHS) = (":", $right); }
	elsif($right eq "") { ($srcLHS, $tgtLHS) = ($left, ":"); }
	elsif(substr($left, -1) eq "-" && substr($left, -5) ne "-LRB-" &&
	      substr($left, -5) ne "-RRB-")
	{
	    ($srcLHS, $tgtLHS) = ($left . ":", $right);
	}
	elsif(substr($right, 0, 1) eq "-" && substr($right, 0, 5) ne "-LRB-" &&
	      substr($right, 0, 5) ne "-RRB-")
	{
	    ($srcLHS, $tgtLHS) = ($left, ":" . $right);
	}
    }

    # Cases with two colons:
    elsif($lhs =~ /^\[?(.+)::([^\]]+)\]?$/)
    {
	($srcLHS, $tgtLHS) = ($1, $2);
    }

    # If not any of the above, the label is probably malformed:
    else
    {
	print STDERR "WARNING: Likely malformed label: '$lhs'\n";
    }

    #print "Returning [$srcLHS] and [$tgtLHS]\n";
    return ($srcLHS, $tgtLHS);
}
