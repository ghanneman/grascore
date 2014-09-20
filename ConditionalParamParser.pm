package ConditionalParamParser;
@EXPORT = qw(GetParams);

use strict;


# Official flag names to specify which columns are in the numerator and which
# are in the denominator of conditional probability scores:
my $SCORE_FLAG = "--score";     # numerator
my $COND_FLAG = "--cond";       # denominator
my $TYPE_FLAG = "--type";       # type of score to compute
my $NAME_FLAG = "--name";       # name of this feature
my $SNFILE_FLAG = "--sn-file";  # file of score names
my $CLOG_FLAG = "--count-log";  # file of denominator counts

# Official column names, to be used as arguments to the above:
# NOTE: Indexes are 0-based for ease of Perl-internal use!
my %Columns = (
    "type" => 0,
    "lhs" => 1,
    "src-rhs" => 2,
    "tgt-rhs" => 3,
    );

# Official type names, to determine which kind of score to compute:
my %Types = (
    "prob" => "compute p($SCORE_FLAG | $COND_FLAG)",
    "counts" => "compute #($SCORE_FLAG, $COND_FLAG) and #($COND_FLAG)",
    "entropy" => "compute H($SCORE_FLAG) within $COND_FLAG",
    "perp" => "compute 2^H($SCORE_FLAG) within $COND_FLAG",
    "gain" => "x",
    );


sub PrintUsage
{
    print STDERR "Usage:\n";
    print STDERR "    cat <rules> | \\\n";
    print STDERR "    perl $0 \\\n";
    print STDERR "        [$SCORE_FLAG <col-name>]+ \\\n";
    print STDERR "        [$COND_FLAG <col-name>]+ \\\n";
    print STDERR "        $TYPE_FLAG <type> \\\n";
    print STDERR "        $NAME_FLAG <feat-name>\n";
    print STDERR "        $SNFILE_FLAG <sn-file>\n";
    print STDERR "        [$CLOG_FLAG <log-file>]\n";
    print STDERR "Column names for <col-name>:\n";
    foreach my $col (keys %Columns) { print STDERR "    $col\n"; }
    print STDERR "Type names for <type>:\n";
    foreach my $type (keys %Types)
    {
	print STDERR "    $type : $Types{$type}\n";
    }
    print STDERR "\nComputes the feature indicated by <type> and calls it <feat-name>.  The input\n";
    print STDERR "file <sn-file> contains a space-separated list of scores already appearing\n";
    print STDERR "in <rules>; it will be OVERWRITTEN with an updated list upon output.  The\n";
    print STDERR "optional <log-file> will contain a list of denominator values from the\n";
    print STDERR "feature and their counts.\n\n";
    print STDERR "WARNING:  Input <rules> must be sorted by the $COND_FLAG columns!\n";
}


sub GetParams
{
    # Get function parameters:
    my @Args = @_;

    # Read through input args one by one; collect lists of numerator and
    # denominator column numbers, along with feature name and score type:
    my @NumCols = ();
    my @DenomCols = ();
    my $name = "";
    my $scoreType = "";
    my $snFile = "";
    my $clogFile = "";
    for(my $i = 0; $i <= $#Args; $i++)
    {
	if($Args[$i] eq $SCORE_FLAG)
	{
	    # Found a numerator column:
	    $i++;
	    if(exists($Columns{$Args[$i]}))
	    {
		# Add this column to the list of numerator columns:
		push(@NumCols, $Columns{$Args[$i]});
	    }
	    else
	    {
		print STDERR "ERROR:  Invalid column name '$Args[$i]'.\n";
		PrintUsage();
		exit(1);
	    }
	}
	elsif($Args[$i] eq $COND_FLAG)
	{
	    # Found a denominator column:
	    $i++;
	    if(exists($Columns{$Args[$i]}))
	    {
		# Add this column to the list of denominator columns:
		push(@DenomCols, $Columns{$Args[$i]});
	    }
	    else
	    {
		print STDERR "ERROR:  Invalid column name '$Args[$i]'.\n";
		PrintUsage();
		exit(1);
	    }
	}
	elsif($Args[$i] eq $NAME_FLAG)
	{
	    # Found the name of this feature:
	    $i++;
	    if($name eq "") { $name = $Args[$i]; }
	    else
	    {
		print STDERR "ERROR:  Tried to name feature twice ('$name' vs. '$Args[$i]').  Pick just one!\n";
		PrintUsage();
		exit(1);
	    }
	}
	elsif($Args[$i] eq $TYPE_FLAG)
	{
	    # Found the type of this feature:
	    $i++;
	    if(exists($Types{$Args[$i]}))
	    {
		if($scoreType eq "") { $scoreType = $Args[$i]; }
		else
		{
		    print STDERR "ERROR:  Tried to set score type twice ('$scoreType' vs. '$Args[$i]').  Pick just one!\n";
		    PrintUsage();
		    exit(1);
		}
	    }
	    else
	    {
		print STDERR "ERROR:  Invalid type name '$Args[$i]'.\n";
		PrintUsage();
		exit(1);
	    }
	}
	elsif($Args[$i] eq $SNFILE_FLAG)
	{
	    # Found the name of the score-names file:
	    $i++;
	    if($snFile eq "") { $snFile = $Args[$i]; }
	    else
	    {
		print STDERR "ERROR:  Tried to specify the score-names file twice ('$snFile' vs. '$Args[$i]').  Pick just one!\n";
		PrintUsage();
		exit(1);
	    }
	}
	elsif($Args[$i] eq $CLOG_FLAG)
	{
	    # Found the name of the count-log file:
	    $i++;
	    if($clogFile eq "") { $clogFile = $Args[$i]; }
	    else
	    {
		print STDERR "ERROR:  Tried to specify the count-log file twice ('$clogFile' vs '$Args[$i]').  Pick just one!\n";
		PrintUsage();
		exit(1);
	    }
	}
	else
	{
	    # Found something unexpected:
	    print STDERR "ERROR:  Invalid argument '$Args[$i]'.\n";
	    PrintUsage();
	    exit(1);
	}
    }

    # Now we have the column lists: make sure at least one in each:
    if($#NumCols < 0 || $#DenomCols < 0)
    {
	print STDERR "ERROR:  Must specify at least one column each for $SCORE_FLAG and $COND_FLAG.\n";
	PrintUsage();
	exit(1);
    }

    # And we want a feature name, score type, and score-names file too:
    if($name eq "")
    {
	print STDERR "ERROR:  Must specify feature name ($NAME_FLAG).\n";
	PrintUsage();
	exit(1);
    }
    if($scoreType eq "")
    {
	print STDERR "ERROR:  Must specify score type ($TYPE_FLAG).\n";
	PrintUsage();
	exit(1);
    }
    if($snFile eq "")
    {
	print STDERR "ERROR:  Must specify score-names file ($SNFILE_FLAG).\n";
	PrintUsage();
	exit(1);
    }

    # Pack into hash to return:
    @NumCols = sort {$a <=> $b} @NumCols;
    @DenomCols = sort {$a <=> $b} @DenomCols;
    # TEMP DEBUG BLOCK:
    print STDERR "num : [@NumCols]\n";
    print STDERR "denom : [@DenomCols]\n";
    print STDERR "name : [$name]\n";
    print STDERR "type : [$scoreType]\n";
    print STDERR "snfile : [$snFile]\n";
    print STDERR "clogfile : [$clogFile]\n";
    ###################
    return ('num' => "@NumCols", 'denom' => "@DenomCols",
	    'name' => $name, 'type' => $scoreType,
	    'snfile' => $snFile, 'clogfile' => $clogFile);
}
