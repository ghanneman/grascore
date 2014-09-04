package ScoreUtils;
@EXPORT = qw(COUNT_SNAME Min Max ReadNonterminal);

use strict;


# Name (from score-names file) for rule count:
# NOTE: This is terrible, but apparently variables aren't accessible outside
# the module -- at least not with "use strict" on...
sub COUNT_SNAME
{
    return "count";
}


# $min = Min($item1, $item2, ...)
#    Returns the numerical minimum from an arbitrarily long parameter list.
sub Min
{
    my @List = @_;
    if($#List == -1) { return 0; }
    else
    {
	my $min = $List[0];
	foreach my $item (@List)
	{
	    if($item < $min) { $min = $item; }
	}
	return $min;
    }
}


# $max = Max($item1, $item2, ...)
#    Returns the numerical maximum from an arbitrarily long parameter list.
sub Max
{
    my @List = @_;
    if($#List == -1) { return 0; }
    else
    {
	my $max = $List[0];
	foreach my $item (@List)
	{
	    if($item > $max) { $max = $item; }
	}
	return $max;
    }
}


# ($src, $tgt) = ReadNonterminal($bracketString)
#    Reads a bracketed string such as "[N::NP]" or "[:::PU]" and returns the
#    source- and target-side nonterminals as separate strings.
sub ReadNonterminal
{
    # Get parameters:
    my $bracketString = shift @_;
    my $src = "";
    my $tgt = "";

    # Parse a nonterminal with... four colons:
    if($bracketString =~ /^\[(.*:)::(:.*)\]$/)
    {
	($src, $tgt) = ($1, $2);
    }
    
    # ... Three colons:
    elsif($bracketString =~ /^\[(.*):::(.*)\]$/)
    {
	my ($left, $right) = ($1, $2);
	if($left eq "") { ($src, $tgt) = (":", $right); }
	elsif($right eq "") { ($src, $tgt) = ($left, ":"); }
	elsif(substr($left, -1) eq "-" && substr($left, -5) ne "-LRB-" &&
	      substr($left, -5) ne "-RRB-")
	{
	    ($src, $tgt) = ($left . ":", $right);
	}
	elsif(substr($right, 0, 1) eq "-" && substr($right, 0, 5) ne "-LRB-" &&
	      substr($right, 0, 5) ne "-RRB-")
	{
	    ($src, $tgt) = ($left, ":" . $right);
	}
    }

    # ... Two colons:
    elsif($bracketString =~ /^\[(.+)::(.+)\]$/)
    {
	($src, $tgt) = ($1, $2);
    }

    return ($src, $tgt);
}
