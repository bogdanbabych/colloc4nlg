#!/usr/bin/perl
#CGI script for accessing CWB files
#die "unknown error\n"
use utf8;
use CGI;
use CGI::Carp qw/fatalsToBrowser/;
use Encode qw/encode decode/;
use GDBM_File;
use CWB::CQP;
use CWB::CL;
use Getopt::Long;
use lib("/corpora/tools");
use smallutils;
use cqpquery4nlg;

#use strict;

$CGI::POST_MAX = 50 * 1024; # avoid denial-of-service attacks (accept max. 50k of POST data)
$spammessagelimit=1000;
binmode( STDOUT, ":utf8" );

readconffile('/corpora/tools/cqp.conf');
readmessagefile('/corpora/tools/messages.conf');

$|=1;

$originalquery=""; # the search string
$parallel;

$cgiquery = new CGI;

$corpuslist=uc(  $cgiquery->param("c") || $cgiquery->param("corpuslist") );
if ($corpuslist) { # CGI run
    $cqpsyntaxonly=$cgiquery->param("cqpsyntaxonly");
    $defaultattrname=$cgiquery->param("searchpositional") || $cgiquery->param("da") || $defaultattrname;

    @parallel=$cgiquery->param("parallel");
    $parallel=uc(join(',',@parallel));

    $originalquery= $cgiquery->param("q") || $cgiquery->param("searchstring");
    die if length($originalquery)>$spammessagelimit;
    $contextsize=$cgiquery->param("cs") || $cgiquery->param("contextsize")|| $contextsize;
    $sort1option=$cgiquery->param("sort1") || $cgiquery->param("s1");
    $sort2option=$cgiquery->param("sort2") || $cgiquery->param("s2");
    $terminate=$cgiquery->param("terminate") || $cgiquery->param("t") || $terminate;
    $terminate=min($terminate,$terminatemax);

    $transliterateout=$cgiquery->param("transliterateout");
    $transliteratein=$cgiquery->param("transliteratein");
    $showtranslations=$cgiquery->param("showtranslations");  # this is for interfacing a dictionary
    $annot=$cgiquery->param("annot");

    $collocationstat=(lc($cgiquery->param("searchtype") eq 'colloc'));
# collocations for NLG
    $collocation4nlg=(lc($cgiquery->param("searchtype") eq 'colloc4nlg'));
    # collocation statistics still should work
    if($collocation4nlg){
        # $collocationstat = $collocation4nlg;
    };
    
    
    
    
    
    $mistat=$cgiquery->param("mistat");
    $dstat=$cgiquery->param("dstat");
    $tstat=$cgiquery->param("tstat");
    $llstat=$cgiquery->param("llstat");
    $cutoff=$cgiquery->param("cutoff") || $cutoff;
    $collocspanleft=$cgiquery->param("collocspanleft") || $cgiquery->param("cleft");
    $collocspanright=$cgiquery->param("collocspanright") || $cgiquery->param("cright");
    $collocfilter=$cgiquery->param("collocfilter") || $cgiquery->param("cfilter");

# collocations for NLG
    $collocspanleft1=$cgiquery->param("collocspanleft1") || $cgiquery->param("cleft1");
    $collocspanright1=$cgiquery->param("collocspanright1") || $cgiquery->param("cright1");
    $collocfilter1=$cgiquery->param("collocfilter1") || $cgiquery->param("cfilter1");

    $collocspanleft2=$cgiquery->param("collocspanleft2") || $cgiquery->param("cleft2");
    $collocspanright2=$cgiquery->param("collocspanright2") || $cgiquery->param("cright2");
    $collocfilter2=$cgiquery->param("collocfilter2") || $cgiquery->param("cfilter2");

    $collocspanleft3=$cgiquery->param("collocspanleft3") || $cgiquery->param("cleft3");
    $collocspanright3=$cgiquery->param("collocspanright3") || $cgiquery->param("cright3");
    $collocfilter3=$cgiquery->param("collocfilter3") || $cgiquery->param("cfilter3");

    $collocspanleft4=$cgiquery->param("collocspanleft4") || $cgiquery->param("cleft4");
    $collocspanright4=$cgiquery->param("collocspanright4") || $cgiquery->param("cright4");
    $collocfilter4=$cgiquery->param("collocfilter4") || $cgiquery->param("cfilter4");

    if($collocation4nlg){

        @collocspans4nlg = ();
        push(@collocspans4nlg, "$collocspanleft1~$collocfilter1~$collocspanright1");
        push(@collocspans4nlg, "$collocspanleft2~$collocfilter2~$collocspanright2");
        push(@collocspans4nlg, "$collocspanleft3~$collocfilter3~$collocspanright3");
        push(@collocspans4nlg, "$collocspanleft4~$collocfilter4~$collocspanright4");
        
    
    };
    



    $learningrestrictlist=$cgiquery->param("learningrestrictlist");

    $encoding=$cgiquery->param("encoding") || $encoding;

#    $similaritysearch=$cgiquery->param("f");
    $debuglevel=$cgiquery->param('debuglevel') || $debuglevel;
} else { # non-CGI
    undef $cgiquery;
    GetOptions ('D=s' => \$corpuslist, 'parallel=s' => \$parallel, 'align=i' => \$showhorizontal, 'q=s' => \$originalquery, 's1=s' => \$sort1option, 's2=s' => \$sort2option, 'ini=s' => \$inifile, 'context=s' => \$contextsize, 
	'terminate=i' => \$terminate, 'coll=i' => \$collocationstat, 'vector=i' => \$maxvector, 'measure=s' => \$measure, 
	'leftspan=i' => \$collocspanleft, 'rightspan=i' => \$collocspanright, 'filter=s' => \$collocfilter, 'dictionary=s' => \$dictionary, 
	'span=i' => \$spansize, 'help' => \$help);
    $corpuslist=uc($corpuslist);
    if ($parallel) {
	@parallel=split ',',$parallel;
    };


    if ($collocationstat || $collocation4nlg) {
	$contextsizecl='1w';
	if ($measure) {
	    $mistat=$measure=~/M/;
	    $tstat=$measure=~/T/;
	    $llstat=$measure=~/L/;
	} else {
	    $llstat=1;
	}
    }
    if (-r $inifile) {
	require($inifile);
    }
}

open(STDLOG, ">>:utf8", "/corpora/query.log") or die "Cannot open the log file.";
print STDLOG "\n\n";

$starttime=scalar(localtime());
print STDLOG "Local time: $starttime; ";
$starttime=time();

if ($debuglevel) {
    open(DEBUGLOG, ">>:utf8", "/corpora/debug.log") or print STDLOG "Attempted write to debug failed: $!\n";
    printdebug("Local time:",scalar(localtime()),"; script $0\n");
};

$curlang=$corpuslang{$corpuslist} || 'en';

if ($curlang eq 'en') { # these are the standard source and target language corpora
    $dict=$dictionaryenru;
    $cname='BNC';
    $newcorpus='RNC2009-MOCKY';
} elsif  ($curlang eq 'ru') {
    $dict=$dictionaryruen;
    $cname='RNC2009-MOCKY';
    $newcorpus='BNC';
};

if ($learningrestrictlist) {
    $learningrestrictstr=getlearningrestrictlist($cgiquery);
}

($contextsize, $contexttype)=$contextsize=~/(\d+)\s*(\w*)/;
$contextsizewords=$contextsize;
if ($contexttype eq 's') {
    $contextsize=min($contextsize,3);
    $contextsizewords=$contextsize*15;
} elsif ($contexttype eq 'c') {
    $charsize=min($contextsize,150);
} else {
    $charsize=min($contextsize*6,30);
    $contexttype='word';
}

#get information about the query with appropriate guessing
$remote_host=getremotehost($cgiquery) if $cgiquery;
#die if $remote_host=~/primacom.net/;
# preprocess the query
#utest($originalquery);
if ($originalquery=~/\xC3[\x80-\xBF]/) {
    $latin1query=1;
    $searchtitle=decode('utf8',"$corpuslist: $originalquery");
    utf8::upgrade($originalquery);
} else {
    utf8::upgrade($originalquery);
    $originalquery=decode('utf8',$originalquery);
    $searchtitle="$corpuslist: $originalquery";
}


print "Content-type: text/html\; charset=$encoding\n\n";
print qq{<html><head><meta http-equiv="Content-Type" content="text/html; charset=$encoding">\n};
print qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="content-type" content="text/html; charset=$encoding" />
<meta name="Author" content="Serge Sharoff, hacked by Marco Baroni, ripped by Emiliano Guevara" />
<meta name="Keywords" content="Web Corpus" />
<title>$searchtitle</title>
<link href="/corpus.css" rel="stylesheet" type="text/css">
};

print qq{</head>\n<body>\n<div id="website">};


# test printing
print "collocationstat $collocationstat <br>\n";
print "collocation4nlg $collocation4nlg <br>\n";


if($collocation4nlg){
    @searchlist = split /\s+/, $originalquery;
    print "<strong>Query list:</strong><br>";
    foreach $query (@searchlist){
        print "$query";
        print "<br>";
    }
    # foreach $collocationspec (@collocspans4nlg){ print "CollocSpec: $collocationspec <br>\n" ;}
    
    
    
}
    
$searchstring=makecqpquery($originalquery);

if ($collocationstat) {
    $terminate=0;
    $contextsize=1;
    $contexttype='word';
    if ($collocspan) {
	$collocspan=min($maxcollocspan,$collocspan);
	$collocspanleft=$collocspan unless defined $collocspanleft;
	$collocspanright=$collocspan unless defined $collocspanright;
    };
    if (($collocfilter) and ($collocfilter=~/\S/)){
	eval {$searchstring=~/$collocfilter/};
	if ($@) {
	    cqperror( $messages{'filter-error'}," $@\n");
	}
    } else {
	undef $collocfilter;
    }
} elsif (collocation4nlg){
    # duplicating collocationstat
    $terminate=0;
    $contextsize=1;
    $contexttype='word';



} else {
    if ($terminate) {$searchstring.=" cut $terminate"};
}


print STDLOG "corpuslist=$corpuslist; \n";
print STDLOG "Using $learningrestrictlist known words per example. " if $learningrestrictlist;
print STDLOG "remote_host=$remote_host\n" unless $remote_host=~/leeds.ac.uk/;
print STDLOG "$searchstring"; # it'll be followed by the number of occurrences, if we do not die

#print STDOUT "<p><strong>Query</strong>:$searchstring</p>";

if ($originalquery=~/^\s*\[?\]?\s*$/) {
    print STDOUT $messages{'empty-condition'};
} elsif (($collocationstat) and ! (($mistat) or ($tstat) or ($llstat))) {
    print STDOUT $messages{'choose-score'};
} elsif(collocation4nlg) {
    
    @AofPairs = ();
    foreach $collocationspec (@collocspans4nlg){
        $numoccur = 0;
        # %pairs = ();
        $totalpairs = 0;
        print "CollocSpec: $collocationspec <br>\n" ;
        if ($collocationspec =~ /(.+)~(.*)~(.+)/){
            $collocspanleft= $1;
            $collocspanright = $3;
            $collocfilter = $2;
            print "&nbsp;Details: $collocspanleft ; $collocspanright ; $collocfilter <br>\n";
            @corpuslist=split ',', $corpuslist;
            foreach $corpus (@corpuslist) {   
                $numoccur+=processcorpus($corpus, $searchstring);
                                    
            }
        

        print STDLOG "Colloc: left=$collocspanleft, right=$collocspanright, collocfilter=$collocfilter\n";
        $numoccur=$totalpairs;
        # foreach $el (keys %paris){ print "Pair: $el <br>\n"}
        showcollocates();
        %hSavedPairs = %pairs;
        push @AofPairs, \%hSavedPairs;
        # print "Corp; Search; Occurrences: $corpus $searchstring $numoccur <br>\n";
            
        }
        
    }

    recombinePairs(@AofPairs);

    
} else { 
    $cqpprocesstime=0;
    if ($corpuslist eq 'RU') {
	$numoccur+=processcorpus('RNC2009-MOCKY',$searchstring);
	$numoccur+=processcorpus('INTERNET-RU',$searchstring);
	$numoccur+=processcorpus('NEWS-RU',$searchstring);
    } elsif ($corpuslist eq 'EN') {
	$numoccur+=processcorpus('BNC',$searchstring);
	$numoccur+=processcorpus('NEWS-GB', $searchstring);
	$numoccur+=processcorpus('INTERNET-EN', $searchstring);
    } elsif ($corpuslist eq 'DE-WAC') {
	foreach $part (1 .. 10) {
	    $corpus = sprintf "DEWAC%02d", $part;
	    $numoccur+=processcorpus($corpus, $searchstring);
	}
    } else {
	@corpuslist=split ',', $corpuslist;
	foreach $corpus (@corpuslist) {
	    $numoccur+=processcorpus($corpus, $searchstring);
	}
    };

    if ($errormessage) {
#the error message has been printed anyway
    } else {
	if ($collocationstat) {
	    print STDLOG "Colloc: left=$collocspanleft, right=$collocspanright, collocfilter=$collocfilter\n";
	    $numoccur=$totalpairs;
	    showcollocates();
	} elsif ($numoccur) {
	    showconcordance(\@storecontexts,0);
	}
	elsif ($learningrestrictlist) {  
	    printf $messages{'noknownwords'},$learningrestrictstr;
	} else {
	    printf $messages{'notfound'}, $searchstring, $corpuslist, $curlang;
	};
	print STDLOG " occurred $numoccur time(s). ";
	$processtime=time()-$starttime;
	print STDLOG "Total process time: $processtime sec; CQP process time: $cqpprocesstime sec.\n";
    }
};

print STDOUT "</html>\n";
close(STDLOG);

sub utest {
$x=(utf8::is_utf8($_[0])) ? utf8 : noutf8;
print STDERR length($_[0]),": $x, $_[0]\n";
}
