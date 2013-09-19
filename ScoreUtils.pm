package ScoreUtils;
@EXPORT = qw(ReadNonterminal);

use strict;


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
